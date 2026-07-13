%% Заглушка для запуска дерева супервизоров
-module(alarm_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    {ok, Req, State}.