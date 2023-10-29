# rappel

`rappel` is a small implementation of some bits of a [Gleam](https://gleam.run)
shell for the Erlang backend.

TODO:  images / gifs

## What does it do?

It supports a small subset of Gleam syntax.  It does some hand-rolled
emitting of Erlang code from the parsed input.  It runs that through
the `erl_eval` module to execute and generate bindings.

It handles some imports (by default `gleam_stdlib` and `gleam_erlang`)
are included. It will try to fully qualify these so Erlang can run them.
The result of the expression is also displayed.

## What _doesn't_ it do?

TODO:  Make sure to update this if I get some of this stuff working lol

Not all Gleam syntax is supported.  Mostly due to time constraints, but also
the codegen in the compiler handles things like variable re-binding, unrolling
pipes, etc.  I did not feel like doing any of that for this.

A big differentiator for Gleam is the type system.  Since this doesn't actually
go through the Gleam compiler -- and because that does not expose any
interface(s) or type information beyond type specs -- there's no easy way to
emit that information.

My plan to do this was to create a stub Gleam project for the shell and start
an LSP instance to communicate to over a port.  This is "working", but I can't
seem to get the `textDocument/hover` request/response to actually populate
the same way it does in my editor.

## Implementation

TODO
