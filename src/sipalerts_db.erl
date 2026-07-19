-module(sipalerts_db).

-include("sipalerts_db.hrl").
-export_type([
    %% subscriber
    subscriber/0,
    subscriber_id/0,
    channel_module/0,
    contact_key/0,
    contact_id/0,
    contact_data/0,

    %% alert
    alert/0,
    alert_id/0,
    alert_text/0,

    %% delivery
    delivery/0,
    delivery_id/0,
    delivery_status/0,

    %% timer
    timer_id/0,
    timer/0,

    %% common
    reason/0
]).
-type alert() :: #alert{}.
-type alert_id() :: binary().
-type alert_text() :: binary().
-type subscriber_id()  :: binary().
-type subscriber()     :: #subscriber{}.
-type channel_module() :: module().
-type contact_key()    :: {channel_module(), contact_id()}.
-type contact_id()     :: term().
-type contact_data()   :: term().
-type delivery_id()    :: binary().
-type delivery_status() :: started
                       | delivered
                       | failed
                       | confirmed 
                       | not_confirmed.
-type delivery() :: #delivery{}.
-type timer() :: #timer{}.
-type reason() :: atom() | {atom(), term()}.
-type timer_id() :: timer_queue:timer_id().

-export([
    init/0
]).

-behaviour(sub_db).
-export([
    create_subscriber/3,
    get_subscriber/1,
    delete_subscriber/1,
    update_contact_id/3,
    update_contact_data/3,
    get_subscriber_by_contact/2,
    list_subscribers/0,
    list_subscribers_channel/1
]).

-behaviour(delivery_db).
-export([
    create_delivery/2,
    get_delivery/1,
    update_delivery_status/2,
    delete_delivery/1,
    list_deliveries/0
]).

-behaviour(timer_db).
-export([
    insert_timer/1,
    delete_timer/1,
    get_timer/1,
    list_timers/0
]).

-behaviour(alert_db).
-export([
    create_alert/1,
    get_alert/1,
    delete_alert/1,
    list_alerts/0
]).

init() ->
    ok = init_sub(),
    ok = init_delivery(),
    ok = init_timer(),
    ok = init_alert(),
    ok.

%% Функции для работы с таблицей subscriber.

init_sub() ->
    case mnesia:create_table(subscriber, [{attributes, record_info(fields, subscriber)},
                              {disc_copies, [node()]},
                              {type, set}]) of
        {atomic, ok} -> mnesia:add_table_index(subscriber, contact_key), ok;
        {aborted, {already_exists, subscriber}} -> ok;
        Error -> Error
    end.

-spec create_subscriber(ChannelMod :: channel_module(), ContactId :: contact_id(), ContactData :: contact_data()) -> {ok, subscriber_id()} | {error, reason()}.
create_subscriber(ChannelMod, ContactId, ContactData) ->
    Subscriber = #subscriber{
        id = generate_id(),
        channel = ChannelMod,
        contact_key = {ChannelMod, ContactId},
        contact_data = ContactData
    },
    AddRec = fun() ->
                     mnesia:write(Subscriber)
             end,
    case mnesia:transaction(AddRec) of
        {atomic, ok} -> {ok, Subscriber#subscriber.id};
        {aborted, Reason} -> {error, Reason}
    end.

-spec get_subscriber(SubscriberId :: subscriber_id()) -> {ok, subscriber()} | {error, not_found} | {error, reason()}.
get_subscriber(SubscriberId) ->
    SearchSub = fun() ->
                         mnesia:read(subscriber, SubscriberId)
                 end,
    case mnesia:transaction(SearchSub) of
        {atomic, [Subscriber]} -> {ok, Subscriber};
        {atomic, []} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec delete_subscriber(SubscriberId :: subscriber_id()) -> ok | {error, reason()}.
delete_subscriber(SubscriberId) ->
    DeleteSub = fun() ->
                         mnesia:delete({subscriber, SubscriberId})
                 end,
    case mnesia:transaction(DeleteSub) of
        {atomic, ok} -> ok;
        {aborted, Reason} -> {error, Reason}
    end.

-spec update_contact_id(SubscriberId :: subscriber_id(), ChannelMod :: channel_module(), NewContactId :: contact_id()) -> ok | {error, not_found} | {error, reason()}.
update_contact_id(SubscriberId, ChannelMod, NewContactId) ->
    UpdateSub = fun() ->
        case mnesia:read(subscriber, SubscriberId) of
            [Subscriber] ->
                UpdatedSubscriber = Subscriber#subscriber{
                    contact_key = {ChannelMod, NewContactId}
                },
                mnesia:write(UpdatedSubscriber),
                ok;
            [] ->
                {error, not_found}
        end
    end,
    case mnesia:transaction(UpdateSub) of
        {atomic, ok} -> ok;
        {atomic, {error, not_found}} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec update_contact_data(ContactId :: contact_id(), ChannelMod :: channel_module(), NewContactData :: contact_data()) -> ok | {error, not_found} | {error, reason()}.
