-module(timer_queue_tests).

-include_lib("eunit/include/eunit.hrl").
-include("sipalerts_db.hrl").

%% Callback экспортирован, потому что timer_queue вызывает его через apply/3.
-export([
    callback_probe/2
]).

timer_queue_test_() ->
    {
        foreach,
        fun setup/0,
        fun cleanup/1,
        [
            fun add_and_list_case/0,
            fun cancel_case/0,
            fun cancel_unknown_case/0,
            fun invalid_delay_case/0,
            fun invalid_destination_case/0,
            fun send_notification_case/0,
            fun callback_notification_case/0,
            fun expired_timer_removed_case/0,
            fun restore_after_restart_case/0
        ]
    }.

%% Перед каждым тестом создаём новую схему Mnesia
%% и запускаем alert_sup с timer_queue.
setup() ->
    _ = mnesia:stop(),
    _ = mnesia:delete_schema([node()]),

    ok = mnesia:create_schema([node()]),
    ok = mnesia:start(),
    ok = sipalerts_db:init(),

    {ok, AlertSupPid} = alert_sup:start_link(),
    unlink(AlertSupPid),
    AlertSupPid.

cleanup(AlertSupPid) ->
    case is_process_alive(AlertSupPid) of
        true ->
            exit(AlertSupPid, shutdown);
        false ->
            ok
    end,

    _ = mnesia:stop(),
    _ = mnesia:delete_schema([node()]),
    ok.

%% Тестовый callback.
%% timer_queue передаёт первым аргументом TimerId,
%% а вторым — исходное Message.
callback_probe(TimerId, {Pid, Message}) ->
    Pid ! {callback_received, TimerId, Message},
    ok.

%% Добавленный таймер сохраняется в БД и появляется в list/0.
add_and_list_case() ->
    {ok, TimerId} =
        timer_queue:add(
            60000,
            {send, self()},
            add_message
        ),

    {ok, Timers} = timer_queue:list(),

    ?assertEqual(1, length(Timers)),

    [Timer] = Timers,

    ?assertEqual(TimerId, Timer#timer.id),
    ?assertEqual({send, self()}, Timer#timer.destination),
    ?assertEqual(add_message, Timer#timer.message),

    State = sys:get_state(timer_queue),
    TimerRefs = maps:get(timer_refs, State),

    ?assert(maps:is_key(TimerId, TimerRefs)).

%% Отмена удаляет системный таймер и запись из БД.
cancel_case() ->
    {ok, TimerId} =
        timer_queue:add(
            60000,
            {send, self()},
            cancelled_message
        ),

    ?assertEqual(ok, timer_queue:cancel(TimerId)),
    ?assertEqual({ok, []}, timer_queue:list()),

    State = sys:get_state(timer_queue),
    TimerRefs = maps:get(timer_refs, State),

    ?assertNot(maps:is_key(TimerId, TimerRefs)).

%% Отмена неизвестного таймера возвращает ошибку.
cancel_unknown_case() ->
    UnknownId = make_ref(),

    ?assertEqual(
        {error, not_found},
        timer_queue:cancel(UnknownId)
    ).

%% Задержка должна быть неотрицательным целым числом.
invalid_delay_case() ->
    ?assertEqual(
        {error, invalid_delay},
        timer_queue:add(
            -1,
            {send, self()},
            invalid_message
        )
    ),

    ?assertEqual(
        {error, invalid_delay},
        timer_queue:add(
            invalid_delay,
            {send, self()},
            invalid_message
        )
    ).

%% Destination должен иметь поддерживаемый формат.
invalid_destination_case() ->
    ?assertEqual(
        {error, invalid_destination},
        timer_queue:add(
            100,
            invalid_destination,
            invalid_message
        )
    ).

%% В режиме send отправляется сообщение с TimerId.
send_notification_case() ->
    {ok, TimerId} =
        timer_queue:add(
            20,
            {send, self()},
            send_message
        ),

    receive
        {timer_expired, TimerId, send_message} ->
            ok
    after 1000 ->
        ?assert(false)
    end.

%% В callback-режиме вызывается переданная функция.
callback_notification_case() ->
    {ok, TimerId} =
        timer_queue:add(
            20,
            {callback, ?MODULE, callback_probe},
            {self(), callback_message}
        ),

    receive
        {callback_received, TimerId, callback_message} ->
            ok
    after 1000 ->
        ?assert(false)
    end.

%% После срабатывания таймер удаляется из БД и runtime-state.
expired_timer_removed_case() ->
    {ok, TimerId} =
        timer_queue:add(
            20,
            {send, self()},
            remove_message
        ),

    receive
        {timer_expired, TimerId, remove_message} ->
            ok
    after 1000 ->
        ?assert(false)
    end,

    ?assertEqual({ok, []}, timer_queue:list()),

    State = sys:get_state(timer_queue),
    TimerRefs = maps:get(timer_refs, State),

    ?assertNot(maps:is_key(TimerId, TimerRefs)).

%% После остановки и повторного запуска таймер
%% восстанавливается из Mnesia.
restore_after_restart_case() ->
    {ok, TimerId} =
        timer_queue:add(
            60000,
            {send, self()},
            restored_message
        ),

    OldPid = whereis(timer_queue),

    %% Имитируем аварийное завершение.
    %% Новый процесс должен запустить supervisor.
    exit(OldPid, kill),

    NewPid = wait_for_restart(OldPid, 50),

    ?assert(is_pid(NewPid)),
    ?assert(OldPid =/= NewPid),

    {ok, Timers} = timer_queue:list(),

    ?assertEqual(1, length(Timers)),

    [Timer] = Timers,

    ?assertEqual(TimerId, Timer#timer.id),

    State = sys:get_state(timer_queue),
    TimerRefs = maps:get(timer_refs, State),

    ?assert(maps:is_key(TimerId, TimerRefs)).

%% Ожидание перезапуска timer_queue супервизором.
wait_for_restart(_OldPid, 0) ->
    undefined;
wait_for_restart(OldPid, AttemptsLeft) ->
    case whereis(timer_queue) of
        undefined ->
            timer:sleep(20),
            wait_for_restart(OldPid, AttemptsLeft - 1);

        OldPid ->
            timer:sleep(20),
            wait_for_restart(OldPid, AttemptsLeft - 1);

        NewPid ->
            NewPid
    end.
