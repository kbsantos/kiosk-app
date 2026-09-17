-- MyKiosk Store Master Catalog
-- Supabase is the store-level source of truth. Kiosks keep a local operational copy.

create table if not exists public.catalog_categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category_id text not null,
  name text not null,
  subtitle text not null default '',
  icon text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, category_id)
);

create table if not exists public.catalog_products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  product_id text not null,
  category_id text not null,
  name text not null,
  product_type text not null,
  group_id text,
  group_name text,
  description text,
  image text,
  active boolean not null default true,
  available boolean not null default true,
  kitchen_prepared boolean not null default false,
  drink_temperature text,
  price numeric,
  sku text,
  recipe_ref text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, product_id),
  foreign key (store_id, category_id)
    references public.catalog_categories(store_id, category_id)
    on update cascade
    on delete restrict
);

create table if not exists public.catalog_product_sizes (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  product_id text not null,
  size_id text not null,
  name text not null,
  volume_ml integer,
  display_volume text,
  price numeric,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, product_id, size_id),
  foreign key (store_id, product_id)
    references public.catalog_products(store_id, product_id)
    on delete cascade
);

create table if not exists public.catalog_product_variants (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  product_id text not null,
  variant_id text not null,
  name text not null,
  price numeric,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, product_id, variant_id),
  foreign key (store_id, product_id)
    references public.catalog_products(store_id, product_id)
    on delete cascade
);

create table if not exists public.catalog_option_definitions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  option_id text not null,
  name text not null,
  product_types jsonb not null default '[]'::jsonb,
  price numeric,
  active boolean not null default true,
  kitchen_prepared boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, option_id)
);

create table if not exists public.catalog_product_options (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  product_id text not null,
  option_id text not null,
  name text not null,
  price numeric,
  active boolean not null default true,
  kitchen_prepared boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, product_id, option_id),
  foreign key (store_id, product_id)
    references public.catalog_products(store_id, product_id)
    on delete cascade,
  foreign key (store_id, option_id)
    references public.catalog_option_definitions(store_id, option_id)
    on delete restrict
);

create table if not exists public.store_catalog_versions (
  store_id uuid primary key references public.stores(id) on delete cascade,
  catalog_version text not null,
  updated_at timestamptz not null default now(),
  updated_by_device_id uuid references public.devices(id) on delete set null
);

create index if not exists idx_catalog_categories_store
  on public.catalog_categories(store_id, active, sort_order);
create index if not exists idx_catalog_products_store_category
  on public.catalog_products(store_id, category_id, active, sort_order);
create index if not exists idx_catalog_product_sizes_product
  on public.catalog_product_sizes(store_id, product_id, active, sort_order);
create index if not exists idx_catalog_product_variants_product
  on public.catalog_product_variants(store_id, product_id, active, sort_order);
create index if not exists idx_catalog_product_options_product
  on public.catalog_product_options(store_id, product_id, active, sort_order);

-- The catalog is accessed through tightly scoped RPCs rather than direct kiosk table reads/writes.
alter table public.catalog_categories enable row level security;
alter table public.catalog_products enable row level security;
alter table public.catalog_product_sizes enable row level security;
alter table public.catalog_product_variants enable row level security;
alter table public.catalog_option_definitions enable row level security;
alter table public.catalog_product_options enable row level security;
alter table public.store_catalog_versions enable row level security;

