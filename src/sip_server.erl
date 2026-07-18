-module(sip_server).

-include_lib("nkserver/include/nkserver_module.hrl").

-export([
    sip_register/2,
    sip_invite/2,
    sip_message/2,
    sip_ack/2
]).

sip_register(Req, _Call) ->
    {reply, nksip_registrar:request(Req)}.

sip_invite(Req, _Call) ->
    case get_invite_data(Req) of
        {ok, <<"4800">>, ContactId} ->
            handle_registration(ContactId);

        {ok, <<"4804">>, ContactId} ->
            handle_unregistration(ContactId);

        {ok, <<"4808">>, ContactId} ->
            handle_confirmation(ContactId);

        {ok, _, _} ->
            {reply, decline};

        {error, _} ->
            {reply, decline}
    end.

sip_message(_Req, _Call) ->
    {reply, ok}.

sip_ack(_Req, _Call) ->
    ok.


%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

get_invite_data(Req) ->
    case {
        nksip_request:get_meta(user, Req),
        nksip_request:get_meta(from_user, Req)
    } of
        {{ok, CalledNumber}, {ok, ContactId}} ->
            {ok, CalledNumber, ContactId};

        _ ->
            {error, invalid_invite}
    end.

handle_registration(ContactId) ->
    SubDb = sub_db_module(),
    ContactData = #{registered_via => invite},

    case SubDb:get_subscriber_by_contact(sip_channel, ContactId) of
        {ok, SubscriberId} ->
            case SubDb:update_contact_data(
                ContactId,
                sip_channel,
                ContactData
            ) of
                ok ->
                    {reply, ok};

                {error, _Reason} ->
                    {reply, internal_error}
            end;

        {error, not_found} ->
            case SubDb:create_subscriber(
                sip_channel,
                ContactId,
                ContactData
            ) of
                {ok, _SubscriberId} ->
                    {reply, ok};

                {error, _Reason} ->
                    {reply, internal_error}
            end;

        {error, _Reason} ->
            {reply, internal_error}
    end.

handle_unregistration(ContactId) ->
    SubDb = sub_db_module(),

    case SubDb:get_subscriber_by_contact(sip_channel, ContactId) of
        {ok, SubscriberId} ->
            case SubDb:delete_subscriber(SubscriberId) of
                ok ->
                    {reply, ok};

                {error, _Reason} ->
                    {reply, internal_error}
            end;

        {error, not_found} ->
            {reply, ok};

        {error, _Reason} ->
            {reply, internal_error}
    end.

handle_confirmation(ContactId) ->
    Core = core_module(),

    case Core:mark_confirmation(undefined, ContactId) of
        ok ->
            {reply, ok};

        {error, no_pending_alarm} ->
            {reply, decline};

        {error, _Reason} ->
            {reply, internal_error}
    end.

sub_db_module() ->
    application:get_env(sipalerts, sub_db_module, sub_db).

core_module() ->
    application:get_env(sipalerts, core_module, alert_manager).