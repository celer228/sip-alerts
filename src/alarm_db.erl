-module(alarm_db).

-export_type([alarm_id/0, alarm_text/0]).

-type alarm_id() :: binary().
-type alarm_text() :: binary().