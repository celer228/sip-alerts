-ifndef(ALERT_MANAGER_HRL_).
-define(ALERT_MANAGER_HRL_, true).

% 30 сек
-define(DELIVERY_TIMEOUT, 18000).
% 60 сек
-define(CONFIRMATION_TIMEOUT, 18000).

-record(mgr_deps, {
    db :: module(),
    tq :: module(),
    log :: module()
}).

-endif.