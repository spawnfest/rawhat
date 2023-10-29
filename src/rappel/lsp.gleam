import gleam/dynamic.{Decoder, Dynamic}
import gleam/erlang/atom.{Atom}
import gleam/erlang/process.{Subject}
import gleam/function
import gleam/io
import gleam/list
import gleam/map.{Map}
import gleam/option
import gleam/result
import gleam/otp/actor
import rappel/lsp/client

pub type Message {
  Request(id: Int, message: String, caller: Subject(String))
  Response(message: String)
  InvalidResponse(Dynamic)
  Shutdown
}

pub type State {
  State(
    buffer: String,
    port: Port,
    has_initialized: Bool,
    temp_dir: String,
    pending_requests: Map(Int, Subject(String)),
  )
}

pub fn open(temp_dir: String) -> Subject(Message) {
  let spawn = atom.create_from_string("spawn")
  let assert Ok(subj) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let subj = process.new_subject()
        let selector =
          process.new_selector()
          |> process.selecting(subj, function.identity)
          |> process.selecting_anything(fn(msg) {
            port_message_decoder()(msg)
            |> result.map(Response)
            |> result.map_error(fn(err) { InvalidResponse(dynamic.from(err)) })
            |> result.unwrap_both
          })

        let port =
          open_port(
            #(spawn, "gleam lsp"),
            [Binary, UseStdio, StderrToStdout, Cd(temp_dir)],
          )
        let msg = client.initialize()
        io.println(msg)
        port_command(port, msg)

        actor.Ready(State("", port, False, temp_dir, map.new()), selector)
      },
      init_timeout: 1000,
      loop: fn(msg, state) {
        io.debug(#("raw message from port", msg))
        case msg, state.has_initialized {
          Request(id, req, caller), True -> {
            io.debug(#("issuing", req))
            port_command(state.port, req)
            let pending = map.insert(state.pending_requests, id, caller)
            actor.continue(State(..state, pending_requests: pending))
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
            actor.continue(State(..state, has_initialized: True))
          }
          Response(resp), True -> {
            io.debug(#("got a response", resp))
            let #(messages, rest) = get_messages(resp, [])
            // TODO:  refactor?
            let new_state =
              list.fold(
                messages,
                state,
                fn(state, message) {
                  case client.decode(message) {
                    Ok(data) -> {
                      case map.get(state.pending_requests, data.id) {
                        Ok(subj) -> {
                          process.send(
                            subj,
                            option.unwrap(data.result.contents, ""),
                          )
                          let new_pending =
                            map.delete(state.pending_requests, data.id)
                          State(..state, pending_requests: new_pending)
                        }
                        _ -> {
                          state
                        }
                      }
                    }
                    _ -> {
                      state
                    }
                  }
                },
              )
            actor.continue(State(..new_state, buffer: rest))
          }
        }
      },
    ))

  subj
}

fn get_messages(resp: String, messages: List(String)) -> #(List(String), String) {
  case client.parse_message(resp) {
    Ok(#(message, "")) -> #([message, ..messages], "")
    Ok(#(message, rest)) -> get_messages(rest, [message, ..messages])
    Error(rest) -> #(messages, rest)
  }
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
