%%%-------------------------------------------------------------------
%% @doc sipalerts public API
%% @end
%%%-------------------------------------------------------------------

-module(sipalerts_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    mnesia:start(),
    wpool:start(),
    sipalerts_db:init(),
    sipalerts_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
