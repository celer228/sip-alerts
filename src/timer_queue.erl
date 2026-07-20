-module(timer_queue).

-behaviour(gen_server).

-include("sipalerts_db.hrl").

%% Модуль работы с хранилищем таймеров.
-ifndef(DB_MODULE).
-define(DB_MODULE, sipalerts_db).
-endif.

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

%% В памяти хранятся только актуальные TimerRef.
-type state() :: #{
    timer_refs := #{timer_id() => reference()}
}.

%% Запуск очереди таймеров.
-spec start_link() ->
    {ok, pid()}
    | ignore
    | {error, term()}.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Добавление нового таймера.
-spec add(
    DelayMs :: non_neg_integer(),
    Destination :: destination(),
    Message :: term()
) ->
    {ok, timer_id()}
    | {error, invalid_delay}
    | {error, invalid_destination}
    | {error, term()}.

add(DelayMs, Destination, Message) ->
    gen_server:call(
        ?MODULE,
        {add, DelayMs, Destination, Message}
    ).

%% Отмена активного таймера.
-spec cancel(TimerId :: timer_id()) ->
    ok
    | {error, not_found}
    | {error, term()}.

cancel(TimerId) ->
    gen_server:call(?MODULE, {cancel, TimerId}).

%% Получение сохранённых таймеров.
-spec list() ->
    {ok, [#timer{}]}
    | {error, term()}.

list() ->
    gen_server:call(?MODULE, list).

%% При запуске получаем таймеры из БД и восстанавливаем send_after.
-spec init([]) ->
    {ok, state()}
    | {stop, term()}.

init([]) ->
    DbModule = ?DB_MODULE,

    case DbModule:list_timers() of
        {ok, Timers} ->
            TimerRefs = restore_timers(Timers),
            {ok, #{timer_refs => TimerRefs}};

        {error, Reason} ->
            {stop, {database_error, Reason}}
    end.

-spec handle_call(
    Request :: term(),
    From :: {pid(), term()},
    State :: state()
) ->
    {reply, term(), state()}.

%% Создание, сохранение и запуск нового таймера.
handle_call(
    {add, DelayMs, Destination, Message},
    _From,
    State = #{timer_refs := TimerRefs}
) when is_integer(DelayMs), DelayMs >= 0 ->
    case valid_destination(Destination) of
        true ->
            TimerId = make_ref(),
            DeadlineMs = current_time_ms() + DelayMs,

            Timer = #timer{
                id = TimerId,
                deadline_ms = DeadlineMs,
                destination = Destination,
                message = Message
            },

            DbModule = ?DB_MODULE,

            case DbModule:insert_timer(Timer) of
                ok ->
                    TimerRef = start_runtime_timer(
                        TimerId,
                        DelayMs
                    ),

                    NewTimerRefs = maps:put(
                        TimerId,
                        TimerRef,
                        TimerRefs
                    ),

                    {reply,
                     {ok, TimerId},
                     State#{timer_refs := NewTimerRefs}};

                {error, Reason} ->
                    {reply, {error, Reason}, State}
            end;

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

%% Отмена таймера.
handle_call(
    {cancel, TimerId},
    _From,
    State = #{timer_refs := TimerRefs}
) ->
    case maps:find(TimerId, TimerRefs) of
        {ok, TimerRef} ->
            DbModule = ?DB_MODULE,

            case DbModule:delete_timer(TimerId) of
                ok ->
                    _ = erlang:cancel_timer(TimerRef),

                    NewTimerRefs = maps:remove(
                        TimerId,
                        TimerRefs
                    ),

                    {reply,
                     ok,
                     State#{timer_refs := NewTimerRefs}};

                {error, Reason} ->
                    {reply, {error, Reason}, State}
            end;

        error ->
            {reply, {error, not_found}, State}
    end;

%% Список берётся из БД, а не из runtime-map.
handle_call(list, _From, State) ->
    DbModule = ?DB_MODULE,
    {reply, DbModule:list_timers(), State};

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
    State = #{timer_refs := TimerRefs}
) ->
    DbModule = ?DB_MODULE,

    case DbModule:get_timer(TimerId) of
        {ok, Timer} ->
            notify(
                Timer#timer.destination,
                TimerId,
                Timer#timer.message
            ),

            _ = DbModule:delete_timer(TimerId),

            NewTimerRefs = maps:remove(
                TimerId,
                TimerRefs
            ),

            {noreply,
             State#{timer_refs := NewTimerRefs}};

        {error, not_found} ->
            NewTimerRefs = maps:remove(
                TimerId,
                TimerRefs
            ),

            {noreply,
             State#{timer_refs := NewTimerRefs}};

        {error, _Reason} ->
            %% При временной ошибке БД запись не удаляем.
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

%% Восстановление runtime-таймеров из записей БД.
-spec restore_timers([#timer{}]) ->
    #{timer_id() => reference()}.

restore_timers(Timers) ->
    lists:foldl(
        fun restore_timer/2,
        #{},
        Timers
    ).

%% Восстановление одного таймера.
-spec restore_timer(
    #timer{},
    #{timer_id() => reference()}
) ->
    #{timer_id() => reference()}.

restore_timer(
    #timer{
        id = TimerId,
        deadline_ms = DeadlineMs
    },
    TimerRefs
) ->
    RemainingMs = erlang:max(
        0,
        DeadlineMs - current_time_ms()
    ),

    TimerRef = start_runtime_timer(
        TimerId,
        RemainingMs
    ),

    maps:put(TimerId, TimerRef, TimerRefs).

%% Запуск системного таймера.
-spec start_runtime_timer(
    timer_id(),
    non_neg_integer()
) ->
    reference().

start_runtime_timer(TimerId, DelayMs) ->
    erlang:send_after(
        DelayMs,
        self(),
        {timer_expired, TimerId}
    ).

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

%% Проверка адреса процесса на удалённой ноде.
-spec is_remote_destination(term()) -> boolean().

is_remote_destination({Name, Node}) ->
    is_atom(Name) andalso is_atom(Node);
is_remote_destination(_Destination) ->
    false.

%% Уведомление о завершении таймера.
-spec notify(
    destination(),
    timer_id(),
    term()
) ->
    term().

notify({send, Destination}, TimerId, Message) ->
    Destination ! {timer_expired, TimerId, Message};
notify({callback, Module, Function}, TimerId, Message) ->
    apply(Module, Function, [TimerId, Message]).

%% Текущее системное время в миллисекундах.
-spec current_time_ms() -> integer().

current_time_ms() ->
    erlang:system_time(millisecond).