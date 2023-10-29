import gleam/dynamic.{Dynamic}
import gleam/list
import gleam/map.{Map}
import gleam/result

pub type Environment {
  Environment(
    import_map: Map(String, String),
    variables: Map(String, Dynamic),
    bindings: BindingStruct,
  )
}

pub fn new() -> Environment {
  Environment(
    import_map: map.new(),
    variables: map.new(),
    bindings: new_bindings(),
  )
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

pub fn set_bindings(env: Environment, bindings: BindingStruct) -> Environment {
  Environment(..env, bindings: bindings)
}

pub fn get(environment: Environment, label: String) -> Result(Dynamic, Nil) {
  map.get(environment.variables, label)
  |> result.lazy_or(fn() {
    map.get(environment.import_map, label)
    |> result.map(dynamic.from)
  })
}

pub fn resolve_import(
  environment: Environment,
  label: String,
) -> Result(String, Nil) {
  map.get(environment.import_map, label)
}

pub fn merge_bindings(env: Environment, bindings: BindingStruct) -> Environment {
  bindings
  |> list_bindings
  |> list.fold(
    env.bindings,
    fn(bindings, binding) {
      let assert #(key, value) = binding
      add_binding(key, value, bindings)
    },
  )
  |> fn(new_bindings) { set_bindings(env, new_bindings) }
}

pub type BindingStruct

@external(erlang, "erl_eval", "new_bindings")
fn new_bindings() -> BindingStruct

@external(erlang, "erl_eval", "add_binding")
fn add_binding(
  name: name,
  value: value,
  existing: BindingStruct,
) -> BindingStruct

@external(erlang, "erl_eval", "bindings")
fn list_bindings(bindings: BindingStruct) -> List(#(Dynamic, Dynamic))
