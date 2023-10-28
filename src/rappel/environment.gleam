import gleam/dynamic.{Dynamic}
import gleam/map.{Map}

pub type Environment {
  Environment(import_map: Map(String, String), variables: Map(String, Dynamic))
}

pub fn new() -> Environment {
  Environment(import_map: map.new(), variables: map.new())
}

pub fn add_import(env: Environment, mapping: #(String, String)) -> Environment {
  let assert #(label, value) = mapping
  Environment(..env, import_map: map.insert(env.import_map, label, value))
}

pub fn define_variable(
  env: Environment,
  label: String,
  value: Dynamic,
) -> Environment {
  Environment(..env, variables: map.insert(env.variables, label, value))
}
