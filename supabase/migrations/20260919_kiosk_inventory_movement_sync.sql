-- K39: explicit kiosk inventory movement synchronization.
-- The existing inventory_movements table is authoritative for inventory.
-- This mapping table makes kiosk movement IDs idempotent without changing the
-- existing inventory_movements primary key contract.

create table if not exists public.kiosk_inventory_movement_sync (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  device_code text not null,
  local_movement_id text not null,
  inventory_movement_id uuid references public.inventory_movements(id),
  status text not null default 'synced',
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, local_movement_id)
);

create index if not exists kiosk_inventory_movement_sync_store_status_idx
  on public.kiosk_inventory_movement_sync (store_id, status);

alter table public.kiosk_inventory_movement_sync enable row level security;

create or replace function public.sync_kiosk_inventory_movements(
  p_store_id uuid,
  p_device_code text,
  p_movements jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id uuid;
  v_item jsonb;
  v_local_id text;
  v_inventory_item_id uuid;
  v_movement_type text;
  v_quantity numeric;
  v_unit text;
  v_reason text;
  v_occurred_at timestamptz;
  v_server_id uuid;
  v_existing public.kiosk_inventory_movement_sync%rowtype;
  v_results jsonb := '[]'::jsonb;
begin
  if p_store_id is null or nullif(trim(p_device_code), '') is null then
    raise exception 'Store ID and device code are required';
  end if;

  select d.id
    into v_device_id
  from public.devices d
  where d.store_id = p_store_id
    and d.device_code = trim(p_device_code)
    and d.is_active = true
  limit 1;

  if v_device_id is null then
    raise exception 'No active kiosk device found for this store and device code';
  end if;

  if jsonb_typeof(p_movements) <> 'array' then
    raise exception 'Inventory movements payload must be an array';
  end if;

  for v_item in select value from jsonb_array_elements(p_movements)
  loop
    v_local_id := nullif(trim(v_item->>'localMovementId'), '');
    begin
      v_inventory_item_id := (v_item->>'inventoryItemId')::uuid;
      v_movement_type := lower(trim(v_item->>'movementType'));
      v_quantity := (v_item->>'quantity')::numeric;
      v_unit := nullif(trim(v_item->>'unit'), '');
      v_reason := coalesce(nullif(trim(v_item->>'reason'), ''), 'Kiosk inventory movement');
      v_occurred_at := coalesce((v_item->>'occurredAt')::timestamptz, now());

      if v_local_id is null then
        raise exception 'Missing local movement ID';
      end if;
      if v_movement_type not in ('usage', 'stock_in', 'adjustment') then
        raise exception 'Unsupported inventory movement type: %', v_movement_type;
      end if;
      if v_quantity = 0 then
        raise exception 'Inventory movement quantity cannot be zero';
      end if;
      if v_unit is null then
        raise exception 'Inventory movement unit is required';
      end if;

      select *
        into v_existing
      from public.kiosk_inventory_movement_sync s
      where s.store_id = p_store_id
        and s.local_movement_id = v_local_id
      for update;

      if v_existing.id is not null then
        if v_existing.status = 'synced' and v_existing.inventory_movement_id is not null then
          v_results := v_results || jsonb_build_array(jsonb_build_object(
            'localMovementId', v_local_id,
            'status', 'already_synced',
            'serverMovementId', v_existing.inventory_movement_id
          ));
        else
          v_results := v_results || jsonb_build_array(jsonb_build_object(
            'localMovementId', v_local_id,
            'status', 'failed',
            'error', coalesce(v_existing.error_message, 'Previous sync failed; retrying is required.')
          ));
        end if;
        continue;
      end if;

      insert into public.inventory_movements (
        id,
        store_id,
        inventory_item_id,
        movement_type,
        quantity,
        reason,
        reference_id,
        created_at
      ) values (
        gen_random_uuid(),
        p_store_id,
        v_inventory_item_id,
        v_movement_type,
        v_quantity,
        v_reason,
        v_local_id,
        v_occurred_at
      )
      returning id into v_server_id;

      insert into public.kiosk_inventory_movement_sync (
        store_id,
        device_code,
        local_movement_id,
        inventory_movement_id,
        status,
        error_message,
        created_at,
        updated_at
      ) values (
        p_store_id,
        trim(p_device_code),
        v_local_id,
        v_server_id,
        'synced',
        null,
        now(),
        now()
      );

      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'localMovementId', v_local_id,
        'status', 'synced',
        'serverMovementId', v_server_id
      ));
    exception when others then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'localMovementId', coalesce(v_local_id, 'unknown'),
        'status', 'failed',
        'error', sqlerrm
      ));
    end;
  end loop;

  return v_results;
end;
$$;

grant execute on function public.sync_kiosk_inventory_movements(uuid, text, jsonb) to anon, authenticated;
