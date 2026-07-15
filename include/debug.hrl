-ifdef(DEBUG).
-define(DEBUG(Fmt, Args),
    io:format("[DEBUG] ~p:~p " ++ Fmt ++ "~n",
              [?MODULE, ?LINE | Args])).
-else.
-define(DEBUG(_Fmt, _Args), ok).
-endif.