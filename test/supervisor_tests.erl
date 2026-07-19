-module(supervisor_tests).

-include_lib("eunit/include/eunit.hrl").

supervisor_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [
            ?_test(application_started()),
            ?_test(main_sup_children()),
            ?_test(alert_sup_children()),
            ?_test(alert_manager_restart()),
            ?_test(alert_sup_restart()),
            ?_test(timer_queue_restart())
     ]}.

setup() ->
    mnesia:stop(),

    %% удалить старую тестовую БД
    mnesia:delete_schema([node()]),

    ok = mnesia:create_schema([node()]),
    
    {ok, _} = application:ensure_all_started(sipalerts),
    ok.

cleanup(_) ->
    application:stop(sipalerts),
    mnesia:stop(),
    mnesia:delete_schema([node()]),
    ok.

application_started() ->
    ?assert(is_process_alive(whereis(sipalerts_sup))).

main_sup_children() ->

    Children = supervisor:which_children(sipalerts_sup),

    Ids = lists:sort([Id || {Id,_,_,_} <- Children]),

    ?assertEqual(
        lists:sort([http_sup, alert_sup, sip_sup]),
        Ids
    ).

alert_sup_children() ->

    Children = supervisor:which_children(alert_sup),

    Ids = lists:sort([Id || {Id,_,_,_} <- Children]),

    ?assertEqual(
        lists:sort([
            alert_manager,
            alert_log,
            timer_queue
        ]),
        Ids
    ).

alert_manager_restart() ->

    {alert_manager, OldPid, _, _} =
        lists:keyfind(alert_manager, 1,
            supervisor:which_children(alert_sup)),

    exit(OldPid, kill),

    timer:sleep(300),

    {alert_manager, NewPid, _, _} =
        lists:keyfind(alert_manager, 1,
            supervisor:which_children(alert_sup)),

    ?assert(is_pid(NewPid)),
    ?assertNotEqual(OldPid, NewPid).

alert_sup_restart() ->

    {alert_manager, Pid, _, _} =
        lists:keyfind(alert_manager, 1,
            supervisor:which_children(alert_sup)),

    exit(whereis(alert_sup), kill),

    timer:sleep(300),

    {alert_manager, NewPid, _, _} =
        lists:keyfind(alert_manager, 1,
            supervisor:which_children(alert_sup)),

    ?assert(is_pid(NewPid)),
    ?assertNotEqual(Pid, NewPid).

timer_queue_restart() ->

    {timer_queue, OldPid, _, _} =
        lists:keyfind(timer_queue, 1,
            supervisor:which_children(alert_sup)),

    exit(OldPid, kill),

    timer:sleep(300),

    {timer_queue, NewPid, _, _} =
        lists:keyfind(timer_queue, 1,
            supervisor:which_children(alert_sup)),

    ?assert(is_pid(NewPid)),
    ?assertNotEqual(OldPid, NewPid).