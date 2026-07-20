%%%-------------------------------------------------------------------
%% @doc
%% Модуль журналирования обработки уведомлений.
%% @end
%%%-------------------------------------------------------------------
-module(alert_log).
-behaviour(gen_server).

%% API
-export([
    start_link/0,
    log_sent/3,
    log_failed/4,
    log_confirmed/3,
    log_finalized/3,
    get_report/0
]).

%% gen_server callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-define(DEFAULT_LOG_FILE, "log/alarm_activity.log").
-define(DEFAULT_MAX_BYTES, 10485760).
-define(DEFAULT_MAX_ARCHIVES, 5).

-record(state, {
    file,
    path,
    max_bytes,
    max_archives
}).

%%% API

-spec start_link() -> gen_server:start_ret().
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec log_sent(term(), term(), term()) -> ok.
log_sent(Client, Message, AlarmId) ->
    log_event(sent_unconfirmed, Client, Message, AlarmId, undefined).

-spec log_failed(term(), term(), term(), term()) -> ok.
log_failed(Client, Message, AlarmId, Reason) ->
    log_event(failed, Client, Message, AlarmId, Reason).

-spec log_confirmed(term(), term(), term()) -> ok.
log_confirmed(Client, Message, AlarmId) ->
    log_event(confirmed, Client, Message, AlarmId, undefined).

-spec log_finalized(term(), term(), term()) -> ok.
log_finalized(Client, Message, AlarmId) ->
    log_event(finalized, Client, Message, AlarmId, undefined).

-spec get_report() -> {ok, [binary()]} | {error, term()}.
get_report() ->
    gen_server:call(?MODULE, get_report).


%%% gen_server callbacks

-spec init([]) -> {ok, #state{}} | {stop, term()}.
init([]) ->
    RawPath = application:get_env(sipalerts, alarm_log_file, ?DEFAULT_LOG_FILE),
    MaxBytes = application:get_env(sipalerts, alarm_log_max_bytes, ?DEFAULT_MAX_BYTES),
    MaxArchives = application:get_env(sipalerts, alarm_log_max_archives, ?DEFAULT_MAX_ARCHIVES),
    Path = normalize_path(RawPath),

    case validate_config(Path, MaxBytes, MaxArchives) of
        ok -> 
            init_open_log(Path, MaxBytes, MaxArchives);
        {error, Reason} -> 
            {stop, Reason}
    end.

init_open_log(Path, MaxBytes, MaxArchives) ->
    case open_log(Path) of
        {ok, File} ->
            {ok, #state{
                file = File, path = Path,
                max_bytes = MaxBytes, max_archives = MaxArchives
            }};
        {error, Reason} ->
            {stop, {alarm_log_open_failed, Reason}}
    end.

