-module(timer_db).

-include("timer_queue.hrl").

%% Контракт модуля хранения таймеров.
-callback insert_timer(#timer{}) ->
    ok
    | {error, term()}.

-callback delete_timer(TimerId :: term()) ->
    ok
    | {error, not_found}
    | {error, term()}.

-callback get_timer(TimerId :: term()) ->
    {ok, #timer{}}
    | {error, not_found}
    | {error, term()}.

-callback list_timers() ->
    {ok, [#timer{}]}
    | {error, term()}.