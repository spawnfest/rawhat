import gleam/dynamic.{Dynamic}
import gleam/io
import gleam/erlang/atom.{Atom}
import gleam/erlang/process.{Selector, Subject}
import gleam/function
import gleam/string
import rappel/evaluator

@external(erlang, "io", "setopts")
fn set_opts(opts: List(#(Atom, Dynamic))) -> any

@external(erlang, "io", "put_chars")
fn put_chars(chars: String) -> any

@external(erlang, "io", "get_line")
fn get_line(prompt: String) -> String

const welcome_message = "Welcome to the Gleam shell ✨\n\n"

pub type State {
  State(eval: Subject(evaluator.Message))
}

pub fn start() {
  process.start(
    fn() {
      let selector =
        process.new_selector()
        |> process.selecting_anything(function.identity)
      set_opts([
        #(atom.create_from_string("binary"), dynamic.from(True)),
        #(
          atom.create_from_string("encoding"),
          dynamic.from(atom.create_from_string("unicode")),
        ),
      ])
      let eval = evaluator.start()
      put_chars(welcome_message)
      loop(selector, State(eval))
    },
    True,
  )
}

fn loop(self: Selector(Dynamic), state: State) -> any {
  let msg = get_line("gleam> ")
  case msg {
    "import " <> _imports -> process.send(state.eval, evaluator.AddImport(msg))
    command -> {
      let resp =
        process.try_call(state.eval, evaluator.Evaluate(command, _), 5000)
      case resp {
        Ok(val) -> {
          io.debug(val)
          Nil
        }
        Error(reason) -> {
          io.print("Error: ")
          io.println(string.inspect(reason))
        }
      }
    }
  }
  loop(self, state)
}
