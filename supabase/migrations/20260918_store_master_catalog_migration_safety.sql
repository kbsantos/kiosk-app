-- Kiosk local-catalog migration safety.
-- Prevent bootstrap from creating a store master from an empty/invalid kiosk catalog.

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
  v_schema_version integer;
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

  if p_catalog is null or jsonb_typeof(p_catalog) <> 'object' then
    raise exception 'Catalog payload must be a JSON object.';
  end if;

  v_schema_version := nullif(p_catalog ->> 'schemaVersion', '')::integer;
  if v_schema_version is distinct from 1 then
    raise exception 'Unsupported catalog schema version: %', coalesce(v_schema_version::text, 'null');
  end if;

  if jsonb_typeof(coalesce(p_catalog -> 'categories', '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_catalog -> 'categories', '[]'::jsonb)) = 0 then
    raise exception 'Catalog must contain at least one category.';
  end if;

  if jsonb_typeof(coalesce(p_catalog -> 'products', '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_catalog -> 'products', '[]'::jsonb)) = 0 then
    raise exception 'Catalog must contain at least one product. Refusing to initialize the store master from an empty kiosk catalog.';
  end if;

  v_version := nullif(trim(p_catalog ->> 'catalogVersion'), '');
  if v_version is null then
    raise exception 'Catalog version is required.';
  end if;

  -- Insert categories first because products reference them.
  for v_category in select value from jsonb_array_elements(p_catalog -> 'categories') loop
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

  for v_product in select value from jsonb_array_elements(p_catalog -> 'products') loop
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

revoke all on function public.initialize_store_catalog_from_kiosk(uuid, text, jsonb) from public;
grant execute on function public.initialize_store_catalog_from_kiosk(uuid, text, jsonb) to anon, authenticated;

notify pgrst, 'reload schema';
