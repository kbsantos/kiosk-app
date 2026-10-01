-- Bigger Brew Kiosk - historical transaction item pricing repair
-- MANUAL ONLY. Default is ROLLBACK.
--
-- Purpose:
--   Repair transaction_items whose stored unit_price/base price is clearly
--   inconsistent with valid historical pricing evidence.
--
-- Safety rules:
--   * NEVER changes transactions.total.
--   * NEVER changes transaction_item_options.
--   * Repairs only transactions with exactly one solution that reconciles
--     the repaired item totals to transactions.total.
--   * Ambiguous or non-matching transactions are REVIEW_REQUIRED.
--   * The transaction is wrapped in a transaction and ends with ROLLBACK.
--
-- IMPORTANT:
--   Run this entire script first with ROLLBACK unchanged.
--   Review SAFE_REPAIR rows before changing ROLLBACK to COMMIT.

begin;

-- ---------------------------------------------------------------------------
-- 1. Learn historical base prices from transaction items that look valid.
-- ---------------------------------------------------------------------------
--
-- A transaction item's base price is:
--     unit_price - sum(recorded option prices)
--
-- We consider an observation usable as historical evidence when:
--   * quantity > 0
--   * base price > 0
--   * base price <= 500
--   * line total matches unit_price * quantity
--
-- The size/variant identifiers are retained so size/variant-specific pricing
-- can be distinguished.
-- ---------------------------------------------------------------------------

create temp table _bb_price_history on commit drop as
with option_totals as (
    select
        transaction_item_id,
        coalesce(sum(coalesce(price, 0)), 0)::numeric as option_total
    from public.transaction_item_options
    group by transaction_item_id
),
observations as (
    select
        ti.id,
        t.store_id,
        t.transaction_date,
        ti.product_id,
        ti.size_id,
        ti.variant_id,
        ti.unit_price,
        ti.total,
        ti.quantity,
        (
            ti.unit_price - coalesce(ot.option_total, 0)
        )::numeric as base_price
    from public.transaction_items ti
    join public.transactions t
        on t.id = ti.transaction_id
    left join option_totals ot
        on ot.transaction_item_id = ti.id
)
select
    store_id,
    product_id,
    size_id,
    variant_id,
    base_price,
    min(transaction_date) as first_seen,
    max(transaction_date) as last_seen,
    count(*) as observation_count
from observations
where quantity > 0
  and base_price > 0
  and base_price <= 500
  and abs(total - (unit_price * quantity)) < 0.01
  and total >= 0
  and unit_price >= 0
group by
    store_id,
    product_id,
    size_id,
    variant_id,
    base_price;

create index _bb_ph_idx
    on _bb_price_history(
        store_id,
        product_id,
        size_id,
        variant_id,
        base_price
    );

-- ---------------------------------------------------------------------------
-- 2. Identify suspicious transaction items.
-- ---------------------------------------------------------------------------
--
-- An item is suspicious when its implied base price is either:
--   * greater than the supported normal-price ceiling, OR
--   * absent from the historical price evidence for the same product,
--     size and variant.
-- ---------------------------------------------------------------------------

create temp table _bb_suspicious on commit drop as
with option_totals as (
    select
        transaction_item_id,
        coalesce(sum(coalesce(price, 0)), 0)::numeric as option_total
    from public.transaction_item_options
    group by transaction_item_id
),
observations as (
    select
        ti.id as transaction_item_id,
        ti.transaction_id,
        t.store_id,
        t.transaction_date,
        ti.product_id,
        ti.product_name,
        ti.size_id,
        ti.variant_id,
        ti.quantity,
        ti.unit_price,
        ti.total,
        coalesce(ot.option_total, 0)::numeric as option_total,
        (
            ti.unit_price - coalesce(ot.option_total, 0)
        )::numeric as implied_base_price
    from public.transaction_items ti
    join public.transactions t
        on t.id = ti.transaction_id
    left join option_totals ot
        on ot.transaction_item_id = ti.id
)
select
    o.*
