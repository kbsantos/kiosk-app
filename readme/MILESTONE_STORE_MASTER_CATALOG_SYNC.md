# MyKiosk Kiosk — Milestone: Store Master Catalog & Kiosk Synchronization

## Milestone Objective

Establish the **Supabase database as the single source of truth for the store-level product catalog**, while maintaining a complete local catalog copy on each kiosk for fast operation and resilience during temporary network/database outages.

The kiosk local catalog is an **operational copy/cache**. It must synchronize from the database master and must never override the database master.

---

## 1. Source of Truth

### Database — Master

Supabase owns the authoritative store catalog:

- Categories
- Products
- Product sizes
- Product variants
- Product options
- Option definitions
- Add-ons

Catalog data is scoped to a store.

### Kiosk — Local Copy

Each kiosk maintains a local copy containing the same catalog structure:

```text
ProductCatalog
├── categories
├── products
│   ├── sizes
│   ├── variants
│   └── options
└── optionDefinitions
```

The kiosk uses this local copy for normal ordering operations.

The local copy is not an independent source of truth.

---

## 2. Catalog Hierarchy

The database catalog should follow this relationship:

```text
STORE
│
├── CATEGORIES
│
├── PRODUCTS
│   │
│   ├── SIZES
│   ├── VARIANTS
│   └── PRODUCT OPTION ASSIGNMENTS
│
├── OPTION DEFINITIONS
│
└── ADD-ON PRODUCTS
```

### Categories

A category belongs to a store and provides the grouping for products.

### Products

A product belongs to a store and references a category.

### Sizes

Sizes belong to a product and may contain their own price, volume, active state, and ordering.

### Variants

Variants belong to a product and may contain their own price, active state, and ordering.

### Options

Options are assigned to products and reference reusable option definitions.

### Add-ons

Add-ons remain catalog products when the existing kiosk model treats them as products with an add-on product type/category. They should not be incorrectly converted into product options.

---

## 3. Proposed Database Tables

### `catalog_categories`

```text
id
store_id
category_id
name
subtitle
icon
active
sort_order
created_at
updated_at
```

Unique identity:

```text
(store_id, category_id)
```

### `catalog_products`

```text
id
store_id
product_id
category_id
name
product_type
group_id
group_name
description
image
active
available
kitchen_prepared
drink_temperature
price
sku
recipe_ref
sort_order
created_at
updated_at
```

Unique identity:

```text
(store_id, product_id)
```

### `catalog_product_sizes`

```text
id
store_id
product_id
size_id
name
volume_ml
display_volume
price
active
sort_order
created_at
updated_at
```

Unique identity:

```text
(store_id, product_id, size_id)
```

### `catalog_product_variants`

```text
id
store_id
product_id
variant_id
name
price
active
sort_order
created_at
updated_at
```

Unique identity:

```text
(store_id, product_id, variant_id)
```

### `catalog_option_definitions`

```text
id
store_id
option_id
name
price
active
kitchen_prepared
product_types
created_at
updated_at
```

### `catalog_product_options`

```text
id
store_id
product_id
option_id
price_override
active
kitchen_prepared
sort_order
created_at
updated_at
```

Relationship:

```text
catalog_products
       │
       └── catalog_product_options
                    │
                    ▼
          catalog_option_definitions
```

---

## 4. Catalog Synchronization Direction

The authoritative direction is:

```text
SUPABASE STORE CATALOG
        │
        │ Pull / Sync
        ▼
KIOSK LOCAL CATALOG
        │
        ▼
KIOSK APP / ORDERING UI
```

There should be **no normal kiosk-to-database catalog publishing process**.

Product/category administration changes should be written to the database master.

After a successful database update, the kiosk refreshes its local copy.

---

## 5. Kiosk Startup Synchronization

At kiosk startup:

```text
Kiosk starts
    ↓
Load Store ID + Kiosk Code
    ↓
Resolve kiosk device
    ↓
Check catalog version
    ↓
Catalog changed?
   ┌──────┴──────┐
  No            Yes
   │              │
Use local      Download master
catalog            │
                   ↓
              Validate catalog
                   │
                   ↓
              Update local copy
                   │
                   └──────┐
                          ↓
                    Start / refresh UI
```

The kiosk should use the local catalog after successful synchronization.

---

## 6. Manual Catalog Refresh

Administration Sync should provide:

### `REFRESH PRODUCT CATALOG`

Purpose:

> Download the latest store catalog from the database master and update the kiosk's local catalog.

This is a **database-to-kiosk** operation.

It is not a local catalog upload.

---

## 7. Periodic Synchronization

The kiosk should also be capable of periodically checking whether the catalog has changed while connected.

Recommended behavior:

