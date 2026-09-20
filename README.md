my_kiosk

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Store Management catalog sync reporting

The Kiosk Store Master synchronization now reports a successful catalog version to
Store Management through `report_kiosk_catalog_sync` after the local catalog has
been validated and cached. Reporting is non-fatal so a missing migration or
transient network failure never takes the customer-facing kiosk offline.

Apply the Store Management migration `supabase/20260918_catalog_sync_state.sql`
from the Store Management project before expecting the Store Management Catalog
Sync page to show live `SYNCED` status.

## Local catalog to Store Master synchronization

Administration Sync now includes `SYNC LOCAL CATALOG TO MASTER`. This publishes the
current validated kiosk catalog to the existing Store Master through the
`publish_store_catalog_from_kiosk` RPC. The kiosk must have a known master version
that matches the current database version; otherwise the operation stops and asks
staff to refresh before publishing. The database RPC performs the final atomic
optimistic-lock check, and the local kiosk catalog/version is updated only after
the master accepts the write.
