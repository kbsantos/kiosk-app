import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../orders/kiosk_order.dart';
import '../orders/kiosk_order_repository.dart';
import 'kiosk_receipt_page.dart';
import 'kiosk_eod_pdf_report_page.dart';
import 'kiosk_monthly_pdf_report_page.dart';
import 'kiosk_eod_email_service.dart';
import '../settings/kiosk_settings_repository.dart';

class KioskOrderHistoryPage extends StatefulWidget {
  const KioskOrderHistoryPage({super.key});

  @override
  State<KioskOrderHistoryPage> createState() => _KioskOrderHistoryPageState();
}

class _KioskOrderHistoryPageState extends State<KioskOrderHistoryPage> {
  final KioskOrderRepository _repository = KioskOrderRepository();
  final KioskSettingsRepository _settingsRepository = KioskSettingsRepository();
  DateTime _selectedDate = DateTime.now();
  KioskOrderStatus? _filter = KioskOrderStatus.completed;
  late Future<List<KioskOrder>> _orders;
  bool _employeeOrderMode = false;
  final Set<String> _cancellingOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepository.load();
    if (!mounted) return;
    setState(() => _employeeOrderMode = settings.employeeOrderMode);
  }

  void _reload() {
    _orders = _repository.getOrdersForDate(_selectedDate);
  }

  List<KioskOrder> _filtered(List<KioskOrder> orders) {
    if (_filter == null) return orders;
    return orders
        .where((order) => order.status == _filter)
        .toList(growable: false);
  }

  List<KioskOrder> _completed(List<KioskOrder> orders) {
    return orders
        .where((order) => order.status == KioskOrderStatus.completed)
        .toList(growable: false);
  }

  int _refundTotal(List<KioskOrder> orders) {
    return orders
        .where(
          (order) =>
              order.status == KioskOrderStatus.cancelled &&
              order.paymentStatus == 'refunded',
        )
        .fold<int>(0, (sum, order) => sum + order.total);
  }

  int _totalItems(List<KioskOrder> orders) {
    return orders.fold<int>(
      0,
      (sum, order) =>
          sum +
          order.items.fold<int>(0, (itemSum, item) => itemSum + item.quantity),
    );
  }

  int _salesTotal(List<KioskOrder> orders) {
    return orders.fold<int>(0, (sum, order) => sum + order.total);
  }

  int _pendingPaymentTotal(List<KioskOrder> orders) {
    return orders
        .where(
          (order) =>
              order.status == KioskOrderStatus.completed &&
              order.paymentStatus != 'paid',
        )
        .fold<int>(0, (sum, order) => sum + order.total);
  }

  String _dateLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = picked;
      _reload();
    });
  }

  Future<void> _openPdfReport(List<KioskOrder> orders) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KioskEodPdfReportPage(
          date: _selectedDate,
          orders: orders,
        ),
      ),
    );
  }


  Future<void> _openMonthlyReport() async {
    final orders = await _repository.getOrders();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KioskMonthlyPdfReportPage(
          month: _selectedDate,
          orders: orders,
        ),
      ),
    );
  }

  Future<void> _emailEodReport(List<KioskOrder> orders) async {
    final settings = await _settingsRepository.load();
    if (!mounted) return;

    final recipient = settings.eodReportEmail;
    if (recipient == null || recipient.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure the EOD report email in Kiosk Settings first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preparing EOD PDF for email...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await KioskEodEmailService.sendReport(
        recipient: recipient,
        date: _selectedDate,
        orders: orders,
        storeName: settings.storeName,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('EOD report prepared for $recipient.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Unable to open email composer: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelEmployeeOrder(KioskOrder order) async {
    if (!_employeeOrderMode ||
        order.orderMode.toLowerCase() != 'employee' ||
        order.status != KioskOrderStatus.completed ||
        order.paymentStatus != 'paid') {
      return;
    }

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
            Text(
              'This employee order is already PAID and COMPLETED. Cancelling it will mark the payment as REFUNDED and remove ${KioskCurrency.format(order.total)} from completed sales.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Cancellation reason *',
                hintText: 'Enter a reason before cancelling',
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
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a cancellation reason first.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('CANCEL & MARK REFUNDED'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    if (confirmed != true) {
      // Let the dialog route finish deactivation before disposing the field controller.
      await WidgetsBinding.instance.endOfFrame;
      reasonController.dispose();
      return;
    }

    // The dialog's focus/inherited widgets are still completing their route
    // transition when showDialog returns. Dispose the controller after the frame
    // to avoid triggering Flutter's InheritedElement dependency assertion.
    await WidgetsBinding.instance.endOfFrame;
    reasonController.dispose();

    if (_cancellingOrderIds.contains(order.id)) return;

    setState(() => _cancellingOrderIds.add(order.id));
    try {
      await _repository.cancelAndRefundEmployeeOrder(
        order.id,
        reason: reason,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${order.orderNumber} cancelled and marked as REFUNDED.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to cancel order: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cancellingOrderIds.remove(order.id));
      }
    }
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

  Future<void> _refundOrder(KioskOrder order) async {
    if (order.paymentStatus != 'paid') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Refund ${order.orderNumber}?',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Confirm a refund of ${KioskCurrency.format(order.total)}. This only records the kiosk payment status as REFUNDED; it does not move money through a payment gateway.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('KEEP PAYMENT'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('CONFIRM REFUND'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repository.refundPayment(order.id);
    if (!mounted) return;
    setState(_reload);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.orderNumber} marked as REFUNDED.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showOrder(KioskOrder order) async {
    final pageContext = context;
    await showDialog<void>(
      context: pageContext,
      builder: (_) => AlertDialog(
        title: Text(
          order.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Time', value: _timeLabel(order.createdAt)),
                _InfoRow(label: 'Order Type', value: order.orderType),
                _InfoRow(
                  label: 'Payment',
                  value:
                      '${order.paymentMethod} • ${order.paymentStatus.toUpperCase()}',
                ),
                if (order.cancellationReason != null)
                  _InfoRow(
                    label: 'Reason',
                    value: order.cancellationReason!,
                  ),
                const Divider(height: 28),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}×',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            [
                              item.displayLabel,
                            ].join(' — '),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          KioskCurrency.format(item.total),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      KioskCurrency.format(order.total),
                      style: const TextStyle(
                        fontSize: 23,
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
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(pageContext).push(
                MaterialPageRoute(
                  builder: (_) => KioskReceiptPage(order: order),
                ),
              );
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('RECEIPT'),
          ),
          if (order.status == KioskOrderStatus.cancelled &&
              order.paymentStatus == 'paid')
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _refundOrder(order);
              },
              icon: const Icon(Icons.currency_exchange),
              label: const Text('REFUND'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          if (order.paymentStatus != 'paid' &&
              order.paymentStatus != 'refunded')
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markPaid(order);
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('MARK PAID'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
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
          'ORDER HISTORY',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Select date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Monthly Report',
            onPressed: _openMonthlyReport,
            icon: const Icon(Icons.summarize_outlined),
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
              child: Text('Unable to load order history: ${snapshot.error}'),
            );
          }

          final allOrders = snapshot.data ?? const <KioskOrder>[];
          final completed = _completed(allOrders);
          final visibleOrders = _filtered(allOrders);
          final sales = _salesTotal(completed);
          final itemCount = _totalItems(completed);
          final pendingPayment = _pendingPaymentTotal(completed);
          final refunds = _refundTotal(allOrders);

          return Column(
            children: [
              _SummaryHeader(
                date: _dateLabel(_selectedDate),
                orderCount: completed.length,
                itemCount: itemCount,
                sales: sales,
                pendingPayment: pendingPayment,
                refunds: refunds,
                onExport: () => _openPdfReport(allOrders),
                onEmail: () => _emailEodReport(allOrders),
              ),
              _HistoryFilters(
                filter: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              if (allOrders.isNotEmpty && completed.length != allOrders.length)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${allOrders.length - completed.length} order(s) from this date are not completed and are excluded from sales.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: visibleOrders.isEmpty
                    ? const _EmptyHistory()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        itemCount: visibleOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final order = visibleOrders[index];
                          return _HistoryCard(
                            order: order,
                            time: _timeLabel(order.createdAt),
                            employeeOrderMode: _employeeOrderMode,
                            onTap: () => _showOrder(order),
                            onCancel: () => _cancelEmployeeOrder(order),
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

class _HistoryFilters extends StatelessWidget {
  final KioskOrderStatus? filter;
  final ValueChanged<KioskOrderStatus?> onChanged;

  const _HistoryFilters({
    required this.filter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('COMPLETED'),
            selected: filter == KioskOrderStatus.completed,
            onSelected: (_) => onChanged(KioskOrderStatus.completed),
          ),
          FilterChip(
            label: const Text('CANCELLED'),
            selected: filter == KioskOrderStatus.cancelled,
            onSelected: (_) => onChanged(KioskOrderStatus.cancelled),
          ),
          FilterChip(
            label: const Text('ALL'),
            selected: filter == null,
            onSelected: (_) => onChanged(null),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final String date;
  final int orderCount;
  final int itemCount;
  final int sales;
  final int pendingPayment;
  final int refunds;
  final VoidCallback onExport;
  final VoidCallback onEmail;

  const _SummaryHeader({
    required this.date,
    required this.orderCount,
    required this.itemCount,
    required this.sales,
    required this.pendingPayment,
    required this.refunds,
    required this.onExport,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'END-OF-DAY SUMMARY',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('VIEW PDF REPORT'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEmail,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('EMAIL PDF'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'COMPLETED ORDERS',
                value: '$orderCount',
              ),
              _MetricCard(
                label: 'ITEMS SOLD',
                value: '$itemCount',
              ),
              _MetricCard(
                label: 'COMPLETED SALES',
                value: KioskCurrency.format(sales),
                emphasize: true,
              ),
              _MetricCard(
                label: 'PAYMENT STILL PENDING',
                value: KioskCurrency.format(pendingPayment),
              ),
              _MetricCard(
                label: 'REFUNDS',
                value: KioskCurrency.format(refunds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _MetricCard({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFF7E5) : const Color(0xFFF7F5F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasize ? const Color(0xFFC69214) : const Color(0xFFE4DED5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color:
                  emphasize ? const Color(0xFFC69214) : const Color(0xFF171717),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final KioskOrder order;
  final String time;
  final bool employeeOrderMode;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  const _HistoryCard({
    required this.order,
    required this.time,
    required this.employeeOrderMode,
    required this.onTap,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                    color: Color(0xFFC69214),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 75,
                child: Text(
                  time,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  order.items
                      .map(
                        (item) => '${item.quantity}× ${item.displayLabel}',
                      )
                      .join('  •  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                KioskCurrency.format(order.total),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                order.paymentStatus == 'paid'
                    ? Icons.check_circle
                    : Icons.pending_outlined,
                size: 20,
                color: order.paymentStatus == 'paid'
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                order.paymentStatus == 'paid' ? 'PAID' : 'PENDING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: order.paymentStatus == 'paid'
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
              ),
              if (employeeOrderMode &&
                  order.orderMode.toLowerCase() == 'employee' &&
                  order.status == KioskOrderStatus.completed &&
                  order.paymentStatus == 'paid') ...[
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Cancel ${order.orderNumber}',
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: Icon(
                      Icons.cancel,
                      size: 20,
                      color: Colors.red.shade600,
                    ),
                    label: Text(
                      'CANCEL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_outlined,
            size: 72,
            color: Colors.black26,
          ),
          SizedBox(height: 14),
          Text(
            'NO ORDERS',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Orders for this date will appear here.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
