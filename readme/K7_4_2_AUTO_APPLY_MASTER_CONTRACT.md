# K7.4.2 — Auto Apply master contract

The kiosk UI/model logic already supports `autoApply`. The missing piece was
the shared Supabase `get_store_catalog()` RPC: it returned product options
without `autoApply`, causing the kiosk JSON decoder to default it to `false`.

This migration also updates kiosk bootstrap/publish RPCs so future kiosk-side
catalog writes do not drop the field.

Apply this migration to the shared Supabase project, then publish the catalog
from Store Management and refresh the kiosk catalog.
