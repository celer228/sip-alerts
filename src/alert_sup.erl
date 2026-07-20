%%%-------------------------------------------------------------------
%% @doc alert_sup top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(alert_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

% Временная заглушка для тестирования супервизора
-define(DUMMY, dummy_server).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    % SipalertsDb = #{id => sipalerts_db,
    %               start => {?DUMMY, start_link, [sipalerts_db]},
    %               restart => permanent,
    %               shutdown => 5000,
    %               type => worker,
    %               modules => [sipalerts_db]},

    AlertManager = #{
        id => alert_manager,
        start => {?DUMMY, start_link, [alert_manager]},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [alert_manager]
    },

    TimerQueue = #{id => timer_queue,
                  start => {?DUMMY, start_link, [timer_queue]},
                  restart => permanent,
                  shutdown => 5000,
                  type => worker,
                  modules => [timer_queue]},

    AlertLog = #{
        id => alert_log,
        start => {alert_log, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [alert_log]
    },

    SupFlags = #{strategy => one_for_one,
                 intensity => 5,
                 period => 10},
    ChildSpecs = [AlertManager, AlertLog, TimerQueue],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions