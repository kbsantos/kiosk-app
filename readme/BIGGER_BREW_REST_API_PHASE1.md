# Bigger Brew REST API — Phase 1

## Purpose

This phase uses Supabase's built-in PostgREST Data API. No separate API server is required.

Base URL:

```text
https://<PROJECT_REF>.supabase.co/rest/v1/
```

The API is store-scoped. Reporting clients should authenticate with a Supabase user whose JWT `app_metadata` contains:

```json
{
  "store_id": "<stores.id UUID>"
}
```

Do not put a Supabase secret/service-role key in the Flutter kiosk or any client application.

## Apply the migration

Run:

```text
supabase/migrations/20260917_rest_reporting_api_phase1.sql
```

in the `MyCoffeeShop` Supabase SQL Editor or through the Supabase CLI migration workflow.

## REST endpoints

### Existing reporting tables

```text
GET /rest/v1/transactions
GET /rest/v1/transaction_items
GET /rest/v1/transaction_item_options
GET /rest/v1/daily_sales_summary
GET /rest/v1/hourly_sales_summary
GET /rest/v1/product_sales_summary
GET /rest/v1/order_sales_summary
GET /rest/v1/payment_summary
GET /rest/v1/payments
GET /rest/v1/device_sales_summary
```

These endpoints are read-only for the API role and are restricted by RLS to the authenticated user's `app_metadata.store_id`.

### Reporting views

```text
GET /rest/v1/report_product_sales
GET /rest/v1/report_category_sales
GET /rest/v1/report_daily_sales
GET /rest/v1/report_device_sales
```

The views are `security_invoker`, so their queries run with the caller's RLS permissions.

## Example requests

### Product sales for one day

```text
GET /rest/v1/report_product_sales?store_id=eq.<STORE_ID>&sales_date=eq.2026-09-17&select=*
```

### Category sales

```text
GET /rest/v1/report_category_sales?store_id=eq.<STORE_ID>&sales_date=eq.2026-09-17&order=category.asc
```

### Device-specific product sales

```text
GET /rest/v1/report_product_sales?store_id=eq.<STORE_ID>&device_id=eq.<DEVICE_UUID>&sales_date=eq.2026-09-17
```

### Daily sales

```text
GET /rest/v1/report_daily_sales?store_id=eq.<STORE_ID>&sales_date=gte.2026-09-01&sales_date=lte.2026-09-17&order=sales_date.asc
```

## Headers

For a normal authenticated client:

```http
apikey: <SUPABASE_PUBLISHABLE_KEY>
Authorization: Bearer <USER_ACCESS_TOKEN>
```

The access token must belong to the authenticated reporting user. The store restriction comes from the user's JWT `app_metadata.store_id` claim.

## Important behavior

- Store ID is the reporting boundary.
- Device ID can further narrow results to a specific kiosk.
- Cancelled transactions are excluded from the four aggregate reporting views.
- Existing kiosk transaction synchronization RPCs are unchanged.
- Inventory remains a separate system and is not included in this migration.
- Store Master Catalog tables are not exposed through these reporting endpoints.
- This phase does not add a separate API server.

## API test with curl

Replace the placeholders:

```bash
curl \
  'https://<PROJECT_REF>.supabase.co/rest/v1/report_product_sales?store_id=eq.<STORE_ID>&sales_date=eq.2026-09-17' \
  -H 'apikey: <SUPABASE_PUBLISHABLE_KEY>' \
  -H 'Authorization: Bearer <USER_ACCESS_TOKEN>'
```

A valid authenticated user with the matching store ID should receive JSON rows. A user associated with another store should receive no rows because of RLS.

## Phase 1 scope

Implemented:

1. Supabase PostgREST endpoints over existing reporting tables.
2. Store-scoped authenticated read policies.
3. Product-level reporting view.
4. Category-level reporting view.
5. Daily sales reporting view.
6. Device-level daily sales view.
7. API documentation and curl examples.

Not implemented yet:

- Reporting application UI.
- User/store administration UI.
- Automatic JWT app_metadata provisioning.
- Inventory API.
- Catalog administration API.
- Write endpoints for reporting data.
