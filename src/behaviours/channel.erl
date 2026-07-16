-module(channel).

%%% Поведение для модулей каналов доставки уведомлений (SIP, Email, ...)
%%%
%%% Единственная callback-функция:
%%%   batch_send/3 - отправка уведомления группе контактов.
%%%
%%% После отправки модуль канала отслеживает статус доставки и
%%% подтверждения получения. Для фиксации результатов он вызывает
%%% функции alert_manager:
%%%   alert_manager:mark_confirmation(alertId, ContactId)
%%%   alert_manager:mark_delivery(alertId, ContactId)
%%% где ContactId - это один из идентификаторов, переданных в batch_send.
%%--------------------------------------------------------------------
%% Callback: batch_send/3
%%
%% Отправляет уведомление группе контактов.
%%
%% Параметры:
%%   alertId    - идентификатор аларма
%%   alertMsg   - текст уведомления
%%   ContactIds - список идентификаторов контактов, специфичных для канала
%%                (например, номера телефонов, email-адреса)
%%
%% Возвращает:
%%   ok              - отправка успешно инициирована
%%   {error, Reason} - не удалось начать отправку
%%--------------------------------------------------------------------
-callback batch_send(AlertId :: sipalerts_db:alert_id(),
                     AlertMsg :: sipalerts_db:alert_text(),
                     ContactIds :: [sipalerts_db:contact_id()]) ->
    ok | {error, Reason :: sipalerts_db:reason()}.