from observations o
where o.quantity > 0
  and (
        o.implied_base_price > 500
        or not exists (
            select 1
            from _bb_price_history h
            where h.store_id = o.store_id
              and h.product_id = o.product_id
              and h.size_id is not distinct from o.size_id
              and h.variant_id is not distinct from o.variant_id
              and abs(h.base_price - o.implied_base_price) < 0.01
        )
    );

create index _bb_sus_idx
    on _bb_suspicious(transaction_id, transaction_item_id);

-- ---------------------------------------------------------------------------
-- 3. Build candidate base prices for each suspicious item.
-- ---------------------------------------------------------------------------
--
-- Historical candidates:
--   Up to eight historical prices nearest to the transaction date.
--
-- Catalog candidate:
--   Current Store catalog price is included only as a fallback candidate.
--
-- Historical evidence is preferred in the candidate ordering, but the final
-- decision is based on exact transaction-total reconciliation.
-- ---------------------------------------------------------------------------

create temp table _bb_candidates on commit drop as
with historical_candidates as (
    select
        s.transaction_item_id,
        h.base_price,
        'historical'::text as source,
        row_number() over (
            partition by s.transaction_item_id
            order by
                case
                    when h.last_seen <= s.transaction_date
                        then 0
                    else 1
                end,
                case
                    when h.last_seen <= s.transaction_date
                        then extract(epoch from (s.transaction_date - h.last_seen))
                    else extract(epoch from (h.first_seen - s.transaction_date))
                end,
                h.observation_count desc,
                h.base_price
        ) as rn
    from _bb_suspicious s
    join _bb_price_history h
        on h.store_id = s.store_id
       and h.product_id = s.product_id
       and h.size_id is not distinct from s.size_id
       and h.variant_id is not distinct from s.variant_id
),
current_catalog_candidates as (
    select
        s.transaction_item_id,
        coalesce(
            case
                when s.size_id is not null then z.price
            end,
            case
                when s.variant_id is not null then v.price
            end,
            cp.price
        )::numeric as base_price,
        'catalog'::text as source
    from _bb_suspicious s
    join public.catalog_products cp
        on cp.store_id = s.store_id
       and cp.product_id = s.product_id
    left join public.catalog_product_sizes z
        on z.store_id = s.store_id
       and z.product_id = s.product_id
       and z.size_id = s.size_id
    left join public.catalog_product_variants v
        on v.store_id = s.store_id
       and v.product_id = s.product_id
       and v.variant_id = s.variant_id
),
all_candidates as (
    select
        transaction_item_id,
        base_price,
        source
    from historical_candidates
    where rn <= 8

    union all

    select
        transaction_item_id,
        base_price,
        source
    from current_catalog_candidates
)
select
    transaction_item_id,
    base_price,
    min(source) as source
from all_candidates
where base_price > 0
  and base_price <= 500
group by
    transaction_item_id,
    base_price;

create index _bb_c_idx
    on _bb_candidates(transaction_item_id, base_price);

-- ---------------------------------------------------------------------------
-- 4. Preview every suspicious item and its possible repaired values.
-- ---------------------------------------------------------------------------

select
    s.transaction_id,
    s.transaction_item_id,
    s.product_id,
    s.product_name,
    s.quantity,
    s.transaction_date,
    s.unit_price as recorded_unit_price,
    s.total as recorded_total,
    s.option_total,
    s.implied_base_price,
    c.base_price as candidate_base_price,
    c.source,
    (c.base_price + s.option_total) as candidate_unit_price,
    (c.base_price + s.option_total) * s.quantity as candidate_total
from _bb_suspicious s
left join _bb_candidates c
    on c.transaction_item_id = s.transaction_item_id
order by
    s.transaction_id,
    s.transaction_item_id,
    c.base_price;

