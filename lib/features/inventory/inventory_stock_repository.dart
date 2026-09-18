import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'inventory_stock_models.dart';

class InventoryStockRepository {
  static const _itemsKey = 'bigger_brew_inventory_stock_items_v1';

  const InventoryStockRepository();

  Future<List<InventoryStockItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => InventoryStockItem.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .where((item) => item.inventoryItemId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveItems(List<InventoryStockItem> items) async {
    final normalized = <String, InventoryStockItem>{};
    for (final item in items) {
      final id = item.inventoryItemId.trim();
      if (id.isEmpty) continue;
      if (item.unit.trim().isEmpty) {
        throw ArgumentError('Inventory item unit is required.');
      }
      if (item.openingQuantity < 0 || item.reorderLevel < 0) {
        throw ArgumentError('Stock quantities cannot be negative.');
      }
      normalized[id] = item;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _itemsKey,
      jsonEncode(normalized.values.map((x) => x.toJson()).toList()),
    );
  }
}