```text
Every configured interval
        ↓
Check catalog version
        ↓
Changed?
   ┌────┴────┐
  No        Yes
   │          │
Nothing    Download
            latest
             │
             ▼
        Update cache
```

The exact interval can be finalized during implementation.

---

## 8. Catalog Versioning

The store catalog should have a version or revision.

Example:

```text
Store catalog version: 42
```

Kiosk stores:

```text
Local catalog version: 41
```

The kiosk detects:

```text
41 != 42
```

and downloads the latest catalog.

After successful synchronization:

```text
Local catalog version = 42
```

This avoids downloading the complete catalog unnecessarily when nothing has changed.

---

## 9. Safe Synchronization

Catalog replacement must be atomic and validated.

Recommended process:

```text
Download master catalog
        ↓
Validate structure
        ↓
Validate categories
        ↓
Validate product references
        ↓
Validate sizes
        ↓
Validate variants
        ↓
Validate options
        ↓
Write temporary local copy
        ↓
Validate saved copy
        ↓
Atomically replace active catalog
```

If synchronization fails:

```text
Sync failed
    ↓
Keep previous valid local catalog
```

A failed synchronization must never leave the kiosk with a partial catalog.

---

## 10. Offline / Database Unavailable Behavior

The kiosk should continue using its last known valid local catalog when the database is temporarily unavailable.

```text
Database unavailable
        ↓
Valid local catalog exists?
        │
       Yes
        ↓
Use local catalog
        ↓
Continue normal kiosk operation
```

When connectivity returns:

```text
Database available
        ↓
Check catalog version
        ↓
Download if changed
```

The local catalog therefore provides operational resilience without becoming the master.

---

## 11. Product Manager

Product Manager must follow the master-catalog architecture.

### Current conceptual flow

```text
Product Manager
      ↓
Local catalog
```

### Target flow

```text
Product Manager
      ↓
Validate change
      ↓
Write change to Supabase master
      ↓
Database confirms success
      ↓
Update / refresh local kiosk catalog
      ↓
UI reflects master
```

This applies to:

- Categories
- Products
- Sizes
- Variants
- Options
- Option assignments
- Add-on products

Changes made by another administration client will be detected by kiosk synchronization.

---

## 12. Catalog Read / Write Rules

### Reads

Normal kiosk ordering reads from:

```text
Kiosk local catalog
```

Catalog synchronization reads from:

```text
Supabase master catalog
```

### Writes

Catalog administration writes to:

```text
Supabase master catalog
```

The kiosk local copy is updated only after a successful master update or synchronization.

---

## 13. Reporting Integration

Reporting must use the database catalog relationship rather than relying blindly on the category stored in historical transaction rows.

Current transaction snapshot:

```text
transaction_items
├── product_id
├── product_name
├── category
├── size_id
├── size_name
├── variant_id
├── variant_name
└── ...
```

Master catalog relationship:

```text
transaction_items.product_id
        ↓
catalog_products.product_id
        ↓
catalog_products.category_id
        ↓
catalog_categories
```

This allows reporting to correctly associate products with their store catalog category.

For example:

```text
AMERICANO
    ↓
catalog_products
    ↓
category_id = coffee
    ↓
Coffee
```

rather than trusting an incorrect historical `transaction_items.category` value.

---

## 14. Historical Transaction Integrity

The master catalog represents the **current catalog**.

Transactions represent **what was actually sold at the time**.

Transaction records should retain their historical snapshot fields so that future catalog changes do not rewrite historical sales information.

Conceptually:

```text
CURRENT CATALOG
"What is this product classified as now?"

TRANSACTION SNAPSHOT
"What was sold at that time?"
```

This distinction must be preserved.

---

## 15. Kiosk Identity

Catalog synchronization must use the established kiosk identity model:

```text
Store ID
    ↓
stores.id

Kiosk Code
    ↓
devices.device_code

        ↓

devices.id
```

The kiosk must not directly bypass the established secure device-resolution mechanism.

Catalog data is store-scoped, while kiosk identity is used to authorize/identify the requesting kiosk.

---

## 16. Administration Sync

The Administration Sync section should contain:

```text
ADMINISTRATION SYNC

[ REFRESH PRODUCT CATALOG ]

[ SYNC HISTORICAL DRINKS ]

[ SYNC ALL TRANSACTIONS ]

[ RESTORE MISSING TRANSACTIONS ]
```

Responsibilities:

| Function                     | Direction  | Purpose                                |
| ---------------------------- | ---------- | -------------------------------------- |
| Refresh Product Catalog      | DB → Kiosk | Update local catalog from master       |
| Sync Historical Drinks       | Kiosk → DB | Historical transaction synchronization |
| Sync All Transactions        | Kiosk → DB | Transaction synchronization            |
| Restore Missing Transactions | DB → Kiosk | Restore missing local transactions     |

