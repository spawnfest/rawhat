import gleam/dynamic.{Decoder, Dynamic}
import gleam/erlang/atom.{Atom}
import gleam/erlang/process.{Pid, Subject}
import gleam/function
import gleam/int
import gleam/list
import gleam/map.{Map}
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import rappel/lsp/client
import shellout

pub type Message {
  Request(id: Int, message: String, caller: Subject(String))
  Notify(message: String)
  Response(message: String)
  InvalidResponse(Dynamic)
  Shutdown(done: Subject(Nil))
}

pub type State {
  State(
    buffer: String,
    port: Port,
    has_initialized: Bool,
    temp_dir: String,
    pending_requests: Map(Int, Subject(String)),
    self: Subject(Message),
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
        port_command(port, msg)
        let pid = port_pid(port)
        let assert True = process.link(pid)

        actor.Ready(State("", port, False, temp_dir, map.new(), subj), selector)
      },
      init_timeout: 1000,
      loop: fn(msg, state) {
        case msg, state.has_initialized {
          Shutdown(done), _ -> {
            // NOTE:  This should do the whole
            // "shutdown request -> response -> exit" process, but I don't feel
            // like doing that
            port_command(state.port, client.exit())
            let os_pid = port_os_pid(state.port)
            port_close(state.port)
            // why won't you DIE
            let assert Ok(_) =
              shellout.command(
                "kill",
                with: ["-9", int.to_string(os_pid)],
                in: ".",
                opt: [],
              )
            process.send(done, Nil)
            actor.Stop(process.Normal)
          }
          Request(id, req, caller), True -> {
            port_command(state.port, req)
            let pending = map.insert(state.pending_requests, id, caller)
            actor.continue(State(..state, pending_requests: pending))
          }
          Notify(msg), True -> {
            port_command(state.port, msg)
            actor.continue(state)
          }
          Notify(_message), False -> {
            process.send_after(state.self, 200, msg)
            actor.continue(state)
          }
          InvalidResponse(_err), _ -> {
            actor.continue(state)
          }
          Response("Hello human!" <> _rest), _has_initialized -> {
            actor.continue(state)
          }
          Response(_resp), False -> {
            port_command(state.port, client.initialized())
            actor.continue(State(..state, has_initialized: True))
          }
          Response(resp), True -> {
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
                          let hover_info =
                            data.result.contents
                            |> option.map(fn(contents) {
                              contents
                              |> string.replace("```gleam", "")
                              |> string.replace("```", "")
                              |> string.trim
                            })
                            |> option.unwrap("")
                          process.send(subj, hover_info)
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

pub fn get_hover_index(command: String) -> Int {
  case command {
    "let " <> _command -> 4
    _ -> 0
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

@external(erlang, "erlang", "port_close")
fn port_close(dest: Port) -> Bool

@external(erlang, "erlang", "port_info")
fn port_info(dest: Port) -> List(#(Atom, Dynamic))

// NOTE:  don't do this
fn port_pid(port: Port) -> Pid {
  let info = port_info(port)
  let assert Ok(#(_key, value)) =
    list.find(
      info,
      fn(item) {
        let assert #(key, _value) = item
        key == atom.create_from_string("links")
      },
    )

  let assert [link] = dynamic.unsafe_coerce(value)
  link
}

fn port_os_pid(port: Port) -> Int {
  let info = port_info(port)
  let assert Ok(#(_key, value)) =
    list.find(
      info,
      fn(item) {
        let assert #(key, _value) = item
        key == atom.create_from_string("os_pid")
      },
    )

  dynamic.unsafe_coerce(value)
}