update_contact_data(ContactId, ChannelMod, NewContactData) ->
    UpdateSub = fun() ->
        case mnesia:index_read(subscriber, {ChannelMod, ContactId}, #subscriber.contact_key) of
            [Subscriber] ->
                UpdatedSubscriber = Subscriber#subscriber{
                    contact_data = NewContactData
                },
                mnesia:write(UpdatedSubscriber),
                ok;
            [] ->
                {error, not_found}
        end
    end,
    case mnesia:transaction(UpdateSub) of
        {atomic, ok} -> ok;
        {atomic, {error, not_found}} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec get_subscriber_by_contact(ChannelMod :: channel_module(), ContactId :: contact_id()) -> {ok, subscriber_id()} | {error, not_found} | {error, reason()}.
get_subscriber_by_contact(ChannelMod, ContactId) ->
    SearchSub = fun() ->
        case mnesia:index_read(subscriber, {ChannelMod, ContactId}, #subscriber.contact_key) of
            [Subscriber] -> {ok, Subscriber#subscriber.id};
            [] -> {error, not_found}
        end
    end,
    case mnesia:transaction(SearchSub) of
        {atomic, {ok, SubscriberId}} -> {ok, SubscriberId};
        {atomic, {error, not_found}} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec list_subscribers() -> [subscriber()] | {error, reason()}.
list_subscribers() ->
    ListSubs = fun() ->
        mnesia:foldl(fun(Subscriber, Acc) -> [Subscriber | Acc] end, [], subscriber)
    end,
    case mnesia:transaction(ListSubs) of
        {atomic, Subscribers} -> Subscribers;
        {aborted, Reason} -> {error, Reason}
    end.

-spec list_subscribers_channel(ChannelMod :: channel_module()) -> [subscriber()] | {error, reason()}.
list_subscribers_channel(ChannelMod) ->
    ListSubs = fun() ->
        mnesia:foldl(fun(Subscriber, Acc) ->
            case Subscriber#subscriber.channel of
                ChannelMod -> [Subscriber | Acc];
                _ -> Acc
            end
        end, [], subscriber)
    end,
    case mnesia:transaction(ListSubs) of
        {atomic, Subscribers} -> Subscribers;
        {aborted, Reason} -> {error, Reason}
    end.

%% Функции для работы с таблицей delivery.

init_delivery() ->
    case mnesia:create_table(delivery, [{attributes, record_info(fields, delivery)},
                                {disc_copies, [node()]},
                                {type, set}]) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, delivery}} -> ok;
        Error -> Error
    end.

-spec create_delivery(Alert :: alert(), SubscriberId :: subscriber_id()) -> {ok, delivery_id()} | {error, reason()}.
create_delivery(Alert, SubscriberId) ->
    Delivery = #delivery{
        delivery_id = generate_id_node(),
        alert_id = Alert#alert.id,
        subscriber_id = SubscriberId,
        channel = case get_subscriber(SubscriberId) of
            {ok, Subscriber} -> Subscriber#subscriber.channel;
            {error, _} -> undefined
        end,
        status = started,
        failed_reason = undefined,
        started_at = calendar:local_time(),
        sent_at = undefined,
        delivered_at = undefined,
        confirmed_at = undefined
    },
    AddRec = fun() ->
                     mnesia:write(Delivery)
             end,
    case mnesia:transaction(AddRec) of
        {atomic, ok} -> {ok, Delivery#delivery.delivery_id};
        {aborted, Reason} -> {error, Reason}
    end.

-spec get_delivery(DeliveryId :: delivery_id()) -> {ok, delivery()} | {error, not_found} | {error, reason()}.
get_delivery(DeliveryId) ->
    SearchDel = fun() ->
                         mnesia:read(delivery, DeliveryId)
                 end,
    case mnesia:transaction(SearchDel) of
        {atomic, [Delivery]} -> {ok, Delivery};
        {atomic, []} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec update_delivery_status(DeliveryId :: delivery_id(), NewStatus :: delivery_status()) -> ok | {error, not_found} | {error, reason()}.
update_delivery_status(DeliveryId, NewStatus) ->
    UpdateDel = fun() ->
        case mnesia:read(delivery, DeliveryId) of
            [Delivery] ->
                UpdatedDelivery = Delivery#delivery{
                    status = NewStatus,
                    sent_at = case NewStatus of
                        started -> calendar:local_time();
                        _ -> Delivery#delivery.sent_at
                    end,
                    delivered_at = case NewStatus of
                        delivered -> calendar:local_time();
                        _ -> Delivery#delivery.delivered_at
                    end,
                    confirmed_at = case NewStatus of
                        confirmed -> calendar:local_time();
                        _ -> Delivery#delivery.confirmed_at
                    end
                },
                mnesia:write(UpdatedDelivery),
                ok;
            [] ->
                {error, not_found}
        end
    end,
    case mnesia:transaction(UpdateDel) of
        {atomic, ok} -> ok;
        {atomic, {error, not_found}} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec delete_delivery(DeliveryId :: delivery_id()) -> ok | {error, reason()}.
