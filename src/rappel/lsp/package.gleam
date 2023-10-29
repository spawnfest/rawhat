import gleam/string_builder.{StringBuilder}
import gleam/erlang/file
import gleam/list
import gleam/result
import gleam/string
import shellout

pub type Dependency {
  Hex(name: String, version: String)
  Path(name: String, path: String)
}

pub type Module {
  Module(imports: List(String), body: StringBuilder)
}

pub type Package {
  Package(
    name: String,
    dependencies: List(Dependency),
    main: Module,
    directory: String,
  )
}

pub fn new(directory: String) -> Package {
  Package(
    name: "rappel",
    dependencies: [
      Hex("gleam_stdlib", "~> 0.31"),
      Hex("gleam_erlang", "~> 0.22"),
    ],
    main: Module(imports: [], body: string_builder.new()),
    directory: directory,
  )
}

pub fn add_import(package: Package, import_: String) -> Package {
  Package(
    ..package,
    main: Module(
      ..package.main,
      imports: [string.trim(import_), ..package.main.imports],
    ),
  )
}

pub fn append_code(package: Package, code: String) -> Package {
  Package(
    ..package,
    main: Module(
      ..package.main,
      body: string_builder.append(package.main.body, code),
    ),
  )
}

import gleam/io

pub fn last_line_index(package: Package) -> Int {
  io.debug(#("getting index for", package))
  let imports = list.length(package.main.imports)
  let code_lines =
    package.main.body
    |> string_builder.to_string
    |> string.split("\n")
    |> list.length

  imports + code_lines - 1
}

pub fn source_file(package: Package) -> String {
  "file://" <> package.directory <> "/src/" <> package.name <> ".gleam"
}

pub fn write(package: Package) -> Result(Nil, Nil) {
  let toml = make_toml(package)
  let mkdir =
    shellout.command(
      "mkdir",
      with: ["-p", "src"],
      in: package.directory,
      opt: [],
    )
  use _ok <- result.try(result.replace_error(mkdir, Nil))
  use _ok <- result.try(result.replace_error(
    file.write(toml, package.directory <> "/gleam.toml"),
    Nil,
  ))
  package
  |> make_main
  |> file.write(package.directory <> "/src/" <> package.name <> ".gleam")
  |> result.replace_error(Nil)
}

pub fn make_toml(package: Package) -> String {
  let dependencies =
    list.map(
      package.dependencies,
      fn(dependency) {
        case dependency {
          Hex(name, version) -> name <> " = \"" <> version <> "\""
          Path(name, path) -> name <> " = { path = \"" <> path <> "\" }"
        }
      },
    )
  [
    "name = \"" <> package.name <> "\"",
    "version = \"0.1.0\"",
    "[dependencies]",
    ..dependencies
  ]
  |> string.join("\n")
}

pub fn make_main(package: Package) -> String {
  list.concat([
    package.main.imports,
    ["pub fn main() {", string_builder.to_string(package.main.body), "}"],
  ])
  |> string.join("\n")
}
