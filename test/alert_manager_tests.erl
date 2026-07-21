-module(alert_manager_tests).
-include_lib("eunit/include/eunit.hrl").
-include("sipalerts_db.hrl").
-include("alert_manager.hrl").

setup() ->
    catch wpool:stop_pool(alert_manager),
    timer:sleep(200),
    case wpool:start() of
        ok -> ok;
        {error, {already_started, _}} -> ok
    end,
    meck:new(sip_channel, [non_strict]),
    ok.

cleanup(_) ->
    wpool:stop_pool(alert_manager),
    timer:sleep(100),
    wpool:stop(),
    meck:unload().

mock_modules() ->
    MockDb = mock_db,
    MockTq = mock_tq,
    meck:new(MockDb, [non_strict]),
    meck:new(MockTq, [non_strict]),
    {ok, _PoolPid} = wpool:start_pool(alert_manager, [
        {workers, 5},
        {worker, {alert_manager, #mgr_deps{db = MockDb, tq = MockTq}}}
    ]),
    {MockDb, MockTq}.

wait() -> timer:sleep(150).

alert_manager_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        fun test_send_alert/0,
        fun test_mark_delivery/0,
        fun test_delivery_timeout/0,
        fun test_mark_confirmation/0,
        fun test_confirmation_timeout/0
    ]}.

test_send_alert() ->
    {MockDb, MockTq} = mock_modules(),
    Alert = #alert{id = <<"alarm1">>, summary = <<"Test">>},
    Sub1 = #subscriber{id = <<"sub1">>, contact_data = #{phone => <<"4801">>}},
    Sub2 = #subscriber{id = <<"sub2">>, contact_data = #{phone => <<"4802">>}},

    meck:expect(MockDb, list_subscribers_channel, fun(sip_channel) -> [Sub1, Sub2] end),
    meck:expect(
        MockDb,
        create_delivery,
        fun
            (#alert{id = <<"alarm1">>}, <<"sub1">>) -> {ok, 1};
            (#alert{id = <<"alarm1">>}, <<"sub2">>) -> {ok, 2}
        end
    ),
    meck:expect(
        MockDb,
        update_delivery_status,
        fun(Did, started, _TimerId) when Did == 1; Did == 2 -> ok end
    ),

    meck:expect(
        MockTq,
        add,
        fun
            (?DELIVERY_TIMEOUT, {callback, alert_manager, mark_delivery_timeout}, 1) -> {ok, ref1};
            (?DELIVERY_TIMEOUT, {callback, alert_manager, mark_delivery_timeout}, 2) -> {ok, ref2}
        end
    ),

    meck:expect(
        sip_channel,
        batch_send,
        fun(<<"alarm1">>, <<"Test">>, [Data1, Data2]) ->
            ?assertEqual([#{phone => <<"4801">>}, #{phone => <<"4802">>}], [Data1, Data2]),
            ok
        end
    ),

    alert_manager:send(Alert),
    wait(),
    ?assert(meck:validate(MockDb)),
    ?assert(meck:validate(MockTq)),
    ?assert(meck:validate(sip_channel)).

test_mark_delivery() ->
    {MockDb, MockTq} = mock_modules(),

    meck:expect(
        MockDb,
        get_subscriber_by_contact,
        fun(sip_channel, <<"ct1">>) -> {ok, <<"sub1">>} end
    ),
    meck:expect(
        MockDb,
        get_delivery_by_key,
        fun(<<"alarm1">>, <<"sub1">>) ->
            {ok, #delivery{delivery_id = 10, timer_id = ref_del}}
        end
    ),
    meck:expect(MockTq, cancel, fun(ref_del) -> ok end),
    meck:expect(
        MockTq,
        add,
        fun(?CONFIRMATION_TIMEOUT, {callback, alert_manager, mark_confirmation_timeout}, 10) ->
            {ok, ref_confirm}
        end
    ),
    meck:expect(
        MockDb,
        update_delivery_status,
        fun(10, delivered, ref_confirm) -> ok end
    ),

    alert_manager:mark_delivery(<<"alarm1">>, <<"ct1">>, sip_channel),
    wait(),
    ?assert(meck:validate(MockDb)),
    ?assert(meck:validate(MockTq)).

test_delivery_timeout() ->
    {MockDb, _MockTq} = mock_modules(),

    meck:expect(
        MockDb,
        get_delivery,
        fun(10) ->
            {ok, #delivery{
                delivery_id = 10,
                status = started,
                alert_id = <<"alarm1">>,
                subscriber_id = <<"sub1">>,
                channel = sip_channel
            }}
        end
    ),
    meck:expect(
        MockDb,
        update_delivery_status,
        fun(10, failed, unchanged) -> ok end
    ),
    meck:expect(
        MockDb,
        delete_delivery,
        fun(10) -> ok end
    ),

    alert_manager:mark_delivery_timeout(ignored_timer_id, 10),
    wait(),
    ?assert(meck:validate(MockDb)).

test_mark_confirmation() ->
    {MockDb, MockTq} = mock_modules(),

    meck:expect(
        MockDb,
        get_subscriber_by_contact,
        fun(sip_channel, <<"ct1">>) -> {ok, <<"sub1">>} end
    ),
    meck:expect(
        MockDb,
        get_delivery_by_key,
        fun(<<"alarm1">>, <<"sub1">>) ->
            {ok, #delivery{delivery_id = 20, timer_id = ref_confirm}}
        end
    ),
    meck:expect(MockTq, cancel, fun(ref_confirm) -> ok end),
    meck:expect(
        MockDb,
        update_delivery_status,
        fun(20, confirmed, unchanged) -> ok end
    ),
    meck:expect(
        MockDb,
        delete_delivery,
        fun(20) -> ok end
    ),

    alert_manager:mark_confirmation(<<"alarm1">>, <<"ct1">>, sip_channel),
    wait(),
    ?assert(meck:validate(MockDb)),
    ?assert(meck:validate(MockTq)).

test_confirmation_timeout() ->
    {MockDb, _MockTq} = mock_modules(),

    meck:expect(
        MockDb,
        get_delivery,
        fun(30) ->
            {ok, #delivery{
                delivery_id = 30,
                status = delivered,
                alert_id = <<"alarm1">>,
                subscriber_id = <<"sub1">>,
                channel = sip_channel
            }}
        end
    ),
    meck:expect(
        MockDb,
        update_delivery_status,
        fun(30, not_confirmed, unchanged) -> ok end
    ),
    meck:expect(
        MockDb,
        delete_delivery,
        fun(30) -> ok end
    ),

    alert_manager:mark_confirmation_timeout(ignored, 30),
    wait(),
    ?assert(meck:validate(MockDb)).
