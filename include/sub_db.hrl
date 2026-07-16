-ifndef(SUB_DB_HRL_).
-define(SUB_DB_HRL_, 1).

-record(subscriber, {
    id :: sub_db:subscriber_id(),
    contact_id :: sub_db:contact_id(),
    contact_data :: sub_db:contact_data()
}).

-endif.