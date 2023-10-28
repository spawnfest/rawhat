import gleam/dynamic.{Dynamic}
import gleam/io
import gleam/erlang/atom.{Atom}
import gleam/erlang/process.{Pid, Selector}
import gleam/function

@external(erlang, "io", "setopts")
fn set_opts(opts: List(#(Atom, Dynamic))) -> any

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
      loop(selector, Nil)
    },
    True,
  )
}

fn loop(self: Selector(Dynamic), state: any) -> any {
  let msg = process.select_forever(self)
  io.debug(#("got a msg", msg))
  loop(self, state)
}
