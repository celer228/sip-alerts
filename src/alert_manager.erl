-module(alert_manager).
-behaviour(gen_server).
% -behaviour(core).

-include("sipalerts_db.hrl").
-include("debuger.hrl").
-include("alert_manager.hrl").

%% API
-export([start_link/0]).

%% core behaviour
-export([mark_delivery/3, mark_confirmation/3]).

%%
-export([mark_delivery_timeout/2, mark_confirmation_timeout/2, send/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

send(Alert) ->
    wpool:cast(?MODULE, {send, Alert}).

%% alert_manager:mark_delivery(<<"71bdfc9919c41b0a">>, <<"4802">>, sip_channel)

mark_delivery(AlertId, ContactId, ChannelMod) ->
    ?DEBUGER("delivery, AlertId: ~p ||| ContactId: ~p", [AlertId, ContactId]),
    wpool:cast(?MODULE, {mark_delivery, AlertId, ChannelMod, ContactId}),
    ok.

mark_confirmation(AlertId, ContactId, ChannelMod) ->
    ?DEBUGER("confirm, AlertId: ~p ||| ContactId: ~p", [AlertId, ContactId]),
    wpool:cast(?MODULE, {mark_confirm, AlertId, ChannelMod, ContactId}).

mark_delivery_timeout(_TimerId, DeliveryId = _Msg) ->
    ?DEBUGER("delivery timeout, ID: ~p ||| Msg: ~p", [_TimerId, _Msg]),
    wpool:cast(?MODULE, {delivery_timeout, DeliveryId}).

mark_confirmation_timeout(_TimerId, DeliveryId = _Msg) ->
    ?DEBUGER("delivery timeout, ID: ~p ||| Msg: ~p", [_TimerId, _Msg]),
    wpool:cast(?MODULE, {confirmation_timeout, DeliveryId}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

-spec init(State :: #mgr_deps{}) -> {ok, #mgr_deps{}}.
init(#mgr_deps{db = MaybeDb, tq = MaybeTq, log = MaybeLog} = State) ->
    % для переопределения используемых модулей в тестах
    Db = alert_core_utils:override_module(MaybeDb, sipalerts_db),
    Tq = alert_core_utils:override_module(MaybeTq, timer_queue),
    Log = alert_core_utils:override_module(MaybeLog, alert_log),
    {ok, #mgr_deps{db = Db, tq = Tq, log = Log}};
init([]) ->
    {ok, #mgr_deps{db = sipalerts_db, tq = timer_queue, log = alert_log}}.

handle_cast({send, #alert{id = AlertId} = Alert}, #mgr_deps{db = Db, tq = Tq} = State) ->
    %% для всех завели delivery
    ChannelContacts = [
        {ChannelMod, [
            {ContactId, begin
                {ok, DeliveryId} = Db:create_delivery(Alert, SubId),
                DeliveryId
            end}
         || #subscriber{id = SubId, contact_key = {_, ContactId}} <- Db:list_subscribers_channel(
                ChannelMod
            )
        ]}
     || ChannelMod <- get_running_channels()
    ],

    AlertMsg = get_alert_msg(Alert),

    lists:foreach(
        fun({ChannelMod, Contacts}) ->
            ok = ChannelMod:batch_send(AlertId, AlertMsg, [
                ContactId
             || {ContactId, _} <- Contacts
            ]),
            ?DEBUGER("Channel: ~p, Contacts: ~p, AlertId: ~p", [ChannelMod, Contacts, AlertId]),
            lists:foreach(
                fun({_, DeliveryId}) ->
                    {ok, DeliveryTimerId} = Tq:add(
                        ?DELIVERY_TIMEOUT, {callback, ?MODULE, mark_delivery_timeout}, DeliveryId
                    ),
                    ok = Db:update_delivery_status(DeliveryId, started, DeliveryTimerId)
                end,
                Contacts
            )
        end,
        ChannelContacts
    ),
    {noreply, State};
handle_cast({mark_delivery, AlertId, ChannelMod, ContactId}, #mgr_deps{db = Db, tq = Tq, log = Log} = State) ->
    {ok, SubId} = Db:get_subscriber_by_contact(ChannelMod, ContactId),
    ?DEBUGER("SubId, mark delivery ~p", [SubId]),
    % #delivery{delivery_id = DeliveryId, timer_id = DeliveryTimerId}
    % 
    
    {ok, #delivery{delivery_id = DeliveryId, timer_id = DeliveryTimerId} = Delivery} = Db:get_delivery_by_key(
        AlertId, SubId
    ),
    %% отменили таймер на доставку
    % ok = Tq:cancel(DeliveryTimerId),
    ok = Db:update_delivery_status(DeliveryId, delivered, DeliveryTimerId),
    
    {ok, Alert} = Db:get_alert(AlertId),

    ok = Log:log_sent({SubId, ChannelMod, ContactId}, get_alert_msg(Alert), AlertId),

    ?DEBUGER("mark_delivery --- AlertId: ~p ||| Channel: ~p ||| SubId: ~p", [
        AlertId, ChannelMod, SubId
    ]),
    {noreply, State};
handle_cast({delivery_timeout, DeliveryId}, #mgr_deps{db = Db, log = Log} = State) ->
    {ok, #delivery{status = Status} = Delivery} = Db:get_delivery(DeliveryId),

    %% TODO на случай, если вдруг таймер отменили, но он всё равно успел прийти
    case Status of
        %% до сих пор на алерт не ответили, значит фейлим
        started ->
            ok = Db:update_delivery_status(DeliveryId, failed, unchanged),
            #delivery{
                alert_id = AlertId,
                subscriber_id = SubId,
                channel = Channel
            } = Delivery,
            
            {ok, Alert} = Db:get_alert(AlertId),
            {ok, #subscriber{contact_key = {_, ContactId}}} = Db:get_subscriber(SubId),
            ok = Log:log_failed({SubId, Channel, ContactId}, get_alert_msg(Alert), AlertId, delivery_timeout),

            ?DEBUGER(
                "delivery_timeout --- AlertId: ~p ||| SubId: ~p ||| Channel: ~p", [
                    AlertId, SubId, Channel
                ]
            ),
            ok = Db:delete_delivery(DeliveryId);
        %% алерт уже был доставлен, значит таймер уже не нужен
        _ ->
            ok
    end,
    {noreply, State};
handle_cast({mark_confirm, AlertId, ChannelMod, ContactId}, #mgr_deps{db = Db, tq = Tq, log = Log} = State) ->
    {ok, SubId} = Db:get_subscriber_by_contact(ChannelMod, ContactId),
    {ok, #delivery{delivery_id = DeliveryId, timer_id = ConfirmationTimerId}} = Db:get_delivery_by_key(
        AlertId, SubId
    ),

    %% отменили таймер на доставку
    % ok = Tq:cancel(ConfirmationTimerId),
    ok = Db:update_delivery_status(DeliveryId, confirmed, unchanged),

    {ok, Alert} = Db:get_alert(AlertId),
    ok = Log:log_confirmed({SubId, ChannelMod, ContactId}, get_alert_msg(Alert), AlertId),
    ok = Log:log_finalized({SubId, ChannelMod, ContactId}, get_alert_msg(Alert), AlertId),


    ?DEBUGER("mark_delivery --- AlertId: ~p ||| Channel: ~p ||| SubId: ~p", [
        AlertId, ChannelMod, SubId
    ]),

    ok = Db:delete_delivery(DeliveryId),
    {noreply, State};
handle_cast({confirmation_timeout, DeliveryId}, #mgr_deps{db = Db, log = Log} = State) ->
    {ok, #delivery{status = Status} = Delivery} = Db:get_delivery(DeliveryId),

    %% TODO на случай, если вдруг таймер отменили, но он всё равно успел прийти
    case Status of
        %% до сих пор на алерт не ответили, значит фейлим
        delivered ->
            ok = Db:update_delivery_status(DeliveryId, not_confirmed, unchanged),
            #delivery{
                alert_id = AlertId,
                subscriber_id = SubId,
                channel = Channel
            } = Delivery,

            {ok, Alert} = Db:get_alert(AlertId),
            {ok, #subscriber{contact_key = {_, ContactId}}} = Db:get_subscriber(SubId),
            ok = Log:log_failed({SubId, Channel, ContactId}, get_alert_msg(Alert), AlertId, confirmation_timeout),

            ?DEBUGER(
                "delivery_timeout --- AlertId: ~p ||| SubId: ~p ||| Channel: ~p", [
                    AlertId, SubId, Channel
                ]
            ),
            ok = Db:delete_delivery(DeliveryId);
        %% алерт уже был доставлен, значит таймер уже не нужен
        _ ->
            ok
    end,
    {noreply, State}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Внутренние функции
%%====================================================================

%% TODO надо заменить на функцию, которая динамически это определяет
get_running_channels() -> [sip_channel].

-spec get_alert_msg(Alert :: sipalerts_db:alert()) -> binary().
get_alert_msg(#alert{summary = Summary} = _Alert) ->
    Summary.
