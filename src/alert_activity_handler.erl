-module(alert_activity_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    handle_request(Method, Req0, State).

%% GET /log/alert_activity
handle_request(<<"GET">>, Req0, State) ->
    Res = get_all_logs(),
    case Res of
        {ok, Logs} ->
            Lines = binary:split(Logs, <<"\n">>, [global]),
            Response = jsx:encode(Lines),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"text/plain">>},
                Response,
                Req0
            ),
            {ok, Req, State};
        {error, Reason} ->
            Response = jsx:encode(#{<<"error">> => <<"Failed to read logs">>, <<"reason">> => Reason}),
            Req = cowboy_req:reply(500,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, State}
    end,
    {ok, Req, State};

handle_request(_, Req0, State) ->
    Req = cowboy_req:reply(405,
        #{<<"content-type">> => <<"application/json">>},
        jsx:encode(#{<<"error">> => <<"Method not allowed">>}),
        Req0
    ),
    {ok, Req, State}.

get_all_logs() ->
    case  file:read_file("log/alert_activity.log") of
        {ok, Logs} -> {ok, Logs};
        {error, Reason} -> {error, Reason}
    end.