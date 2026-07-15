-ifdef(DEBUGER).
-define(DEBUGER(Fmt, Args),
    io:format("[DEBUG] ~p:~p " ++ Fmt ++ "~n",
              [?MODULE, ?LINE | Args])).
-else.
-define(DEBUGER(_Fmt, _Args), ok).
-endif.