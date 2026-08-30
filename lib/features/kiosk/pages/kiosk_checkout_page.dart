import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../models/kiosk_models.dart';
import '../orders/kiosk_order.dart';
import '../orders/kiosk_order_repository.dart';
import '../payments/kiosk_payment.dart';
import '../settings/kiosk_settings_repository.dart';
import 'kiosk_customer_queue_page.dart';
import 'kiosk_receipt_page.dart';
import 'kiosk_receipt_printer.dart';

class KioskCheckoutPage extends StatefulWidget {
  final KioskCart cart;

  const KioskCheckoutPage({
    super.key,
    required this.cart,
  });

  @override
  State<KioskCheckoutPage> createState() => _KioskCheckoutPageState();
}

class _KioskCheckoutPageState extends State<KioskCheckoutPage> {
  String _orderType = 'Take Out';
  bool _submitting = false;
  final KioskOrderRepository _orders = KioskOrderRepository();
  final KioskPaymentProcessor _payment = const CounterPaymentProcessor();
  final KioskSettingsRepository _settingsRepository = KioskSettingsRepository();
  bool _employeeOrderMode = false;
  bool _settingsLoaded = false;
  bool _printCustomerReceipt = true;
  bool _autoPrintReceipt = true;
  bool _printBaristaCopy = true;
  bool _printKitchenCopy = true;
  bool _bluetoothPrinterConfigured = false;
  KioskPaymentMethod _paymentMethod = KioskPaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _employeeOrderMode = settings.employeeOrderMode;
      _printCustomerReceipt = settings.printCustomerReceipt;
      _autoPrintReceipt = settings.autoPrintReceipt;
      _printBaristaCopy = settings.printBaristaCopy;
      _printKitchenCopy = settings.printKitchenCopy;
      _bluetoothPrinterConfigured =
          settings.printerConnectionType == 'bluetooth' &&
              settings.bluetoothPrinterAddress?.isNotEmpty == true;
      _settingsLoaded = true;
    });
  }

  Future<void> _placeOrder() async {
    if (widget.cart.items.isEmpty || _submitting) return;

    setState(() => _submitting = true);

    // Employee Order Mode is an operational override for staff-entered
    // orders. It keeps the selected payment method for reporting, but marks
    // the order paid and completed immediately without invoking a payment
    // gateway/counter workflow.
    late final String paymentStatus;
    late final KioskOrderStatus orderStatus;

    if (_employeeOrderMode) {
      paymentStatus = 'paid';
      orderStatus = KioskOrderStatus.completed;
    } else {
      final paymentResult = await _payment.startPayment(
        amount: widget.cart.total,
        method: _paymentMethod,
      );

      if (!paymentResult.isSuccessful &&
          paymentResult.status != KioskPaymentStatus.pending) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment could not be started.'),
          ),
        );
        return;
      }

      paymentStatus = paymentResult.status.value;
      orderStatus = KioskOrderStatus.pending;
    }

    // Save the order after the payment mode has been accepted.
    late final KioskOrder order;
    try {
      order = await _orders.createOrder(
        cart: widget.cart,
        orderType: _orderType,
        paymentMethod: _paymentMethod.label,
        paymentStatus: paymentStatus,
        orderMode: _employeeOrderMode ? 'Employee' : 'Customer',
        status: orderStatus,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save order: $error'),
        ),
      );
      return;
    }

    if (!mounted) return;

    // Print immediately after the order is saved. On native platforms with
    // direct-print support this sends the ticket straight to the configured
    // default printer without opening a receipt/PDF preview.
    bool printSucceeded = false;
    final customerReceiptPrintAttempted =
        _printCustomerReceipt && _autoPrintReceipt;
    if (customerReceiptPrintAttempted) {
      try {
        printSucceeded = await KioskReceiptPrinter.printOrder(
          order,
          allowPrintDialogFallback: !_bluetoothPrinterConfigured,
          includeCustomerReceipt: true,
          includeBaristaCopy: _printBaristaCopy,
          includeKitchenCopy: _printKitchenCopy,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order saved, but printing failed: $error'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    if (!mounted) return;

    final orderNumber = order.orderNumber;
    widget.cart.clear();

    var retryingPrint = false;

    final viewReprint = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> retryPrint() async {
            if (retryingPrint) return;

            setDialogState(() => retryingPrint = true);
            bool success = false;
            try {
              success = await KioskReceiptPrinter.printOrder(
                order,
                allowPrintDialogFallback: !_bluetoothPrinterConfigured,
                includeCustomerReceipt: true,
                includeBaristaCopy: _printBaristaCopy,
                includeKitchenCopy: _printKitchenCopy,
              );
            } catch (_) {
              success = false;
            }

            if (!dialogContext.mounted) return;
            setDialogState(() {
              printSucceeded = success;
              retryingPrint = false;
            });
          }

          final hasBaristaItems = order.items.any(
            (item) => item.product.productType.toLowerCase() == 'drink',
          );
          final hasKitchenItems = order.items.any(
            (item) =>
                item.product.kitchenPrepared ||
                item.options.any((option) => option.kitchenPrepared),
          );

          Future<void> printCopy({required bool barista}) async {
            if (retryingPrint) return;
            setDialogState(() => retryingPrint = true);
            bool success = false;
            try {
              success = await KioskReceiptPrinter.printOrder(
                order,
                allowPrintDialogFallback: !_bluetoothPrinterConfigured,
                includeCustomerReceipt: false,
                includeBaristaCopy: barista,
                includeKitchenCopy: !barista,
              );
            } catch (_) {
              success = false;
            }
            if (!dialogContext.mounted) return;
            setDialogState(() => retryingPrint = false);
            if (!success) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    barista
                        ? 'Barista copy could not be printed.'
                        : 'Kitchen copy could not be printed.',
                  ),
                ),
              );
            }
          }

          return AlertDialog(
            title: const Text(
              'ORDER RECEIVED',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !customerReceiptPrintAttempted || printSucceeded
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 72,
                  color: !customerReceiptPrintAttempted || printSucceeded
                      ? const Color(0xFFC69214)
                      : Colors.orange.shade700,
                ),
                const SizedBox(height: 16),
                Text(
                  orderNumber,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'YOUR QUEUE NUMBER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black54,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _employeeOrderMode
                      ? 'Employee order: payment recorded as PAID and order marked COMPLETED.'
                      : 'Your payment mode has been tagged on the order. Please follow the store payment instructions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: .65),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  !customerReceiptPrintAttempted
                      ? 'Order saved. Receipt printing on checkout is disabled.'
                      : printSucceeded
                          ? 'Receipt sent to the printer.'
                          : 'Order saved, but the printer did not confirm the receipt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !customerReceiptPrintAttempted
                        ? const Color(0xFFC69214)
                        : printSucceeded
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (customerReceiptPrintAttempted && !printSucceeded) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Check that the XP-58H is powered on and connected, then try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (_printKitchenCopy && hasKitchenItems)
                OutlinedButton.icon(
                  onPressed:
                      retryingPrint ? null : () => printCopy(barista: false),
                  icon: const Icon(Icons.soup_kitchen_outlined),
                  label: const Text('PRINT KITCHEN'),
                ),
              if (_printBaristaCopy && hasBaristaItems)
                OutlinedButton.icon(
                  onPressed:
                      retryingPrint ? null : () => printCopy(barista: true),
                  icon: const Icon(Icons.local_cafe_outlined),
                  label: const Text('PRINT BARISTA'),
                ),
              if (customerReceiptPrintAttempted && !printSucceeded)
                OutlinedButton.icon(
                  onPressed: retryingPrint ? null : retryPrint,
                  icon: retryingPrint
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: Text(retryingPrint ? 'RETRYING...' : 'RETRY PRINT'),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('VIEW / REPRINT'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC69214),
                ),
                child: const Text('DONE'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted) return;

    if (viewReprint == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KioskReceiptPage(order: order),
        ),
      );
      if (!mounted) return;
    }

    if (_employeeOrderMode) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => KioskCustomerQueuePage(
          orderId: order.id,
          orderNumber: order.orderNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    const dark = Color(0xFF171717);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text(
          'REVIEW YOUR ORDER',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.cart,
        builder: (_, __) {
          final items = widget.cart.items;

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              final summary = Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE4DED5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDER SUMMARY',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 20),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1ECE4),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (item.size != null)
                                      Text(
                                        '${item.size!.name}${item.size!.displayVolume == null ? '' : ' • ${item.size!.displayVolume}'}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    if (item.options.isNotEmpty)
                                      Text(
                                        item.options
                                            .map((option) => option.name)
                                            .join(' • '),
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                KioskCurrency.format(item.total),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          KioskCurrency.format(widget.cart.total),
                          style: const TextStyle(
                            color: gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final details = Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE4DED5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_employeeOrderMode) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3D6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC69214)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.badge_outlined,
                                color: Color(0xFFC69214)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'EMPLOYEE MODE • ORDER WILL BE PAID + COMPLETED AUTOMATICALLY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text(
                      'ORDER DETAILS',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ORDER TYPE',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Take Out',
                          label: Text('TAKE OUT'),
                          icon: Icon(Icons.takeout_dining),
                        ),
                        ButtonSegment(
                          value: 'Dine In',
                          label: Text('DINE IN'),
                          icon: Icon(Icons.restaurant),
                        ),
                      ],
                      selected: {_orderType},
                      onSelectionChanged: (value) {
                        setState(() => _orderType = value.first);
                      },
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'PAYMENT',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<KioskPaymentMethod>(
                      segments: const [
                        ButtonSegment(
                          value: KioskPaymentMethod.gcash,
                          label: Text('GCASH'),
                          icon: Icon(Icons.qr_code_2_outlined),
                        ),
                        ButtonSegment(
                          value: KioskPaymentMethod.cash,
                          label: Text('CASH'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                        ButtonSegment(
                          value: KioskPaymentMethod.others,
                          label: Text('OTHERS'),
                          icon: Icon(Icons.more_horiz),
                        ),
                      ],
                      selected: {_paymentMethod},
                      onSelectionChanged: (value) {
                        setState(() => _paymentMethod = value.first);
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Select the payment mode used for this order. The selected mode will be printed on the order ticket.',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton(
                        onPressed: _submitting || !_settingsLoaded
                            ? null
                            : _placeOrder,
                        style: FilledButton.styleFrom(
                          backgroundColor: gold,
                        ),
                        child: !_settingsLoaded
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : _submitting
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'PLACE ORDER',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                      ),
                    ),
                  ],
                ),
              );

              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: summary),
                      const SizedBox(width: 18),
                      SizedBox(width: 390, child: details),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    SizedBox(height: 470, child: summary),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 430,
                      child: details,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