-- ---------------------------------------------------------------------------
-- 5. Find exact transaction-level solutions.
-- ---------------------------------------------------------------------------
--
-- Fixed items are items in a suspicious transaction that are NOT suspicious.
-- Suspicious items are solved by trying candidate historical/catalog prices.
-- A solution is valid only when:
--
--     fixed item totals + repaired suspicious item totals
--       = transactions.total
--
-- The recursive walk also prunes branches that already exceed the required
-- transaction total.
-- ---------------------------------------------------------------------------

create temp table _bb_solutions on commit drop as
with recursive
fixed_totals as (
    select
        t.id as transaction_id,
        t.total as transaction_total,
        coalesce(
            sum(
                case
                    when s.transaction_item_id is null then ti.total
                    else 0
                end
            ),
            0
        )::numeric as fixed_total
    from public.transactions t
    join (
        select distinct transaction_id
        from _bb_suspicious
    ) affected
        on affected.transaction_id = t.id
    join public.transaction_items ti
        on ti.transaction_id = t.id
    left join _bb_suspicious s
        on s.transaction_item_id = ti.id
    group by
        t.id,
        t.total
),
ordered_suspicious as (
    select
        s.*,
        row_number() over (
            partition by s.transaction_id
            order by s.transaction_item_id
        ) as item_no
    from _bb_suspicious s
),
item_counts as (
    select
        transaction_id,
        max(item_no) as item_count
    from ordered_suspicious
    group by transaction_id
),
walk(
    transaction_id,
    item_no,
    item_count,
    running_total,
    solution
) as (
    select
        o.transaction_id,
        o.item_no,
        c.item_count,
        (
            (p.base_price + o.option_total) * o.quantity
        )::numeric as running_total,
        jsonb_build_object(
            o.transaction_item_id::text,
            jsonb_build_object(
                'basePrice', p.base_price,
                'unitPrice', p.base_price + o.option_total,
                'total', (p.base_price + o.option_total) * o.quantity,
                'source', p.source
            )
        ) as solution
    from ordered_suspicious o
    join item_counts c
        on c.transaction_id = o.transaction_id
    join _bb_candidates p
        on p.transaction_item_id = o.transaction_item_id
    where o.item_no = 1

    union all

    select
        o.transaction_id,
        o.item_no,
        w.item_count,
        (
            w.running_total
            + (p.base_price + o.option_total) * o.quantity
        )::numeric as running_total,
        w.solution || jsonb_build_object(
            o.transaction_item_id::text,
            jsonb_build_object(
                'basePrice', p.base_price,
                'unitPrice', p.base_price + o.option_total,
                'total', (p.base_price + o.option_total) * o.quantity,
                'source', p.source
            )
        ) as solution
    from walk w
    join ordered_suspicious o
        on o.transaction_id = w.transaction_id
       and o.item_no = w.item_no + 1
    join _bb_candidates p
        on p.transaction_item_id = o.transaction_item_id
    join fixed_totals f
        on f.transaction_id = o.transaction_id
    where (
        w.running_total
        + (p.base_price + o.option_total) * o.quantity
    ) <= (
        f.transaction_total - f.fixed_total
    )
),
matched as (
    select
        w.transaction_id,
        f.transaction_total,
        f.fixed_total,
        w.running_total as repaired_suspicious_total,
        (
            w.running_total + f.fixed_total
        )::numeric as repaired_item_total,
        w.solution
    from walk w
    join item_counts c
        on c.transaction_id = w.transaction_id
       and w.item_no = c.item_count
    join fixed_totals f
        on f.transaction_id = w.transaction_id
    where (
        w.running_total + f.fixed_total
    ) = f.transaction_total
)
select
    m.*,
    count(*) over (
        partition by m.transaction_id
    ) as solution_count
from matched m;

