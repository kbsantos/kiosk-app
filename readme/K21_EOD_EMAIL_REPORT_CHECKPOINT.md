# K21 — End-of-Day Email Report Checkpoint

## Base

Built from `bigger_brew_kiosk_K20_barista_copy_v2.zip`.

## Added

- EOD report recipient email saved in Kiosk Settings.
- Email address validation and clear option.
- `EMAIL PDF` button on the End-of-Day summary page.
- The currently selected EOD date is used for the report.
- Reuses the existing EOD PDF generator.
- Generates `Bigger_Brew_EOD_YYYY-MM-DD.pdf` and attaches it to the native email composer.
- Email subject and body are prefilled.
- Android email app package visibility query for `mailto:`.
- Added `flutter_email_sender` 8.0.0 and `path_provider` 2.1.5.

## Email behavior

The kiosk does not send email silently. It opens the tablet's native email composer with the configured recipient and generated PDF attached. Staff confirms the Send action in the email app.

## Protected subsystems

No changes were made to the XP-58H Bluetooth printer, ESC/POS printing, receipt printing, Barista Copy, or Kitchen Copy logic.

## Validation

Flutter/Android validation was not run in this environment. Validate with:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Then test on the Samsung SM-P615 with an email app configured.
