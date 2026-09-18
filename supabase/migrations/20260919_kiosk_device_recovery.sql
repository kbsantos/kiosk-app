                          qq-- Safe kiosk/device identity verification for recovery workflows.
-- This function is read-only. It never changes devices or kiosk transactions.
create or replace function public.get_kiosk_device_recovery_status(
    p_store_id uuid,
    p_device_code text
)
returns jsonb
language sql
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'found', true,
        'deviceId', d.id,
        'storeId', d.store_id,
        'deviceCode', d.device_code,
        'isActive', d.is_active
    )
    from public.devices d
    where d.store_id = p_store_id
      and d.device_code = p_device_code
    order by d.id
    limit 1;
$$;

revoke all on function public.get_kiosk_device_recovery_status(uuid, text)
from public;

grant execute on function public.get_kiosk_device_recovery_status(uuid, text)
to anon, authenticated;
