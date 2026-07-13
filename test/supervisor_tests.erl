-module(supervisor_tests).

-include_lib("eunit/include/eunit.hrl").

supervisor_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [
            ?_test(application_started()),
            ?_test(main_sup_children()),
            ?_test(alarm_sup_children()),
            ?_test(alarm_manager_restart()),
            ?_test(alarm_sup_restart()),
            ?_test(timer_queue_restart())
     ]}.

setup() ->
    {ok, _} = application:ensure_all_started(sipalerts),
    ok.

cleanup(_) ->
    application:stop(sipalerts).

application_started() ->
    ?assert(is_process_alive(whereis(sipalerts_sup))).

main_sup_children() ->

    Children = supervisor:which_children(sipalerts_sup),

    Ids = lists:sort([Id || {Id,_,_,_} <- Children]),

    ?assertEqual(
        lists:sort([http_sup, alarm_sup, sip_sup]),
        Ids
    ).

alarm_sup_children() ->

    Children = supervisor:which_children(alarm_sup),

    Ids = lists:sort([Id || {Id,_,_,_} <- Children]),

    ?assertEqual(
        lists:sort([
            alarm_manager,
            alarm_db,
            alarm_log,
            timer_queue
        ]),
        Ids
    ).

alarm_manager_restart() ->

    {alarm_manager, OldPid, _, _} =
        lists:keyfind(alarm_manager, 1,
            supervisor:which_children(alarm_sup)),

    exit(OldPid, kill),

    timer:sleep(300),

    {alarm_manager, NewPid, _, _} =
        lists:keyfind(alarm_manager, 1,
            supervisor:which_children(alarm_sup)),

    ?assert(is_pid(NewPid)),
    ?assertNotEqual(OldPid, NewPid).

alarm_sup_restart() ->

    {alarm_manager, Pid, _, _} =
        lists:keyfind(alarm_manager, 1,
            supervisor:which_children(alarm_sup)),

    exit(whereis(alarm_sup), kill),

    timer:sleep(300),

    {alarm_manager, NewPid, _, _} =
        lists:keyfind(alarm_manager, 1,
            supervisor:which_children(alarm_sup)),

    ?assert(is_pid(NewPid)),
    ?assertNotEqual(Pid, NewPid).

timer_queue_restart() ->

    {timer_queue, OldPid, _, _} =
        lists:keyfind(timer_queue, 1,
            supervisor:which_children(alarm_sup)),

    exit(OldPid, kill),

    timer:sleep(300),

    {timer_queue, NewPid, _, _} =
        lists:keyfind(timer_queue, 1,
            supervisor:which_children(alarm_sup)),

    ?assert(is_pid(NewPid)),
    ?assertNotEqual(OldPid, NewPid).