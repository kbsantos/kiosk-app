# Bigger Brew Kiosk K4.11.8 — K13 Final Regression / Release Validation

## Status

Implemented — ready for local CLI and hardware verification.

## Goal

Complete the dedicated K13 regression gate before the planned APK/deployment
milestone. This checkpoint does not intentionally change customer-facing
behavior; it adds release-contract tests around the existing K4.11.x features.

## Added

`test/kiosk/kiosk_k13_release_regression_test.dart`

Coverage includes:

- size-based drink pricing plus add-on totals;
- Rice Meal kitchen-preparation metadata;
- order JSON round-trip for size, options, payment and order mode;
- production default settings;
- counter payment pending behavior;
- locked staff session and 30-minute staff-session contract;
- idle-timeout stop behavior for staff mode;
- stable stored-order category IDs.

## Full verification command

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Manual regression gate

### Customer ordering

- [ ] Kiosk launches directly into customer Home.
- [ ] Categories and products load.
- [ ] Drink size selection works for configured sizes.
- [ ] Drink add-ons calculate correctly.
- [ ] Rice Meal add-ons calculate correctly.
- [ ] Cart quantity increase/decrease/remove works.
- [ ] Normal customer checkout works.

### Employee Order Mode

- [ ] Employee Order Mode remains ON by default.
- [ ] Employee checkout records the selected payment mode.
- [ ] Employee checkout marks the order paid/completed.
- [ ] Employee checkout prints immediately.
- [ ] Customer checkout behavior remains unchanged when Employee Order Mode is OFF.

### Kitchen preparation

- [ ] Rice Meals remain kitchen-prepared.
- [ ] Kitchen-tagged Rice Meal add-ons appear in KITCHEN COPY.
- [ ] Drink products/add-ons remain excluded unless catalog metadata marks them kitchen-prepared.
- [ ] Customer receipt remains unchanged.

### EOD Excel

- [ ] End of Day Summary is present.
- [ ] Orders worksheet is present.
- [ ] Items worksheet is present.
- [ ] Drink Summary groups cups by commercial size.
- [ ] Drink Summary includes Total Cups.
- [ ] Meal Summary counts completed meals.
- [ ] Meal add-on counts are present.
- [ ] Only completed orders are included in sales summaries.

### Kiosk safety / production mode

- [ ] Three-minute customer idle timeout clears the cart and returns Home.
- [ ] Customer activity resets the timeout.
- [ ] Staff screens pause the customer timeout.
- [ ] Staff Mode is not visible in the normal customer UI.
- [ ] Five taps on BIGGER BREW within four seconds opens staff PIN access.
- [ ] Correct PIN opens Staff Tools.
- [ ] Staff Tools provides Queue, History/EOD, and Settings.
- [ ] Exit Staff Mode locks staff access.
- [ ] Store Closed does not expose customer Settings access.

## Release decision

Do not mark K13 complete until local `flutter test` and the manual regression
checklist pass on the target kiosk/tablet.

After K13 passes, proceed to the planned APK/deployment milestone:

```bash
flutter build apk --release
```
