-module(alert_db).

-export_type([alert_id/0, alert_text/0]).

-type alert_id() :: binary().
-type alert_text() :: binary().