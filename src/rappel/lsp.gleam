import gleam/base
import gleam/crypto
import gleam/dynamic.{Decoder, Dynamic}
import gleam/erlang/atom.{Atom}
import gleam/erlang/process.{Subject}
import gleam/io
import gleam/result
import gleam/otp/actor
import gleam/string
import rappel/lsp/client
import shellout

pub type Message {
  UpdateDocument(String)
  Request(String)
  Response(String)
  InvalidResponse(Dynamic)
  Shutdown
}

pub type State {
  State(
    port: Port,
    has_initialized: Bool,
    temp_dir: String,
    file_name: String,
    request_id: Int,
  )
}

pub fn open() -> Subject(Message) {
  let spawn = atom.create_from_string("spawn")
  let assert Ok(subj) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let assert Ok(tmpdir) =
          shellout.command("mktemp", with: ["--directory"], in: ".", opt: [])

        let subj = process.new_subject()
        let selector =
          process.new_selector()
          |> process.selecting(subj, Request)
          |> process.selecting_anything(fn(msg) {
            port_message_decoder()(msg)
            |> result.map(Response)
            |> result.map_error(fn(err) { InvalidResponse(dynamic.from(err)) })
            |> result.unwrap_both
          })

        let port =
          open_port(
            #(spawn, "gleam lsp"),
            [Binary, UseStdio, StderrToStdout, Cd(tmpdir)],
          )
        let msg = client.initialize()
        io.println(msg)
        port_command(port, msg)
        let filename =
          "rappel_" <> base.encode64(crypto.strong_random_bytes(12), False) <> ".gleam"

        io.debug(#("temp dir is", tmpdir, "with filename", filename))

        actor.Ready(
          State(port, False, string.trim(tmpdir), filename, 1),
          selector,
        )
      },
      init_timeout: 1000,
      loop: fn(msg, state) {
        case msg, state.has_initialized {
          Request(req), True -> {
            port_command(state.port, req)
            actor.continue(state)
          }
          InvalidResponse(err), _ -> {
            io.debug(#("Got a bad message", err))
            actor.continue(state)
          }
          Response("Hello human!" <> _rest), _has_initialized -> {
            actor.continue(state)
          }
          Response(resp), False -> {
            io.debug(#("got a response", resp))
            io.println("sending initialized")
            port_command(state.port, client.initialized())
            actor.continue(
              State(
                ..state,
                has_initialized: True,
                request_id: state.request_id + 1,
              ),
            )
          }
          Response(resp), True -> {
            io.debug(#("got a response", resp))
            let file = "./" <> state.file_name
            port_command(state.port, client.hover(state.request_id, file, 1))
            actor.continue(state)
          }
        }
      },
    ))

  subj
}

fn port_message_decoder() -> Decoder(String) {
  dynamic.element(1, dynamic.element(1, dynamic.string))
}

type Opts {
  // Packet(Int)
  Cd(String)
  // Args(List(String))
  Binary
  UseStdio
  StderrToStdout
}

pub type Port

@external(erlang, "erlang", "open_port")
fn open_port(command: #(Atom, String), opts: List(Opts)) -> Port

@external(erlang, "erlang", "port_command")
fn port_command(dest: Port, msg: any) -> Bool
