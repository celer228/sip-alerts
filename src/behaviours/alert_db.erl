-module(alert_db).

-callback create_alert(Alert :: sipalerts_db:alert()) ->
    {ok, AlertId :: sipalerts_db:alert_id()} | {error, Reason :: sipalerts_db:reason()}.


-callback get_alert(AlertId :: sipalerts_db:alert_id()) ->
    {ok, Alert :: sipalerts_db:alert()} | {error, Reason :: sipalerts_db:reason()}.

-callback delete_alert(AlertId :: sipalerts_db:alert_id()) ->
    ok | {error, Reason :: sipalerts_db:reason()}.

-callback list_alerts() ->
    [sipalerts_db:alert()] | {error, Reason :: sipalerts_db:reason()}.