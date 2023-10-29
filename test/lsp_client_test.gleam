import gleeunit/should
import rappel/lsp/client

pub fn it_should_parse_multiple_messages_test() {
  let msg =
    "Content-Length: 133\r\n\r\n{\"jsonrpc\":\"2.0\",\"id\":\"create-compiling-gleam\",\"method\":\"window/workDoneProgress/create\",\"params\":{\"token\":\"create-compiling-gleam\"}}Content-Length: 142\r\n\r\n{\"jsonrpc\":\"2.0\",\"id\":\"create-compiling-gleam\",\"method\":\"window/workDoneProgress/create\",\"params\":{\"token\":\"create-downloading-dependencies\"}}"

  let resp = client.parse_message(msg)

  resp
  |> should.equal(Ok(#(
    "{\"jsonrpc\":\"2.0\",\"id\":\"create-compiling-gleam\",\"method\":\"window/workDoneProgress/create\",\"params\":{\"token\":\"create-compiling-gleam\"}}",
    "Content-Length: 142\r\n\r\n{\"jsonrpc\":\"2.0\",\"id\":\"create-compiling-gleam\",\"method\":\"window/workDoneProgress/create\",\"params\":{\"token\":\"create-downloading-dependencies\"}}",
  )))

  let assert Ok(#(_msg, rest)) = resp

  let resp = client.parse_message(rest)

  resp
  |> should.equal(Ok(#(
    "{\"jsonrpc\":\"2.0\",\"id\":\"create-compiling-gleam\",\"method\":\"window/workDoneProgress/create\",\"params\":{\"token\":\"create-downloading-dependencies\"}}",
    "",
  )))
}
