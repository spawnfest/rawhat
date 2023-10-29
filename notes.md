# Ideas

- when doing the variable lookup, maybe do some checks for if it's a function?
    - if so, maybe that can be included in the bindings to `erl_eval` or something?
    - can also do this for things like PIDs, etc

- for LSP hover, check the text capabilities it's sending over
    - it might be that the gleam LSP only supports some, and i'm asking for
      the wrong one?
