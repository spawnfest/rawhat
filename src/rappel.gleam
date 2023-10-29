import gleam/erlang/atom.{Atom}
import gleam/erlang/process.{Subject}
import gleam/function

type MFA =
  #(Atom, Atom, List(Subject(Nil)))

@external(erlang, "code", "ensure_loaded")
fn ensure_loaded(module: Atom) -> any

@external(erlang, "shell", "start_interactive")
fn start_interactive(mfa: MFA) -> any

pub fn main() {
  let subj = process.new_subject()

  ensure_loaded(atom.create_from_string("prim_tty"))

  let mfa = #(
    atom.create_from_string("rappel@shell"),
    atom.create_from_string("start"),
    [subj],
  )

  start_interactive(mfa)

  let selector =
    process.new_selector()
    |> process.selecting(subj, function.identity)

  process.select_forever(selector)
}
