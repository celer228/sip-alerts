-module(db_tests).

-include_lib("eunit/include/eunit.hrl").
-include("sipalerts_db.hrl").

setup() ->
    mnesia:stop(),

    %% удалить старую тестовую БД
    mnesia:delete_schema([node()]),

    ok = mnesia:create_schema([node()]),

    ok = mnesia:start(),

    ok = sipalerts_db:init(),

    ok.


cleanup(_) ->
    mnesia:stop(),
    mnesia:delete_schema([node()]),
    ok.


subscriber_create_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun() ->
            Channel = sip_channel,
            ContactId = <<"79991234567">>,
            Data = #{name => <<"test">>},

            {ok, SubscriberId} = sipalerts_db:create_subscriber(Channel, ContactId, Data),


            {ok, Subscriber} = sipalerts_db:get_subscriber(SubscriberId),

            ?assertEqual(SubscriberId, Subscriber#subscriber.id),

            ?assertEqual(Data, Subscriber#subscriber.contact_data)

        end
    }.

subscriber_find_by_contact_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun() ->
            Channel = sip_channel,
            Contact = <<"100500">>,
        {ok, Id} = sipalerts_db:create_subscriber(Channel, Contact, #{}),

        {ok, FoundId} = sipalerts_db:get_subscriber_by_contact(Channel, Contact),

        ?assertEqual(Id, FoundId)

        end
    }.

update_contact_data_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun() ->

            Channel = sip_channel,
            Contact = <<"111">>,

            {ok, Id} = sipalerts_db:create_subscriber(Channel, Contact, #{old => true}),

            ok = sipalerts_db:update_contact_data(Contact, Channel, #{new => true}),

            {ok, Subscriber} = sipalerts_db:get_subscriber(Id),

            ?assertEqual(#{new => true}, Subscriber#subscriber.contact_data)

        end
    }.

delete_subscriber_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun() ->

            {ok, Id} = sipalerts_db:create_subscriber(sip_channel, <<"123">>, #{}),

            ok = sipalerts_db:delete_subscriber(Id),

            ?assertEqual({error,not_found}, sipalerts_db:get_subscriber(Id))

        end
    }.

delivery_create_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun() ->
            Alert = #alert{id = <<"alert1">>,
                           alertname = <<"TestAlert">>,
                           description = <<"This is only a test.">>,
                           summary = <<"Test alert">>,
                           severity = <<"critical">>,
                           status = <<"firing">>,
                           source = <<"prometheus">>,
                           starts_at = <<"2026-07-14T14:33:53Z">>,
                           ends_at = <<"0001-01-01T00:00:00Z">>
            },

            {ok, SubId} = sipalerts_db:create_subscriber(sip_channel, <<"555">>, #{}),

            {ok, DeliveryId} = sipalerts_db:create_delivery(Alert, SubId),

            {ok, Delivery} = sipalerts_db:get_delivery(DeliveryId),

            ?assertEqual(started, Delivery#delivery.status)

        end
    }.

delivery_status_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun() ->
            Alert = #alert{id = <<"alert1">>,
                           alertname = <<"TestAlert">>,
                           description = <<"This is only a test.">>,
                           summary = <<"Test alert">>,
                           severity = <<"critical">>,
                           status = <<"firing">>,
                           source = <<"prometheus">>,
                           starts_at = <<"2026-07-14T14:33:53Z">>,
                           ends_at = <<"0001-01-01T00:00:00Z">>
            },

            {ok, SubId} = sipalerts_db:create_subscriber(sip_channel, <<"111">>, #{}),

            {ok, DeliveryId} = sipalerts_db:create_delivery(Alert, SubId),

            ok = sipalerts_db:update_delivery_status(DeliveryId, delivered, unchanged),

            {ok, Delivery} = sipalerts_db:get_delivery(DeliveryId),

            ?assertEqual(delivered, Delivery#delivery.status)

        end
    }.

timer_insert_test_() ->
    {
        setup,
        fun setup/0,
        fun cleanup/1,
        fun() ->
            Timer = #timer{id = <<"timer1">>, deadline_ms = 1000,
                           destination = test, message = <<"hello">>},

            ok = sipalerts_db:insert_timer(Timer),

            {ok, Result} = sipalerts_db:get_timer(<<"timer1">>),

            ?assertEqual(Timer, Result)


        end
    }.