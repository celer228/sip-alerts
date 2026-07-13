-ifndef(TIMER_QUEUE_HRL).
-define(TIMER_QUEUE_HRL, true).

%% Долговременное представление таймера.
%% TimerRef здесь отсутствует, потому что он действителен
%% только в рамках текущего запуска Erlang-ноды.
-record(timer, {
    id,
    deadline_ms,
    destination,
    message
}).

-endif.
