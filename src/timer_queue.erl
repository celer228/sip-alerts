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

%% Добавление и запуск нового таймера.
add_timer(TimerId, DelayMs, Destination, Message) ->
    gen_server:call(
        ?MODULE,
        {add_timer, TimerId, DelayMs, Destination, Message}
    ).

%% Запрос на отмену существующего таймера.
%% Логика отмены будет добавлена на следующем этапе.
cancel_timer(TimerId) ->
    gen_server:call(?MODULE, {cancel_timer, TimerId}).

%% Получение списка активных таймеров.
list_timers() ->
    gen_server:call(?MODULE, list_timers).

%% Инициализация состояния очереди таймеров.
init([]) ->
    {ok, #{timers => #{}}}.

%% Создание нового таймера.
handle_call(
    {add_timer, TimerId, DelayMs, Destination, Message},
    _From,
    State = #{timers := Timers}
) when is_integer(DelayMs), DelayMs >= 0 ->
    case maps:is_key(TimerId, Timers) of
        true ->
            {reply, {error, already_exists}, State};

        false ->
            DeadlineMs = current_time_ms() + DelayMs,
            TimerRef = erlang:send_after(
                DelayMs,
                self(),
                {timer_expired, TimerId}
            ),

            TimerInfo = #{
                timer_ref => TimerRef,
                deadline_ms => DeadlineMs,
                destination => Destination,
                message => Message
            },

            NewTimers = maps:put(TimerId, TimerInfo, Timers),
            NewState = State#{timers := NewTimers},

            {reply, {ok, TimerId}, NewState}
    end;

%% Проверка корректности задержки.
handle_call(
    {add_timer, _TimerId, _DelayMs, _Destination, _Message},
    _From,
    State
) ->
    {reply, {error, invalid_delay}, State};

%% Отмена пока не реализована.
handle_call({cancel_timer, _TimerId}, _From, State) ->
    {reply, {error, not_implemented}, State};

%% Получение активных таймеров.
handle_call(list_timers, _From, State = #{timers := Timers}) ->
    {reply, Timers, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_request}, State}.

handle_cast(_Message, State) ->
    {noreply, State}.

%% Обработка срабатывания таймера.
handle_info(
    {timer_expired, TimerId},
    State = #{timers := Timers}
) ->
    case maps:find(TimerId, Timers) of
        {ok, TimerInfo} ->
            Destination = maps:get(destination, TimerInfo),
            Message = maps:get(message, TimerInfo),

            Destination ! Message,

            NewTimers = maps:remove(TimerId, Timers),
            {noreply, State#{timers := NewTimers}};

        error ->
            {noreply, State}
    end;

handle_info(_Message, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

%% Получение текущего системного времени в миллисекундах.
current_time_ms() ->
    erlang:system_time(millisecond).