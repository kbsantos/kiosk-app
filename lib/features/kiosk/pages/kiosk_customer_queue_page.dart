import 'dart:async';
import '../currency/kiosk_currency.dart';

import 'package:flutter/material.dart';

import '../orders/kiosk_order.dart';
import '../orders/kiosk_order_repository.dart';

class KioskCustomerQueuePage extends StatefulWidget {
  final String orderId;
  final String orderNumber;

  const KioskCustomerQueuePage({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  State<KioskCustomerQueuePage> createState() =>
      _KioskCustomerQueuePageState();
}

class _KioskCustomerQueuePageState extends State<KioskCustomerQueuePage> {
  final KioskOrderRepository _repository = KioskOrderRepository();
  Timer? _timer;
  KioskOrder? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final orders = await _repository.getOrders();

    if (!mounted) return;

    KioskOrder? found;
    for (final order in orders) {
      if (order.id == widget.orderId) {
        found = order;
        break;
      }
    }

    setState(() {
      _order = found;
      _loading = false;
    });
  }

  String _statusTitle(KioskOrderStatus status) {
    switch (status) {
      case KioskOrderStatus.pending:
        return 'ORDER RECEIVED';
      case KioskOrderStatus.preparing:
        return 'BEING PREPARED';
      case KioskOrderStatus.ready:
        return 'ORDER READY';
      case KioskOrderStatus.completed:
        return 'ORDER COMPLETED';
      case KioskOrderStatus.cancelled:
        return 'ORDER CANCELLED';
    }
  }

  String _statusMessage(KioskOrderStatus status) {
    switch (status) {
      case KioskOrderStatus.pending:
        return 'Please wait while we prepare your order.';
      case KioskOrderStatus.preparing:
        return 'Our team is preparing your order now.';
      case KioskOrderStatus.ready:
        return 'Please proceed to the counter and claim your order.';
      case KioskOrderStatus.completed:
        return 'Thank you for ordering with Bigger Brew!';
      case KioskOrderStatus.cancelled:
        return 'Please see the counter for assistance.';
    }
  }

  IconData _statusIcon(KioskOrderStatus status) {
    switch (status) {
      case KioskOrderStatus.pending:
        return Icons.receipt_long_rounded;
      case KioskOrderStatus.preparing:
        return Icons.local_cafe_rounded;
      case KioskOrderStatus.ready:
        return Icons.notifications_active_rounded;
      case KioskOrderStatus.completed:
        return Icons.check_circle_rounded;
      case KioskOrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    const dark = Color(0xFF171717);
    final order = _order;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : order == null
                      ? _missingOrder(context)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'BIGGER BREW',
                              style: TextStyle(
                                color: dark,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ORDER STATUS',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 34),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 32,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: const Color(0xFFE4DED5),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 25,
                                    offset: Offset(0, 12),
                                    color: Color(0x16000000),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _statusIcon(order.status),
                                    size: 76,
                                    color: gold,
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    _statusTitle(order.status),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: dark,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'YOUR QUEUE NUMBER',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.orderNumber,
                                    style: const TextStyle(
                                      color: gold,
                                      fontSize: 64,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _statusMessage(order.status),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F6F2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          order.items
                                              .map(
                                                (item) =>
                                                    '${item.quantity}× ${item.displayLabel}',
                                              )
                                              .join('  •  '),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${order.orderType}  •  ${KioskCurrency.format(order.total)}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).popUntil(
                                  (route) => route.isFirst,
                                );
                              },
                              child: const Text('BACK TO MENU'),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _missingOrder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 70,
          color: Colors.black26,
        ),
        const SizedBox(height: 16),
        const Text(
          'ORDER NOT FOUND',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text('BACK TO MENU'),
        ),
      ],
    );
  }
}
