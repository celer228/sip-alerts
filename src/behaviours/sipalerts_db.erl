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
-type delivery_id()    :: integer().
-type delivery_status() :: started
                       | delivered
                       | failed
                       | confirmed 
                       | not_confirmed.
-type delivery() :: #delivery{}.
-type timer() :: #timer{}.
-type reason() :: atom() | {atom(), term()}.
-type timer_id() :: timer_queue:timer_id().