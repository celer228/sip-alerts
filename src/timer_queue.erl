-module(timer_queue).

-behaviour(gen_server).

%% Публичное API.
-export([
    start_link/0,
    add_timer/4,
    cancel_timer/1,
    list_timers/0
]).

%% Callback-функции gen_server.
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%% Запуск процесса очереди таймеров.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Запрос на добавление нового таймера.
%% Логика создания таймера будет добавлена на следующем этапе.
add_timer(TimerId, DelayMs, Destination, Message) ->
    gen_server:call(
        ?MODULE,
        {add_timer, TimerId, DelayMs, Destination, Message}
    ).

%% Запрос на отмену существующего таймера.
%% Логика отмены будет добавлена позже.
cancel_timer(TimerId) ->
    gen_server:call(?MODULE, {cancel_timer, TimerId}).

%% Получение списка активных таймеров.
list_timers() ->
    gen_server:call(?MODULE, list_timers).

%% Инициализация состояния очереди таймеров.
init([]) ->
    {ok, #{timers => #{}}}.

handle_call(_Request, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast(_Message, State) ->
    {noreply, State}.

handle_info(_Message, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.
