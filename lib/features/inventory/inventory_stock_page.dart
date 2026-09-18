import 'package:flutter/material.dart';

import 'inventory_movement_models.dart';
import 'inventory_movement_repository.dart';
import 'inventory_movement_service.dart';
import 'inventory_stock_models.dart';
import 'inventory_stock_repository.dart';
import 'inventory_stock_service.dart';

class InventoryStockPage extends StatefulWidget {
  const InventoryStockPage({super.key, this.repository, this.movementRepository});

  final InventoryStockRepository? repository;
  final InventoryMovementRepository? movementRepository;

  @override
  State<InventoryStockPage> createState() => _InventoryStockPageState();
}

class _InventoryStockPageState extends State<InventoryStockPage> {
  late final InventoryStockRepository _repository =
      widget.repository ?? const InventoryStockRepository();
  late final InventoryMovementRepository _movementRepository =
      widget.movementRepository ?? const InventoryMovementRepository();
  List<InventoryStockItem> _items = const [];
  List<InventoryMovement> _movements = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.loadItems(),
        _movementRepository.loadMovements(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<InventoryStockItem>;
        _movements = results[1] as List<InventoryMovement>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItem() async {
    final id = TextEditingController();
    final name = TextEditingController();
    final unit = TextEditingController();
    final opening = TextEditingController(text: '0');
    final reorder = TextEditingController(text: '0');
    try {
      final result = await showDialog<InventoryStockItem>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ADD INVENTORY ITEM'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(id, 'Inventory Item ID'),
                const SizedBox(height: 10),
                _field(name, 'Name'),
                const SizedBox(height: 10),
                _field(unit, 'Unit'),
                const SizedBox(height: 10),
                _field(opening, 'Opening Quantity', number: true),
                const SizedBox(height: 10),
                _field(reorder, 'Reorder Level', number: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final openingValue = num.tryParse(opening.text.trim());
                final reorderValue = num.tryParse(reorder.text.trim());
                if (id.text.trim().isEmpty ||
                    unit.text.trim().isEmpty ||
                    openingValue == null ||
                    reorderValue == null ||
                    openingValue < 0 ||
                    reorderValue < 0) {
                  return;
                }
                Navigator.of(dialogContext).pop(InventoryStockItem(
                  inventoryItemId: id.text.trim(),
                  name: name.text.trim(),
                  unit: unit.text.trim(),
                  openingQuantity: openingValue,
                  reorderLevel: reorderValue,
                ));
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      );
      if (result == null) return;
      final items = [..._items];
      final existingIndex =
          items.indexWhere((x) => x.inventoryItemId == result.inventoryItemId);
      if (existingIndex >= 0) {
        throw StateError('Inventory item ID already exists.');
      }
      items.add(result);
      await _repository.saveItems(items);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory item saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inventory item save failed: $error')),
      );
    } finally {
      id.dispose();
      name.dispose();
      unit.dispose();
      opening.dispose();
      reorder.dispose();
    }
  }

  Future<void> _recordMovement(InventoryStockItem item, InventoryMovementType type) async {
    final quantity = TextEditingController();
    final reason = TextEditingController();
    final reference = TextEditingController();
    try {
      final result = await showDialog<num>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(type == InventoryMovementType.stockIn
              ? 'RECORD STOCK-IN'
              : 'RECORD STOCK ADJUSTMENT'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${item.name.isEmpty ? item.inventoryItemId : item.name} • ${item.unit}'),
                const SizedBox(height: 12),
                _field(
                  quantity,
                  type == InventoryMovementType.stockIn
                      ? 'Quantity Received'
                      : 'Adjustment Quantity (+/-)',
                  number: true,
                ),
                const SizedBox(height: 10),
                _field(reason, 'Reason'),
                const SizedBox(height: 10),
                _field(reference, 'Reference (optional)'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final value = num.tryParse(quantity.text.trim());
                if (value == null || value == 0 || reason.text.trim().isEmpty) return;
                if (type == InventoryMovementType.stockIn && value < 0) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('RECORD'),
            ),
          ],
        ),
      );
      if (result == null) return;
      final movement = InventoryStockOperations.buildManualMovement(
        inventoryItemId: item.inventoryItemId,
        unit: item.unit,
        quantity: result,
        type: type,
        reason: reason.text,
        reference: reference.text,
        occurredAt: DateTime.now(),
      );
      final added = await _movementRepository.appendIfAbsent(movement);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added ? 'Inventory movement recorded.' : 'Duplicate movement ignored.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inventory movement failed: $error')),
      );
    } finally {
      quantity.dispose();
      reason.dispose();
      reference.dispose();
    }
  }

  Future<void> _showHistory(InventoryStockItem item) async {
    final movements = _movements
        .where((movement) =>
            movement.inventoryItemId == item.inventoryItemId && movement.unit == item.unit)
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${item.name.isEmpty ? item.inventoryItemId : item.name} MOVEMENTS'),
        content: SizedBox(
          width: 620,
          height: 420,
          child: movements.isEmpty
              ? const Center(child: Text('No local manual movements recorded.'))
              : ListView.separated(
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final movement = movements[index];
                    final sign = movement.signedQuantity >= 0 ? '+' : '';
                    return ListTile(
                      dense: true,
                      title: Text('${movement.type.name.toUpperCase()}  $sign${movement.signedQuantity} ${movement.unit}'),
                      subtitle: Text('${movement.occurredAt} • ${movement.note ?? ''}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  static Widget _field(TextEditingController controller, String label,
      {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projections = InventoryStockService.fromLedger(
      items: _items,
      movements: _movements,
    );
    final lowCount = projections.where((x) => x.isLowStock).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('INVENTORY STOCK'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            tooltip: 'Add inventory item',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text('${_items.length} INVENTORY ITEMS'),
                          subtitle: Text('$lowCount at or below reorder level'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: projections.isEmpty
                          ? const Center(
                              child: Text('No local inventory items configured.'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: projections.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final projection = projections[index];
                                final item = projection.item;
                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      projection.isNegative
                                          ? Icons.error_outline
                                          : projection.isLowStock
                                              ? Icons.warning_amber_outlined
                                              : Icons.inventory_2_outlined,
                                    ),
                                    title: Text(item.name.isEmpty
                                        ? item.inventoryItemId
                                        : item.name),
                                    subtitle: Text(
                                      '${item.inventoryItemId} • Current ${projection.currentQuantity} ${item.unit} • Reorder ${item.reorderLevel} ${item.unit}',
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'stockIn':
                                            _recordMovement(item, InventoryMovementType.stockIn);
                                            break;
                                          case 'adjustment':
                                            _recordMovement(item, InventoryMovementType.adjustment);
                                            break;
                                          case 'history':
                                            _showHistory(item);
                                            break;
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'stockIn',
                                          child: Text('RECORD STOCK-IN'),
                                        ),
                                        PopupMenuItem(
                                          value: 'adjustment',
                                          child: Text('RECORD ADJUSTMENT'),
                                        ),
                                        PopupMenuItem(
                                          value: 'history',
                                          child: Text('VIEW MOVEMENT HISTORY'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
