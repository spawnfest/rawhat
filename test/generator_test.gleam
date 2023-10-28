import gleeunit/should
import rappel/generator
import rappel/evaluator

fn generate(code: String) -> String {
  code
  |> evaluator.encode
  |> evaluator.decode
  |> generator.generate
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
