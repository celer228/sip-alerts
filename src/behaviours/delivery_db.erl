-module(delivery_db).

-callback create_delivery(Alert :: sipalerts_db:alert(), SubscriberId :: sipalerts_db:subscriber_id()) ->
    {ok, DeliveryId :: sipalerts_db:delivery_id()} | {error, Reason :: sipalerts_db:reason()}.

-callback get_delivery(DeliveryId :: sipalerts_db:delivery_id()) ->
    {ok, Delivery :: sipalerts_db:delivery()} | {error, Reason :: sipalerts_db:reason()}.

-callback update_delivery_status(DeliveryId :: sipalerts_db:delivery_id(),
                                 NewStatus :: sipalerts_db:delivery_status()) ->
    ok | {error, Reason :: sipalerts_db:reason()}.

-callback delete_delivery(DeliveryId :: sipalerts_db:delivery_id()) ->
    ok | {error, Reason :: sipalerts_db:reason()}.

-callback list_deliveries() ->
    [sipalerts_db:delivery()] | {error, Reason :: sipalerts_db:reason()}.