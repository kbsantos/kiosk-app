# K7.9 — EOD Automatic Charge Reconciliation

## Scope

K7.9 makes automatic-charge reporting use one shared aggregation contract across the kiosk EOD PDF and Excel reports.

### Behavior

- Only completed orders contribute to the automatic-charge summary.
- Options marked `automatic: true` are grouped by charge ID.
- Quantity is multiplied by the order-item quantity.
- Automatic-charge sales are already included in the order total; the EOD report does not add them again.
- EOD sales reconciliation now shows:
  - Completed Sales
  - Automatic Charges
  - Sales Excl. Automatic Charges
- PDF and Excel detailed automatic-charge sections use the same summary implementation.
- Existing selectable add-ons are excluded from automatic-charge totals.
- Cancelled/refunded orders are excluded from the automatic-charge sales summary.

## Validation

This checkpoint was source-checked for balanced Dart delimiters and packaging integrity in the tool environment. Flutter/Dart is not installed in the tool environment, so runtime validation must be performed on the development Mac.

Run:

```bash
flutter analyze
flutter test
```

No new Supabase migration is required for K7.9. It consumes the already validated `automatic: true` transaction-option contract from K7.8.1.
