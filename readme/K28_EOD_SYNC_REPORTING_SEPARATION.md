# K28 — EOD Sync / Reporting Separation

## Scope

K28 makes EOD reporting explicitly local-first while keeping cloud reporting
synchronization as a separate staff action.

## Behavior

- VIEW PDF REPORT reads the selected date from the local kiosk repository.
- EMAIL PDF generates its attachment from the local kiosk order snapshot.
- Neither local report action requires Supabase/reporting synchronization.
- `SYNC TO REPORTING` is an explicit EOD action that uses the existing
  idempotent `ReportingSyncService.syncAllTransactions()` flow.
- A reporting sync failure does not block local PDF generation or email.
- Existing administration transaction sync remains unchanged.

## Safety

- No local transaction data is modified by report generation or email.
- No background synchronization is introduced.
- Existing printer, checkout/payment, Store Master catalog sync, and historical
  reporting integrity behavior are unchanged.
