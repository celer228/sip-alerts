%%%-------------------------------------------------------------------
%% @doc alarm_sup top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(alarm_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

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
    AlarmDb = #{id => aladrm_db,
                  start => {aladrm_db, start_link(), []},
                  restart => permament,
                  shutdown => 5000,
                  type => worker,
                  modules => [aladrm_db]},

    AlarmManager = #{id => alarm_manager,
                  start => {alarm_manager, start_link(), []},
                  restart => permament,
                  shutdown => 5000,
                  type => worker,
                  modules => [alarm_manager]},

    TimerQueue = #{id => timer_queue,
                  start => {timer_queue, start_link(), []},
                  restart => permament,
                  shutdown => 5000,
                  type => worker,
                  modules => [timer_queue]},

    AlarmLog = #{id => alarm_log,
                  start => {alarm_log, start_link(), []},
                  restart => permament,
                  shutdown => 5000,
                  type => worker,
                  modules => [alarm_log]},

    SupFlags = #{strategy => one_for_one,
                 intensity => 5,
                 period => 10},
    ChildSpecs = [AlarmDb, AlarmManager, AlarmLog, TimerQueue],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
