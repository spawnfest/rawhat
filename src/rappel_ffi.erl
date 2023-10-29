-module(rappel_ffi).

-export([scan_string/1]).

scan_string(Str) ->
  case erl_scan:string(Str) of
    {ok, Tokens, _} ->
      {ok, Tokens};
    {error, Info, Location} ->
      {error, {Info, Location}}
  end.
