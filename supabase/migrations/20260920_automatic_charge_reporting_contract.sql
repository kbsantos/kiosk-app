-- Bigger Brew Kiosk K7.8
-- Preserve the mandatory automatic-charge flag in transaction reporting
-- and transaction restore payloads.
--
-- The kiosk reporting mapper already sends `automatic` in each option object.
-- This migration makes the persisted option contract explicit and updates the
-- restore RPC so the flag survives a database -> kiosk recovery.

alter table public.transaction_item_options
    add column if not exists automatic boolean not null default false;

create or replace function public.get_kiosk_transactions_for_restore(
    p_store_id uuid,
    p_device_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_device_id uuid;
    v_transactions jsonb;
begin
    select d.id
      into v_device_id
      from public.devices d
     where d.store_id = p_store_id
       and d.device_code = trim(p_device_code)
       and d.is_active = true
     limit 1;

    if v_device_id is null then
        raise exception
            'No active kiosk device found for store_id % and device_code %',
            p_store_id,
            trim(p_device_code);
    end if;

    select coalesce(
        jsonb_agg(
            jsonb_build_object(
                'id', t.external_transaction_id,
                'orderNumber', coalesce(t.order_number, t.external_transaction_id),
                'createdAt', t.transaction_date,
                'orderType', coalesce(t.order_type, 'Take Out'),
                'paymentMethod', coalesce(t.payment_method, 'Pay at Counter'),
                'paymentStatus', coalesce(t.payment_status, 'pending'),
                'orderMode', coalesce(t.order_mode, 'Customer'),
                'status', coalesce(t.status, 'pending'),
                'cancellationReason', t.cancellation_reason,
                'modificationReason', t.modification_reason,
                'modifiedAt', t.modified_at,
                'total', round(t.total)::int,
                'items', coalesce(
                    (
                        select jsonb_agg(
                            jsonb_build_object(
                                'productId', coalesce(ti.product_id, ''),
                                'productName', ti.product_name,
                                'productType', coalesce(ti.product_type, 'drink'),
                                'drinkTemperature', ti.drink_temperature,
                                'groupId', ti.group_id,
                                'groupName', ti.group_name,
                                'kitchenPrepared', coalesce(ti.kitchen_prepared, false),
                                'category', coalesce(ti.category, 'accessories'),
                                'size', case
                                    when ti.size_id is null then null
                                    else jsonb_build_object(
                                        'id', ti.size_id,
                                        'name', coalesce(ti.size_name, ti.size_id),
                                        'volumeMl', case
                                            when ti.size_volume_ml is null then null
                                            else round(ti.size_volume_ml)::int
                                        end,
                                        'displayVolume', case
                                            when ti.size_volume_ml is null then null
                                            when round(ti.size_volume_ml)::int = 355 then '12oz'
                                            when round(ti.size_volume_ml)::int = 650 then '22oz'
                                            when round(ti.size_volume_ml)::int = 1000 then '1L'
                                            else concat(round(ti.size_volume_ml)::int, 'ml')
                                        end,
                                        'price', round(
                                            ti.unit_price - coalesce(
                                                (
                                                    select sum(coalesce(tio.price, 0))
                                                    from public.transaction_item_options tio
                                                    where tio.transaction_item_id = ti.id
                                                ),
                                                0
                                            )
                                        )::int
                                    )
                                end,
                                'variant', case
                                    when ti.variant_id is null then null
                                    else jsonb_build_object(
                                        'id', ti.variant_id,
                                        'name', coalesce(ti.variant_name, ti.variant_id),
                                        'price', round(
                                            ti.unit_price - coalesce(
                                                (
                                                    select sum(coalesce(tio.price, 0))
                                                    from public.transaction_item_options tio
                                                    where tio.transaction_item_id = ti.id
                                                ),
                                                0
                                            )
                                        )::int
                                    )
                                end,
                                'quantity', ti.quantity,
                                'unitPrice', round(
                                    ti.unit_price - coalesce(
                                        (
                                            select sum(coalesce(tio.price, 0))
                                            from public.transaction_item_options tio
                                            where tio.transaction_item_id = ti.id
                                        ),
                                        0
                                    )
                                )::int,
                                'total', round(ti.total)::int,
                                'options', coalesce(
                                    (
                                        select jsonb_agg(
                                            jsonb_build_object(
                                                'id', coalesce(tio.option_id, tio.id::text),
                                                'name', tio.option_name,
                                                'price', coalesce(round(tio.price)::int, 0),
                                                'kitchenPrepared', coalesce(tio.kitchen_prepared, false),
                                                'automatic', coalesce(tio.automatic, false)
                                            )
                                            order by tio.created_at nulls last, tio.id
                                        )
                                        from public.transaction_item_options tio
                                        where tio.transaction_item_id = ti.id
                                    ),
                                    '[]'::jsonb
                                )
                            )
                            order by ti.created_at nulls last, ti.id
                        )
                        from public.transaction_items ti
                        where ti.transaction_id = t.id
                    ),
                    '[]'::jsonb
                )
            )
            order by t.transaction_date, t.id
        ),
        '[]'::jsonb
    )
    into v_transactions
    from public.transactions t
    where t.store_id = p_store_id
      and t.device_id = v_device_id;

    return v_transactions;
end;
$$;

revoke all on function public.get_kiosk_transactions_for_restore(uuid, text)
from public;

grant execute on function public.get_kiosk_transactions_for_restore(uuid, text)
to anon, authenticated;

notify pgrst, 'reload schema';
