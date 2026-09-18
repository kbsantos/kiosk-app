# K33 — Device Lifecycle Management & Audit

K33 adds safe kiosk-side lifecycle visibility. The kiosk can verify whether its configured Store ID + Device / Kiosk Code is registered and active, and records local observations for audit/recovery context.

## Lifecycle authority

- Store Management remains authoritative for device registration, activation, deactivation, and retirement.
- The kiosk does not mutate the `devices` table.
- An inactive device is not treated as a usable kiosk.
- A network or Supabase error is shown as **DEVICE STATUS UNAVAILABLE**, never as inactive or unregistered.

## Administration

Administration Sync shows a Device Lifecycle card with the current observed state and a refresh action. Existing device verification and replacement/re-provisioning remain separate workflows.

## Audit

Lifecycle observations are stored locally in a bounded SharedPreferences audit list. Existing re-provisioning audit entries remain separate.

## Database

Migration `20260919_kiosk_device_lifecycle.sql` adds a read-only `get_kiosk_device_lifecycle_status` RPC. No device lifecycle mutation RPC is exposed to the kiosk.
