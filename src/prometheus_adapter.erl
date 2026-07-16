-module(prometheus_adapter).
-export([normalize/1]).
-include("sipalerts_db.hrl").
-include("debuger.hrl").

normalize(Webhook) ->
    case maps:get(<<"notification_reason">>, Webhook, undefined) of
        <<"first notification">> ->
            Annot = maps:get(<<"alerts">>, Webhook),

            [#{<<"annotations">> := #{
                <<"description">> := Desc,
                <<"summary">> := Summary},
                <<"endsAt">> := EndsAt,
                <<"fingerprint">> := Id,
                <<"generatorURL">> := _,
                <<"labels">> :=
                    #{<<"alertname">> := AlertName,
                      <<"severity">> := Severity},
                <<"startsAt">> := StartsAt,
                <<"status">> := Status} | _] = Annot,

            Alert = #alert{id = Id, alertname = AlertName, description = Desc,
                          summary = Summary, severity = Severity, status = Status,
                          source = <<"prometheus">>, starts_at = StartsAt, ends_at = EndsAt},
            ?DEBUGER("Alert map = ~p~n", [Alert]),
            {ok, Alert};
        _ ->
            {ok, duplicate_webhook}
    end.