import gleam/dynamic.{Decoder, Dynamic}
import gleam/function
import gleam/string
import gleam/list
import gleam/map.{Map}
import gleam/result
import rappel/environment.{Environment}
import glance.{
  AddFloat, AddInt, And, Assignment, BinaryOperator, Block, Call, Concatenate,
  Discarded, DivFloat, DivInt, Eq, Expression, Field, Float, Fn, FnParameter,
  GtEqFloat, GtEqInt, GtFloat, GtInt, Int, Let, LtEqFloat, LtEqInt, LtFloat,
  LtInt, MultFloat, MultInt, Named, NotEq, Or, Pattern, PatternAssignment,
  PatternBitString, PatternConcatenate, PatternConstructor, PatternDiscard,
  PatternFloat, PatternInt, PatternList, PatternString, PatternTuple,
  PatternVariable, Pipe, RemainderInt, Statement, String, SubFloat, SubInt,
  Tuple, Use, Variable,
}

pub type ReturnShape {
  NotProvided
  SingleValue(name: String)
  Tuple2(first: ReturnShape, second: ReturnShape)
  Tuple3(first: ReturnShape, second: ReturnShape, third: ReturnShape)
  Tuple4(
    first: ReturnShape,
    second: ReturnShape,
    third: ReturnShape,
    fourth: ReturnShape,
  )
  Record1(record_name: String, first: ReturnShape)
  Record2(record_name: String, first: ReturnShape, second: ReturnShape)
  Record3(
    record_name: String,
    first: ReturnShape,
    second: ReturnShape,
    third: ReturnShape,
  )
  List1(item: ReturnShape)
  List2(item1: ReturnShape, item2: ReturnShape)
  List3(item1: ReturnShape, item2: ReturnShape, item3: ReturnShape)
}

pub fn get_decoders_for_return(
  shape: ReturnShape,
) -> Map(String, Decoder(Dynamic)) {
  do_get_decoders_for_return(shape, function.identity, map.new())
}

