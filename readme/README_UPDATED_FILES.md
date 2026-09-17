# Bigger Brew Kiosk — K15.3.10 Updated Files

This package contains the source files updated/added for K15.3.10 Catalog Navigation Integration & Staff Entry Point.

## Files
- `lib/features/kiosk/pages/kiosk_home_page.dart`
- `lib/features/kiosk/staff_access.dart`
- `lib/features/catalog/catalog_manager_dashboard.dart` (K15.3.9 dependency)
- `test/kiosk/kiosk_k15_3_10_staff_entry_test.dart`
- `Bigger_Brew_Kiosk_Sprint_Roadmap.md`

## Integration
Place these files into the existing Bigger Brew kiosk project using the same relative paths.

Production PIN is supplied with:

```bash
flutter build apk --release --dart-define=BIGGER_BREW_STAFF_PIN=YOUR_STORE_PIN
```

Development fallback PIN is `0000` unless overridden by the Dart define.

Flutter runtime verification was not available in the generation environment because the Flutter/Dart CLI is not installed there.
