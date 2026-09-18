# K32.2 — Multi-Kiosk Device Re-Provisioning Compile Fix

Based on validated K31 and K32.1.

## Fix

Re-exported `kiosk_device_recovery.dart` from `kiosk_device_reprovisioning.dart` so consumers of the reprovisioning API can access `KioskDeviceRecoveryState` without importing an internal sibling file separately.

No runtime behavior or database behavior was changed.

## Verification

Run:

```bash
flutter analyze
flutter test
```
