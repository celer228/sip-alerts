-module(sip_server_tests).

-include_lib("eunit/include/eunit.hrl").

sip_registrar_store_test_() ->
    {
        foreach,
        fun setup/0,
        fun cleanup/1,
        [
            fun get/0,
            fun put/0,
            fun delete/0,
            fun delete_all/0
        ]
    }.

setup() ->
    meck:new(nklib_store, [passthrough]),
    ok.

cleanup(_) ->
    meck:unload(nklib_store),
    ok.

get() ->
    SrvId = test_srv,
    AOR = <<"sip:1001@example.com">>,
    Contacts = [#{uri => <<"sip:1001@127.0.0.1">>}],
    Key = {nksip_registrar, SrvId, AOR},

    meck:expect(
        nklib_store,
        get,
        fun(KeyArg, Default) ->
            ?assertEqual(Key, KeyArg),
            ?assertEqual([], Default),
            Contacts
        end
    ),

    ?assertEqual(
        Contacts,
        sip_server:sip_registrar_store(SrvId, {get, AOR})
    ),

    ?assert(meck:validate(nklib_store)).

put() ->
    SrvId = test_srv,
    AOR = <<"sip:1002@example.com">>,
    Contacts = [#{uri => <<"sip:1002@127.0.0.1">>}],
    TTL = 60,
    Key = {nksip_registrar, SrvId, AOR},

    meck:expect(
        nklib_store,
        put,
        fun(KeyArg, ContactsArg, Options) ->
            ?assertEqual(Key, KeyArg),
            ?assertEqual(Contacts, ContactsArg),
            ?assertEqual([{ttl, TTL}], Options),
            ok
        end
    ),

    ?assertEqual(
        ok,
        sip_server:sip_registrar_store(
            SrvId,
            {put, AOR, Contacts, TTL}
        )
    ),

    ?assert(meck:validate(nklib_store)).

delete() ->
    SrvId = test_srv,
    AOR = <<"sip:1003@example.com">>,
    Key = {nksip_registrar, SrvId, AOR},

    meck:expect(
        nklib_store,
        del,
        fun(KeyArg) ->
            ?assertEqual(Key, KeyArg),
            ok
        end
    ),

    ?assertEqual(
        ok,
        sip_server:sip_registrar_store(SrvId, {del, AOR})
    ),

    ?assert(meck:validate(nklib_store)).

delete_all() ->
    SrvId = test_srv,
    MatchingAOR = <<"sip:1004@example.com">>,
    MatchingKey = {nksip_registrar, SrvId, MatchingAOR},
    OtherKey = {nksip_registrar, another_srv, <<"sip:2000@example.com">>},

    meck:expect(
        nklib_store,
        del,
        fun(KeyArg) ->
            ?assertEqual(MatchingKey, KeyArg),
            ok
        end
    ),

    meck:expect(
        nklib_store,
        fold,
        fun(FoldFun, InitialAcc) ->
            ?assertEqual(none, InitialAcc),

            ok = FoldFun(MatchingKey, contacts, InitialAcc),
            none = FoldFun(OtherKey, contacts, InitialAcc),

            ok
        end
    ),

    ?assertEqual(
        ok,
        sip_server:sip_registrar_store(SrvId, del_all)
    ),

    ?assertEqual(1, meck:num_calls(nklib_store, del, 1)),
    ?assert(meck:validate(nklib_store)).
