import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:flutter/material.dart';

import '../currency/kiosk_currency.dart';
import '../orders/kiosk_order.dart';
import '../orders/kiosk_order_repository.dart';
import '../data/kiosk_catalog_data.dart';
import 'kiosk_category_page.dart' show addKioskProductToCart;
import 'kiosk_receipt_page.dart';
import '../settings/kiosk_settings_repository.dart';
import 'kiosk_receipt_printer.dart';

class KioskTransactionViewPage extends StatefulWidget {
  const KioskTransactionViewPage({super.key});

  @override
  State<KioskTransactionViewPage> createState() =>
      _KioskTransactionViewPageState();
}

class _KioskTransactionViewPageState extends State<KioskTransactionViewPage> {
  final KioskOrderRepository _repository = KioskOrderRepository();
  final KioskSettingsRepository _settingsRepository = KioskSettingsRepository();
  late Future<List<KioskOrder>> _transactions;
  bool _printBaristaCopyEnabled = true;
  bool _printKitchenCopyEnabled = true;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadPrintSettings();
  }

  Future<void> _loadPrintSettings() async {
    final settings = await _settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _printBaristaCopyEnabled = settings.printBaristaCopy;
      _printKitchenCopyEnabled = settings.printKitchenCopy;
    });
  }

  void _reload() {
    _transactions = _repository.getOrdersForDate(DateTime.now());
  }

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool _hasBaristaItems(KioskOrder order) {
    return order.items.any(
      (item) => item.product.productType.trim().toLowerCase() == 'drink',
    );
  }

  bool _hasKitchenItems(KioskOrder order) {
    return order.items.any(
      (item) =>
          item.product.kitchenPrepared ||
          item.options.any((option) => option.kitchenPrepared),
    );
  }

  Future<void> _printCopy(
    KioskOrder order, {
    required bool barista,
  }) async {
    final label = barista ? 'Barista' : 'Kitchen';
    try {
      final printed = await KioskReceiptPrinter.printOrder(
        order,
        includeCustomerReceipt: false,
        includeBaristaCopy: barista,
        includeKitchenCopy: !barista,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed
                ? '$label copy sent to printer.'
                : 'Unable to print $label copy.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print $label copy: $error')),
      );
    }
  }

  Future<void> _modify(KioskOrder order) async {
    if (order.status == KioskOrderStatus.cancelled ||
        order.paymentStatus == 'refunded') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Cancelled or refunded transactions cannot be modified.')),
      );
      return;
    }

    // Edit the transaction first. The reason/confirmation is intentionally
    // collected only after the item changes are complete so staff can review
    // the final transaction before confirming the audit record.
    final edited = await showDialog<_TransactionEditResult>(
      context: context,
      builder: (_) => _TransactionEditor(order: order),
    );
    if (edited == null || !mounted) return;

    final newTotal = edited.items.fold<int>(0, (sum, item) => sum + item.total);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm transaction update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save the updated ${order.orderNumber}?'),
            const SizedBox(height: 10),
            Text(
              '${edited.orderType} • ${edited.paymentMethod}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'New total: ${KioskCurrency.format(newTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'Why is this transaction being modified?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('CONFIRM & SAVE'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await _repository.modifyTransaction(order.id,
          items: edited.items, reason: reason,
          orderType: edited.orderType, paymentMethod: edited.paymentMethod);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${order.orderNumber} modified successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to modify transaction: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('TODAY\'S TRANSACTIONS',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<KioskOrder>>(
        future: _transactions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load transactions: ${snapshot.error}'));
          }
          final orders = snapshot.data ?? const <KioskOrder>[];
          if (orders.isEmpty) {
            return const Center(child: Text('No transactions today.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final order = orders[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(order.orderNumber,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      SizedBox(width: 90, child: Text(_time(order.createdAt))),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} item(s)'),
                            const SizedBox(height: 2),
                            Text(
                                KioskCurrency.format(order.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                            ),
                            Text(
                                '${order.paymentMethod} • ${order.status.name.toUpperCase()}',
                                style: const TextStyle(color: Colors.black54)),
                            if (order.modificationReason != null)
                              Text('Modified: ${order.modificationReason}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.deepOrange)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => KioskReceiptPage(order: order),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('VIEW RECEIPT'),
                      ),
                      if (_printBaristaCopyEnabled && _hasBaristaItems(order)) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _printCopy(order, barista: true),
                          icon: const Icon(Icons.local_cafe_outlined),
                          label: const Text('BARISTA'),
                        ),
                      ],
                      if (_printKitchenCopyEnabled && _hasKitchenItems(order)) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _printCopy(order, barista: false),
                          icon: const Icon(Icons.restaurant_outlined),
                          label: const Text('KITCHEN'),
                        ),
                      ],
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => _modify(order),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('MODIFY'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TransactionEditResult {
  final List<KioskCartItem> items;
  final String orderType;
  final String paymentMethod;

  const _TransactionEditResult({
    required this.items,
    required this.orderType,
    required this.paymentMethod,
  });
}

class _TransactionEditor extends StatefulWidget {
  final KioskOrder order;
  const _TransactionEditor({required this.order});

  @override
  State<_TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<_TransactionEditor> {
  late List<KioskCartItem> _items;
  late String _orderType;
  late String _paymentMethod;
  bool _addingProduct = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.order.items);
    _orderType = widget.order.orderType == 'Dine In' ? 'Dine In' : 'Take Out';
    _paymentMethod = const {'GCash', 'Cash', 'Others'}.contains(widget.order.paymentMethod)
        ? widget.order.paymentMethod
        : 'Others';
  }

  void _changeQuantity(int index, int delta) {
    final item = _items[index];
    final quantity = item.quantity + delta;
    setState(() {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = item.copyWith(quantity: quantity);
      }
    });
  }

  Future<void> _addProduct() async {
    if (_addingProduct) return;
    setState(() => _addingProduct = true);
    try {
      final catalog = await KioskCatalogData.load();
      if (!mounted) return;

      final products =
          catalog.values.expand((items) => items).toList(growable: false);
      final selected = await showDialog<KioskProduct>(
        context: context,
        builder: (dialogContext) =>
            _TransactionProductPicker(products: products),
      );
      if (selected == null || !mounted) return;

      final tempCart = KioskCart();
      await addKioskProductToCart(context, selected, tempCart);
      if (!mounted) return;
      if (tempCart.items.isEmpty) return;

      setState(() {
        _items = [..._items, ...tempCart.items];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add product: $error')),
      );
    } finally {
      if (mounted) setState(() => _addingProduct = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (sum, item) => sum + item.total);
    return AlertDialog(
      title: Text('Modify ${widget.order.orderNumber}'),
      content: SizedBox(
        width: 760,
        height: 540,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Adjust quantities, remove items, or add products. Existing variants and options are preserved.',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _addingProduct ? null : _addProduct,
                  icon: _addingProduct
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart),
                  label: const Text('ADD PRODUCT'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORDER TYPE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(height: 5),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Take Out', label: Text('TAKE OUT'), icon: Icon(Icons.takeout_dining)),
                          ButtonSegment(value: 'Dine In', label: Text('DINE IN'), icon: Icon(Icons.restaurant)),
                        ],
                        selected: {_orderType},
                        onSelectionChanged: (value) => setState(() => _orderType = value.first),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PAYMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(height: 5),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'GCash', label: Text('GCASH'), icon: Icon(Icons.qr_code_2_outlined)),
                          ButtonSegment(value: 'Cash', label: Text('CASH'), icon: Icon(Icons.payments_outlined)),
                          ButtonSegment(value: 'Others', label: Text('OTHERS'), icon: Icon(Icons.more_horiz)),
                        ],
                        selected: {_paymentMethod},
                        onSelectionChanged: (value) => setState(() => _paymentMethod = value.first),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text('No items. Add a product to continue.'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(item.displayLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(KioskCurrency.format(item.unitPrice)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _changeQuantity(index, -1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${item.quantity}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              IconButton(
                                onPressed: () => _changeQuantity(index, 1),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                const Expanded(
                    child: Text('NEW TOTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18))),
                Text(KioskCurrency.format(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(
          onPressed: _items.isEmpty
              ? null
              : () => Navigator.pop(
                  context, _TransactionEditResult(
                    items: List<KioskCartItem>.unmodifiable(_items),
                    orderType: _orderType,
                    paymentMethod: _paymentMethod,
                  )),
          child: const Text('REVIEW & SAVE'),
        ),
      ],
    );
  }
}

class _TransactionProductPicker extends StatefulWidget {
  final List<KioskProduct> products;
  const _TransactionProductPicker({required this.products});

  @override
  State<_TransactionProductPicker> createState() =>
      _TransactionProductPickerState();
}

class _TransactionProductPickerState extends State<_TransactionProductPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((product) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty || product.name.toLowerCase().contains(query);
    }).toList(growable: false);

    return AlertDialog(
      title: const Text('ADD PRODUCT'),
      content: SizedBox(
        width: 650,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                labelText: 'Search product',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final product = filtered[index];
                        return ListTile(
                          title: Text(product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(product.category.title),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
      ],
    );
  }
}
