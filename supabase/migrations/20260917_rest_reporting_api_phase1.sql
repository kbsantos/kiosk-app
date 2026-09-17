-- Bigger Brew REST API Phase 1
--
-- Supabase automatically exposes tables/views through PostgREST at /rest/v1/.
-- This migration adds store-scoped reporting views and enables store-scoped
-- read access for authenticated reporting clients.
--
-- IMPORTANT:
-- Reporting clients must authenticate with a Supabase user whose JWT app_metadata
-- contains: { "store_id": "<stores.id UUID>" }
-- service_role continues to bypass RLS for trusted server-side operations.

create or replace function public.current_api_store_id()
returns uuid
language sql
stable
security invoker
set search_path = public
as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'store_id', '')::uuid;
$$;

revoke all on function public.current_api_store_id() from public;
grant execute on function public.current_api_store_id() to authenticated;

-- ---------------------------------------------------------------------------
-- Store-scoped reporting views
-- ---------------------------------------------------------------------------

create or replace view public.report_product_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  ti.category,
  ti.product_id,
  ti.product_name,
  sum(ti.quantity)::integer as quantity_sold,
  sum(ti.total) as total_sales,
  case
    when sum(ti.quantity) = 0 then 0
    else sum(ti.total) / sum(ti.quantity)
  end as average_unit_price
from public.transactions t
join public.transaction_items ti on ti.transaction_id = t.id
where lower(coalesce(t.status, '')) <> 'cancelled'
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date,
  ti.category,
  ti.product_id,
  ti.product_name;

create or replace view public.report_category_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  coalesce(nullif(ti.category, ''), 'Uncategorized') as category,
  sum(ti.quantity)::integer as quantity_sold,
  sum(ti.total) as total_sales
from public.transactions t
join public.transaction_items ti on ti.transaction_id = t.id
where lower(coalesce(t.status, '')) <> 'cancelled'
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date,
  coalesce(nullif(ti.category, ''), 'Uncategorized');

create or replace view public.report_daily_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  count(distinct t.id)::integer as transaction_count,
  coalesce(sum(t.subtotal), 0) as subtotal,
  coalesce(sum(t.discount), 0) as discount,
  coalesce(sum(t.total), 0) as total_sales
from public.transactions t
where lower(coalesce(t.status, '')) <> 'cancelled'
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date;

create or replace view public.report_device_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  count(distinct t.id)::integer as transaction_count,
  coalesce(sum(t.subtotal), 0) as subtotal,
  coalesce(sum(t.discount), 0) as discount,
  coalesce(sum(t.total), 0) as total_sales
from public.transactions t
where lower(coalesce(t.status, '')) <> 'cancelled'
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date;

-- ---------------------------------------------------------------------------
-- RLS for existing reporting sources
-- ---------------------------------------------------------------------------
-- IMPORTANT: Some existing reporting relations are PostgreSQL VIEWS, not tables.
-- PostgreSQL does not support ALTER TABLE ... ENABLE ROW LEVEL SECURITY or
-- CREATE POLICY on a view.  The custom report_* views above use
-- security_invoker=true, so their reads inherit RLS from the underlying tables.
--
-- We therefore apply RLS policies only to base tables and only when the
-- relation is actually a table/partitioned table. This keeps the migration
-- safe across installations where summary objects are views.

-- Transaction base tables ---------------------------------------------------
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;
alter table public.transaction_item_options enable row level security;

-- payments may be a table in some installations. Apply RLS only if it is a
-- base/partitioned table; if it is a view, its underlying sources control access.
do $$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'payments'
      and c.relkind in ('r', 'p')
  ) then
    execute 'alter table public.payments enable row level security';
  end if;
end;
$$;

-- Drop only policies owned by this API migration so it can be safely re-run.
drop policy if exists "reporting_api_store_read" on public.transactions;
drop policy if exists "reporting_api_store_read" on public.transaction_items;
drop policy if exists "reporting_api_store_read" on public.transaction_item_options;

create policy "reporting_api_store_read"
on public.transactions
for select to authenticated
using (store_id = public.current_api_store_id());

create policy "reporting_api_store_read"
on public.transaction_items
for select to authenticated
using (
  exists (
    select 1 from public.transactions t
    where t.id = transaction_items.transaction_id
      and t.store_id = public.current_api_store_id()
  )
);

create policy "reporting_api_store_read"
on public.transaction_item_options
for select to authenticated
using (
  exists (
    select 1
    from public.transaction_items ti
    join public.transactions t on t.id = ti.transaction_id
    where ti.id = transaction_item_options.transaction_item_id
      and t.store_id = public.current_api_store_id()
  )
);

-- payments varies by deployment. In the current Bigger Brew schema it does
-- not have a store_id column, so it cannot safely receive a direct store-scoped
-- policy. We therefore enable RLS only when both the relation is a base table
-- and a store_id column exists. If it lacks store_id, authenticated clients are
-- explicitly denied direct reads; payment reporting should use payment_summary
-- or a future transaction-linked reporting view instead.
do $$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'payments'
      and c.relkind in ('r', 'p')
  ) then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'payments'
        and column_name = 'store_id'
    ) then
      execute 'alter table public.payments enable row level security';
      execute 'drop policy if exists "reporting_api_store_read" on public.payments';
      execute 'create policy "reporting_api_store_read" on public.payments for select to authenticated using (store_id = public.current_api_store_id())';
    else
      execute 'drop policy if exists "reporting_api_store_read" on public.payments';
      execute 'revoke select on public.payments from authenticated';
    end if;
  end if;
end;
$$;

-- Existing summary relations may be either tables or views. Do not attempt to
-- enable RLS on views. If a summary is a table, apply the store_id policy.
do $$
declare
  rel text;
begin
  foreach rel in array array[
    'daily_sales_summary',
    'hourly_sales_summary',
    'product_sales_summary',
    'order_sales_summary',
    'payment_summary',
    'device_sales_summary'
  ] loop
    if exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = rel
        and c.relkind in ('r', 'p')
    ) then
      execute format('alter table public.%I enable row level security', rel);
      execute format('drop policy if exists "reporting_api_store_read" on public.%I', rel);
      execute format('create policy "reporting_api_store_read" on public.%I for select to authenticated using (store_id = public.current_api_store_id())', rel);
    end if;
  end loop;
end;
$$;

-- Read access to custom security-invoker views follows the underlying tables'
-- RLS. Existing summary views are also granted explicitly for PostgREST.
grant select on public.report_product_sales to authenticated;
grant select on public.report_category_sales to authenticated;
grant select on public.report_daily_sales to authenticated;
grant select on public.report_device_sales to authenticated;

grant select on public.transactions to authenticated;
grant select on public.transaction_items to authenticated;
grant select on public.transaction_item_options to authenticated;
grant select on public.daily_sales_summary to authenticated;
grant select on public.hourly_sales_summary to authenticated;
grant select on public.product_sales_summary to authenticated;
grant select on public.order_sales_summary to authenticated;
grant select on public.payment_summary to authenticated;
-- Do not grant direct payments access here. The payments relation in the
-- current schema has no store_id, so direct access would bypass store scoping.
grant select on public.device_sales_summary to authenticated;

notify pgrst, 'reload schema';
