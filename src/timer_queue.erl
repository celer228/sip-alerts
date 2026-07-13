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

%% Идентификатор таймера.
-type timer_id() :: reference().

%% Адрес процесса, которому можно отправить сообщение.
-type process_destination() ::
    pid()
    | atom()
    | {atom(), node()}.

%% Способ уведомления о завершении таймера.
-type destination() ::
    {send, process_destination()}
    | {callback, module(), atom()}.

%% Информация об активном таймере.
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

%% Запуск очереди таймеров.
-spec start_link() ->
    {ok, pid()}
    | ignore
    | {error, term()}.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Добавление таймера.
%%
%% Destination определяет способ уведомления:
%%   {send, ProcessDestination}
%%   {callback, Module, Function}
-spec add(
    DelayMs :: non_neg_integer(),
    Destination :: destination(),
    Message :: term()
) ->
    {ok, timer_id()}
    | {error, invalid_delay}
    | {error, invalid_destination}.

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

%% Получение активных таймеров.
-spec list() ->
    #{timer_id() => timer_info()}.

list() ->
    gen_server:call(?MODULE, list).

%% Инициализация пустого состояния.
-spec init([]) ->
    {ok, state()}.

init([]) ->
    {ok, #{timers => #{}}}.

-spec handle_call(
    Request :: term(),
    From :: {pid(), term()},
    State :: state()
) ->
    {reply, term(), state()}.

%% Создание и запуск нового таймера.
handle_call(
    {add, DelayMs, Destination, Message},
    _From,
    State = #{timers := Timers}
) when is_integer(DelayMs), DelayMs >= 0 ->
    case valid_destination(Destination) of
        true ->
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

        false ->
            {reply, {error, invalid_destination}, State}
    end;

%% Некорректная задержка.
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

-spec handle_info(
    Message :: term(),
    State :: state()
) ->
    {noreply, state()}.

%% Обработка завершения таймера.
handle_info(
    {timer_expired, TimerId},
    State = #{timers := Timers}
) ->
    case maps:take(TimerId, Timers) of
        {TimerInfo, NewTimers} ->
            Destination = maps:get(destination, TimerInfo),
            Message = maps:get(message, TimerInfo),

            notify(Destination, TimerId, Message),

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

%% Проверка способа уведомления.
-spec valid_destination(term()) -> boolean().

valid_destination({send, Destination}) ->
    is_pid(Destination)
    orelse is_atom(Destination)
    orelse is_remote_destination(Destination);
valid_destination({callback, Module, Function}) ->
    is_atom(Module) andalso is_atom(Function);
valid_destination(_Destination) ->
    false.

%% Проверка адреса зарегистрированного процесса на удалённой ноде.
-spec is_remote_destination(term()) -> boolean().

is_remote_destination({Name, Node}) ->
    is_atom(Name) andalso is_atom(Node);
is_remote_destination(_Destination) ->
    false.

%% Уведомление вызывающего модуля о завершении таймера.
-spec notify(destination(), timer_id(), term()) -> term().

notify({send, Destination}, TimerId, Message) ->
    Destination ! {timer_expired, TimerId, Message};
notify({callback, Module, Function}, TimerId, Message) ->
    apply(Module, Function, [TimerId, Message]).

%% Текущее системное время в миллисекундах.
-spec current_time_ms() -> integer().

current_time_ms() ->
    erlang:system_time(millisecond).