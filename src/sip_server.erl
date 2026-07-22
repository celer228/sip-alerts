-module(sip_server).

-include_lib("nkserver/include/nkserver_module.hrl").

-include("debuger.hrl").

-export([
    sip_register/2,
    sip_invite/2,
    sip_message/2,
    sip_registrar_store/2,
    sip_get_user_pass/4,
    sip_authorize/3,
    sip_route/5
]).

%% Called to check the user password for a realm
sip_get_user_pass(User, _Realm, _Req, _Call) ->
    io:format("sip_server: sip_get_user_pass(~p)~n", [User]),
    find_pass_userauth(User).

%% Called for every incoming request to be authorized or not
sip_authorize(AuthList, Req, _Call) ->
    io:format("sip_server: sip_authorize()~n"),
    Method = nksip_sipmsg:get_meta(method, Req),
    io:format("Method = ~p~n", [Method]),
    FromUser = nksip_sipmsg:get_meta(from_user, Req),
    io:format("FromUser = ~p~n", [FromUser]),
    FoundedUser = find_user_no_auth(FromUser),
    io:format("sip_server: trying to auth user ~p~n", [FoundedUser]),
    case {Method, FromUser} of
        {'MESSAGE', <<"alert_manager">>} ->
            ok;
        _ ->
            case lists:member(dialog, AuthList) orelse lists:member(register, AuthList) of
                true ->
                    io:format("Authorized (dialog or register)~n", []),
                    ok;
                false ->
                    case proplists:get_value({digest, <<"nksip">>}, AuthList) of
                        true ->
                            io:format("Authorized (digest ok)~n", []),
                            ok;
                        false ->
                            io:format("Forbidden (digest failed)~n", []),
                            forbidden;
                        undefined ->
                            io:format("Challenge (no digest yet)~n", []),
                            {proxy_authenticate, <<"nksip">>}
                    end
            end
    end.


%% This function is called by NkSIP for every new request, to check if it must be proxied, processed locally or replied immediately

