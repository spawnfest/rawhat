import gleam/string
import gleam/list
import glance.{
  AddFloat, AddInt, And, Assignment, BinaryOperator, Block, Concatenate,
  Discarded, DivFloat, DivInt, Eq, Expression, Field, Float, Fn, FnParameter,
  GtEqFloat, GtEqInt, GtFloat, GtInt, Int, Let, LtEqFloat, LtEqInt, LtFloat,
  LtInt, MultFloat, MultInt, Named, NotEq, Or, Pattern, PatternAssignment,
  PatternBitString, PatternConcatenate, PatternConstructor, PatternDiscard,
  PatternFloat, PatternInt, PatternList, PatternString, PatternTuple,
  PatternVariable, Pipe, RemainderInt, Statement, String, SubFloat, SubInt,
  Tuple, Use, Variable,
}

pub fn generate(statement: Statement) -> String {
  case statement {
    Use(..) -> {
      panic as "use not supported in shell"
    }
    Assignment(Let, pattern, _annotation, value) -> {
      generate_pattern(pattern) <> " = " <> generate_expression(value)
    }
    Expression(expression) -> generate_expression(expression)
  }
}

import gleam/io

fn generate_expression(expr: Expression) -> String {
  case expr {
    Int(value) | Float(value) -> value
    String(value) -> "\"" <> value <> "\""
    Block(statements) -> {
      statements
      |> list.map(generate)
      |> string.join(",\n")
    }
    Variable(name) -> convert_variable_name(name)
    Tuple(expressions) -> {
      let tuple_expressions =
        expressions
        |> list.map(generate_expression)
        |> string.join(", ")

      "{" <> tuple_expressions <> "}"
    }
    glance.List(expressions, _rest) -> {
      let list_expressions =
        expressions
        |> list.map(generate_expression)
        |> string.join(", ")

      "[" <> list_expressions <> "]"
    }
    Fn(arguments, _return_annnotation, body) -> {
      let args =
        arguments
        |> list.map(generate_fn_parameter)
        |> string.join(", ")
      let body_statements =
        body
        |> list.map(generate)
        |> string.join(",\n")
      "fun(" <> args <> ") -> " <> body_statements <> "\nend"
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
      generate_expression(left) <> operator <> generate_expression(right)
    }
    _ -> {
      io.println(string.inspect(expr))
      panic as "got an unknown expression"
    }
  }
}

fn generate_pattern(pattern: Pattern) -> String {
  case pattern {
    PatternInt(value) | PatternFloat(value) | PatternString(value) -> value
    PatternDiscard(name) -> "_" <> name
    PatternVariable(name) -> convert_variable_name(name)
    PatternTuple(elements) -> {
      let tuple_elements =
        elements
        |> list.map(generate_pattern)
        |> string.join(", ")
      "{" <> tuple_elements <> "}"
    }
    PatternList(elements, _tail) -> {
      let list_elements =
        elements
        |> list.map(generate_pattern)
        |> string.join(", ")
      "[" <> list_elements <> "]"
    }
    PatternAssignment(_pattern, name) -> convert_variable_name(name)
    PatternConcatenate(literal, name) -> {
      let assignment = case name {
        Named(value) -> convert_variable_name(value)
        Discarded(value) -> "_" <> convert_variable_name(value)
      }
      "\"" <> literal <> "\" ++ " <> assignment
    }
    PatternBitString(_segments) -> {
      todo
    }
    PatternConstructor(_module, constructor, arguments, _with_spread) -> {
      let constructor_name = convert_constructor_name(constructor)
      let joined_arguments =
        arguments
        |> list.map(fn(arg) {
          let assert Field(_label, pattern) = arg
          generate_pattern(pattern)
        })
        |> string.join(", ")
      "{" <> constructor_name <> ", " <> joined_arguments <> "}"
    }
  }
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
