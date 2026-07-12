%% Заглушка для запуска дерева супервизоров
-module(dummy_server).

-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2, code_change/3]).

-export([crash/1]).

start_link(Name) ->
    gen_server:start_link({local, Name}, ?MODULE, Name, []).

init(Name) ->
    io:format("~p started~n", [Name]),
    {ok, Name}.

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

handle_cast(crash, State) ->
    exit(test_crash),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    io:format("~p stopped~n", [State]),
    ok.

code_change(_, State, _) ->
    {ok, State}.

crash(Name) ->
    gen_server:cast(Name, crash).