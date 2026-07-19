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

    AlertManager = #{id => alert_manager,
                  start => {?DUMMY, start_link, [alert_manager]},
                  restart => permanent,
                  shutdown => 5000,
                  type => worker,
                  modules => [alert_manager]},

    TimerQueue = #{id => timer_queue,
                  start => {?DUMMY, start_link, [timer_queue]},
                  restart => permanent,
                  shutdown => 5000,
                  type => worker,
                  modules => [timer_queue]},

    AlertLog = #{id => alert_log,
                  start => {?DUMMY, start_link, [alert_log]},
                  restart => permanent,
                  shutdown => 5000,
                  type => worker,
                  modules => [alert_log]},

    SupFlags = #{strategy => one_for_one,
                 intensity => 5,
                 period => 10},
    ChildSpecs = [AlertManager, AlertLog, TimerQueue],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
