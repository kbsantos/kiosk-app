-- K29: reporting synchronization audit trail.
--
-- A dedicated table is used instead of assuming a pre-existing sync_logs
-- schema. Existing sync_logs consumers are therefore not changed or coupled
-- to the kiosk reporting contract.

create table if not exists public.reporting_sync_logs (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  device_id uuid not null references public.devices(id),
  started_at timestamptz not null,
  completed_at timestamptz not null,
  attempted integer not null check (attempted >= 0),
  succeeded integer not null check (succeeded >= 0),
  failed integer not null check (failed >= 0),
  failures jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (succeeded + failed <= attempted)
);

create index if not exists reporting_sync_logs_store_device_created_idx
  on public.reporting_sync_logs(store_id, device_id, created_at desc);

alter table public.reporting_sync_logs enable row level security;

drop policy if exists "reporting_sync_logs_store_read" on public.reporting_sync_logs;
create policy "reporting_sync_logs_store_read"
on public.reporting_sync_logs
for select to authenticated
using (store_id = public.current_api_store_id());

revoke all on public.reporting_sync_logs from anon;
grant select on public.reporting_sync_logs to authenticated;

create or replace function public.record_kiosk_reporting_sync_log(
  p_store_id uuid,
  p_device_code text,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_attempted integer,
  p_succeeded integer,
  p_failed integer,
  p_failures jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id uuid;
  v_log_id uuid;
begin
  if p_store_id is null or nullif(trim(p_device_code), '') is null then
    raise exception 'Store ID and Device Code are required for sync audit logging';
  end if;
  if p_started_at is null or p_completed_at is null then
    raise exception 'Sync audit timestamps are required';
  end if;
  if p_attempted < 0 or p_succeeded < 0 or p_failed < 0 then
    raise exception 'Sync audit counts cannot be negative';
  end if;
  if p_succeeded + p_failed > p_attempted then
    raise exception 'Sync audit result counts are inconsistent';
  end if;

  select d.id
    into v_device_id
  from public.devices d
  where d.store_id = p_store_id
    and d.device_code = trim(p_device_code)
    and d.active = true
  limit 1;

  if v_device_id is null then
    raise exception 'No active kiosk device was found for the supplied Store ID and Device Code';
  end if;

  insert into public.reporting_sync_logs(
    store_id, device_id, started_at, completed_at,
    attempted, succeeded, failed, failures
  ) values (
    p_store_id, v_device_id, p_started_at, p_completed_at,
    p_attempted, p_succeeded, p_failed, coalesce(p_failures, '[]'::jsonb)
  )
  returning id into v_log_id;

  return v_log_id;
end;
$$;

revoke all on function public.record_kiosk_reporting_sync_log(
  uuid, text, timestamptz, timestamptz, integer, integer, integer, jsonb
) from public;
grant execute on function public.record_kiosk_reporting_sync_log(
  uuid, text, timestamptz, timestamptz, integer, integer, integer, jsonb
) to anon, authenticated;
