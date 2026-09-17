# Bigger Brew Kiosk K4.11.6 — Kiosk Safety Checkpoint

## Result

IMPLEMENTED — Kiosk customer-session idle timeout and customer isolation foundation added.

## Goal

Advance the kiosk toward the planned Kiosk Navigation & Safety milestone without changing the existing ordering, employee-mode, payment, receipt, or EOD behavior.

## Completed

- Added a reusable `KioskIdleTimeoutController`.
- Added a 3-minute default customer inactivity timeout.
- Root-level pointer activity resets the customer timeout across kiosk routes and customization dialogs.
- Timeout clears the current cart.
- Timeout returns the kiosk to the first/home route.
- Staff settings, order queue, and order history screens disable the customer timeout while staff access is active.
- Returning from staff screens re-enables the customer timeout.
- Customer queue remains covered by the timeout so an unattended customer-status screen eventually returns to kiosk home.
- Added unit coverage for timeout-controller start/stop behavior.

## Safety flow

```text
Customer starts order
        ↓
Any touch / pointer activity
        ↓
3-minute inactivity timer resets
        ↓
No activity for 3 minutes
        ↓
Cart cleared
        ↓
Return to Kiosk Home
```

## Staff isolation

```text
Customer flow
    ↓
Idle timeout ACTIVE

Staff access
    ↓
PIN / existing 30-minute staff session
    ↓
Idle timeout PAUSED
    ↓
Return to kiosk customer screen
    ↓
Idle timeout ACTIVE
```

## Files changed

```text
lib/main.dart
lib/features/kiosk/kiosk_idle_timeout.dart
lib/features/kiosk/pages/kiosk_home_page.dart
test/kiosk/kiosk_idle_timeout_test.dart
```

## Verification

The current source environment does not expose the Flutter/Dart CLI, so CLI test execution is not claimed here.

Run locally:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Manual verification

1. Start an order and wait for the configured timeout.
2. Confirm the cart is cleared and the kiosk returns to Home.
3. Start an order and interact before the timeout; confirm the timer resets.
4. Open Staff Settings / Order Queue / Order History and confirm the customer timeout does not interrupt staff work.
5. Exit staff mode and confirm customer timeout resumes.
6. Place a customer order and confirm the existing checkout/receipt/order-status flow remains unchanged.

## Next

Proceed to the next production-readiness review: verify kiosk safety behavior in Chrome and on the target kiosk hardware, then move toward the planned K12 Production / Store Mode and K13 final testing milestones.