handle_call(get_report, _From, State = #state{file = File, path = Path, max_archives = MaxArchives}) ->
    case file:sync(File) of
        ok ->
            {reply, read_report(Path, MaxArchives), State};
        {error, Reason} ->
            {reply, {error, {sync_failed, Reason}}, State}
    end;
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({log, Status, Client, Message, AlarmId, Reason}, State0) ->
    Line = format_event(Status, Client, Message, AlarmId, Reason),
    case ensure_capacity(byte_size(Line), State0) of
        {ok, State1} ->
            write_to_file(Line, State1);
        {error, RotateReason, State1} ->
            logger:error("alarm_log: ошибка ротации: ~p", [RotateReason]),
            {noreply, State1}
    end;
handle_cast(_Message, State) ->
    {noreply, State}.

write_to_file(Line, State) ->
    io:format("WRITE LINE: ~p~n", [Line]),
    Result = file:write(State#state.file, Line),
    io:format("WRITE RESULT: ~p~n", [Result]),
    case Result of
        ok ->
            ok = file:sync(State#state.file),
            {noreply, State};
        {error, WriteReason} ->
            logger:error("alarm_log: ошибка записи: ~p", [WriteReason]),
            {noreply, State}
    end.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{file = File}) ->
    _ = file:sync(File),
    _ = file:close(File),
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.


%%% Internal functions

log_event(Status, Client, Message, AlarmId, Reason) ->
    gen_server:cast(?MODULE, {
        log, Status,
        sanitize(Client), sanitize(Message), sanitize(AlarmId),
        normalize_reason(Reason)
    }).

open_log(Path) ->
    case filelib:ensure_dir(Path) of
        ok -> file:open(Path, [append, raw, binary]);
        {error, Reason} -> {error, {ensure_directory_failed, Reason}}
    end.

ensure_capacity(NewLineSize, State = #state{file = File, max_bytes = MaxBytes}) ->
    case file:position(File, eof) of
        {ok, CurrentSize} when CurrentSize > 0, CurrentSize + NewLineSize > MaxBytes ->
            rotate(State);
        {ok, _CurrentSize} ->
            {ok, State};
        {error, Reason} ->
            {error, {position_failed, Reason}, State}
    end.

rotate(State = #state{file = File, path = Path, max_archives = MaxArchives}) ->
    case file:sync(File) of
        ok ->
            case file:close(File) of
                ok -> rotate_closed_log(State, Path, MaxArchives);
                {error, Reason} -> {error, {close_failed, Reason}, State}
            end;
        {error, Reason} ->
            {error, {sync_failed, Reason}, State}
    end.

rotate_closed_log(State, Path, 0) ->
    case file:open(Path, [write, raw, binary]) of
        {ok, NewFile}   -> {ok, State#state{file = NewFile}};
        {error, Reason} -> {error, {reopen_failed, Reason}, State}
    end;
rotate_closed_log(State, Path, MaxArchives) ->
    case rotate_files(Path, MaxArchives) of
        ok ->
            reopen_log_success(State, Path);
        {error, Reason} ->
            reopen_log_fallback(State, Path, Reason)
    end.

reopen_log_success(State, Path) ->
    case open_log(Path) of
        {ok, NewFile}   -> {ok, State#state{file = NewFile}};
        {error, Reason} -> {error, {reopen_failed, Reason}, State}
    end.

reopen_log_fallback(State, Path, RotateError) ->
    case open_log(Path) of
        {ok, NewFile} -> 
            {error, RotateError, State#state{file = NewFile}};
        {error, ReopenReason} -> 
            {error, {RotateError, {reopen_failed, ReopenReason}}, State}
    end.

rotate_files(Path, MaxArchives) ->
    LastArchive = archive_path(Path, MaxArchives),
    case delete_if_exists(LastArchive) of
        ok ->
            execute_shift_and_rename(Path, MaxArchives);
        {error, _} = Error -> 
            Error
    end.

execute_shift_and_rename(Path, MaxArchives) ->
    case shift_archives(Path, MaxArchives - 1) of
        ok -> 
            rename_if_exists(Path, archive_path(Path, 1));
        {error, _} = Error -> 
            Error
    end.

shift_archives(_Path, Index) when Index < 1 ->
    ok;
shift_archives(Path, Index) ->
    Source = archive_path(Path, Index),
    Target = archive_path(Path, Index + 1),
    case rename_if_exists(Source, Target) of
        ok             -> shift_archives(Path, Index - 1);
        {error, _} = E -> E
    end.

rename_if_exists(Source, Target) ->
    case file:read_file_info(Source) of
        {ok, _Info}     -> file:rename(Source, Target);
        {error, enoent} -> ok;
        {error, Reason} -> {error, {file_info_failed, Source, Reason}}
    end.

delete_if_exists(Path) ->
    case file:delete(Path) of
        ok              -> ok;
        {error, enoent} -> ok;
        {error, Reason} -> {error, {delete_failed, Path, Reason}}
    end.

read_report(Path, MaxArchives) ->
    Files = report_files(Path, MaxArchives),
    read_report_files(Files, []).

report_files(Path, MaxArchives) ->
    ArchiveNumbers = case MaxArchives of
        0 -> [];
        _ -> lists:seq(MaxArchives, 1, -1)
    end,
    [archive_path(Path, Index) || Index <- ArchiveNumbers] ++ [Path].

read_report_files([], Acc) ->
    {ok, lists:reverse(Acc)};
read_report_files([Path | Rest], Acc) ->
    case file:read_file(Path) of
        {ok, Binary} ->
            Lines = non_empty_lines(Binary),
            read_report_files(Rest, lists:reverse(Lines, Acc));
        {error, enoent} ->
            read_report_files(Rest, Acc);
        {error, Reason} ->
            {error, {read_failed, Path, Reason}}
    end.

non_empty_lines(Binary) ->
    [Line || Line <- binary:split(Binary, <<"\n">>, [global]), Line =/= <<>>].

format_event(Status, Client, Message, AlarmId, Reason) ->
    Timestamp = timestamp(),
    StatusText = status_text(Status),
    Base = io_lib:format("[~ts] [~ts] Client: ~ts | AlarmID: ~ts | Message: ~ts",
                         [Timestamp, StatusText, Client, AlarmId, Message]),
    Line = case Reason of
        undefined    -> [Base, $\n];
        ReasonBinary -> [Base, " | Reason: ", ReasonBinary, $\n]
    end,
    unicode:characters_to_binary(Line).

timestamp() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    unicode:characters_to_binary(
        io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ", [Y, Mo, D, H, Mi, S])
    ).

status_text(sent_unconfirmed) -> <<"SENT_UNCONFIRMED">>;
status_text(failed)           -> <<"FAILED">>;
status_text(confirmed)        -> <<"CONFIRMED">>;
status_text(finalized)        -> <<"FINALIZED">>.

normalize_reason(undefined) -> undefined;
normalize_reason(Reason)    -> sanitize(io_lib:format("~tp", [Reason])).

sanitize(Value) ->
    Binary = to_binary(Value),
    WithoutCR = binary:replace(Binary, <<"\r">>, <<"\\r">>, [global]),
    binary:replace(WithoutCR, <<"\n">>, <<"\\n">>, [global]).

to_binary(V) when is_binary(V) -> V;
to_binary(V) when is_list(V)   -> unicode:characters_to_binary(V);
to_binary(V) when is_atom(V)   -> atom_to_binary(V, utf8);
to_binary(V) when is_integer(V)-> integer_to_binary(V);
to_binary(V)                   -> unicode:characters_to_binary(io_lib:format("~tp", [V])).

archive_path(Path, Index) ->
    Path ++ "." ++ integer_to_list(Index).

normalize_path(Path) when is_binary(Path) -> binary_to_list(Path);
normalize_path(Path) when is_list(Path)   -> Path;
normalize_path(Path)                      -> Path.

validate_config(Path, MaxBytes, MaxArchives)
  when is_list(Path), Path =/= [],
       is_integer(MaxBytes), MaxBytes > 0,
       is_integer(MaxArchives), MaxArchives >= 0 ->
    ok;
validate_config(Path, MaxBytes, MaxArchives) ->
    {error, {invalid_alarm_log_config, #{
        file => Path, max_bytes => MaxBytes, max_archives => MaxArchives
    }}}.