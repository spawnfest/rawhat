import gleam/dynamic.{Dynamic}
import gleam/erlang/atom.{Atom}
import gleam/erlang/process.{Selector, Subject}
import gleam/function
import gleam/int
import gleam/io
import gleam/result
import gleam/string
import rappel/evaluator
import rappel/lsp
import rappel/lsp/client
import rappel/lsp/package.{Package}
import shellout

@external(erlang, "io", "setopts")
fn set_opts(opts: List(#(Atom, Dynamic))) -> any

@external(erlang, "io", "put_chars")
fn put_chars(chars: String) -> any

@external(erlang, "io", "get_line")
fn get_line(prompt: String) -> String

@external(erlang, "shell", "strings")
fn shell_strings(toggle: Bool) -> Nil

const welcome_message = "Welcome to the Gleam shell ✨\n\n"

pub type State {
  State(
    eval: Subject(evaluator.Message),
    lsp: Subject(lsp.Message),
    package: Package,
  )
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

      shell_strings(True)

      let assert Ok(tmpdir) =
        shellout.command("mktemp", with: ["--directory"], in: ".", opt: [])
      let tmpdir = string.trim(tmpdir)
      let pkg = package.new(tmpdir)
      let assert Ok(_) = package.write(pkg)

      let eval = evaluator.start()
      let client = lsp.open(tmpdir)
      put_chars(welcome_message)
      loop(selector, State(eval, client, pkg))
    },
    True,
  )
}

fn loop(self: Selector(Dynamic), state: State) -> any {
  let msg = get_line("gleam> ")
  case msg {
    "import " <> _imports -> {
      process.send(state.eval, evaluator.AddImport(msg))
      let new_package = package.add_import(state.package, msg)
      let assert Ok(_) = package.write(new_package)
      let new_state = State(..state, package: new_package)
      loop(self, new_state)
    }
    command -> {
      let resp =
        process.try_call(state.eval, evaluator.Evaluate(command, _), 5000)
        |> result.replace_error("Command took longer than 5s...")
      let new_state = case result.flatten(resp) {
        Ok(val) -> {
          io.debug(val)
          let new_package = package.append_code(state.package, command)
          let assert Ok(_) = package.write(new_package)
          let index = package.last_line_index(new_package)
          io.debug(#("issuing hover at", index))
          let assert Ok(resp) =
            process.try_call(
              state.lsp,
              fn(subj) {
                let id = int.random(0, 1000)
                lsp.Request(
                  id,
                  client.hover(id, package.source_file(new_package), index),
                  subj,
                )
              },
              5000,
            )
          io.debug(#("we got a resp!", resp))
          State(..state, package: new_package)
        }
        Error(reason) -> {
          io.print("Error: ")
          io.println(string.inspect(reason))
          state
        }
      }
      loop(self, new_state)
    }
  }
}