create or replace function public.get_store_catalog_version(p_store_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version text;
begin
  select catalog_version into v_version
  from public.store_catalog_versions
  where store_id = p_store_id;

  if v_version is null then
    raise exception 'No master catalog exists for store %', p_store_id;
  end if;

  return v_version;
end;
$$;

create or replace function public.get_store_catalog(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version text;
  v_result jsonb;
begin
  select catalog_version into v_version
  from public.store_catalog_versions
  where store_id = p_store_id;

  if v_version is null then
    raise exception 'No master catalog exists for store %', p_store_id;
  end if;

  select jsonb_build_object(
    'schemaVersion', 1,
    'catalogVersion', v_version,
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'categoryId', c.category_id,
          'name', c.name,
          'subtitle', c.subtitle,
          'active', c.active,
          'icon', c.icon
        ) order by c.sort_order, c.name
      ) from public.catalog_categories c
      where c.store_id = p_store_id
    ), '[]'::jsonb),
    'optionDefinitions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'optionId', o.option_id,
          'name', o.name,
          'productTypes', o.product_types,
          'price', o.price,
          'active', o.active,
          'kitchenPrepared', o.kitchen_prepared
        ) order by o.name
      ) from public.catalog_option_definitions o
      where o.store_id = p_store_id
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'productId', p.product_id,
          'name', p.name,
          'productType', p.product_type,
          'drinkTemperature', p.drink_temperature,
          'categoryId', p.category_id,
          'groupId', p.group_id,
          'groupName', p.group_name,
          'description', p.description,
          'image', p.image,
          'active', p.active,
          'available', p.available,
          'kitchenPrepared', p.kitchen_prepared,
          'price', p.price,
          'sku', p.sku,
          'recipeRef', p.recipe_ref,
          'sizes', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'sizeId', s.size_id,
                'name', s.name,
                'volumeMl', s.volume_ml,
                'displayVolume', s.display_volume,
                'price', s.price
              ) order by s.sort_order, s.name
            ) from public.catalog_product_sizes s
            where s.store_id = p.store_id and s.product_id = p.product_id
          ), '[]'::jsonb),
          'variants', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'variantId', v.variant_id,
                'name', v.name,
                'price', v.price,
                'active', v.active
              ) order by v.sort_order, v.name
            ) from public.catalog_product_variants v
            where v.store_id = p.store_id and v.product_id = p.product_id
          ), '[]'::jsonb),
          'options', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'optionId', x.option_id,
                'name', x.name,
                'price', x.price,
                'active', x.active,
                'kitchenPrepared', x.kitchen_prepared
              ) order by x.sort_order, x.name
            ) from public.catalog_product_options x
            where x.store_id = p.store_id and x.product_id = p.product_id
          ), '[]'::jsonb)
        ) order by p.sort_order, p.name
      ) from public.catalog_products p
      where p.store_id = p_store_id
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

