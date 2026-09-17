-- Bigger Brew Store Master Catalog Phase 2
-- Database-master catalog writes for kiosk catalog administration.
-- The kiosk must identify itself with the configured store ID + active device code.

create or replace function public.publish_store_catalog_from_kiosk(
  p_store_id uuid,
  p_device_code text,
  p_expected_version text,
  p_catalog jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id uuid;
  v_current_version text;
  v_new_version text;
  v_category jsonb;
  v_product jsonb;
  v_size jsonb;
  v_variant jsonb;
  v_option jsonb;
  v_option_definition jsonb;
  v_schema_version integer;
begin
  select d.id
    into v_device_id
  from public.devices d
  where d.store_id = p_store_id
    and d.device_code = trim(p_device_code)
    and d.is_active = true
  limit 1;

  if v_device_id is null then
    raise exception 'No active kiosk found for store % and device %',
      p_store_id, p_device_code;
  end if;

  if jsonb_typeof(p_catalog) <> 'object' then
    raise exception 'Catalog payload must be a JSON object.';
  end if;

  v_schema_version := coalesce((p_catalog ->> 'schemaVersion')::integer, 1);
  if v_schema_version <> 1 then
    raise exception 'Unsupported catalog schema version: %', v_schema_version;
  end if;

  -- Serialize writes for the store so two catalog editors cannot overwrite
  -- each other silently.
  select catalog_version
    into v_current_version
  from public.store_catalog_versions
  where store_id = p_store_id
  for update;

  if v_current_version is null then
    raise exception 'No master catalog exists for store %. Initialize it first.', p_store_id;
  end if;

  if coalesce(trim(p_expected_version), '') <> v_current_version then
    raise exception
      'Catalog changed on the server. Refresh the catalog before saving again. Current version: %',
      v_current_version;
  end if;

  v_new_version := 'db-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS');

  -- Delete children before parents. The complete catalog is replaced in one
  -- transaction, so a failed insert rolls the whole change back.
  delete from public.catalog_product_options where store_id = p_store_id;
  delete from public.catalog_product_sizes where store_id = p_store_id;
  delete from public.catalog_product_variants where store_id = p_store_id;
  delete from public.catalog_products where store_id = p_store_id;
  delete from public.catalog_option_definitions where store_id = p_store_id;
  delete from public.catalog_categories where store_id = p_store_id;

  for v_category in
    select value from jsonb_array_elements(coalesce(p_catalog -> 'categories', '[]'::jsonb))
  loop
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

  for v_option_definition in
    select value from jsonb_array_elements(coalesce(p_catalog -> 'optionDefinitions', '[]'::jsonb))
  loop
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

  for v_product in
    select value from jsonb_array_elements(coalesce(p_catalog -> 'products', '[]'::jsonb))
  loop
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

    for v_size in
      select value from jsonb_array_elements(coalesce(v_product -> 'sizes', '[]'::jsonb))
    loop
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

    for v_variant in
      select value from jsonb_array_elements(coalesce(v_product -> 'variants', '[]'::jsonb))
    loop
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

    for v_option in
      select value from jsonb_array_elements(coalesce(v_product -> 'options', '[]'::jsonb))
    loop
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

  update public.store_catalog_versions
  set catalog_version = v_new_version,
      updated_at = now(),
      updated_by_device_id = v_device_id
  where store_id = p_store_id;

  return v_new_version;
end;
$$;

revoke all on function public.publish_store_catalog_from_kiosk(uuid, text, text, jsonb) from public;
grant execute on function public.publish_store_catalog_from_kiosk(uuid, text, text, jsonb) to anon, authenticated;

notify pgrst, 'reload schema';
