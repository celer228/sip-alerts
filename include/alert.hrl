-type id() :: binary().
-type alertname() :: binary().
-type description() :: binary().
-type summary() :: binary().
-type severity() :: binary().
-type status() :: binary().
-type source() :: binary().
-type starts_at() :: binary(). %% ISO 8601
-type ends_at() :: binary(). %% ISO 8601

-record(alert, {
    id :: id(),
    alertname :: alertname(),
    description :: description(),
    summary :: summary(),
    severity :: severity(),
    status :: status(),
    source :: source(),
    starts_at :: starts_at(), %% ISO 8601
    ends_at :: ends_at()
}).
