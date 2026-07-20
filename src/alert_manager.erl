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
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

% 30 сек
-define(DELIVERY_TIMEOUT, 2000).
% 60 сек
-define(CONFIRMATION_TIMEOUT, 60000).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

send(Alert) ->
    wpool:cast(?MODULE, {send, Alert}).

mark_delivery(AlertId, ContactId, ChannelMod) ->
    ?DEBUGER("delivery, AlertId: ~p ||| ContactId: ~p", [AlertId, ContactId]),
    wpool:cast(?MODULE, {mark_delivery, AlertId, ChannelMod, ContactId}),
    ok.

mark_confirmation(AlertId, ContactId, ChannelMod) ->
    ?DEBUGER("confirm, AlertId: ~p ||| ContactId: ~p", [AlertId, ContactId]),
    wpool:cast(?MODULE, {mark_confirmation, AlertId, ChannelMod, ContactId}).

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
init(#mgr_deps{db = MaybeDb, tq = MaybeTq} = State) ->
    % для переопределения используемых модулей в тестах
    Db = alert_core_utils:override_module(MaybeDb, sipalerts_db),
    Tq = alert_core_utils:override_module(MaybeTq, timer_queue),
    {ok, #mgr_deps{db = Db, tq = Tq}};
init([]) ->
    {ok, #mgr_deps{db = sipalerts_db, tq = timer_queue}}.

handle_cast({send, #alert{id = AlertId} = Alert}, #mgr_deps{db = Db, tq = Tq} = State) ->
    %% для всех завели delivery
    ChannelContacts = [
        {ChannelMod, [
            {ContactData, begin
                {ok, DeliveryId} = Db:create_delivery(Alert, SubId),
                DeliveryId
            end}
         || #subscriber{id = SubId, contact_data = ContactData} <- Db:list_subscribers_channel(
                ChannelMod
            )
        ]}
     || ChannelMod <- get_running_channels()
    ],

    AlertMsg = get_alert_msg(Alert),

    lists:foreach(
        fun({ChannelMod, Contacts}) ->
            ok = ChannelMod:batch_send(AlertId, AlertMsg, [
                ContactData
             || {ContactData, _} <- Contacts
            ]),
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
handle_cast({mark_delivery, AlertId, ChannelMod, ContactId}, #mgr_deps{db = Db, tq = Tq} = State) ->
    {ok, SubId} = Db:get_subscriber_by_contact(ChannelMod, ContactId),
    {ok, #delivery{delivery_id = DeliveryId, timer_id = DeliveryTimerId}} = Db:get_delivery(
        {SubId, AlertId}
    ),
    %% отменили таймер на доставку
    ok = Tq:cancel(DeliveryTimerId),
    {ok, ConfirmationTimerId} = Tq:add(
        ?CONFIRMATION_TIMEOUT, {callback, ?MODULE, mark_confirmation_timeout}, DeliveryId
    ),
    ok = Db:update_delivery(DeliveryId, delivered, ConfirmationTimerId),

    %% TODO заменить на alert_log
    ?DEBUGER("mark_delivery --- AlertId: ~p ||| Channel: ~p ||| SubId: ~p", [
        AlertId, ChannelMod, SubId
    ]),
    {noreply, State};
handle_cast({delivery_timeout, DeliveryId}, #mgr_deps{db = Db} = State) ->
    {ok, #delivery{status = Status} = Delivery} = Db:get_delivery(DeliveryId),

    %% TODO на случай, если вдруг таймер отменили, но он всё равно успел прийти
    case Status of
        %% до сих пор на алерт не ответили, значит фейлим
        started ->
            ok = Db:update_delivery(DeliveryId, failed),
            #delivery{
                alert_id = AlertId,
                subscriber_id = SubId,
                channel = Channel
            } = Delivery,
            %% TODO заменить на alert_log
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
handle_cast({mark_confirm, AlertId, ChannelMod, ContactId}, #mgr_deps{db = Db, tq = Tq} = State) ->
    {ok, SubId} = Db:get_subscriber_by_contact(ChannelMod, ContactId),
    {ok, #delivery{delivery_id = DeliveryId, timer_id = ConfirmationTimerId}} = Db:get_delivery(
        {SubId, AlertId}
    ),

    %% отменили таймер на доставку
    ok = Tq:cancel(ConfirmationTimerId),
    ok = Db:update_delivery(DeliveryId, confirmed, unchanged),

    %% TODO заменить на alert_log
    ?DEBUGER("mark_delivery --- AlertId: ~p ||| Channel: ~p ||| SubId: ~p", [
        AlertId, ChannelMod, SubId
    ]),

    ok = Db:delete_delivery(DeliveryId),
    {noreply, State};
handle_cast({confirmation_timeout, DeliveryId}, #mgr_deps{db = Db} = State) ->
    {ok, #delivery{status = Status} = Delivery} = Db:get_delivery(DeliveryId),

    %% TODO на случай, если вдруг таймер отменили, но он всё равно успел прийти
    case Status of
        %% до сих пор на алерт не ответили, значит фейлим
        delivered ->
            ok = Db:update_delivery(DeliveryId, not_confirmed),
            #delivery{
                alert_id = AlertId,
                subscriber_id = SubId,
                channel = Channel
            } = Delivery,
            %% TODO заменить на alert_log
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

%%====================================================================
%% Внутренние функции
%%====================================================================

%% TODO нужно ли?
% check_all_finished(Db, alertId) ->
%     case Db:all_deliveries_finished(alertId) of
%         true ->
%             alert_log:write_final_report(alertId),
%             Db:finalize_alert(alertId);
%         false ->
%             ok
%     end.

%% TODO надо заменить на функцию, которая динамически это определяет
get_running_channels() -> [sip_channel].

-spec get_alert_msg(Alert :: sipalerts_db:alert()) -> binary().
get_alert_msg(#alert{summary = Summary} = _Alert) ->
    Summary.