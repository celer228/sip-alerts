%%%-------------------------------------------------------------------
%% @doc sipalerts top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(sipalerts_sup).

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
    CowboySup = #{id => cowboy_sup,
                  start => {cowboy_sup, start_link(), []},
                  restart => permament,
                  shutdown => 5000,
                  type => supervisor,
                  modules => [cowboy_sup]},

    AlarmSup = #{id => alarm_sup,
                  start => {alarm_sup, start_link(), []},
                  restart => permament,
                  shutdown => infinity,
                  type => supervisor,
                  modules => [alarm_sup]},

    SipSup = #{id => sip_sup,
                  start => {sip_sup, start_link(), []},
                  restart => permament,
                  shutdown => infinity,
                  type => supervisor,
                  modules => [sip_sup]},

    SupFlags = #{strategy => one_for_one,
                 intensity => 5,
                 period => 10},
    ChildSpecs = [CowboySup, AlarmSup, SipSup],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
