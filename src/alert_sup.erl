%%%-------------------------------------------------------------------
%% @doc alert_sup top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(alert_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-include("alert_acceptor.hrl").

-define(SERVER, ?MODULE).

% Временная заглушка для тестирования супервизора
-define(DUMMY, dummy_server).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    % SipalertsDb = #{id => sipalerts_db,
    %               start => {?DUMMY, start_link, [sipalerts_db]},
    %               restart => permanent,
    %               shutdown => 5000,
    %               type => worker,
    %               modules => [sipalerts_db]},

    AlertAcceptorWPoolOpts = [
        {workers, 10},
        {worker, {alert_acceptor, #accept_deps{db = sipalerts_db}}}
    ],

    AlertAcceptorWPool = #{
        id => alert_acceptor,
        start => {wpool, start_pool, [alert_acceptor, AlertAcceptorWPoolOpts]},
        restart => permanent,
        shutdown => infinity,
        type => supervisor,
        modules => [wpool]
    },

    AlertManagerWPoolOpts = [
        {workers, 10},
        {worker, {alert_acceptor, #accept_deps{db = sipalerts_db}}}
    ],

    AlertManagerWPool = #{
        id => alert_manager,
        start => {wpool, start_pool, [alert_manager, AlertManagerWPoolOpts]},
        restart => permanent,
        shutdown => infinity,
        type => supervisor,
        modules => [wpool]
    },

    TimerQueue = #{
        id => timer_queue,
        start => {timer_queue, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [timer_queue]
    },

    AlertLog = #{
        id => alert_log,
        start => {?DUMMY, start_link, [alert_log]},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [alert_log]
    },

    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    ChildSpecs = [AlertLog, TimerQueue, AlertAcceptorWPool, AlertManagerWPool],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
