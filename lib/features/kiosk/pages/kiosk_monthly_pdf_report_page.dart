import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../currency/kiosk_currency.dart';
import '../models/kiosk_models.dart';
import '../orders/kiosk_order.dart';

/// Monthly sales PDF report.
///
/// Historical transactions are read as stored. Drink temperature is taken
/// from the transaction item's snapshot, so later catalog edits do not
/// reclassify historical sales.
class KioskMonthlyPdfReportPage extends StatelessWidget {
  const KioskMonthlyPdfReportPage({
    super.key,
    required this.month,
    required this.orders,
  });

  final DateTime month;
  final List<KioskOrder> orders;

  List<KioskOrder> get completed => orders
      .where((o) =>
          o.status == KioskOrderStatus.completed &&
          o.createdAt.year == month.year &&
          o.createdAt.month == month.month)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: Text(
          'MONTHLY REPORT',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Print / Share PDF',
            onPressed: () => Printing.layoutPdf(onLayout: (_) => buildPdf()),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: PdfPreview(
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: true,
        canChangeOrientation: false,
        pdfFileName: 'Bigger_Brew_Monthly_${_safeMonth()}.pdf',
        build: (_) => buildPdf(),
      ),
    );
  }

  Future<Uint8List> buildPdf() async {
    final regularFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final boldFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
        header: (_) => _header(),
        footer: (c) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'BIGGER BREW • MONTHLY REPORT',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Page ${c.pageNumber} of ${c.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        build: (_) => [
          _section('DAILY SALES'),
          _dailySalesTable(),
          pw.SizedBox(height: 18),
          _section('TOTAL DRINK IN CUPS'),
          _drinkCupsTable(),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header() => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(
              color: PdfColor.fromInt(0xFFC69214),
              width: 1.5,
            ),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'BIGGER BREW',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '${_monthName(month.month)} ${month.year}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  pw.Widget _dailySalesTable() {
    final rows = <pw.TableRow>[
      _headerRow(['Date', 'Drinks', 'Meals', 'Accessories', 'Total']),
    ];

    final days = <DateTime, Map<String, int>>{};

    for (final order in completed) {
      final day = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      final map = days.putIfAbsent(
        day,
        () => <String, int>{
          'drinks': 0,
          'meals': 0,
          'accessories': 0,
          'total': 0,
        },
      );

      map['total'] = map['total']! + order.total;

      for (final item in order.items) {
        final type = item.product.productType.trim().toLowerCase();
        final value = item.total;
        if (type == 'drink') {
          map['drinks'] = map['drinks']! + value;
        } else if (type == 'accessory') {
          map['accessories'] = map['accessories']! + value;
        } else {
          map['meals'] = map['meals']! + value;
        }
      }
    }

    if (days.isEmpty) return _empty('No completed sales for this month.');

    var drinkTotal = 0;
    var mealTotal = 0;
    var accessoryTotal = 0;
    var grandTotal = 0;

    final orderedDays = days.keys.toList()..sort();
    for (final day in orderedDays) {
      final map = days[day]!;
      drinkTotal += map['drinks']!;
      mealTotal += map['meals']!;
      accessoryTotal += map['accessories']!;
      grandTotal += map['total']!;

      rows.add(
        pw.TableRow(
          children: [
            _cell(_dateLabel(day), bold: true),
            _cell(_peso(map['drinks']!), align: pw.TextAlign.right),
            _cell(_peso(map['meals']!), align: pw.TextAlign.right),
            _cell(_peso(map['accessories']!), align: pw.TextAlign.right),
            _cell(_peso(map['total']!), bold: true, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        children: [
          _cell('TOTAL', bold: true),
          _cell(_peso(drinkTotal), bold: true, align: pw.TextAlign.right),
          _cell(_peso(mealTotal), bold: true, align: pw.TextAlign.right),
          _cell(_peso(accessoryTotal), bold: true, align: pw.TextAlign.right),
          _cell(_peso(grandTotal), bold: true, align: pw.TextAlign.right),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#D8D1C7'),
        width: .4,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }

  pw.Widget _drinkCupsTable() {
    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          _cell('Date', bold: true),
          _cell('Hot', bold: true, align: pw.TextAlign.center),
          _cell('Iced', bold: true, align: pw.TextAlign.center),
          _cell('', bold: true),
          _cell('', bold: true),
          _cell('Total', bold: true, align: pw.TextAlign.center),
        ],
      ),
      pw.TableRow(
        children: [
          _cell(''),
          _cell('12oz', bold: true, align: pw.TextAlign.center),
          _cell('12oz', bold: true, align: pw.TextAlign.center),
          _cell('22oz', bold: true, align: pw.TextAlign.center),
          _cell('1L', bold: true, align: pw.TextAlign.center),
          _cell(''),
        ],
      ),
    ];

    final days = <DateTime, Map<String, int>>{};

    for (final order in completed) {
      final day = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      final map = days.putIfAbsent(
        day,
        () => <String, int>{
          'hot12oz': 0,
          'iced12oz': 0,
          'iced22oz': 0,
          'iced1L': 0,
        },
      );

      for (final item in order.items) {
        if (item.product.productType.trim().toLowerCase() != 'drink') {
          continue;
        }

        final temperature = item.drinkTemperature?.trim().toLowerCase();
        final size = _drinkSizeLabel(item.size);

        // The requested report layout reserves the Hot column for 12oz.
        // Existing hot drinks without a size are also treated as hot 12oz.
        if (temperature == 'hot') {
          if (size.isEmpty || size == '12oz') {
            map['hot12oz'] = map['hot12oz']! + item.quantity;
          }
          continue;
        }

        // Legacy records without temperature continue to use the existing
        // Hot Coffee fallback, matching the EOD report.
        if ((temperature == null || temperature.isEmpty) &&
            _isHotCoffee(item)) {
          map['hot12oz'] = map['hot12oz']! + item.quantity;
          continue;
        }

        switch (size) {
          case '12oz':
            map['iced12oz'] = map['iced12oz']! + item.quantity;
            break;
          case '22oz':
            map['iced22oz'] = map['iced22oz']! + item.quantity;
            break;
          case '1L':
            map['iced1L'] = map['iced1L']! + item.quantity;
            break;
        }
      }
    }

    if (days.isEmpty) return _empty('No completed drink sales for this month.');

    var hotTotal = 0;
    var iced12Total = 0;
    var iced22Total = 0;
    var iced1LTotal = 0;
    var grandTotal = 0;

    final orderedDays = days.keys.toList()..sort();
    for (final day in orderedDays) {
      final map = days[day]!;
      final hot = map['hot12oz']!;
      final iced12 = map['iced12oz']!;
      final iced22 = map['iced22oz']!;
      final iced1L = map['iced1L']!;
      final total = hot + iced12 + iced22 + iced1L;

      hotTotal += hot;
      iced12Total += iced12;
      iced22Total += iced22;
      iced1LTotal += iced1L;
      grandTotal += total;

      rows.add(
        pw.TableRow(
          children: [
            _cell(_dateLabel(day), bold: true),
            _cell('$hot', align: pw.TextAlign.right),
            _cell('$iced12', align: pw.TextAlign.right),
            _cell('$iced22', align: pw.TextAlign.right),
            _cell('$iced1L', align: pw.TextAlign.right),
            _cell('$total', bold: true, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        children: [
          _cell('TOTAL CUPS', bold: true),
          _cell('$hotTotal', bold: true, align: pw.TextAlign.right),
          _cell('$iced12Total', bold: true, align: pw.TextAlign.right),
          _cell('$iced22Total', bold: true, align: pw.TextAlign.right),
          _cell('$iced1LTotal', bold: true, align: pw.TextAlign.right),
          _cell('$grandTotal', bold: true, align: pw.TextAlign.right),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#D8D1C7'),
        width: .4,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  bool _isHotCoffee(KioskCartItem item) {
    final name = item.product.name.trim().toLowerCase();
    final group = item.product.groupName?.trim().toLowerCase() ?? '';
    final groupId = item.product.groupId?.trim().toLowerCase() ?? '';
    return name == 'hot coffee' ||
        group == 'hot coffee' ||
        groupId == 'hot_coffee';
  }

  String _drinkSizeLabel(KioskSize? size) {
    if (size == null) return '';
    final name = size.name.trim().toLowerCase();
    final volume = size.displayVolume?.trim().toLowerCase() ?? '';
    if (name == '12oz' || volume == '12oz') return '12oz';
    if (name == '22oz' || volume == '22oz') return '22oz';
    if (name == '1l' ||
        name == '1 liter' ||
        volume == '1l' ||
        volume == '1 liter') {
      return '1L';
    }
    return size.displayVolume?.trim().isNotEmpty == true
        ? size.displayVolume!.trim()
        : size.name.trim();
  }

  pw.Widget _section(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  pw.TableRow _headerRow(List<String> labels) => pw.TableRow(
        children: labels
            .map((label) => _cell(label, bold: true))
            .toList(growable: false),
      );

  pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.Widget _empty(String text) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColor.fromHex('#D8D1C7'),
            width: .5,
          ),
        ),
        child: pw.Text(
          text,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
      );

  String _peso(int value) => KioskCurrency.format(value);

  String _dateLabel(DateTime v) =>
      '${_monthName(v.month)} ${v.day}, ${v.year}';

  String _safeMonth() =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  String _monthName(int value) => const [
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
      ][value - 1];
}
