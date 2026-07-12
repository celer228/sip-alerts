%%%-------------------------------------------------------------------
%% @doc sip_sup top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(sip_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    ChildSpecs = [
        %% SIP-сервер для приема звонков (ping)
        nksip:get_sup_spec(sip_server, #{
            sip_local_host => "localhost",
            plugins => [nksip_registrar],
            sip_listen => "sip:all:5060"
        })
        %% SIP-клиент для обратного звонка (pong)
        % nksip:get_sup_spec(sip_client, #{
        %     sip_local_host => "localhost",
        %     sip_from => "sip:sip_client@127.0.0.1",
        %     plugins => [nksip_uac_auto_auth],
        %     sip_listen => "sip:127.0.0.1:5075"
        % })
    ],

    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 60
    },
    {ok, {SupFlags, ChildSpecs}}.