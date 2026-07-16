-module(sub_db).

-include("sub_db.hrl").

%%% Поведение для CRUD-операций с подписчиками (один подписчик - один контакт).
%%%
%%% Канал связи идентифицируется не атомом, а именем модуля,
%%% который реализует поведение channel_behaviour.

-export_type([subscriber_id/0, subscriber/0, channel_module/0, contact_id/0, reason/0]).

-type subscriber_id()  :: binary().        
-type subscriber()     :: #subscriber{}.   % содержит id и contact
-type channel_module() :: module().        % модуль, реализующий channel_behaviour
-type contact_id()     :: term().
-type contact_data()   :: term().
-type reason()         :: term().

%%--------------------------------------------------------------------
%% Callback: create_subscriber/3
%% Создаёт подписчика с указанным контактом.
%% ChannelMod - модуль канала связи (например, sip_channel).
%%--------------------------------------------------------------------
-callback create_subscriber(ChannelMod :: channel_module(),
                            ContactId :: contact_id(),
                            Data :: map()) ->
    {ok, SubscriberId :: subscriber_id()} | {error, Reason :: reason()}.

%%--------------------------------------------------------------------
%% Callback: get_subscriber/1
%% Возвращает запись подписчика по идентификатору.
%%--------------------------------------------------------------------
-callback get_subscriber(SubscriberId :: subscriber_id()) ->
    {ok, Subscriber :: subscriber()} | {error, Reason :: reason()}.

%%--------------------------------------------------------------------
%% Callback: delete_subscriber/1
%% Удаляет подписчика и его контакт.
%%--------------------------------------------------------------------
-callback delete_subscriber(SubscriberId :: subscriber_id()) ->
    ok | {error, Reason :: reason()}.

%%--------------------------------------------------------------------
%% Callback: update_contact_id/3
%% Изменяет идентификатор контакта (например, новый номер телефона).
%%--------------------------------------------------------------------
-callback update_contact_id(SubscriberId :: subscriber_id(),
                            ChannelMod :: channel_module(),
                            NewContactId :: contact_id()) ->
    ok | {error, Reason :: reason()}.

%%--------------------------------------------------------------------
%% Callback: update_contact_data/3
%% Частично обновляет данные контакта (map).
%%--------------------------------------------------------------------
-callback update_contact_data(ContactId :: contact_id(),
                              ChannelMod :: channel_module(),
                              NewContactData :: contact_data()) ->
    ok | {error, Reason :: reason()}.

%%--------------------------------------------------------------------
%% Callback: get_subscriber_by_contact/2
%% Ищет подписчика по модулю канала и идентификатору контакта.
%%--------------------------------------------------------------------
-callback get_subscriber_by_contact(ChannelMod :: channel_module(),
                                    ContactId :: contact_id()) ->
    {ok, SubscriberId :: subscriber_id()} | {error, Reason :: reason()}.

%%--------------------------------------------------------------------
%% Callback: list_subscribers/0
%% Возвращает список всех подписчиков.
%%--------------------------------------------------------------------
-callback list_subscribers() ->
    [subscriber()] | {error, Reason :: reason()}.
