-ifndef(SIPALERTS_DB_HRL).
-define(SIPALERTS_DB_HRL, true).

-record(subscriber, {
    id :: sipalerts_db:subscriber_id(),
    channel :: sipalerts_db:channel_module(),
    contact_key :: {ChannelModule :: sipalerts_db:channel_module(), ContactId :: sipalerts_db:contact_id()},
    contact_data :: sipalerts_db:contact_data()
}).

-record(alert, {
    id :: sipalerts_db:alert_id(),
    alertname :: binary(),
    description :: binary(),
    summary :: binary(),
    severity :: binary(),
    status :: binary(),
    source :: binary(),
    starts_at :: binary(),
    ends_at :: binary()
}).

-record(delivery, {
    delivery_id :: sipalerts_db:delivery_id(),
    alert_id :: sipalerts_db:alert_id(),
    subscriber_id :: sipalerts_db:subscriber_id(),
    channel :: sipalerts_db:channel_module(),
    status :: sipalerts_db:delivery_status(),
    failed_reason :: sipalerts_db:reason() | undefined,
    started_at :: calendar:datetime_utc(),                % Время начала доставки уведомления
    sent_at :: calendar:datetime_utc() | undefined,       % Время отправки уведомления (если статус = started)
    delivered_at :: calendar:datetime_utc() | undefined,  % Время подтверждения доставки (если статус = delivered)
    confirmed_at :: calendar:datetime_utc() | undefined   % Время подтверждения получения уведомления (если статус = confirmed)
}).

-record(timer, {
    id :: timer_queue:timer_id(),
    deadline_ms :: integer(),
    destination :: timer_queue:destination(),
    message :: term()
}).

-endif.