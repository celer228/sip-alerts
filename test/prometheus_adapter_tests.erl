-module(prometheus_adapter_tests).

-include_lib("eunit/include/eunit.hrl").
-include("alert.hrl").

adapter_test_() ->
     [
            ?_test(normalize()),
            ?_test(ignore_notification())
     ].

normalize() ->
    Webhook = #{
        <<"notification_reason">> => <<"first notification">>,
        <<"alerts">> => [
            #{
                <<"annotations">> => #{
                    <<"description">> => <<"This is only a test.">>,
                    <<"summary">> => <<"Test alarm">>
                },
                <<"endsAt">> => <<"0001-01-01T00:00:00Z">>,
                <<"fingerprint">> => <<"abc123">>,
                <<"generatorURL">> => <<"http://localhost">>,
                <<"labels">> => #{
                    <<"alertname">> => <<"TestAlert">>,
                    <<"severity">> => <<"critical">>
                },
                <<"startsAt">> => <<"2026-07-14T14:33:53Z">>,
                <<"status">> => <<"firing">>
            }
        ]
    },

    {ok, Alert} = prometheus_adapter:normalize(Webhook),

    ?assertEqual(<<"abc123">>, Alert#alert.id),
    ?assertEqual(<<"TestAlert">>, Alert#alert.alertname),
    ?assertEqual(<<"critical">>, Alert#alert.severity),
    ?assertEqual(<<"firing">>, Alert#alert.status),
    ?assertEqual(<<"prometheus">>, Alert#alert.source).

ignore_notification() ->
    Webhook = #{<<"notification_reason">> => <<"repeat notification">>},

    ?assertEqual({ok, duplicate_webhook}, prometheus_adapter:normalize(Webhook)).