-- One-time bootstrap only: a master catalog may be initialized from a kiosk
-- while the store has no catalog. Once a master exists, this RPC cannot overwrite it.
create or replace function public.initialize_store_catalog_from_kiosk(
  p_store_id uuid,
  p_device_code text,
  p_catalog jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id uuid;
  v_existing integer;
  v_version text;
  v_category jsonb;
  v_product jsonb;
  v_size jsonb;
  v_variant jsonb;
  v_option jsonb;
  v_option_definition jsonb;
begin
  select d.id into v_device_id
  from public.devices d
  where d.store_id = p_store_id
    and d.device_code = trim(p_device_code)
    and d.is_active = true
  limit 1;

  if v_device_id is null then
    raise exception 'No active kiosk found for store % and device %', p_store_id, p_device_code;
  end if;

  select count(*) into v_existing
  from public.store_catalog_versions
  where store_id = p_store_id;

  if v_existing > 0 then
    raise exception 'A master catalog already exists for store %. Use the catalog administration workflow instead of bootstrap.', p_store_id;
  end if;

  v_version := nullif(trim(p_catalog ->> 'catalogVersion'), '');
  if v_version is null then
    raise exception 'Catalog version is required.';
  end if;

  -- Insert categories first because products reference them.
  for v_category in select value from jsonb_array_elements(coalesce(p_catalog -> 'categories', '[]'::jsonb)) loop
    insert into public.catalog_categories (
      store_id, category_id, name, subtitle, icon, active, sort_order
    ) values (
      p_store_id,
      v_category ->> 'categoryId',
      coalesce(v_category ->> 'name', ''),
      coalesce(v_category ->> 'subtitle', ''),
      nullif(v_category ->> 'icon', ''),
      coalesce((v_category ->> 'active')::boolean, true),
      0
    );
  end loop;

  for v_option_definition in select value from jsonb_array_elements(coalesce(p_catalog -> 'optionDefinitions', '[]'::jsonb)) loop
    insert into public.catalog_option_definitions (
      store_id, option_id, name, product_types, price, active, kitchen_prepared
    ) values (
      p_store_id,
      v_option_definition ->> 'optionId',
      coalesce(v_option_definition ->> 'name', ''),
      coalesce(v_option_definition -> 'productTypes', '[]'::jsonb),
      nullif(v_option_definition ->> 'price', '')::numeric,
      coalesce((v_option_definition ->> 'active')::boolean, true),
      coalesce((v_option_definition ->> 'kitchenPrepared')::boolean, false)
    );
  end loop;

  for v_product in select value from jsonb_array_elements(coalesce(p_catalog -> 'products', '[]'::jsonb)) loop
    insert into public.catalog_products (
      store_id, product_id, category_id, name, product_type, group_id, group_name,
      description, image, active, available, kitchen_prepared, drink_temperature,
      price, sku, recipe_ref, sort_order
    ) values (
      p_store_id,
      v_product ->> 'productId',
      v_product ->> 'categoryId',
      coalesce(v_product ->> 'name', ''),
      coalesce(v_product ->> 'productType', ''),
      nullif(v_product ->> 'groupId', ''),
      nullif(v_product ->> 'groupName', ''),
      nullif(v_product ->> 'description', ''),
      nullif(v_product ->> 'image', ''),
      coalesce((v_product ->> 'active')::boolean, true),
      coalesce((v_product ->> 'available')::boolean, true),
      coalesce((v_product ->> 'kitchenPrepared')::boolean, false),
      nullif(v_product ->> 'drinkTemperature', ''),
      nullif(v_product ->> 'price', '')::numeric,
      nullif(v_product ->> 'sku', ''),
      nullif(v_product ->> 'recipeRef', ''),
      0
    );

    for v_size in select value from jsonb_array_elements(coalesce(v_product -> 'sizes', '[]'::jsonb)) loop
      insert into public.catalog_product_sizes (
        store_id, product_id, size_id, name, volume_ml, display_volume, price, active, sort_order
      ) values (
        p_store_id,
        v_product ->> 'productId',
        v_size ->> 'sizeId',
        coalesce(v_size ->> 'name', ''),
        nullif(v_size ->> 'volumeMl', '')::integer,
        nullif(v_size ->> 'displayVolume', ''),
        nullif(v_size ->> 'price', '')::numeric,
        true,
        0
      );
    end loop;

    for v_variant in select value from jsonb_array_elements(coalesce(v_product -> 'variants', '[]'::jsonb)) loop
      insert into public.catalog_product_variants (
        store_id, product_id, variant_id, name, price, active, sort_order
      ) values (
        p_store_id,
        v_product ->> 'productId',
        v_variant ->> 'variantId',
        coalesce(v_variant ->> 'name', ''),
        nullif(v_variant ->> 'price', '')::numeric,
        coalesce((v_variant ->> 'active')::boolean, true),
        0
      );
    end loop;

    for v_option in select value from jsonb_array_elements(coalesce(v_product -> 'options', '[]'::jsonb)) loop
      insert into public.catalog_product_options (
        store_id, product_id, option_id, name, price, active, kitchen_prepared, sort_order
      ) values (
        p_store_id,
        v_product ->> 'productId',
        v_option ->> 'optionId',
        coalesce(v_option ->> 'name', ''),
        nullif(v_option ->> 'price', '')::numeric,
        coalesce((v_option ->> 'active')::boolean, true),
        coalesce((v_option ->> 'kitchenPrepared')::boolean, false),
        0
      );
    end loop;
  end loop;

  insert into public.store_catalog_versions (
    store_id, catalog_version, updated_by_device_id
  ) values (
    p_store_id, v_version, v_device_id
  );

  return v_version;
end;
$$;

revoke all on function public.get_store_catalog_version(uuid) from public;
revoke all on function public.get_store_catalog(uuid) from public;
revoke all on function public.initialize_store_catalog_from_kiosk(uuid, text, jsonb) from public;

grant execute on function public.get_store_catalog_version(uuid) to anon, authenticated;
grant execute on function public.get_store_catalog(uuid) to anon, authenticated;
grant execute on function public.initialize_store_catalog_from_kiosk(uuid, text, jsonb) to anon, authenticated;

notify pgrst, 'reload schema';
