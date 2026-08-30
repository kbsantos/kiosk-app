# Bigger Brew Kiosk — K4.11.5 EOD Excel Summary

## Completed

- Extended the existing End-of-Day Excel export.
- Added `Drink Summary` worksheet.
- Drink Summary groups completed drink sales by product and commercial size.
- Includes `12oz`, `22oz`, and `1 Liter` columns when those sizes are present.
- Includes `Total Cups` per drink and a `TOTAL CUPS` row.
- Added `Meal Summary` worksheet.
- Meal Summary counts completed Rice Meal quantities.
- Includes `TOTAL MEALS`.
- Added a meal add-on count section for completed Rice Meal options.
- Includes `TOTAL MEAL ADD-ONS`.
- Summary sheets use only completed orders, matching the existing EOD sales logic.
- Existing `End of Day Summary`, `Orders`, and `Items` worksheets remain unchanged.

## Export workbook

1. End of Day Summary
2. Orders
3. Items
4. Drink Summary
5. Meal Summary

## Notes

The order-history screen already passes orders for the selected date to the exporter, so the new summaries are daily summaries for the selected date.

Drink size is taken from the stored order item's catalog size. The exporter does not infer a size from price or product name.
