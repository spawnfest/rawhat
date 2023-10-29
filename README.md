# rappel

`rappel` is a small implementation of some bits of a [Gleam](https://gleam.run)
shell for the Erlang backend.

TODO:  images / gifs

## How to run it?

You need a relatively recent Gleam version installed (I was using 0.31.0).
I think it should work with any recent OTP version as well, as I'm using the
`shell` but nothing explicitly new.

In this directory, just execute `gleam run`.  You can exit with `quit()`.

NOTE:  The project creates a folder in a random directory generated with
`mktemp`. If you want to clean that up, it's in there somewhere. Additionally,
the `gleam lsp` command really doesn't want to exit sometimes.  I've gone fully
nuclear in the code to kill it, but it's possible that a process might linger
after exiting the program.

### Tests

There are some tests for various bits of the logic strewn about. You can run
them with a `gleam test`.

## What does it do?

It supports a small subset of Gleam syntax.  It does some hand-rolled
emitting of Erlang code from the parsed input.  It runs that through
the `erl_eval` module to execute and generate bindings.

It handles some imports (by default `gleam_stdlib` and `gleam_erlang`)
are included. It will try to fully qualify these so Erlang can run them.
The result of the expression is also displayed.

A big differentiator for Gleam is the type system.  Since this doesn't actually
go through the Gleam compiler -- and because that does not expose any
interface(s) or type information beyond type specs -- there's no easy way to
emit that information.

This project creates a stub Gleam project for the shell and starts an LSP
instance to communicate to over a port. When you enter a line, a process
issues a `textDocument/hover` request to the Gleam LSP.  If it gets back
a response, which should include definitions for your code, it's displayed
alongside the expression value.

## What _doesn't_ it do?

Not all Gleam syntax is supported.  Mostly due to time constraints, but also
the codegen in the compiler handles things like variable re-binding, unrolling
pipes, etc.  I did not feel like doing any of that for this.

## Implementation

The `rappel/shell` module is the `{module, function, arity}` entrypoint for
`shell:start_interactive/1`.  This starts a process which does the following:
    - generate the temp directory for the shell's Gleam project
    - initialize the `Evaluator` process
    - initialize the `LSP` process
    - loop to receive user input

The shell process also handles dispatching messages to the LSP process.

The `rappel/evaluator` module handles receiving the user input, turning it into
some Erlang code, evaluating the results, and returning those back to the shell.
It has a special case for imports, since the rest of the code is placed in the
module body.

The evaluator calls into the `rappel/generator` module.  This handles
translating some Gleam syntax into (hopefully) valid Erlang. It receives
parsed Gleam code from the [glance](https://hexdocs.pm/glance/index.html) library.

After the Erlang code is generated, it passes through a series of Erlang
modules that tokenize, parse, and interpret the code to get both the result and
any variable bindings in the pattern. These bindings are stored in the
`Environment`. I think that type is largely superfluous now, but the way I
built up the decoders was cool to me. It uses `erl_scan:string/1`,
`erl_parse:parse_exprs/1`, and `erl_eval:exprs/2` to perform these actions.

One the result is obtained from the evaluator, it's returned to the shell. The
shell module then puts the command into the stub project and issues two LSP
requests -- one to signify that the document changed, the other to issue the
`textDocument/hover` request.

The `lsp` module houses the process for interacting with the port. It sends
and receives messages as they come in.

The `lsp/client` module is a request builder / response decoder. It only
supports a small subset of the protocol that I needed to get this working. And
probably a few others it doesn't need, but that I thought it did.