delete_delivery(DeliveryId) ->
    DeleteDel = fun() ->
                         mnesia:delete({delivery, DeliveryId})
                 end,
    case mnesia:transaction(DeleteDel) of
        {atomic, ok} -> ok;
        {aborted, Reason} -> {error, Reason}
    end.

-spec list_deliveries() -> [delivery()] | {error, reason()}.
list_deliveries() ->
    ListDels = fun() ->
        mnesia:foldl(fun(Delivery, Acc) -> [Delivery | Acc] end, [], delivery)
    end,
    case mnesia:transaction(ListDels) of
        {atomic, Deliveries} -> Deliveries;
        {aborted, Reason} -> {error, Reason}
    end.

%% Функции для работы с таблицей timer.

init_timer() ->
    case mnesia:create_table(timer, [{attributes, record_info(fields, timer)},
                              {disc_copies, [node()]},
                              {type, set}]) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, timer}} -> ok;
        Error -> Error
    end.

-spec insert_timer(#timer{}) -> ok | {error, reason()}.
insert_timer(Timer = #timer{}) ->
    AddRec = fun() ->
                     mnesia:write(Timer)
             end,
    case mnesia:transaction(AddRec) of
        {atomic, ok} -> ok;
        {aborted, Reason} -> {error, Reason}
    end.

-spec delete_timer(TimerId :: timer_id()) -> ok | {error, reason()}.
delete_timer(TimerId) ->
    DeleteTimer = fun() ->
                         mnesia:delete({timer, TimerId})
                 end,
    case mnesia:transaction(DeleteTimer) of
        {atomic, ok} -> ok;
        {aborted, Reason} -> {error, Reason}
    end.

-spec get_timer(TimerId :: timer_id()) -> {ok, timer()} | {error, not_found} | {error, reason()}.
get_timer(TimerId) ->
    GetRec = fun() ->
        case mnesia:read(timer, TimerId) of
            [Timer] ->
                {ok, Timer};
            [] ->
                {error, not_found}
        end
    end,
    case mnesia:transaction(GetRec) of
        {atomic, {ok, Timer}} -> {ok, Timer};
        {atomic, {error, not_found}} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec list_timers() -> {ok, [timer()]} | {error, reason()}.
list_timers() ->
    ListTimers = fun() ->
        mnesia:foldl(fun(Timer, Acc) -> [Timer | Acc] end, [], timer)
    end,
    case mnesia:transaction(ListTimers) of
        {atomic, Timers} -> {ok, Timers};
        {aborted, Reason} -> {error, Reason}
    end.

%% Функции для работы с таблицей alert.

init_alert() ->
    case mnesia:create_table(alert, [{attributes, record_info(fields, alert)},
                              {disc_copies, [node()]},
                              {type, set}]) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, alert}} -> ok;
        Error -> Error
    end.

-spec create_alert(#alert{}) -> {ok, alert_id()} | {error, reason()}.
create_alert(Alert = #alert{id = AlertId}) ->
    AddRec = fun() ->
                     mnesia:write(Alert)
             end,
    case mnesia:transaction(AddRec) of
        {atomic, ok} -> {ok, AlertId};
        {aborted, Reason} -> {error, Reason}
    end.

-spec get_alert(AlertId :: alert_id()) -> {ok, alert()} | {error, not_found} | {error, reason()}.
get_alert(AlertId) ->
    GetRec = fun() ->
        case mnesia:read(alert, AlertId) of
            [Alert] ->
                {ok, Alert};
            [] ->
                {error, not_found}
        end
    end,
    case mnesia:transaction(GetRec) of
        {atomic, {ok, Alert}} -> {ok, Alert};
        {atomic, {error, not_found}} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.

-spec delete_alert(AlertId :: alert_id()) -> ok | {error, reason()}.
delete_alert(AlertId) ->
    DeleteAlert = fun() ->
        mnesia:delete({alert, AlertId})
    end,
    case mnesia:transaction(DeleteAlert) of
        {atomic, ok} -> ok;
        {aborted, Reason} -> {error, Reason}
    end.

-spec list_alerts() -> [alert()] | {error, reason()}.
list_alerts() ->
    ListAlerts = fun() ->
        mnesia:foldl(fun(Alert, Acc) -> [Alert | Acc] end, [], alert)
    end,
    case mnesia:transaction(ListAlerts) of
        {atomic, Alerts} -> Alerts;
        {aborted, Reason} -> {error, Reason}
    end.

% Вспомогательные функции для генерации уникальных идентификаторов.

-spec generate_id() -> binary().
generate_id() ->
    base64:encode(crypto:strong_rand_bytes(8)).

-spec generate_id_node() -> binary().
generate_id_node() ->
    Unique = base64:encode(crypto:strong_rand_bytes(16)),
    Node = atom_to_binary(node(), utf8),
    <<Node/binary, "-", Unique/binary>>.