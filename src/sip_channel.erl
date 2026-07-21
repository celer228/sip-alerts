-module(sip_channel).

-behaviour(channel).

-export([batch_send/3]).

-include("debuger.hrl").

-spec batch_send(
    sipalerts_db:alert_id(),
    sipalerts_db:alert_text(),
    [sipalerts_db:contact_id()]
) -> ok | {error, sipalerts_db:reason()}.

batch_send(AlertId, AlertMsg, ContactIds)
        when is_binary(AlertId),
             is_binary(AlertMsg),
             is_list(ContactIds) ->
    Results = [send_message(AlertId, AlertMsg, ContactId) || ContactId <- ContactIds],
    case first_error(Results) of
        none ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end;

batch_send(_AlertId, _AlertMsg, _ContactIds) ->
    {error, invalid_arguments}.


send_message(AlertId, AlertMsg, ContactId) when is_binary(ContactId) ->
    Uri = build_uri(ContactId),

    Options = [
        {expires, 10},
        {from, <<"sip:alert_manager@localhost">>},
        {content_type, <<"text/plain">>},
        {body, AlertMsg}
    ],

    %% nksip_uac:message(alertsender, "sip:3003@localhost:5060", [{expires, 10}, {content_type, <<"text/plain">>}, {body, <<"Hello\n">>}]).

    ?DEBUGER("AlertId ~p, msg: ~p", [AlertId, AlertMsg]),
    try
        case nksip_uac:message(sip_server, Uri, Options) of
            {ok, Code, _Meta} when Code >= 200, Code < 300 ->
                io:format("SIP_CHANNEL: MESSAGE SENDED~n"),
                mark_delivery(AlertId, ContactId);

            {ok, Code, _Meta} ->
                io:format("SIP_CHANNEL: RESPONSE ERROR~n"),
                {error, {sip_response, Code}};

            {error, SipReason} ->
                io:format("SIP_CHANNEL: SIP REASON =~p~n", [SipReason]),
                {error, {sip_error, SipReason}};

            {async, _Handle} ->
                ok;

            Other ->
                {error, {unexpected_sip_result, Other}}
        end
    catch
        Class:ExceptionReason ->
            {error, {sip_exception, Class, ExceptionReason}}
    end;

send_message(_AlertId, _AlertMsg, ContactId) ->
    io:format("SIP_CHANNEL: INVALID CONTACT ID = ~p~n", [ContactId]),
    {error, {invalid_contact_id, ContactId}}.


build_uri(<<"sip:", _/binary>> = ContactId) ->
    ContactId;

build_uri(ContactId) ->
    Uri = <<"sip:", ContactId/binary, "@localhost">>,
    io:format("SIP_CHANNEL: BUILD URI ~p~n", [Uri]),
    Uri.


mark_delivery(AlertId, ContactId) ->
    Core = core_module(),

    try Core:mark_delivery(AlertId, ContactId, ?MODULE) of
        ok ->
            ok;

        {error, Reason} ->
            {error, {mark_delivery_failed, Reason}};

        Other ->
            {error, {unexpected_core_result, Other}}
    catch
        error:undef ->
            {error, core_module_unavailable};

        Class:Reason ->
            {error, {core_exception, Class, Reason}}
    end.


first_error([]) ->
    none;

first_error([ok | Rest]) ->
    first_error(Rest);

first_error([{error, _Reason} = Error | _Rest]) ->
    Error.


core_module() ->
    application:get_env(
        sipalerts,
        core_module,
        alert_manager
    ).