Catalog refresh remains separate from transaction synchronization.

---

## 17. EOD Relationship

EOD should continue to automatically synchronize transactions before generating the EOD report.

Catalog synchronization should **not** be part of the EOD transaction sync.

```text
EOD
 ↓
Sync transactions
 ↓
Generate report
```

Catalog management remains an Administration function.

---

## 18. Acceptance Criteria

This milestone is complete when all of the following are true:

### Database

- [ ] Store-level catalog tables exist.
- [ ] Categories are store-scoped.
- [ ] Products are store-scoped.
- [ ] Products reference categories.
- [ ] Sizes are stored and linked to products.
- [ ] Variants are stored and linked to products.
- [ ] Option definitions are stored.
- [ ] Product option assignments are stored.
- [ ] Add-on products are represented correctly.
- [ ] Catalog versioning exists.

### Kiosk

- [ ] Kiosk maintains a complete local catalog.
- [ ] Local catalog contains categories.
- [ ] Local catalog contains products.
- [ ] Local catalog contains sizes.
- [ ] Local catalog contains variants.
- [ ] Local catalog contains options.
- [ ] Local catalog contains add-ons.
- [ ] Local catalog is treated as a cache/copy.
- [ ] Kiosk can operate from the last valid local catalog when offline.

### Synchronization

- [ ] Kiosk can check the master catalog version.
- [ ] Kiosk detects catalog changes.
- [ ] Kiosk downloads the latest catalog.
- [ ] Catalog synchronization is validated.
- [ ] Catalog replacement is atomic/safe.
- [ ] Failed sync preserves the previous valid catalog.
- [ ] Manual `REFRESH PRODUCT CATALOG` works.
- [ ] Periodic synchronization can be implemented.
- [ ] Product Manager writes changes to the database master.

### Reporting

- [ ] Reporting can resolve product → category through the master catalog.
- [ ] Americano is reported under its actual master category.
- [ ] Spanish Latte is reported under its actual master category.
- [ ] Size information remains available.
- [ ] Variant information remains available.
- [ ] Options/add-ons remain available for reporting.
- [ ] Historical transaction snapshots remain intact.

### Regression

- [ ] Existing ordering flow continues to work.
- [ ] Existing transaction synchronization continues to work.
- [ ] Existing EOD flow continues to work.
- [ ] Existing restore functionality continues to work.
- [ ] Existing Bluetooth printer functionality is not changed.
- [ ] Existing Product Manager functionality remains available.
- [ ] Flutter analyzer has no new issues.
- [ ] Existing automated tests continue to pass.

---

## 19. Milestone Definition

### Milestone Name

**Store Master Catalog & Kiosk Catalog Synchronization**

### Objective

Make Supabase the authoritative store-level catalog while maintaining a synchronized local catalog on each kiosk containing:

- Categories
- Products
- Sizes
- Variants
- Options
- Add-ons

### Core Principle

> **Database is the master. Kiosk is the synchronized local operational copy.**

### Data Direction

```text
CATALOG ADMINISTRATION
        │
        ▼
SUPABASE MASTER
        │
        │ Synchronization
        ▼
KIOSK LOCAL COPY
        │
        ▼
KIOSK ORDERING
```

This milestone should be completed before expanding the Reporting page to depend on the master catalog for category, product, size, variant, option, and add-on reporting.

---

## Implementation Status — Phase 1 Started

### Completed in this checkpoint

- Added the store master catalog database migration.
- Added store-scoped tables for categories, products, sizes, variants, option definitions, and product option assignments.
- Added catalog version tracking.
- Added secure database RPCs for catalog version and catalog retrieval.
- Added one-time master initialization from the current kiosk catalog. The database rejects bootstrap after a master already exists.
- Added `StoreCatalogSyncService` to pull the database master into the kiosk local catalog.
- Added local master-version tracking.
- Added validation before replacing the local catalog.
- Added rollback recovery backup before local catalog replacement.
- Added `REFRESH PRODUCT CATALOG` to Administration Sync.
- Added a one-time `INITIALIZE MASTER CATALOG` action when no store master exists.

### Intentionally not changed yet

- Product Manager still uses the existing local repository until the database master catalog is populated and the database write workflow is implemented.
- Automatic background catalog synchronization is not enabled yet. This prevents an existing local Product Manager edit from being overwritten before Product Manager is migrated to database-master writes.
- Existing transaction sync, EOD, restore, and Bluetooth printer flows are unchanged.

### Next implementation step

Migrate Product Manager and the category/size/variant/option management workflows so catalog administration writes to the Supabase master, then enable automatic version-based kiosk refresh.
