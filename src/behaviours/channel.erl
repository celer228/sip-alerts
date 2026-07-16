-module(channel).

%%% Поведение для модулей каналов доставки уведомлений (SIP, Email, ...)
%%%
%%% Единственная callback-функция:
%%%   batch_send/3 - отправка уведомления группе контактов.
%%%
%%% После отправки модуль канала отслеживает статус доставки и
%%% подтверждения получения. Для фиксации результатов он вызывает
%%% функции alarm_manager:
%%%   alarm_manager:mark_confirmation(AlarmId, ContactId)
%%%   alarm_manager:mark_delivery(AlarmId, ContactId)
%%% где ContactId - это один из идентификаторов, переданных в batch_send.

-export_type([reason/0]).

-type reason() :: term().

%%--------------------------------------------------------------------
%% Callback: batch_send/3
%%
%% Отправляет уведомление группе контактов.
%%
%% Параметры:
%%   AlarmId    - идентификатор аларма
%%   AlarmMsg   - текст уведомления
%%   ContactIds - список идентификаторов контактов, специфичных для канала
%%                (например, номера телефонов, email-адреса)
%%
%% Возвращает:
%%   ok              - отправка успешно инициирована
%%   {error, Reason} - не удалось начать отправку
%%--------------------------------------------------------------------
-callback batch_send(AlarmId :: alarm_db:alarm_id(),
                     AlarmMsg :: alarm_db:alarm_text(),
                     ContactIds :: [sub_db:contact_id()]) ->
    ok | {error, Reason :: reason()}.
