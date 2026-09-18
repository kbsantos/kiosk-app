import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'inventory_movement_models.dart';

class InventoryMovementRepository {
  static const _movementsKey = 'bigger_brew_inventory_movements_v1';

  const InventoryMovementRepository();

  Future<List<InventoryMovement>> loadMovements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_movementsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final movements = <InventoryMovement>[];
    for (final entry in decoded.whereType<Map>()) {
      try {
        final movement = InventoryMovement.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (movement.id.trim().isNotEmpty &&
            movement.inventoryItemId.trim().isNotEmpty &&
            movement.unit.trim().isNotEmpty) {
          movements.add(movement);
        }
      } on FormatException {
        // Ignore malformed legacy entries rather than breaking stock operations.
      }
    }
    return List.unmodifiable(movements);
  }

  Future<bool> appendIfAbsent(InventoryMovement movement) async {
    if (movement.id.trim().isEmpty) {
      throw ArgumentError('Movement ID is required.');
    }
    if (movement.inventoryItemId.trim().isEmpty || movement.unit.trim().isEmpty) {
      throw ArgumentError('Inventory item and unit are required.');
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadMovements();
    if (existing.any((item) => item.id == movement.id)) return false;
    final updated = [...existing, movement];
    await prefs.setString(
      _movementsKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    return true;
  }
}
