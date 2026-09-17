# MyKiosk Store Master Catalog — Phase 3 Automatic Kiosk Synchronization

## Status

Implemented.

## Behavior

The customer-facing kiosk now checks the store master catalog whenever `KioskCatalogData.load()` is called. If the server catalog version differs from the kiosk's recorded master version, the kiosk pulls the complete master catalog, validates it, creates a recovery backup, and replaces the local operational catalog.

## Offline / failure safety

Automatic refresh failures are intentionally non-fatal. If Supabase is unavailable, the master has not been initialized, or the returned catalog fails validation, the kiosk continues using the last known-good local catalog.

## Master authority

Product Manager and catalog administration remain database-master writes from Phase 2. The kiosk remains a local operational cache. Automatic refresh does not publish local kiosk changes to Supabase.

## Existing functionality preserved

No changes were made to transaction synchronization, EOD synchronization, restore, printer behavior, ordering calculations, or inventory.

## Validation

The environment used to prepare this checkpoint does not include the Flutter/Dart SDK, so `flutter analyze` and Flutter tests were not run here. Source delimiter sanity checks were performed on the modified Dart files.
