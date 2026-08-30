import 'dart:typed_data';
import '../currency/kiosk_currency.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../orders/kiosk_order.dart';
import '../models/kiosk_models.dart';

class KioskEodPdfReportPage extends StatelessWidget {
  const KioskEodPdfReportPage({
    super.key,
    required this.date,
    required this.orders,
  });

  final DateTime date;
  final List<KioskOrder> orders;

  List<KioskOrder> get completed => orders
      .where((o) => o.status == KioskOrderStatus.completed)
      .toList(growable: false);

  List<KioskOrder> get refunded => orders
      .where((o) =>
          o.status == KioskOrderStatus.cancelled &&
          o.paymentStatus == 'refunded')
      .toList(growable: false);

  int get itemsSold => completed.fold(
      0, (sum, o) => sum + o.items.fold(0, (s, i) => s + i.quantity));
  int get sales => completed.fold(0, (sum, o) => sum + o.total);
  int get pending => completed
      .where((o) => o.paymentStatus != 'paid')
      .fold(0, (sum, o) => sum + o.total);
  int get refunds => refunded.fold(0, (sum, o) => sum + o.total);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('PDF REPORT',
            style: TextStyle(fontWeight: FontWeight.w900)),
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
        pdfFileName: 'Bigger_Brew_EOD_${_safeDate()}.pdf',
        build: (_) => buildPdf(),
      ),
    );
  }

  Future<Uint8List> buildPdf() async {
    // The pdf package's built-in fonts do not contain all currency/symbol
    // glyphs used by the kiosk (for example ₱ and ×). Embed a Unicode font
    // so the EOD PDF renders the same characters as the app.
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
        header: (_) => _header(),
        footer: (c) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('BIGGER BREW • END-OF-DAY REPORT',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.Text('Page ${c.pageNumber} of ${c.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
        build: (_) => [
          _section('SALES SUMMARY'),
          _summaryTable(),
          pw.SizedBox(height: 16),
          _section('PAYMENT BREAKDOWN'),
          _paymentTable(),
          pw.SizedBox(height: 16),
          _section('DRINK SUMMARY — CUPS'),
          _drinkTable(),
          pw.SizedBox(height: 16),
          _section('MEAL SUMMARY — COUNT'),
          _mealTable(),
          pw.SizedBox(height: 16),
          _section('ACCESSORIES DAILY SUMMARY'),
          _accessoriesTable(),
          pw.SizedBox(height: 16),
          _section('ORDER DETAILS'),
          _ordersTable(),
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
                  color: PdfColor.fromInt(0xFFC69214), width: 1.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BIGGER BREW',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('END-OF-DAY REPORT',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFC69214))),
                ]),
            pw.Text(_dateLabel(date),
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ],
        ),
      );

  pw.Widget _section(String title) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        color: const PdfColor.fromInt(0xFFF7F5F1),
        child: pw.Text(title,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _summaryTable() => pw.Table(
        border:
            pw.TableBorder.all(color: PdfColor.fromHex('#E4DED5'), width: .5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(1)
        },
        children: [
          _row('COMPLETED ORDERS', '${completed.length}', 'ITEMS SOLD',
              '$itemsSold'),
          _row('COMPLETED SALES', _peso(sales), 'PAYMENT PENDING',
              _peso(pending)),
          _row('REFUNDS', _peso(refunds), 'TOTAL ORDERS', '${orders.length}'),
        ],
      );

  pw.TableRow _row(String a, String av, String b, String bv) =>
      pw.TableRow(children: [
        _cell(a, bold: true),
        _cell(av, bold: true, align: pw.TextAlign.right),
        _cell(b, bold: true),
        _cell(bv, bold: true, align: pw.TextAlign.right),
      ]);

  pw.Widget _paymentTable() {
    final methods = _paymentMethods();
    return pw.Table(
      border:
          pw.TableBorder.all(color: PdfColor.fromHex('#D8D1C7'), width: .45),
      children: [
        _headerRow(['Payment Mode', 'Completed', 'Sales', 'Pending']),
        ...methods.map((method) {
          final list = completed
              .where((o) => o.paymentMethod == method)
              .toList(growable: false);
          final total = list.fold(0, (s, o) => s + o.total);
          final due = list
              .where((o) => o.paymentStatus != 'paid')
              .fold(0, (s, o) => s + o.total);
          return pw.TableRow(children: [
            _cell(method),
            _cell('${list.length}', align: pw.TextAlign.right),
            _cell(_peso(total), align: pw.TextAlign.right),
            _cell(_peso(due), align: pw.TextAlign.right)
          ]);
        }),
      ],
    );
  }

  pw.Widget _ordersTable() => pw.Table(
        border:
            pw.TableBorder.all(color: PdfColor.fromHex('#D8D1C7'), width: .4),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(3),
          3: const pw.FlexColumnWidth(1.3),
          4: const pw.FlexColumnWidth(1.2),
          5: const pw.FlexColumnWidth(1.2)
        },
        children: [
          _headerRow(
              ['Order #', 'Time', 'Items', 'Payment', 'Status', 'Total']),
          ...orders.map((o) => pw.TableRow(children: [
                _cell(o.orderNumber, bold: true),
                _cell(_timeLabel(o.createdAt)),
                _cell(o.items
                    .map((i) => '${i.quantity}× ${i.displayLabel}')
                    .join('\n')),
                _cell('${o.paymentMethod}\n${o.paymentStatus.toUpperCase()}'),
                _cell(
                  o.modificationReason != null
                      ? '${o.status.name.toUpperCase()}\nMODIFIED'
                      : o.status.name.toUpperCase(),
                  bold: o.modificationReason != null,
                ),
                _cell(_peso(o.total), bold: true, align: pw.TextAlign.right),
              ])),
          pw.TableRow(children: [
            _cell('TOTAL', bold: true),
            _cell(''),
            _cell('$itemsSold item(s)', bold: true),
            _cell(''),
            _cell('${completed.length} completed', bold: true),
            _cell(_peso(sales), bold: true, align: pw.TextAlign.right)
          ]),
        ],
      );

  pw.Widget _drinkTable() {
    // Each drink row keeps its own Hot/Iced counts. New transactions use the
    // explicit drinkTemperature snapshot stored on the order item. Legacy
    // transactions without that field retain the existing Hot Coffee fallback
    // so historical reports are not reclassified.
    final counts = <String, Map<String, int>>{};

    for (final o in completed) {
      for (final i in o.items) {
        if (i.product.productType.toLowerCase() != 'drink') continue;

        final name = i.product.name;
        final map = counts.putIfAbsent(name, () => <String, int>{
              'hot12oz': 0,
              'iced12oz': 0,
              '22oz': 0,
              '1L': 0,
            });

        final temperature = i.drinkTemperature?.trim().toLowerCase();
        if (temperature == 'hot') {
          map['hot12oz'] = map['hot12oz']! + i.quantity;
          continue;
        }

        if ((temperature == null || temperature.isEmpty) && _isHotCoffee(i)) {
          map['hot12oz'] = map['hot12oz']! + i.quantity;
          continue;
        }

        final size = _drinkSizeLabel(i.size);
        if (size.isEmpty) continue;
        switch (size) {
          case '12oz':
            map['iced12oz'] = map['iced12oz']! + i.quantity;
            break;
          case '22oz':
            map['22oz'] = map['22oz']! + i.quantity;
            break;
          case '1 Liter':
          case '1L':
            map['1L'] = map['1L']! + i.quantity;
            break;
        }
      }
    }

    if (counts.isEmpty) return _empty('No completed drink sales.');

    final byColumn = <String, int>{
      'hot12oz': 0,
      'iced12oz': 0,
      '22oz': 0,
      '1L': 0,
    };
    var grand = 0;

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _cell('Drink', bold: true),
        _cell('Hot', bold: true, align: pw.TextAlign.center),
        _cell('Iced', bold: true, align: pw.TextAlign.center),
        _cell('', bold: true),
        _cell('', bold: true),
        _cell('Total', bold: true, align: pw.TextAlign.center),
      ]),
      pw.TableRow(children: [
        _cell(''),
        _cell('12oz', bold: true, align: pw.TextAlign.center),
        _cell('12oz', bold: true, align: pw.TextAlign.center),
        _cell('22oz', bold: true, align: pw.TextAlign.center),
        _cell('1L', bold: true, align: pw.TextAlign.center),
        _cell(''),
      ]),
    ];

    for (final name in counts.keys.toList()..sort()) {
      final map = counts[name]!;
      final hot = map['hot12oz'] ?? 0;
      final iced12 = map['iced12oz'] ?? 0;
      final q22 = map['22oz'] ?? 0;
      final q1l = map['1L'] ?? 0;
      final total = hot + iced12 + q22 + q1l;
      if (total == 0) continue;

      byColumn['hot12oz'] = byColumn['hot12oz']! + hot;
      byColumn['iced12oz'] = byColumn['iced12oz']! + iced12;
      byColumn['22oz'] = byColumn['22oz']! + q22;
      byColumn['1L'] = byColumn['1L']! + q1l;
      grand += total;

      rows.add(pw.TableRow(children: [
        _cell(name, bold: true),
        _cell('$hot', align: pw.TextAlign.right),
        _cell('$iced12', align: pw.TextAlign.right),
        _cell('$q22', align: pw.TextAlign.right),
        _cell('$q1l', align: pw.TextAlign.right),
        _cell('$total', bold: true, align: pw.TextAlign.right),
      ]));
    }

    rows.add(pw.TableRow(children: [
      _cell('TOTAL CUPS', bold: true),
      _cell('${byColumn['hot12oz']}', bold: true, align: pw.TextAlign.right),
      _cell('${byColumn['iced12oz']}', bold: true, align: pw.TextAlign.right),
      _cell('${byColumn['22oz']}', bold: true, align: pw.TextAlign.right),
      _cell('${byColumn['1L']}', bold: true, align: pw.TextAlign.right),
      _cell('$grand', bold: true, align: pw.TextAlign.right),
    ]));

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3.2),
        1: pw.FlexColumnWidth(1.0),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(1.1),
      },
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#D8D1C7'),
        width: .4,
      ),
      children: rows,
    );
  }


  bool _isHotCoffee(KioskCartItem item) {
    final groupId = item.product.groupId?.trim().toLowerCase();
    final groupName = item.product.groupName?.trim().toLowerCase();
    return groupId == 'hot_coffee' ||
        groupName == 'hot coffee' ||
        item.product.id.trim().toLowerCase().startsWith('hot_');
  }

  pw.Widget _mealTable() {
    final meals = <String, int>{};
    final addons = <String, int>{};
    for (final o in completed) {
      for (final i in o.items) {
        if (i.product.category != KioskCategory.riceMeals) continue;
        meals[i.product.name] = (meals[i.product.name] ?? 0) + i.quantity;
        for (final option in i.options) {
          addons[option.name] = (addons[option.name] ?? 0) + i.quantity;
        }
      }
    }
    if (meals.isEmpty && addons.isEmpty) {
      return _empty('No completed meal sales.');
    }
    final rows = <pw.TableRow>[
      _headerRow(['Meal', 'Qty'])
    ];
    for (final name in meals.keys.toList()..sort()) {
      rows.add(pw.TableRow(children: [
        _cell(name, bold: true),
        _cell('${meals[name]}', align: pw.TextAlign.right)
      ]));
    }

    if (meals.isNotEmpty) {
      rows.add(pw.TableRow(children: [
        _cell('TOTAL MEALS', bold: true),
        _cell('${meals.values.fold(0, (a, b) => a + b)}',
            bold: true, align: pw.TextAlign.right)
      ]));
    }
    if (addons.isNotEmpty) {
      rows.add(_headerRow(['MEAL ADD-ONS', 'Qty']));
      for (final name in addons.keys.toList()..sort()) {
        rows.add(pw.TableRow(children: [
          _cell(name),
          _cell('${addons[name]}', align: pw.TextAlign.right)
        ]));
      }
      rows.add(pw.TableRow(children: [
        _cell('TOTAL MEAL ADD-ONS', bold: true),
        _cell('${addons.values.fold(0, (a, b) => a + b)}',
            bold: true, align: pw.TextAlign.right)
      ]));
    }
    return pw.Table(
        border:
            pw.TableBorder.all(color: PdfColor.fromHex('#D8D1C7'), width: .4),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1)
        },
        children: rows);
  }

  pw.Widget _accessoriesTable() {
    final accessories = <String, int>{};

    for (final o in completed) {
      for (final i in o.items) {
        if (i.product.productType.toLowerCase() != 'accessory') continue;
        accessories[i.product.name] =
            (accessories[i.product.name] ?? 0) + i.quantity;
      }
    }

    if (accessories.isEmpty) {
      return _empty('No completed accessory sales.');
    }

    final rows = <pw.TableRow>[
      _headerRow(['Accessory', 'Qty']),
    ];

    for (final name in accessories.keys.toList()..sort()) {
      rows.add(pw.TableRow(children: [
        _cell(name, bold: true),
        _cell('${accessories[name]}', align: pw.TextAlign.right),
      ]));
    }

    rows.add(pw.TableRow(children: [
      _cell('TOTAL ACCESSORIES', bold: true),
      _cell('${accessories.values.fold(0, (a, b) => a + b)}',
          bold: true, align: pw.TextAlign.right),
    ]));

    return pw.Table(
      border:
          pw.TableBorder.all(color: PdfColor.fromHex('#D8D1C7'), width: .4),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  pw.TableRow _headerRow(List<String> labels) => pw.TableRow(
      children: labels
          .map((s) => pw.Container(
              padding: const pw.EdgeInsets.all(5),
              color: const PdfColor.fromInt(0xFFF7F5F1),
              child: pw.Text(s,
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold))))
          .toList());

  pw.Widget _cell(String text,
          {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  pw.Widget _empty(String text) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#D8D1C7'), width: .5)),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));

  Set<String> _paymentMethods() {
    final result = <String>{};
    for (final o in orders) {
      if (o.paymentMethod.trim().isNotEmpty) {
        result.add(o.paymentMethod);
      }
    }
    if (result.isEmpty) result.addAll(const ['GCash', 'Cash', 'Others']);
    return result;
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


  String _peso(int value) => KioskCurrency.format(value);
  String _timeLabel(DateTime v) =>
      '${v.hour % 12 == 0 ? 12 : v.hour % 12}:${v.minute.toString().padLeft(2, '0')} ${v.hour >= 12 ? 'PM' : 'AM'}';
  String _dateLabel(DateTime v) {
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
      'December'
    ];
    return '${months[v.month - 1]} ${v.day}, ${v.year}';
  }

  String _safeDate() =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
