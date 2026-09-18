# K40 — Advanced Sales & Reporting Dashboard

K40 adds a manager-only local sales dashboard. It reads the kiosk's persisted transaction snapshots and provides date-range KPIs plus category, product, variant, add-on, payment, order-mode and hourly sales breakdowns.

The dashboard is explicitly local-kiosk reporting. It does not query or modify Supabase and does not replace the EOD PDF or reporting synchronization workflow. Cross-store/cross-device analytics remain a reporting-database responsibility.
