import gleam/bit_string
import gleam/dynamic.{Dynamic}
import gleam/erlang/charlist.{Charlist}
import gleam/erlang/process.{Subject}
import gleam/list
import gleam/map.{Map}
import gleam/option.{None}
import gleam/otp/actor
import gleam/string
import rappel/generator
import rappel/environment.{Environment}
import glance.{
  Definition, Function, Module, Private, Statement, UnexpectedEndOfInput,
}

pub type Message {
  Evaluate(command: String, caller: Subject(BitString))
  AddImport(command: String)
}

pub type State {
  State(environment: Environment)
}

fn new_state() -> State {
  State(environment: environment.new())
}

import gleam/io

pub fn start() -> Subject(Message) {
  let assert Ok(subj) =
    actor.start(
      new_state(),
      fn(msg, state) {
        case msg {
          Evaluate("\n", caller) -> {
            process.send(caller, <<>>)
            actor.continue(state)
          }
          Evaluate(command, caller) -> {
            let assert Ok(sample) =
              command
              |> encode
              |> decode
              |> generator.generate(state.environment)
            let eval_result = evaluate(sample.generated)
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
                    Ok(value) -> environment.define_variable(env, label, value)
                    _ -> env
                  }
                },
              )
            process.send(
              caller,
              bit_string.from_string(string.inspect(eval_result)),
            )
            actor.continue(State(environment: new_env))
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

type EvalResult(unknown) {
  Value(Dynamic, unknown)
}

@external(erlang, "erl_scan", "string")
fn scan_string(str: Charlist) -> #(ok, List(Token), unknown)

@external(erlang, "erl_parse", "parse_exprs")
fn parse_exprs(tokens: List(Token)) -> Result(ParseResult, Nil)

@external(erlang, "erl_eval", "exprs")
fn eval_exprs(parsed: ParseResult, unused: List(any)) -> EvalResult(unknown)

pub fn evaluate(code: String) -> Dynamic {
  let assert #(_ok, tokens, _unknown) =
    scan_string(charlist.from_string(code <> "."))
  let assert Ok(parse_result) = parse_exprs(tokens)
  let assert Value(return, _unknown) = eval_exprs(parse_result, [])
  return
}

pub fn encode(code: String) -> Module {
  let assert Ok(mod) = glance.module("fn main() { " <> code <> " }")
  mod
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
    #(module_name, module_path),
    ..qualified_imports
    |> string.drop_left(1)
    |> string.drop_right(1)
    |> string.split(",")
    |> list.map(string.trim)
    |> list.filter(fn(str) { string.is_empty(str) == False })
    |> list.map(fn(qualified) { #(qualified, module_path <> ":" <> qualified) })
  ]
}
