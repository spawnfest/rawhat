import gleam/dynamic
import gleam/map
import gleeunit/should
import rappel/generator.{Record2, SingleValue, Tuple2}
import rappel/environment.{Environment}
import rappel/evaluator

fn generate(code: String) -> String {
  let assert Ok(res) =
    code
    |> evaluator.encode
    |> evaluator.decode
    |> generator.generate(environment.new())

  res.generated
}

pub fn it_generates_simple_assignment_test() {
  let result = generate("let val = 1")

  result
  |> should.equal("Val = 1")
}

pub fn it_handles_gleam_type_constructors_test() {
  let result = generate("let MyGleamConstructor(1, 2, 3) = some_other_value")

  result
  |> should.equal("{my_gleam_constructor, 1, 2, 3} = SomeOtherValue")
}

pub fn it_handles_lists_and_tuples_test() {
  let result = generate("let items = [one, two, #(three, 4)]")

  result
  |> should.equal("Items = [One, Two, {Three, 4}]")
}

pub fn it_handles_blocks_test() {
  let result = generate("{ let value = 1 let other_value = 2 }")

  result
  |> should.equal("Value = 1,\nOtherValue = 2")
}

pub fn it_handles_concatenate_operator_test() {
  let result = generate("let \"my_str\" <> rest = some_string_value")

  result
  |> should.equal("\"my_str\" ++ Rest = SomeStringValue")
}

pub fn it_handles_function_definitions_test() {
  let result = generate("let my_func = fn(arg_one, arg_two) { let value = 1 }")

  result
  |> should.equal("MyFunc = fun(ArgOne, ArgTwo) -> Value = 1\nend")
}

pub fn it_handles_decoding_single_values_test() {
  let return_shape = generator.SingleValue("value")
  let output = generator.get_decoders_for_return(return_shape)

  output
  |> should.equal(map.from_list([#("value", dynamic.dynamic)]))

  let input = dynamic.from(123)
  let assert Ok(decoder) = map.get(output, "value")

  decoder(input)
  |> should.equal(Ok(dynamic.from(123)))
}

pub fn it_handles_nested_tuple_values_test() {
  let return_shape =
    Tuple2(SingleValue("a"), Tuple2(SingleValue("b"), SingleValue("c")))

  let output = generator.get_decoders_for_return(return_shape)

  output
  |> should.equal(map.from_list([
    #("a", dynamic.element(0, dynamic.dynamic)),
    #("b", dynamic.element(1, dynamic.element(0, dynamic.dynamic))),
    #("c", dynamic.element(1, dynamic.element(1, dynamic.dynamic))),
  ]))

  let input = dynamic.from(#(1, #(2, 3)))
  let assert Ok(a_decoder) = map.get(output, "a")
  let assert Ok(b_decoder) = map.get(output, "b")
  let assert Ok(c_decoder) = map.get(output, "c")

  a_decoder(input)
  |> should.equal(Ok(dynamic.from(1)))
  b_decoder(input)
  |> should.equal(Ok(dynamic.from(2)))
  c_decoder(input)
  |> should.equal(Ok(dynamic.from(3)))
}

type TestRecord {
  TestRecord(first: String, second: Bool)
}

pub fn it_handles_records_test() {
  let return_shape =
    Record2("doesn't matter", SingleValue("key_one"), SingleValue("key_two"))

  let output = generator.get_decoders_for_return(return_shape)

  output
  |> should.equal(map.from_list([
    #("key_one", dynamic.element(1, dynamic.dynamic)),
    #("key_two", dynamic.element(2, dynamic.dynamic)),
  ]))

  let input = dynamic.from(TestRecord("hi mom", False))
  let assert Ok(key_one) = map.get(output, "key_one")
  let assert Ok(key_two) = map.get(output, "key_two")

  key_one(input)
  |> should.equal(Ok(dynamic.from("hi mom")))
  key_two(input)
  |> should.equal(Ok(dynamic.from(False)))
}
