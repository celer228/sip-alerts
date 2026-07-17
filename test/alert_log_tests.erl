-module(alert_log_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TEST_LOG_FILE, "log/test_alert.log").

alert_log_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun(_Pid) ->
            [
                ?_test(logging_flow_case())
            ]
        end
    }.

setup() ->
    stop_existing_logger(),
    clean_logs(),

    application:set_env(
        sipalerts,
        alarm_log_file,
        ?TEST_LOG_FILE
    ),

    application:set_env(
        sipalerts,
        alarm_log_max_bytes,
        10485760
    ),

    application:set_env(
        sipalerts,
        alarm_log_max_archives,
        5
    ),

    {ok, Pid} = alert_log:start_link(),

    %% EUnit выполняет setup в отдельном временном процессе.
    %% Без unlink alert_log завершится вместе с ним.
    unlink(Pid),

    Pid.

cleanup(Pid) ->
    case is_process_alive(Pid) of
        true ->
            ok = gen_server:stop(Pid);
        false ->
            ok
    end,

    application:unset_env(
        sipalerts,
        alarm_log_file
    ),

    application:unset_env(
        sipalerts,
        alarm_log_max_bytes
    ),

    application:unset_env(
        sipalerts,
        alarm_log_max_archives
    ),

    clean_logs().

logging_flow_case() ->
    ok = alert_log:log_sent(
        <<"4801">>,
        <<"High CPU">>,
        <<"alarm1">>
    ),

    ok = alert_log:log_failed(
        <<"4802">>,
        <<"Database">>,
        <<"alarm2">>,
        timeout
    ),

    ok = alert_log:log_confirmed(
        <<"4801">>,
        <<"High CPU">>,
        <<"alarm1">>
    ),

    ok = alert_log:log_finalized(
        <<"4801">>,
        <<"High CPU">>,
        <<"alarm1">>
    ),

    %% get_report/0 вызывается через call.
    %% Поэтому все предыдущие cast уже будут обработаны
    %% до формирования отчёта.
    {ok, Report} = alert_log:get_report(),

    ?assertEqual(
        4,
        length(Report)
    ),

    [Line1, Line2, Line3, Line4] = Report,

    ?assert(contains(
        Line1,
        <<"SENT_UNCONFIRMED">>
    )),

    ?assert(contains(
        Line1,
        <<"4801">>
    )),

    ?assert(contains(
        Line1,
        <<"High CPU">>
    )),

    ?assert(contains(
        Line1,
        <<"alarm1">>
    )),

    ?assert(contains(
        Line2,
        <<"FAILED">>
    )),

    ?assert(contains(
        Line2,
        <<"timeout">>
    )),

    ?assert(contains(
        Line3,
        <<"CONFIRMED">>
    )),

    ?assert(contains(
        Line4,
        <<"FINALIZED">>
    )).

contains(Line, Fragment) ->
    binary:match(
        Line,
        Fragment
    ) =/= nomatch.

stop_existing_logger() ->
    case whereis(alert_log) of
        undefined ->
            ok;

        Pid ->
            unlink(Pid),
            ok = gen_server:stop(Pid)
    end.

clean_logs() ->
    Files = filelib:wildcard(
        ?TEST_LOG_FILE ++ "*"
    ),

    lists:foreach(
        fun(File) ->
            case file:delete(File) of
                ok ->
                    ok;

                {error, enoent} ->
                    ok
            end
        end,
        Files
    ),

    ok.