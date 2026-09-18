import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../currency/kiosk_currency.dart';
import '../orders/kiosk_order_repository.dart';
import '../../reporting_sync/sales_reporting_dashboard.dart';

class KioskSalesDashboardPage extends StatefulWidget {
  const KioskSalesDashboardPage({super.key});

  @override
  State<KioskSalesDashboardPage> createState() => _KioskSalesDashboardPageState();
}

class _KioskSalesDashboardPageState extends State<KioskSalesDashboardPage> {
  final _repository = KioskOrderRepository();
  DateTime _start = _dayStart(DateTime.now());
  DateTime _end = _dayStart(DateTime.now()).add(const Duration(days: 1));
  SalesReportingDashboard? _report;
  bool _loading = true;

  static DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _repository.getOrders();
    final report = SalesReportingDashboardCalculator.calculate(
      orders: orders,
      start: _start,
      end: _end,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  void _setCurrentMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    setState(() {
      _start = start;
      _end = DateTime(now.year, now.month + 1);
    });
    _load();
  }

  void _setPreset(int days) {
    final today = _dayStart(DateTime.now());
    setState(() {
      _start = today.subtract(Duration(days: days - 1));
      _end = today.add(const Duration(days: 1));
    });
    _load();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = _dayStart(picked);
      if (!_start.isBefore(_end)) {
        _end = _start.add(const Duration(days: 1));
      }
    });
    _load();
  }

  Future<void> _pickEnd() async {
    final currentEndDate = _end.subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: currentEndDate.isBefore(DateTime(2020))
          ? DateTime.now()
          : currentEndDate,
      firstDate: _start,
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _end = _dayStart(picked).add(const Duration(days: 1)));
    _load();
  }

  Future<void> _copyReportData(SalesReportingDashboard report) async {
    final lines = <String>[
      'Metric,Value',
      'Period,"${_dateRange()}"',
      'Sales,${report.salesTotal}',
      'Completed Orders,${report.completedOrders}',
      'Items Sold,${report.itemsSold}',
      'Average Order Value,${report.averageOrderValue.round()}',
      'Previous Period Sales,${report.previousPeriodSales}',
      'Sales Change,${report.salesChange}',
      'Sales Change Percent,${report.salesChangePercent.toStringAsFixed(2)}%',
      '',
      'Daily Sales,Amount',
      ...report.dailySales.entries.map(
        (entry) => '${_formatDate(entry.key)},${entry.value}',
      ),
      '',
      'Weekly Sales,Amount',
      ...report.weeklySales.entries.map(
        (entry) => '${_formatDate(entry.key)},${entry.value}',
      ),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('REPORT DATA COPIED')),
    );
  }

  String _dateRange() {
    final endDate = _end.subtract(const Duration(days: 1));
    return '${_formatDate(_start)} — ${_formatDate(endDate)}';
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('SALES DASHBOARD',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _buildRangeCard(),
                  const SizedBox(height: 14),
                  if (_report != null) ...[
                    _buildKpis(_report!),
                    const SizedBox(height: 14),
                    _buildComparison(_report!),
                    const SizedBox(height: 14),
                    _buildExportCard(_report!),
                    const SizedBox(height: 14),
                    _buildBreakdown('SALES BY CATEGORY', _report!.categorySales),
                    _buildBreakdown('SALES BY PRODUCT', _report!.productSales),
                    _buildBreakdown('SALES BY VARIANT', _report!.variantSales),
                    _buildBreakdown('ADD-ON SALES', _report!.optionSales),
                    _buildBreakdown('PAYMENT METHOD', _report!.paymentSales),
                    _buildBreakdown('ORDER MODE', _report!.orderModeSales),
                    _buildDaily(_report!.dailySales),
                    _buildDaily(_report!.weeklySales, title: 'WEEKLY SALES'),
                    _buildBreakdown('MONTHLY SALES', _report!.monthlySales),
                    _buildHourly(_report!.hourlySales),
                    const SizedBox(height: 12),
                    const Text(
                      'LOCAL KIOSK DATA • COMPLETED ORDERS ONLY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black54,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('REPORTING PERIOD',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_dateRange(), style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => _setPreset(1), child: const Text('TODAY')),
                OutlinedButton(onPressed: () => _setPreset(7), child: const Text('7 DAYS')),
                OutlinedButton(onPressed: () => _setPreset(30), child: const Text('30 DAYS')),
                OutlinedButton(onPressed: _setCurrentMonth, child: const Text('THIS MONTH')),
                OutlinedButton(onPressed: _pickStart, child: const Text('START DATE')),
                OutlinedButton(onPressed: _pickEnd, child: const Text('END DATE')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _peso(num value) => KioskCurrency.format(value);

  Widget _buildComparison(SalesReportingDashboard report) {
    final change = report.salesChangePercent;
    final direction = change > 0 ? 'UP' : change < 0 ? 'DOWN' : 'NO CHANGE';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PERIOD COMPARISON',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Previous period: ${_peso(report.previousPeriodSales)}'),
            const SizedBox(height: 4),
            Text(
              '$direction • ${_peso(report.salesChange.abs())} • ${change.abs().toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(SalesReportingDashboard report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'EXPORT REPORT DATA',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _copyReportData(report),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('COPY CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpis(SalesReportingDashboard report) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpi('SALES', _peso(report.salesTotal)),
        _kpi('ORDERS', '${report.completedOrders}'),
        _kpi('ITEMS', '${report.itemsSold}'),
        _kpi('AVG ORDER', _peso(report.averageOrderValue.round())),
      ],
    );
  }

  Widget _kpi(String label, String value) => SizedBox(
        width: 180,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      );

  Widget _buildBreakdown(String title, Map<String, int> values) {
    final rows = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final row in rows.take(20))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(row.key),
                trailing: Text(_peso(row.value),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaily(Map<DateTime, int> values, {String title = 'DAILY SALES'}) {
    if (values.isEmpty) return const SizedBox.shrink();
    final rows = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final row in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_formatDate(row.key)),
                trailing: Text(_peso(row.value),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourly(Map<int, int> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    final rows = values.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HOURLY SALES', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final row in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${row.key.toString().padLeft(2, '0')}:00'),
                trailing: Text(_peso(row.value),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }
}
