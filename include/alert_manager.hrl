-ifndef(ALERT_MANAGER_HRL_).
-define(ALERT_MANAGER_HRL_, true).

-record(mgr_deps, {
    db :: module(),
    tq :: module()
}).

-endif.