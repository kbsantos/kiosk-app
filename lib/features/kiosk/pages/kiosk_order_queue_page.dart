import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../models/kiosk_models.dart';
import '../orders/kiosk_order.dart';
import '../orders/kiosk_order_repository.dart';
import 'kiosk_order_history_page.dart';
import 'kiosk_receipt_page.dart';

class KioskOrderQueuePage extends StatefulWidget {
  const KioskOrderQueuePage({super.key});

  @override
  State<KioskOrderQueuePage> createState() => _KioskOrderQueuePageState();
}

class _KioskOrderQueuePageState extends State<KioskOrderQueuePage> {
  final KioskOrderRepository _repository = KioskOrderRepository();
  late Future<List<KioskOrder>> _orders;
  KioskOrderStatus? _filter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _orders = _repository.getActiveOrders();
  }

  List<KioskOrder> _filtered(List<KioskOrder> orders) {
    if (_filter == null) return orders;
    return orders.where((order) => order.status == _filter).toList();
  }

  Future<void> _setStatus(
    KioskOrder order,
    KioskOrderStatus status,
  ) async {
    await _repository.updateStatus(order.id, status);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _markPaid(KioskOrder order) async {
    if (order.paymentStatus == 'paid') return;

    await _repository.updatePaymentStatus(order.id, 'paid');
    if (!mounted) return;
    setState(_reload);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.orderNumber} marked as PAID.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cancelOrder(KioskOrder order) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Cancel ${order.orderNumber}?',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes the order from the active queue. If it was already paid, refund it separately after cancellation.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('KEEP ORDER'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('CANCEL ORDER'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    await _repository.cancelOrder(
      order.id,
      reason: reason.isEmpty ? null : reason,
    );

    if (!mounted) return;
    setState(_reload);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.orderNumber} cancelled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showOrderDetails(KioskOrder order) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Order Type', value: order.orderType),
                  _InfoRow(
                    label: 'Payment',
                    value:
                        '${order.paymentMethod} • ${order.paymentStatus.toUpperCase()}',
                  ),
                  _InfoRow(
                    label: 'Time',
                    value: _formatTime(order.createdAt),
                  ),
                  const Divider(height: 28),
                  const Text(
                    'ORDER ITEMS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _OrderItemDetail(item: item),
                    ),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        KioskCurrency.format(order.total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFC69214),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    // const gold = Color(0xFFC69214);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text(
          'ORDER QUEUE',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Order History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const KioskOrderHistoryPage(),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<KioskOrder>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load orders: ${snapshot.error}'),
            );
          }

          final allOrders = snapshot.data ?? const <KioskOrder>[];
          final orders = _filtered(allOrders);

          return Column(
            children: [
              _QueueSummary(
                orders: allOrders,
                filter: _filter,
                onFilterChanged: (filter) {
                  setState(() => _filter = filter);
                },
              ),
              Expanded(
                child: orders.isEmpty
                    ? _EmptyQueue(filter: _filter)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final order = orders[index];

                          return _OrderCard(
                            order: order,
                            onDetails: () => _showOrderDetails(order),
                            onStatusChanged: (status) =>
                                _setStatus(order, status),
                            onMarkPaid: () => _markPaid(order),
                            onCancel: () => _cancelOrder(order),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  final List<KioskOrder> orders;
  final KioskOrderStatus? filter;
  final ValueChanged<KioskOrderStatus?> onFilterChanged;

  const _QueueSummary({
    required this.orders,
    required this.filter,
    required this.onFilterChanged,
  });

  int _count(KioskOrderStatus status) {
    return orders.where((order) => order.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      color: Colors.white,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'TODAY',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          _FilterChip(
            label: 'ALL ${orders.length}',
            selected: filter == null,
            onTap: () => onFilterChanged(null),
          ),
          _FilterChip(
            label: 'PENDING ${_count(KioskOrderStatus.pending)}',
            selected: filter == KioskOrderStatus.pending,
            onTap: () => onFilterChanged(KioskOrderStatus.pending),
          ),
          _FilterChip(
            label: 'PREPARING ${_count(KioskOrderStatus.preparing)}',
            selected: filter == KioskOrderStatus.preparing,
            onTap: () => onFilterChanged(KioskOrderStatus.preparing),
          ),
          _FilterChip(
            label: 'READY ${_count(KioskOrderStatus.ready)}',
            selected: filter == KioskOrderStatus.ready,
            onTap: () => onFilterChanged(KioskOrderStatus.ready),
          ),
          const SizedBox(width: 8),
          Text(
            'Active orders: ${orders.length}',
            style: const TextStyle(
              color: gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final KioskOrder order;
  final VoidCallback onDetails;
  final ValueChanged<KioskOrderStatus> onStatusChanged;
  final VoidCallback onMarkPaid;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.onDetails,
    required this.onStatusChanged,
    required this.onMarkPaid,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      color: Color(0xFFC69214),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(status: order.status),
                ],
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onDetails,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.items
                            .map(
                              (item) =>
                                  '${item.quantity}× ${item.displayLabel}',
                            )
                            .join('  •  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${order.orderType}  •  ${order.paymentMethod}  •  ${order.paymentStatus.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap order to view size, add-ons & details',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: .4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Print receipt',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => KioskReceiptPage(order: order),
                  ),
                );
              },
              icon: const Icon(Icons.print_outlined),
            ),
            const SizedBox(width: 4),
            Text(
              KioskCurrency.format(order.total),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            if (order.paymentStatus != 'paid')
              FilledButton.icon(
                onPressed: onMarkPaid,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('MARK PAID'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              )
            else
              const Chip(
                avatar: Icon(
                  Icons.check_circle,
                  size: 17,
                  color: Colors.green,
                ),
                label: Text(
                  'PAID',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            if (order.status != KioskOrderStatus.cancelled)
              IconButton(
                tooltip: 'Cancel order',
                onPressed: onCancel,
                icon: Icon(
                  Icons.cancel_outlined,
                  color: Colors.red.shade700,
                ),
              ),
            const SizedBox(width: 4),
            PopupMenuButton<KioskOrderStatus>(
              tooltip: 'Change status',
              onSelected: onStatusChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: KioskOrderStatus.pending,
                  child: Text('Pending'),
                ),
                PopupMenuItem(
                  value: KioskOrderStatus.preparing,
                  child: Text('Preparing'),
                ),
                PopupMenuItem(
                  value: KioskOrderStatus.ready,
                  child: Text('Ready'),
                ),
                PopupMenuItem(
                  value: KioskOrderStatus.completed,
                  child: Text('Completed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemDetail extends StatelessWidget {
  final KioskCartItem item;

  const _OrderItemDetail({required this.item});

  @override
  Widget build(BuildContext context) {
    final size = item.size;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE6D8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (size != null)
                  Text(
                    '${size.name}${size.displayVolume == null ? '' : ' • ${size.displayVolume}'}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (item.options.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.options.map((option) => option.name).join(' • '),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            KioskCurrency.format(item.total),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final KioskOrderStatus status;

  const _StatusChip({required this.status});

  String get _label {
    switch (status) {
      case KioskOrderStatus.pending:
        return 'PENDING';
      case KioskOrderStatus.preparing:
        return 'PREPARING';
      case KioskOrderStatus.ready:
        return 'READY';
      case KioskOrderStatus.completed:
        return 'COMPLETED';
      case KioskOrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        _label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  final KioskOrderStatus? filter;

  const _EmptyQueue({required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = filter == null ? 'ACTIVE ORDERS' : filter!.name.toUpperCase();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 70,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'NO $label',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
