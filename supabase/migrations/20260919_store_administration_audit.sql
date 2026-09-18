-- K34 Store Administration audit support.
-- Store rows remain the authority. This table records successful manager-side
-- changes without coupling audit history to kiosk transactions.
create table if not exists public.store_administration_audit (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  action text not null,
  store_name text not null,
  is_active boolean not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_store_administration_audit_store_created
  on public.store_administration_audit(store_id, created_at desc);

alter table public.store_administration_audit enable row level security;

revoke all on table public.store_administration_audit from public;
