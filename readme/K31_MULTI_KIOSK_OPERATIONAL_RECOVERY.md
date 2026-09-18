# K31 — Multi-Kiosk Operational Recovery

## Scope

K31 adds a safe, non-destructive device identity verification step to the
Administration Sync page.

## Recovery principles

- Store Master remains authoritative for catalog data.
- Local kiosk transactions remain authoritative for local operations.
- Reporting data is synchronized explicitly.
- Device recovery never overwrites or deletes local transactions.
- A kiosk must map to an active `devices` record before recovery workflows are
  considered ready.
- Catalog refresh and transaction restore continue through their existing
  protected workflows.

## Device verification

Administration Sync now provides **VERIFY DEVICE IDENTITY**. The kiosk calls
the `get_kiosk_device_recovery_status` SECURITY DEFINER RPC using the configured
Store ID and Device / Kiosk Code.

Possible states:

- Device identity not configured
- Device not registered
- Device inactive
- Device identity verified

The RPC is read-only. It does not change the `devices` table or kiosk
transactions.

## Supabase migration

Apply:

`supabase/migrations/20260919_kiosk_device_recovery.sql`

before using server-side device verification.
