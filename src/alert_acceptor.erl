%%%-------------------------------------------------------------------
%%% @doc Пример gen_server-сервера.
%%% @end
%%%-------------------------------------------------------------------
-module(alert_acceptor).
-behaviour(gen_server).

-include("sipalerts_db.hrl").
-include("debuger.hrl").
-include("alert_acceptor.hrl").

%% ------------------------------------------------------------------
%% API-функции для клиентов
%% ------------------------------------------------------------------
-export([start_link/0, stop/0, new_alert/1]).

%% ------------------------------------------------------------------
%% Callback-функции gen_server
%% ------------------------------------------------------------------
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%% ===================================================================
%% API-функции
%% ===================================================================

%% Запускает сервер и регистрирует его локально под именем my_server.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Останавливает сервер.
stop() ->
    gen_server:cast(?MODULE, stop).

-spec new_alert(Alert :: sipalerts_db:alert()) -> ok.
new_alert(Alert) ->
    ?DEBUGER("new_alert at ~p: ~p", [erlang:system_time(second), Alert]),
    wpool:call(?MODULE, {new_alert, Alert}).

%% ===================================================================
%% Callback-функции gen_server
%% ===================================================================

%% @private Инициализирует состояние сервера.
init(#accept_deps{db = MaybeDb}) ->
    Db = alert_core_utils:override_module(MaybeDb, sipalerts_db),
    {ok, #accept_deps{db = Db}};
init([]) ->
    {ok, #accept_deps{db = sipalerts_db}}.

%% @private Обрабатывает синхронные запросы (gen_server:call/2).
%% Завели алерт, отправили воркеру на обработку, ответили что задача в работе
handle_call({new_alert, Alert}, _From, #accept_deps{db = Db} = State) ->
    {ok, AlertId} = Db:create_alert(Alert),
    ?DEBUGER("ok ~p ~n", [erlang:system_time(seconds)]),
    ok = alert_manager:send(Alert),
    {reply, ok, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

%% @private Обрабатывает асинхронные сообщения (gen_server:cast/2).
handle_cast(_Msg, State) ->
    {noreply, State}.

%% @private Обрабатывает все остальные сообщения (таймеры, мониторы и т.п.).
handle_info(_Info, State) ->
    {noreply, State}.

%% @private Вызывается при завершении сервера.
terminate(_Reason, _State) ->
    ok.

%% @private Вызывается при горячей замене кода.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
