-module(mock_alert_db).

-behaviour(timer_db).

-include("sipalerts_db.hrl").

-export([
    start/0,
    reset/0,
    insert_timer/1,
    delete_timer/1,
    get_timer/1,
    list_timers/0
]).

-define(STORAGE_KEY, {?MODULE, timers}).

%% Инициализация мок-хранилища.
-spec start() -> ok.

start() ->
    case persistent_term:get(?STORAGE_KEY, undefined) of
        undefined ->
            persistent_term:put(?STORAGE_KEY, #{}),
            ok;
        _Timers ->
            ok
    end.

%% Очистка мок-хранилища между тестами.
-spec reset() -> ok.

reset() ->
    persistent_term:put(?STORAGE_KEY, #{}),
    ok.

%% Сохранение таймера.
-spec insert_timer(#timer{}) ->
    ok
    | {error, term()}.

insert_timer(Timer = #timer{id = TimerId}) ->
    start(),
    Timers = persistent_term:get(?STORAGE_KEY),
    persistent_term:put(
        ?STORAGE_KEY,
        maps:put(TimerId, Timer, Timers)
    ),
    ok.

%% Удаление таймера.
-spec delete_timer(term()) ->
    ok
    | {error, not_found}.

delete_timer(TimerId) ->
    start(),
    Timers = persistent_term:get(?STORAGE_KEY),

    case maps:is_key(TimerId, Timers) of
        true ->
            persistent_term:put(
                ?STORAGE_KEY,
                maps:remove(TimerId, Timers)
            ),
            ok;
        false ->
            {error, not_found}
    end.

%% Получение одного таймера.
-spec get_timer(term()) ->
    {ok, #timer{}}
    | {error, not_found}.

get_timer(TimerId) ->
    start(),
    Timers = persistent_term:get(?STORAGE_KEY),

    case maps:find(TimerId, Timers) of
        {ok, Timer} ->
            {ok, Timer};
        error ->
            {error, not_found}
    end.

%% Получение всех таймеров.
-spec list_timers() ->
    {ok, [#timer{}]}.

list_timers() ->
    start(),
    Timers = persistent_term:get(?STORAGE_KEY),
    {ok, maps:values(Timers)}.