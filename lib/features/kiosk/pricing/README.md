# Kiosk Pricing

The kiosk uses the **Product Catalog as the single commercial price source**.
Customer-facing widgets must not contain a second selling-price table.

## Price authority

- Products without sizes/variants use `CatalogProduct.price`.
- Sized products use the selected `ProductSize.price`.
- Variant products use the selected `ProductVariant.price`.
- Product-specific options use their catalog option price when assigned.
- Shared option definitions provide the fallback for the matching product type.
- An option without an explicit price is not exposed to the customer kiosk.
- Missing product/size/variant prices remain unpriced; the kiosk does not invent a value.

`KioskPricing` is a resolver/validation boundary over these catalog-projected values.
It intentionally contains no hard-coded commercial price map.

## Current approved menu rules

For the configured drink menu:

- Regular = the approved menu price.
- Go Big = Regular + ₱10.
- Go Bigger = Regular + ₱40.
- Hot Coffee uses its configured single size.
- Slushies remain unpriced when no approved price is present.

These values are stored in the Product Catalog rather than in kiosk UI code.

### Kitchen Preparation

Kitchen routing is independent of pricing. Products and add-ons can be tagged
for inclusion in the printed KITCHEN COPY without changing their price.
