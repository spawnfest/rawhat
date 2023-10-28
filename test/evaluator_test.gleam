import gleeunit/should
import rappel/evaluator

pub fn it_should_resolve_imports_test() {
  let result =
    evaluator.resolve_import("import one/two/three.{Value, some_func}")

  result
  |> should.equal([
    #("three", "one@two@three"),
    #("Value", "one@two@three:Value"),
    #("some_func", "one@two@three:some_func"),
  ])
}
