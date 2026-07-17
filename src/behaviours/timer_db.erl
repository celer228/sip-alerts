-module(timer_db).

%% Контракт модуля хранения таймеров.
-callback insert_timer(Timer :: sipalerts_db:timer()) ->
    ok
    | {error, sipalerts_db:reason()}.

-callback delete_timer(TimerId :: sipalerts_db:timer_id()) ->
    ok
    | {error, not_found}
    | {error, sipalerts_db:reason()}.

-callback get_timer(TimerId :: sipalerts_db:timer_id()) ->
    {ok, sipalerts_db:timer()}
    | {error, not_found}
    | {error, sipalerts_db:reason()}.

-callback list_timers() ->
    {ok, [sipalerts_db:timer()]}
    | {error, sipalerts_db:reason()}.