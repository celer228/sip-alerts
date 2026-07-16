-module(timer_db).

%% Контракт модуля хранения таймеров.
-callback insert_timer(Timer :: sipalerts_db:timer()) ->
    ok
    | {error, term()}.

-callback delete_timer(TimerId :: sipalerts_db:timer_id()) ->
    ok
    | {error, not_found}
    | {error, term()}.

-callback get_timer(TimerId :: sipalerts_db:timer_id()) ->
    {ok, sipalerts_db:timer()}
    | {error, not_found}
    | {error, term()}.

-callback list_timers() ->
    {ok, [sipalerts_db:timer()]}
    | {error, term()}.