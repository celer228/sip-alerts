-module(prometheus_adapter).
-export([normalize/1]).
-include("alert.hrl").
-include("debug.hrl").

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
            ?DEBUG("Alert map = ~p~n", [Alert]),
            {ok, Alert};
        _ ->
            {ok, duplicate_webhook}
    end.