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
    HttpSup = #{id => http_sup,
                  start => {http_sup, start_link, []},
                  restart => permanent,
                  shutdown => 5000,
                  type => supervisor,
                  modules => [http_sup]},

    AlertSup = #{id => alert_sup,
                  start => {alert_sup, start_link, []},
                  restart => permanent,
                  shutdown => infinity,
                  type => supervisor,
                  modules => [alert_sup]},

    SipSup = #{id => sip_sup,
                  start => {sip_sup, start_link, []},
                  restart => permanent,
                  shutdown => infinity,
                  type => supervisor,
                  modules => [sip_sup]},

    SupFlags = #{strategy => one_for_one,
                 intensity => 5,
                 period => 10},
    ChildSpecs = [HttpSup, AlertSup, SipSup],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
