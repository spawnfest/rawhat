import gleam/dynamic.{Dynamic}
import gleam/erlang/atom.{Atom}
import gleam/erlang/process

type MFA =
  #(Atom, Atom, List(Dynamic))

@external(erlang, "code", "ensure_loaded")
fn ensure_loaded(module: Atom) -> any

@external(erlang, "shell", "start_interactive")
fn start_interactive(mfa: MFA) -> any

pub fn main() {
  ensure_loaded(atom.create_from_string("prim_tty"))

  let mfa = #(
    atom.create_from_string("rappel@shell"),
    atom.create_from_string("start"),
    [],
  )

  start_interactive(mfa)

  process.sleep_forever()
}
