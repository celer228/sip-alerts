#!/bin/bash
set -e

echo "===> Creating mnesia schema..."

erl -noshell \
-name sipalerts@127.0.0.1 \
-eval '
case mnesia:create_schema([node()]) of
    ok ->
        io:format("Schema created~n");
    {error,{_,{already_exists,_}}} ->
        io:format("Schema already exists~n");
    Error ->
        io:format("Schema error: ~p~n",[Error])
end,
halt().
'

echo "===> Starting application..."

# Добавляем эту строку, когда нужно открыть приложение фоном (например для тестов)
# А так запуск rebar3 shell --name sipalerts@127.0.0.1
exec rebar3 shell --name sipalerts@127.0.0.1