sip_route(_Scheme, User, _Domain, Req, _Call) ->
    io:format("sip_server: sip_route(User = ~p)~n", [User]),
    % %% nksip_request:is_local_ruri не отрабатывает в контейнере так, как нам нужно, поэтому ей не пользуемся
    Res = container_is_local_ruri(Req),
    ?DEBUGER("Domain: ~p, TO DOMAIN: ~p", [_Domain, Res]),
    % [{} = nksip_request:get_meta(Field, Arg2),
    case Res of
        true ->
            process;
        false ->
            proxy
    end.

container_is_local_ruri(Req) ->
    {ok, ToDomain} = nksip_request:get_meta(to_domain, Req),
    true.
    % case ToDomain of
    %     <<"172.19.0.1">> -> true;
    %     <<"172.17.0.1">> -> true;
    %     <<"127.0.0.1">> -> true;
    %     <<"localhost">> -> true;
    %     _ -> false
    % end.

sip_register(Req, _Call) ->
    {ok, [{from_scheme, FromScheme}, {from_user, FromUser}, {from_domain, FromDomain}]} =
        nksip_request:get_metas([from_scheme, from_user, from_domain], Req),
    {ok, [{to_scheme, ToScheme}, {to_user, ToUser}, {to_domain, ToDomain}]} =
        nksip_request:get_metas([to_scheme, to_user, to_domain], Req),

    io:format("sip_server: sip_register(From ~p)~n", [FromUser]),
    case {FromScheme, FromUser, FromDomain} of
        {ToScheme, ToUser, ToDomain} ->
            io:format("REGISTER OK: ~p~n", [{ToUser, ToDomain}]),
            {reply, nksip_registrar:request(Req)};
        _ ->
            {reply, forbidden}
    end.

sip_invite(Req, _Call) ->
    {ok, [{scheme, _Scheme}, {from_user, FromUser}, {user, User}, {domain, _Domain}]} =
        nksip_request:get_metas([scheme, from_user, user, domain], Req),
    io:format("sip_server: sip_invite(From ~p, User ~p)~n", [FromUser, User]),
    case get_invite_data(Req) of
        {ok, <<"4800">>, ContactId} ->
            handle_registration(ContactId);

        {ok, <<"4804">>, ContactId} ->
            handle_unregistration(ContactId);

        {ok, <<"4808">>, ContactId} ->
            AlertId = case nksip_request:header(<<"subject">>, Req) of
                {ok, [Id | _]} -> 
                    ?DEBUGER("ID ~p", [Id]),
                    Id;
                {ok, []} -> undefined
            end,
            handle_confirmation(ContactId, AlertId);

        {ok, _, _} ->
            {reply, decline};

        {error, _} ->
            {reply, decline}
    end.

sip_message(_Req, _Call) ->
    ?DEBUGER("REQ ~p, CALL ~p", [_Req, _Call]),
    {reply, ok}.

% sip_ack(_Req, _Call) ->
%     ok.


%%--------------------------------------------------------------------
%% NkSIP registrar storage
%%
%% SIP REGISTER используется только для обнаружения текущего контакта.
%% Эти данные хранятся в оперативной памяти и не создают подписчика
%% в основной базе данных.
%%--------------------------------------------------------------------

sip_registrar_store(SrvId, {get, AOR}) ->
    nklib_store:get({nksip_registrar, SrvId, AOR}, []);

sip_registrar_store(SrvId, {put, AOR, Contacts, TTL}) ->
    nklib_store:put({nksip_registrar, SrvId, AOR}, Contacts, [{ttl, TTL}]);

sip_registrar_store(SrvId, {del, AOR}) ->
    nklib_store:del({nksip_registrar, SrvId, AOR});

sip_registrar_store(SrvId, del_all) ->
    FoldFun =
        fun(Key, _Value, Acc) ->
            case Key of
                {nksip_registrar, SrvId, AOR} ->
                    nklib_store:del({nksip_registrar, SrvId, AOR});
                _ ->
                    Acc
            end
        end,

    nklib_store:fold(FoldFun, none);

sip_registrar_store(_SrvId, list) ->
    FoldFun = fun(Key, Value, Acc) ->
        case Key of
            {nksip_registrar, _, AOR} ->
                [{AOR, Value} | Acc];
            _ ->
                Acc
        end
    end,
    nklib_store:fold(FoldFun, []).


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
    ContactData = #{registered_via => invite},

    case sipalerts_db:get_subscriber_by_contact(sip_channel, ContactId) of
        {ok, _SubscriberId} ->
            case sipalerts_db:update_contact_data(ContactId, sip_channel, ContactData) of
                ok ->
                    io:format("Update sub~n"),
                    {reply, {487, []}};
                {error, Reason} ->
                    io:format("Error = ~p~n", [Reason]),
                    {reply, forbidden}
            end;
        {error, not_found} ->
            case sipalerts_db:create_subscriber(sip_channel, ContactId, ContactData) of
                {ok, SubscriberId} ->
                    io:format("New sub = ~p~n", [SubscriberId]),
                    {reply, {487, []}};
                {error, Reason} ->
                    io:format("Error = ~p~n", [Reason]),
                    {reply, forbidden}
            end;
        {error, Reason} ->
            io:format("Error = ~p~n", [Reason]),
            {reply, forbidden}
    end.

handle_unregistration(ContactId) ->
    case sipalerts_db:get_subscriber_by_contact(sip_channel, ContactId) of
        {ok, SubscriberId} ->
            case sipalerts_db:delete_subscriber(SubscriberId) of
                ok ->
                    io:format("Delete sub~n"),
                    {reply, {487, []}};
                {error, Reason} ->
                    io:format("Error = ~p~n", [Reason]),
                    {reply, forbidden}
            end;

        {error, not_found} ->
            io:format("Error = not_found~n"),
            {reply, forbidden};
        {error, Reason} ->
            io:format("Error = ~p~n", [Reason]),
            {reply, forbidden}
    end.

handle_confirmation(ContactId, AlertId) ->
    Core = core_module(),

    case Core:mark_confirmation(AlertId, ContactId, sip_channel) of
        ok ->
            {reply, {487, []}};

        {error, no_pending_alarm} ->
            io:format("Error = no_pending_alarm~n"),
            {reply, forbidden};

        {error, Reason} ->
            io:format("Error = ~p~n", [Reason]),
            {reply, forbidden}
    end.

% sub_db_module() ->
%     application:get_env(sipalerts, sub_db_module, sub_db).

core_module() ->
    application:get_env(sipalerts, core_module, alert_manager).

%% Private functions

get_users_from_json() ->
    {ok, Binary} = file:read_file("priv/users.json"),
    Output = jsx:decode(Binary),
    #{<<"users">> := Users} = Output,
    Users.

find_user_no_auth(UserFrom) ->
    Users = get_users_from_json(),
    Filter = fun(UserMap) ->
        Auth = maps:get(<<"userAuth">>, UserMap),
        UserPhone = maps:get(<<"userPhone">>, UserMap),
        AuthType = maps:get(<<"authType">>, Auth),
        AuthType == <<"no">> andalso UserPhone == UserFrom
    end,
    lists:filter(Filter, Users).

find_pass_userauth(User) ->
    Users = get_users_from_json(),
    Filter = fun(UserMap) ->
        Auth = maps:get(<<"userAuth">>, UserMap),
        Login = maps:get(<<"userLogin">>, Auth),
        AuthType = maps:get(<<"authType">>, Auth),
        AuthType == <<"yes">> andalso Login == User
    end,
    UserList = lists:filter(Filter, Users),
    case UserList of
        [] -> <<>>;
        _ ->
            [UserMap] = UserList,
            #{<<"userAuth">> := UserAuth} = UserMap,
            #{<<"userPass">> := UserPass} = UserAuth,
            UserPass
    end.
