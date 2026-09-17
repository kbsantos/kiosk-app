# Bigger Brew Kiosk — K15.3.24 Merge

The supplied working kiosk project is the base. K15.3 catalog-management updates were merged into it rather than replacing the existing kiosk application.

Merged:
- Catalog Manager Hub
- Categories / Products / Sizes & Variants / Options
- Catalog Health
- Backup / Restore / Rollback
- Audit History
- JSON Import / Export
- Schema Guard
- Multi-Kiosk Sync + K15.3.24 hardening
- Editor / Manager permission model

Preserved from the working project:
- Customer ordering flow
- Cart / checkout / payments
- Orders / queue / history
- Receipt/EOD functionality
- Kiosk settings
- Existing staff tools/session gate
- Idle timeout and kiosk navigation

Runtime verification still needs Flutter installed:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
