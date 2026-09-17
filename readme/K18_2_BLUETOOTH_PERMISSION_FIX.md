# K18.2 Bluetooth Permission Fix

## Target
XP-58H Bluetooth Classic thermal printer on Android.

## Changes
- Added `permission_handler: ^13.0.1`.
- Added explicit Android runtime permission request for `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` through `permission_handler`.
- Bluetooth helper now treats Android as the native Bluetooth target and safely reports unsupported/non-Android environments instead of surfacing `Platform._operatingSystem` as "Bluetooth OFF".
- Bluetooth settings now requests Nearby devices permission before checking Bluetooth state.
- Added an `ALLOW NEARBY DEVICES` recovery button when permission is denied.
- Paired-printer discovery remains based on the Android paired-device list; the XP-58H should be paired in Android Bluetooth settings first.
- Existing ESC/POS receipt and test-print logic is preserved.

## Validation
Run on the development machine:

```bash
flutter pub get
flutter analyze
flutter test
```

Then on the Android tablet:

1. Install a clean/rebuilt APK.
2. Open Receipt Printer settings.
3. Allow Nearby devices when requested.
4. Turn Bluetooth on.
5. Pair XP-58H in Android Bluetooth settings.
6. Return to Bigger Brew and press SEARCH.
7. Select XP-58H.
8. Press PRINT TEST.

## Note
The supplied source archive does not contain the Android platform directory. The existing local `android/app/src/main/AndroidManifest.xml` should retain the `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` declarations already added to the project. This checkpoint changes the Dart runtime-permission flow; it does not invent or replace the missing Android Gradle project files.