-- ---------------------------------------------------------------------------
-- 6. Decide which transactions are safe to repair.
-- ---------------------------------------------------------------------------
--
-- IMPORTANT FIX:
-- PostgreSQL has no max(jsonb) aggregate. Therefore we use array_agg()[1]
-- only when there is exactly one solution.
-- ---------------------------------------------------------------------------

create temp table _bb_decisions on commit drop as
select
    a.transaction_id,
    max(s.transaction_total) as transaction_total,
    max(s.repaired_item_total) as repaired_item_total,
    count(s.transaction_id) as solution_count,
    case
        when count(s.transaction_id) = 1
            then 'SAFE_REPAIR'
        when count(s.transaction_id) = 0
            then 'REVIEW_REQUIRED_NO_MATCH'
        else 'REVIEW_REQUIRED_AMBIGUOUS'
    end as decision,
    case
        when count(s.transaction_id) = 1
            then (array_agg(s.solution))[1]
        else null
    end as unique_solution
from (
    select distinct transaction_id
    from _bb_suspicious
) a
left join _bb_solutions s
    on s.transaction_id = a.transaction_id
group by
    a.transaction_id;

-- ---------------------------------------------------------------------------
-- 7. Decision summary.
-- ---------------------------------------------------------------------------

select
    decision,
    count(*) as transaction_count
from _bb_decisions
group by decision
order by decision;

select
    transaction_id,
    transaction_total,
    repaired_item_total,
    solution_count,
    decision
from _bb_decisions
order by
    decision,
    transaction_id;

-- ---------------------------------------------------------------------------
-- 8. Detailed SAFE_REPAIR preview.
-- ---------------------------------------------------------------------------

select
    s.transaction_id,
    s.transaction_item_id,
    s.product_id,
    s.product_name,
    s.quantity,
    s.unit_price as recorded_unit_price,
    s.total as recorded_total,
    s.option_total,
    (d.unique_solution -> (s.transaction_item_id::text) ->> 'basePrice')::numeric
        as repaired_base_price,
    (d.unique_solution -> (s.transaction_item_id::text) ->> 'unitPrice')::numeric
        as repaired_unit_price,
    (d.unique_solution -> (s.transaction_item_id::text) ->> 'total')::numeric
        as repaired_total,
    d.transaction_total
from _bb_suspicious s
join _bb_decisions d
    on d.transaction_id = s.transaction_id
   and d.decision = 'SAFE_REPAIR'
order by
    s.transaction_id,
    s.transaction_item_id;

-- ---------------------------------------------------------------------------
-- 9. Apply SAFE_REPAIR updates inside the transaction.
-- ---------------------------------------------------------------------------
--
-- This UPDATE is intentionally executed even during preview, because the
-- final ROLLBACK below guarantees that nothing is committed. This lets the
-- reconciliation query in section 10 validate the actual resulting rows.
-- ---------------------------------------------------------------------------

update public.transaction_items ti
set
    unit_price = (
        d.unique_solution -> (ti.id::text) ->> 'unitPrice'
    )::numeric,
    total = (
        d.unique_solution -> (ti.id::text) ->> 'total'
    )::numeric
from _bb_decisions d
where d.decision = 'SAFE_REPAIR'
  and d.unique_solution ? (ti.id::text);

-- ---------------------------------------------------------------------------
-- 10. Final reconciliation preview.
-- ---------------------------------------------------------------------------

select
    t.id as transaction_id,
    t.total as transaction_total,
    coalesce(sum(ti.total), 0) as item_total,
    coalesce(sum(ti.total), 0) - t.total as difference
from public.transactions t
join _bb_decisions d
    on d.transaction_id = t.id
   and d.decision = 'SAFE_REPAIR'
left join public.transaction_items ti
    on ti.transaction_id = t.id
group by
    t.id,
    t.total
order by
    t.id;

-- ---------------------------------------------------------------------------
-- 11. DO NOT CHANGE THIS UNTIL ALL PREVIEWS HAVE BEEN REVIEWED.
-- ---------------------------------------------------------------------------

rollback;
