import gleam/dynamic.{Dynamic}
import gleam/erlang/atom.{Atom}
import gleam/erlang/process
import gleam/io
import gleam/map.{Map}

type MFA =
  #(Atom, Atom, List(Dynamic))

@external(erlang, "user_drv", "start")
fn user_drv_start(args: Map(Atom, MFA)) -> any

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
  let ret =
    // [
    //   dynamic.from(atom.create_from_string("tty_sl -c -e")),
    //   dynamic.from(#(
    //     atom.create_from_string("rappel@shell"),
    //     atom.create_from_string("start"),
    //     [],
    //   )),
    // ]
    map.from_list([#(atom.create_from_string("initial_shell"), mfa)])
    |> user_drv_start

  io.debug(#("return from drv", ret))

  start_interactive(mfa)

  process.sleep_forever()
}