fn do_get_decoders_for_return(
  shape: ReturnShape,
  current_decoder: fn(Decoder(Dynamic)) -> Decoder(Dynamic),
  decoders: Map(String, Decoder(Dynamic)),
) -> Map(String, Decoder(Dynamic)) {
  case shape {
    NotProvided -> decoders
    SingleValue(label) ->
      map.insert(decoders, label, current_decoder(dynamic.dynamic))
    Tuple2(first, second) -> {
      let decoders =
        do_get_decoders_for_return(
          first,
          fn(next) { current_decoder(dynamic.element(0, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          second,
          fn(next) { current_decoder(dynamic.element(1, next)) },
          decoders,
        )
      decoders
    }
    Tuple3(first, second, third) -> {
      let decoders =
        do_get_decoders_for_return(
          first,
          fn(next) { current_decoder(dynamic.element(0, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          second,
          fn(next) { current_decoder(dynamic.element(1, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          third,
          fn(next) { current_decoder(dynamic.element(2, next)) },
          decoders,
        )
      decoders
    }
    Tuple4(first, second, third, fourth) -> {
      let decoders =
        do_get_decoders_for_return(
          first,
          fn(next) { current_decoder(dynamic.element(0, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          second,
          fn(next) { current_decoder(dynamic.element(1, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          third,
          fn(next) { current_decoder(dynamic.element(2, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          fourth,
          fn(next) { current_decoder(dynamic.element(3, next)) },
          decoders,
        )
      decoders
    }
    Record1(_name, first) -> {
      do_get_decoders_for_return(
        first,
        fn(next) { current_decoder(dynamic.element(1, next)) },
        decoders,
      )
    }
    Record2(_name, first, second) -> {
      let decoders =
        do_get_decoders_for_return(
          first,
          fn(next) { current_decoder(dynamic.element(1, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          second,
          fn(next) { current_decoder(dynamic.element(2, next)) },
          decoders,
        )
      decoders
    }
    Record3(_name, first, second, third) -> {
      let decoders =
        do_get_decoders_for_return(
          first,
          fn(next) { current_decoder(dynamic.element(1, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          second,
          fn(next) { current_decoder(dynamic.element(2, next)) },
          decoders,
        )
      let decoders =
        do_get_decoders_for_return(
          third,
          fn(next) { current_decoder(dynamic.element(3, next)) },
          decoders,
        )
      decoders
    }
    _ -> {
      todo as "not exactly sure how to do lists with this right now"
    }
  }
}

pub type Error {
  UnboundVariable(String)
}

pub type GenerateResult {
  GenerateResult(return_shape: ReturnShape, generated: String)
}

fn no_returns(generated: String) -> GenerateResult {
  GenerateResult(return_shape: NotProvided, generated: generated)
}

pub fn generate(
  statement: Statement,
  env: Environment,
) -> Result(GenerateResult, Error) {
  case statement {
    Use(..) -> {
      panic as "use not supported in shell"
    }
    Assignment(Let, pattern, _annotation, value) -> {
      let generate_result = generate_pattern(pattern)
      use expression <- result.try(generate_expression(value, env))
      Ok(GenerateResult(
        return_shape: generate_result.return_shape,
        generated: generate_result.generated <> " = " <> expression,
      ))
    }
    Expression(expression) -> {
      use expr <- result.try(generate_expression(expression, env))
      Ok(GenerateResult(return_shape: NotProvided, generated: expr))
    }
  }
}

fn generate_expression(
  expr: Expression,
  env: Environment,
) -> Result(String, Error) {
  case expr {
    Int(value) | Float(value) -> Ok(value)
    String(value) -> Ok("\"" <> value <> "\"")
    Block(statements) -> {
      statements
      |> list.try_map(fn(statement) {
        // NOTE:  We can ignore the return shape since variables are scoped here
        use generate_result <- result.try(generate(statement, env))
        Ok(generate_result.generated)
      })
      |> result.map(string.join(_, ",\n"))
    }
    Variable(name) -> {
      environment.get(env, name)
      |> result.map(string.inspect)
      |> result.replace_error(UnboundVariable(name))
    }
    Tuple(expressions) -> {
      use tuple_expressions <- result.try(
        expressions
        |> list.try_map(generate_expression(_, env))
        |> result.map(string.join(_, ", ")),
      )

      Ok("{" <> tuple_expressions <> "}")
    }
    glance.List(expressions, _rest) -> {
      use list_expressions <- result.try(
        expressions
        |> list.try_map(generate_expression(_, env))
        |> result.map(string.join(_, ", ")),
      )

      Ok("[" <> list_expressions <> "]")
    }
    Fn(arguments, _return_annnotation, body) -> {
      let args =
        arguments
        |> list.map(generate_fn_parameter)
        |> string.join(", ")
      use body_statements <- result.try(
        body
        |> list.try_map(fn(statement) {
          // NOTE:  We can ignore the return shape since variables are scoped here
          use generate_result <- result.try(generate(statement, env))
          Ok(generate_result.generated)
        })
        |> result.map(string.join(_, ",\n")),
      )
      Ok("fun(" <> args <> ") -> " <> body_statements <> "\nend")
    }
    BinaryOperator(op, left, right) -> {
      let operator = case op {
        AddInt | AddFloat -> "+"
        SubInt | SubFloat -> "-"
        MultInt | MultFloat -> "*"
        DivInt | DivFloat -> "/"
        GtInt | GtFloat -> ">"
        LtInt | LtFloat -> "<"
        LtEqInt | LtEqFloat -> "<="
        GtEqInt | GtEqFloat -> ">="
        Eq -> "=="
        NotEq -> "=/="
        And -> "and"
        Or -> "or"
        Concatenate -> "++"
        RemainderInt -> "rem"
        Pipe -> "pls break"
      }
      use left_expr <- result.try(generate_expression(left, env))
      use right_expr <- result.try(generate_expression(right, env))
      Ok(left_expr <> operator <> right_expr)
    }
    Call(call_expression, arguments) -> {
      use call <- result.try(generate_expression(call_expression, env))
      use args <- result.try(
        arguments
        |> list.try_map(fn(arg) {
          let assert Field(_label, expression) = arg
          generate_expression(expression, env)
        })
        |> result.map(string.join(_, ", ")),
      )
      Ok(call <> "(" <> args <> ")")
    }
    _ -> {
      panic as "got an unknown expression"
    }
  }
}

fn generate_pattern(pattern: Pattern) -> GenerateResult {
  case pattern {
    PatternInt(value) | PatternFloat(value) | PatternString(value) ->
      no_returns(value)
    PatternDiscard(name) -> no_returns("_" <> name)
    PatternVariable(name) ->
      GenerateResult(SingleValue(name), convert_variable_name(name))
    PatternTuple(elements) -> {
      elements
      |> list.map(generate_pattern)
      |> list.fold(
        #([], []),
        fn(results, element_result) {
          let assert #(assigns, generated) = results
          #(
            [element_result.return_shape, ..assigns],
            [element_result.generated, ..generated],
          )
        },
      )
      |> fn(results) {
        let assert #(assigns, generated) = results
        let assigns = list.reverse(assigns)
        let generated = list.reverse(generated)
        let return_shape = case list.length(elements) {
          2 -> {
            let assert [first, second] = assigns
            Tuple2(first, second)
          }
          3 -> {
            let assert [first, second, third] = assigns
            Tuple3(first, second, third)
          }
          4 -> {
            let assert [first, second, third, fourth] = assigns
            Tuple4(first, second, third, fourth)
          }
          _ -> panic as "tuple size not supported at the moment"
        }
        GenerateResult(
          return_shape: return_shape,
          generated: "{" <> string.join(generated, ", ") <> "}",
        )
      }
    }
    PatternList(elements, _tail) -> {
      elements
      |> list.map(generate_pattern)
      |> list.fold(
        #([], []),
        fn(results, element_result) {
          let assert #(assigns, generated) = results
          #(
            [element_result.return_shape, ..assigns],
            [element_result.generated, ..generated],
          )
        },
      )
      |> fn(results) {
        let assert #(assigns, generated) = results
        let assigns = list.reverse(assigns)
        let generated = list.reverse(generated)
        let return_shape = case list.length(elements) {
          1 -> {
            let assert [first] = assigns
            List1(first)
          }
          2 -> {
            let assert [first, second] = assigns
            List2(first, second)
          }
          3 -> {
            let assert [first, second, third] = assigns
            List3(first, second, third)
          }
          _ -> panic as "list size not supported at the moment"
        }
        GenerateResult(
          return_shape: return_shape,
          generated: "[" <> string.join(generated, ", ") <> "]",
        )
      }
    }
    PatternAssignment(_pattern, name) -> {
      GenerateResult(
        return_shape: SingleValue(name),
        generated: convert_variable_name(name),
      )
    }
    PatternConcatenate(literal, name) -> {
      case name {
        Named(value) ->
          GenerateResult(
            return_shape: SingleValue(value),
            generated: "\"" <> literal <> "\" ++ " <> convert_variable_name(
              value,
            ),
          )
        Discarded(value) ->
          GenerateResult(
            return_shape: NotProvided,
            generated: "\"" <> literal <> "\" ++ _" <> convert_variable_name(
              value,
            ),
          )
      }
    }
    PatternBitString(_segments) -> {
      todo
    }
    PatternConstructor(_module, constructor, arguments, _with_spread) -> {
      let constructor_name = convert_constructor_name(constructor)
      arguments
      |> list.map(fn(arg) {
        let assert Field(_label, pattern) = arg
        generate_pattern(pattern)
      })
      |> list.fold(
        #([], []),
        fn(results, field_result) {
          let assert #(assigns, generated) = results
          #(
            [field_result.return_shape, ..assigns],
            [field_result.generated, ..generated],
          )
        },
      )
      |> fn(results) {
        let assert #(assigns, generated) = results
        let return_shapes = list.reverse(assigns)
        let generated = list.reverse(generated)
        let joined = string.join(generated, ", ")
        case list.length(arguments) {
          1 -> {
            let assert [one] = return_shapes
            GenerateResult(
              return_shape: Record1(constructor_name, one),
              generated: "{" <> constructor_name <> ", " <> joined <> "}",
            )
          }
          2 -> {
            let assert [one, two] = return_shapes
            GenerateResult(
              return_shape: Record2(constructor_name, one, two),
              generated: "{" <> constructor_name <> ", " <> joined <> "}",
            )
          }
          3 -> {
            let assert [one, two, three] = return_shapes
            GenerateResult(
              return_shape: Record3(constructor_name, one, two, three),
              generated: "{" <> constructor_name <> ", " <> joined <> "}",
            )
          }
          _ -> panic as "record size not support at the moment"
        }
      }
    }
  }
  // let joined_arguments =
  //   arguments
  //   |> list.map(fn(arg) {
  //   })
  //   |> string.join(", ")
  // "{" <> constructor_name <> ", " <> joined_arguments <> "}"
}

fn generate_fn_parameter(param: FnParameter) -> String {
  let assert FnParameter(name, ..) = param
  case name {
    Named(str) -> convert_variable_name(str)
    Discarded(str) -> "_" <> convert_variable_name(str)
  }
}

// some_other_value -> SomeOtherValue
fn convert_variable_name(name: String) -> String {
  name
  |> string.split("_")
  |> list.map(string.capitalise)
  |> string.join("")
}

// MyGleamType -> my_gleam_type
fn convert_constructor_name(name: String) -> String {
  name
  |> string.to_graphemes
  |> list.fold(
    [],
    fn(terms, char) {
      let is_new = string.capitalise(char) == char
      case terms, is_new {
        [], _ -> [string.lowercase(char)]
        [word, ..rest], True -> [string.lowercase(char), word, ..rest]
        [word, ..rest], False -> [word <> char, ..rest]
      }
    },
  )
  |> list.reverse
  |> string.join("_")
}
