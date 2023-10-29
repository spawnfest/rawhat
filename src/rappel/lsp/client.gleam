//// REQUEST
//// RESPONSE

import gleam/dynamic.{Dynamic}
import gleam/int
import gleam/json
import gleam/map.{Map}
import gleam/option.{Option}
import gleam/result
import gleam/string

// interface Message {
// 	jsonrpc: string;
// }
// interface RequestMessage extends Message {
//
// 	/**
// 	 * The request id.
// 	 */
// 	id: integer | string;
//
// 	/**
// 	 * The method to be invoked.
// 	 */
// 	method: string;
//
// 	/**
// 	 * The method's params.
// 	 */
// 	params?: array | object;
// }

// interface ResponseMessage extends Message {
// 	/**
// 	 * The request id.
// 	 */
// 	id: integer | string | null;
//
// 	/**
// 	 * The result of a request. This member is REQUIRED on success.
// 	 * This member MUST NOT exist if there was an error invoking the method.
// 	 */
// 	result?: string | number | boolean | array | object | null;
//
// 	/**
// 	 * The error object in case a request fails.
// 	 */
// 	error?: ResponseError;
// }
// interface ResponseError {
// 	/**
// 	 * A number indicating the error type that occurred.
// 	 */
// 	code: integer;
//
// 	/**
// 	 * A string providing a short description of the error.
// 	 */
// 	message: string;
//
// 	/**
// 	 * A primitive or structured value that contains additional
// 	 * information about the error. Can be omitted.
// 	 */
// 	data?: string | number | boolean | array | object | null;
// }

// TODO:  make this a proper ADT
pub type Request {
  Request(id: Int, method: String, params: Map(String, Dynamic))
}

pub fn initialize() -> String {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("id", json.int(1)),
    #("method", json.string("initialize")),
    #(
      "params",
      json.object([
        #("processId", json.null()),
        #("clientInfo", json.object([#("name", json.string("rappel"))])),
        #(
          "capabilities",
          json.object([
            #(
              "textDocument",
              json.object([
                #(
                  "hover",
                  json.object([
                    #("dynamicRegistration", json.bool(False)),
                    #("contentFormat", json.array(["plaintext"], json.string)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  |> encode
}

pub fn initialized() -> String {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("method", json.string("initialized")),
    #("params", json.object([])),
  ])
  |> encode
}

pub fn hover(id: Int, document: String, line: Int, column: Int) -> String {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("id", json.int(id)),
    #("method", json.string("textDocument/hover")),
    #(
      "params",
      json.object([
        #("textDocument", json.object([#("uri", json.string(document))])),
        #(
          "position",
          json.object([
            #("line", json.int(line)),
            #("character", json.int(column)),
          ]),
        ),
      ]),
    ),
  ])
  |> encode
}

pub fn did_open(document: String, contents: String) -> String {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("method", json.string("textDocument/didOpen")),
    #(
      "params",
      json.object([
        #(
          "textDocument",
          json.object([
            #("languageId", json.string("gleam")),
            #("version", json.int(8)),
            #("text", json.string(contents)),
            #("uri", json.string(document)),
          ]),
        ),
      ]),
    ),
  ])
  |> encode
}

pub fn did_change(id: Int, document: String, content: String) -> String {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("id", json.int(id)),
    #("method", json.string("textDocument/didChange")),
    #(
      "params",
      json.object([
        #("textDocument", json.object([#("uri", json.string(document))])),
        #("contentChanges", json.array([content], json.string)),
      ]),
    ),
  ])
  |> encode
}

pub fn encode(msg: json.Json) -> String {
  let message = json.to_string(msg)

  let content_length = string.byte_size(message)

  ["Content-Length: " <> int.to_string(content_length), message]
  |> string.join("\r\n\r\n")
}

pub type Hover {
  Hover(contents: Option(String))
}

pub type Response {
  Response(id: Int, result: Hover)
}

pub fn parse_message(resp: String) -> Result(#(String, String), String) {
  case resp {
    "Content-Length: " <> rest -> {
      use #(length, rest) <- result.try(result.replace_error(
        string.split_once(rest, "\r\n\r\n"),
        resp,
      ))
      use length <- result.try(result.replace_error(int.parse(length), resp))
      let message = string.slice(rest, 0, length)
      let rest = string.slice(rest, length, string.length(rest))
      Ok(#(message, rest))
    }
    _ -> Error(resp)
  }
}

pub fn decode(resp: String) -> Result(Response, Nil) {
  let decoder =
    dynamic.decode2(
      Response,
      dynamic.field("id", dynamic.int),
      dynamic.field(
        "result",
        dynamic.decode1(
          Hover,
          dynamic.optional(dynamic.field(
            "contents",
            dynamic.field("contents", dynamic.string),
          )),
        ),
      ),
    )
  json.decode(resp, decoder)
  |> result.replace_error(Nil)
}
