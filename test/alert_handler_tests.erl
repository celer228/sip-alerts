-module(alert_handler_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PORT, 8000).

setup() ->
    application:ensure_all_started(cowboy),
    application:ensure_all_started(inets),
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/log/alert_activity", alert_activity_handler, []},
            {"/alerts/:source", alert_handler, []}
        ]}
    ]),
    {ok, _} = cowboy:start_clear(
            test_http_listener,
            [{port, ?PORT}],
            #{env => #{dispatch => Dispatch}}
    ),
    io:format("Listener info = ~p~n", [ranch:get_addr(test_http_listener)]),
    ok.


cleanup(_) ->
    cowboy:stop_listener(test_http_listener),
    ok.

alert_handler_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        [
            fun prometheus_post/0,
            fun unknown_source/0,
            fun wrong_method/0,
            fun wrong_method_log/0,
            fun log_activity/0
        ]
    }.

prometheus_post() ->

    Body = jsx:encode(#{
        <<"notification_reason">> =>
            <<"first notification">>,

        <<"alerts">> => [
            #{
                <<"annotations">> => #{
                    <<"description">> => <<"Test alert">>,
                    <<"summary">> => <<"Test">>},
                <<"endsAt">> => <<"0001-01-01T00:00:00Z">>,
                <<"fingerprint">> => <<"abc123">>,
                <<"generatorURL">> => <<"http://localhost">>,
                <<"labels">> => #{
                    <<"alertname">> => <<"TestAlert">>,
                    <<"severity">> => <<"critical">>},
                <<"startsAt">> => <<"2026-07-14T14:00:00Z">>,
                <<"status">> => <<"firing">>
            }
        ]
    }),

    {ok, {{_, Status, _}, Headers, Response}} =
        httpc:request(post,{url("/alerts/prometheus"),[],"application/json",Body},[],[]),
    io:format("Status = ~p~nHead = ~p~nResp = ~p~n", [Status, Headers, Response]),
    ?assertEqual(200, Status).

unknown_source() ->

    Body = <<"{}">>,
    {ok, {{_, Status, _}, _Headers, Response}} =
        httpc:request(post,{url("/alerts/zabbix"),[],"application/json",Body},[],[]),

    ?assertEqual(400, Status),
    ?assertEqual("Source Not Allowed",Response).

wrong_method() ->

    {ok, {{_, Status, _}, _, Response}} =
        httpc:request(get,{url("/alerts/prometheus"),[]},[],[]),

    ?assertEqual(405, Status),
    ?assertEqual("Method Not Allowed",Response).

wrong_method_log() ->

    {ok, {{_, Status, _}, _, Response}} =
        httpc:request(post,{url("/log/alert_activity"),[],"application/json",<<"{}">>},[],[]),

    ?assertEqual(405, Status),
    ?assertEqual("{\"error\":\"Method not allowed\"}",Response).

log_activity() ->

    {ok, {{_, Status, _}, _Headers, Response}} =
        httpc:request(get,{url("/log/alert_activity"),[]},[],[]),

    ?assertEqual(200, Status),
    ?assert(is_list(Response)).

url(Path) ->
    lists:flatten(io_lib:format("http://localhost:~p~s",[?PORT, Path])).