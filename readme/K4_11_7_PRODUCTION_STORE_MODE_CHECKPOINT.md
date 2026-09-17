# Bigger Brew Kiosk K4.11.7 — Production / Store Mode Checkpoint

## Status

Implemented — ready for local verification.

## Goal

Prepare the kiosk for customer-facing production use by keeping staff tools
out of the normal customer interface while retaining a protected staff entry.

## Changes

- Kiosk continues to launch directly into `KioskHomePage`.
- Removed visible Settings, Order History, and Order Queue buttons from the
  customer-facing header.
- Added a hidden staff-entry gesture: tap the `BIGGER BREW` logo 5 times within
  4 seconds.
- The existing 4-digit staff PIN is still required unless the 30-minute staff
  session is already active.
- Added `KioskStaffToolsPage` as the authenticated staff hub.
- Staff hub provides:
  - Order Queue
  - Order History / EOD
  - Kiosk Settings
  - Return to Customer Kiosk
- Exiting Staff Mode explicitly ends the staff session.
- Customer idle timeout is stopped while Staff Mode is active and resumes when
  returning to the customer kiosk.
- Store Closed no longer exposes a visible Settings button to customers.
- Employee Order Mode remains default `true` and is unchanged.
- Existing payment, receipt, kitchen-preparation, catalog, and EOD logic is
  unchanged.

## Verification

Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Manual checks:

1. Customer sees only the customer kiosk controls.
2. Tap `BIGGER BREW` 5 times within 4 seconds.
3. Staff PIN dialog appears.
4. Correct PIN opens Staff Mode.
5. Order Queue, Order History/EOD, and Settings are accessible.
6. `EXIT STAFF MODE` returns to the customer kiosk and locks staff access.
7. While Staff Mode is active, customer idle timeout does not interrupt staff
   work.
8. When the store is closed, customers cannot see an `OPEN SETTINGS` control.
9. Normal ordering and Employee Order Mode still behave as before.

## Next

After K4.11.7 is verified, proceed to the final dedicated kiosk regression /
release validation before APK deployment.
