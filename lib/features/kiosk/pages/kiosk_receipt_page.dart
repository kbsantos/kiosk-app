import 'package:flutter/material.dart';
import '../orders/kiosk_order.dart';
import 'kiosk_receipt_printer.dart';
import '../currency/kiosk_currency.dart';

class KioskReceiptPage extends StatelessWidget {
  final KioskOrder order;

  const KioskReceiptPage({
    super.key,
    required this.order,
  });

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _print(BuildContext context) async {
    try {
      await KioskReceiptPrinter.printOrder(
        order,
        includeCustomerReceipt: true,
        includeBaristaCopy: false,
        includeKitchenCopy: false,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open print dialog: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);

    return Scaffold(
      backgroundColor: const Color(0xFFECE9E3),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: Text(
          'RECEIPT • ${order.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => _print(context),
            icon: const Icon(Icons.print_outlined),
            label: const Text('PRINT'),
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 390,
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BIGGER BREW',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'MILKTEA • COFFEE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  order.orderNumber,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: gold,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _time(order.createdAt),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                _Info(label: 'ORDER TYPE', value: order.orderType),
                _Info(label: 'PAYMENT', value: order.paymentMethod),
                _Info(
                  label: 'STATUS',
                  value: order.paymentStatus.toUpperCase(),
                ),
                const Divider(height: 28),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity} × ${item.product.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
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
                        if (item.size != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              '${item.size!.name}'
                              '${item.size!.displayVolume == null ? '' : ' • ${item.size!.displayVolume}'}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (item.variant != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              item.variant!.name,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (item.options.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              item.options.map((o) => o.name).join(' • '),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      KioskCurrency.format(order.total),
                      style: const TextStyle(
                        color: gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  order.paymentStatus == 'paid'
                      ? 'PAID'
                      : 'PAY AT COUNTER',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thank you for ordering with Bigger Brew!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;

  const _Info({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
