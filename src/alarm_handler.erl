-module(alarm_handler).
-behaviour(cowboy_handler).

-export([init/2]).

-include("alert.hrl").
-include("debuger.hrl").

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    case Method of
        <<"POST">> ->
            {ok, Body, Req1} = cowboy_req:read_body(Req0),

            Webhook = jsx:decode(Body, [return_maps]),
            Source = cowboy_req:binding(source, Req0),

            ?DEBUGER("Webhook = ~p~nSource = ~p~n", [Webhook, Source]),

            Res = case Source of
                <<"prometheus">> -> prometheus_adapter:normalize(Webhook);
                _ -> {error, unknown_source}
            end,

            case Res of
                {error, unknown_source} ->
                    Req = cowboy_req:reply(400,
                        #{<<"content-type">> => <<"application/json">>},
                            <<"Source Not Allowed">>,
                            Req1
                    ),
                    {ok, Req, State};
                {ok, duplicate_webhook} ->
                    Req = cowboy_req:reply(200,
                        #{<<"content-type">> => <<"application/json">>},
                            <<"Webhook ignored">>,
                            Req1
                    ),
                    {ok, Req, State};
                {ok, Alert} ->
                    % alarm_manager:new_alarm(Alert),
                    Response = jsx:encode(Webhook),
                    Req = cowboy_req:reply(200,
                        #{<<"content-type">> => <<"application/json">>},
                        Response,
                        Req1
                    ),
                    {ok, Req, State};
                _ ->
                    Req = cowboy_req:reply(400,
                        #{<<"content-type">> => <<"application/json">>},
                            <<"Unknown error">>,
                            Req1
                    ),
                    {ok, Req, State}
            end;
        _ ->
            %% Для других методов возвращаем ошибку
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                    <<"Method Not Allowed">>,
                    Req0
            ),
            {ok, Req, State}
    end.