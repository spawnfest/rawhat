import gleam/dynamic.{Dynamic}
import gleam/erlang/charlist.{Charlist}
import gleam/erlang/process.{Subject}
import gleam/erlang
import gleam/list
import gleam/map
import gleam/option.{None}
import gleam/otp/actor
import gleam/result
import gleam/string
import rappel/generator
import rappel/environment.{BindingStruct, Environment}
import glance.{
  Definition, Function, Module, Private, Statement, UnexpectedEndOfInput,
}

pub type Message {
  Evaluate(command: String, caller: Subject(Result(Dynamic, String)))
  AddImport(command: String)
}

pub type State {
  State(environment: Environment)
}

fn new_state() -> State {
  State(environment: environment.new())
}

pub fn start() -> Subject(Message) {
  let assert Ok(subj) =
    actor.start(
      new_state(),
      fn(msg, state) {
        case msg {
          Evaluate("\n", caller) -> {
            process.send(caller, Ok(dynamic.from(Nil)))
            actor.continue(state)
          }
          Evaluate(command, caller) -> {
            command
            |> encode
            |> result.map(decode)
            |> result.then(fn(code) {
              generator.generate(code, state.environment)
              |> result.replace_error(Nil)
            })
            |> result.then(fn(sample) {
              case evaluate(sample.generated, state.environment.bindings) {
                Ok(pair) -> Ok(#(sample, pair))
                Error(reason) -> Error(reason)
              }
            })
            |> result.map(fn(res) {
              let assert #(sample, #(eval_result, bindings)) = res
              // TODO: :( do i need to do this?
              let decoders =
                generator.get_decoders_for_return(sample.return_shape)
              let new_env =
                decoders
                |> map.to_list
                |> list.fold(
                  state.environment,
                  fn(env, pair) {
                    let label = pair.0
                    let decoder = pair.1
                    case decoder(eval_result) {
                      Ok(value) ->
                        environment.define_variable(env, label, value)
                      _ -> env
                    }
                  },
                )
              let new_env = environment.merge_bindings(new_env, bindings)
              process.send(caller, Ok(eval_result))
              actor.continue(State(environment: new_env))
            })
            |> result.map_error(fn(_nil) {
              process.send(
                caller,
                Error("Invalid syntax or failed to execute."),
              )
              actor.continue(state)
            })
            |> result.unwrap_both
          }
          AddImport(str) -> {
            let imports = resolve_import(str)
            let new_env =
              imports
              |> list.fold(
                state.environment,
                fn(env, import_) { environment.add_import(env, import_) },
              )
            actor.continue(State(environment: new_env))
          }
        }
      },
    )
  subj
}

type Token

type ParseResult

type EvalResult {
  Value(Dynamic, BindingStruct)
}

@external(erlang, "rappel_ffi", "scan_string")
fn scan_string(str: Charlist) -> Result(List(Token), #(Dynamic, Dynamic))

@external(erlang, "erl_parse", "parse_exprs")
fn parse_exprs(tokens: List(Token)) -> Result(ParseResult, Nil)

@external(erlang, "erl_eval", "exprs")
fn eval_exprs(
  parsed: ParseResult,
  bindings: environment.BindingStruct,
) -> EvalResult

pub fn evaluate(
  code: String,
  bindings: BindingStruct,
) -> Result(#(Dynamic, BindingStruct), Nil) {
  use tokens <- result.try(result.replace_error(
    scan_string(charlist.from_string(code <> ".")),
    Nil,
  ))
  use parse_result <- result.try(parse_exprs(tokens))
  use Value(return, new_bindings) <- result.try(result.replace_error(
    erlang.rescue(fn() { eval_exprs(parse_result, bindings) }),
    Nil,
  ))

  Ok(#(return, new_bindings))
}

pub fn encode(code: String) -> Result(Module, Nil) {
  glance.module("fn main() { " <> code <> " }")
  |> result.replace_error(Nil)
}

pub fn decode(mod: Module) -> Statement {
  let assert Ok(statement) = case mod {
    Module(
      [],
      [],
      [],
      [],
      [],
      [],
      [Definition([], Function("main", Private, [], None, [statement], _span))],
    ) -> Ok(statement)
    _ -> Error(UnexpectedEndOfInput)
  }
  statement
}

pub fn resolve_import(str: String) -> List(#(String, String)) {
  let assert "import " <> rest = string.trim(str)
  let [import_path, qualified_imports] = case string.split(rest, ".") {
    [import_path] -> [import_path, ""]
    both -> both
  }

  let module_segments = string.split(import_path, "/")
  let module_path = string.join(module_segments, "@")

  let assert Ok(module_name) = list.last(module_segments)

  [
    #(module_name, string.trim(module_path)),
    ..qualified_imports
    |> string.drop_left(1)
    |> string.drop_right(1)
    |> string.split(",")
    |> list.map(string.trim)
    |> list.filter(fn(str) { string.is_empty(str) == False })
    |> list.map(fn(qualified) { #(qualified, module_path <> ":" <> qualified) })
  ]
}
