import gleeunit/should
import gleam/option.{Some}
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

pub fn it_should_parse_valid_hover_message_test() {
  let msg = "{\"jsonrpc\":\"2.0\",\"id\":85,\"result\":{\"contents\":\"```gleam\\nInt\\n```\\n\",\"range\":{\"end\":{\"character\":7,\"line\":1},\"start\":{\"character\":4,\"line\":1}}}}"

  client.decode(msg)
  |> should.equal(Ok(client.Response(
    id: 85,
    result: client.Hover(
      contents: Some("```gleam\\nInt\\n```\\n")
    )
  )))
}
