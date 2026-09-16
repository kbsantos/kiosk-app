-- Bigger Brew Kiosk reporting identity resolution
-- Store ID is stores.id (uuid).
-- Device/Kiosk Code is devices.device_code (text).
-- The kiosk must not directly SELECT from the RLS-protected devices table.

create or replace function public.resolve_kiosk_device(
    p_store_id uuid,
    p_device_code text
)
returns uuid
language sql
security definer
set search_path = public
as $$
    select d.id
    from public.devices d
    where d.store_id = p_store_id
      and d.device_code = p_device_code
      and d.is_active = true
    limit 1;
$$;

revoke all on function public.resolve_kiosk_device(uuid, text)
from public;

grant execute on function public.resolve_kiosk_device(uuid, text)
to anon, authenticated;
