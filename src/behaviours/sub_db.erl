-module(sub_db).

%%% Поведение для CRUD-операций с подписчиками (один подписчик - один контакт).
%%%
%%% Канал связи идентифицируется именем модуля,
%%% который реализует поведение channel.
%%--------------------------------------------------------------------
%% Callback: create_subscriber/3
%% Создаёт подписчика с указанным контактом.
%% ChannelMod - модуль канала связи (например, sip_channel).
%%--------------------------------------------------------------------
-callback create_subscriber(ChannelMod :: sipalerts_db:channel_module(),
                            ContactId :: sipalerts_db:contact_id(),
                            ContactData :: sipalerts_db:contact_data()) ->
    {ok, SubscriberId :: sipalerts_db:subscriber_id()} | {error, Reason :: sipalerts_db:reason()}.

%%--------------------------------------------------------------------
%% Callback: get_subscriber/1
%% Возвращает запись подписчика по идентификатору.
%%--------------------------------------------------------------------
-callback get_subscriber(SubscriberId :: sipalerts_db:subscriber_id()) ->
    {ok, Subscriber :: sipalerts_db:subscriber()} | {error, Reason :: sipalerts_db:reason()}.

%%--------------------------------------------------------------------
%% Callback: delete_subscriber/1
%% Удаляет подписчика и его контакт.
%%--------------------------------------------------------------------
-callback delete_subscriber(SubscriberId :: sipalerts_db:subscriber_id()) ->
    ok | {error, Reason :: sipalerts_db:reason()}.

%%--------------------------------------------------------------------
%% Callback: update_contact_id/3
%% Изменяет идентификатор контакта (например, новый номер телефона).
%%--------------------------------------------------------------------
-callback update_contact_id(SubscriberId :: sipalerts_db:subscriber_id(),
                            ChannelMod :: sipalerts_db:channel_module(),
                            NewContactId :: sipalerts_db:contact_id()) ->
    ok | {error, Reason :: sipalerts_db:reason()}.

%%--------------------------------------------------------------------
%% Callback: update_contact_data/3
%% Частично обновляет данные контакта (map).
%%--------------------------------------------------------------------
-callback update_contact_data(ContactId :: sipalerts_db:contact_id(),
                              ChannelMod :: sipalerts_db:channel_module(),
                              NewContactData :: sipalerts_db:contact_data()) ->
    ok | {error, Reason :: sipalerts_db:reason()}.

%%--------------------------------------------------------------------
%% Callback: get_subscriber_by_contact/2
%% Ищет подписчика по модулю канала и идентификатору контакта.
%%--------------------------------------------------------------------
-callback get_subscriber_by_contact(ChannelMod :: sipalerts_db:channel_module(),
                                    ContactId :: sipalerts_db:contact_id()) ->
    {ok, SubscriberId :: sipalerts_db:subscriber_id()} | {error, Reason :: sipalerts_db:reason()}.

%%--------------------------------------------------------------------
%% Callback: list_subscribers/0
%% Возвращает список всех подписчиков.
%%--------------------------------------------------------------------
-callback list_subscribers() ->
    [sipalerts_db:subscriber()] | {error, Reason :: sipalerts_db:reason()}.

-callback list_subscribers_channel(ChannelMod :: sipalerts_db:channel_module()) ->
    [sipalerts_db:subscriber()] | {error, Reason :: sipalerts_db:reason()}.