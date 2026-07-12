-module(timer_queue).

-behaviour(gen_server).

%% Публичное API.
-export([
    start_link/0,
    add/3,
    cancel/1,
    list/0
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

%% Идентификатор генерируется самим модулем при создании таймера.
-type timer_id() :: reference().

%% Получатель уведомления о завершении таймера.
-type destination() ::
    pid()
    | atom()
    | {atom(), node()}.

%% Внутренняя информация об активном таймере.
-type timer_info() :: #{
    timer_ref := reference(),
    deadline_ms := integer(),
    destination := destination(),
    message := term()
}.

%% Состояние процесса очереди таймеров.
-type state() :: #{
    timers := #{timer_id() => timer_info()}
}.

%% Запуск процесса очереди таймеров.
-spec start_link() ->
    {ok, pid()}
    | ignore
    | {error, term()}.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Добавление таймера с задержкой в миллисекундах.
%% Идентификатор таймера генерируется внутри модуля.
-spec add(
    DelayMs :: non_neg_integer(),
    Destination :: destination(),
    Message :: term()
) ->
    {ok, timer_id()}
    | {error, invalid_delay}.

add(DelayMs, Destination, Message) ->
    gen_server:call(
        ?MODULE,
        {add, DelayMs, Destination, Message}
    ).

%% Отмена активного таймера.
-spec cancel(TimerId :: timer_id()) ->
    ok
    | {error, not_found}.

cancel(TimerId) ->
    gen_server:call(?MODULE, {cancel, TimerId}).

%% Получение информации об активных таймерах.
-spec list() ->
    #{timer_id() => timer_info()}.

list() ->
    gen_server:call(?MODULE, list).

%% Инициализация пустого состояния очереди.
-spec init([]) ->
    {ok, state()}.

init([]) ->
    {ok, #{timers => #{}}}.

%% Создание и запуск нового таймера.
-spec handle_call(
    Request :: term(),
    From :: {pid(), term()},
    State :: state()
) ->
    {reply, term(), state()}.

handle_call(
    {add, DelayMs, Destination, Message},
    _From,
    State = #{timers := Timers}
) when is_integer(DelayMs), DelayMs >= 0 ->
    TimerId = make_ref(),
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

    {reply, {ok, TimerId}, NewState};

%% Обработка некорректного значения задержки.
handle_call(
    {add, _DelayMs, _Destination, _Message},
    _From,
    State
) ->
    {reply, {error, invalid_delay}, State};

%% Отмена существующего таймера.
handle_call(
    {cancel, TimerId},
    _From,
    State = #{timers := Timers}
) ->
    case maps:find(TimerId, Timers) of
        {ok, TimerInfo} ->
            TimerRef = maps:get(timer_ref, TimerInfo),
            _ = erlang:cancel_timer(TimerRef),

            NewTimers = maps:remove(TimerId, Timers),
            {reply, ok, State#{timers := NewTimers}};

        error ->
            {reply, {error, not_found}, State}
    end;

%% Получение активных таймеров.
handle_call(list, _From, State = #{timers := Timers}) ->
    {reply, Timers, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_request}, State}.

-spec handle_cast(
    Message :: term(),
    State :: state()
) ->
    {noreply, state()}.

handle_cast(_Message, State) ->
    {noreply, State}.

%% Отправка уведомления при завершении таймера.
-spec handle_info(
    Message :: term(),
    State :: state()
) ->
    {noreply, state()}.

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
            %% Таймер мог быть отменён до обработки сообщения.
            {noreply, State}
    end;

handle_info(_Message, State) ->
    {noreply, State}.

-spec terminate(
    Reason :: term(),
    State :: state()
) ->
    ok.

terminate(_Reason, _State) ->
    ok.

-spec code_change(
    OldVersion :: term(),
    State :: state(),
    Extra :: term()
) ->
    {ok, state()}.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

%% Получение текущего системного времени в миллисекундах.
-spec current_time_ms() -> integer().

current_time_ms() ->
    erlang:system_time(millisecond).