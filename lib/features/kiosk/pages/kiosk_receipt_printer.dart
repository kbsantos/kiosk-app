import 'dart:typed_data';
import '../currency/kiosk_currency.dart';

import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/kiosk_models.dart';
import '../orders/kiosk_order.dart';
import 'kiosk_bluetooth_printer.dart';
import '../settings/kiosk_settings_repository.dart';

class KioskReceiptPrinter {
  const KioskReceiptPrinter._();

  // Small trailing feed used by production copies so the thermal printer
  // advances the paper far enough for a clean tear/cut.
  static const double _productionBottomFeedMm = 8.0;

  static Future<pw.ThemeData> _pdfTheme() async {
    final regularFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final boldFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    return pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );
  }

  static final KioskSettingsRepository _settingsRepository =
      KioskSettingsRepository();

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static Future<List<Printer>> listAvailablePrinters() async {
    final info = await Printing.info();
    if (!info.canListPrinters) return const <Printer>[];

    final printers = await Printing.listPrinters();
    final available = printers
        .where((printer) => printer.isAvailable != false)
        .toList(growable: false);

    return available;
  }

  static Future<Printer?> findConfiguredPrinter() async {
    final settings = await _settingsRepository.load();
    final printerId = settings.printerId;

    if (printerId == null || printerId.isEmpty) return null;

    final printers = await listAvailablePrinters();

    for (final printer in printers) {
      if (printer.url == printerId) return printer;
    }

    return null;
  }

  static Future<Printer?> findDefaultPrinter() async {
    final printers = await listAvailablePrinters();

    for (final printer in printers) {
      if (printer.isDefault == true) return printer;
    }

    if (printers.length == 1) return printers.first;

    return null;
  }

  /// Prints directly to the configured printer.
  ///
  /// If no printer is configured, or the configured printer is unavailable,
  /// this returns false instead of silently selecting another printer.
  /// The caller may then decide whether to offer a manual print fallback.
  static Future<bool> printOrder(
    KioskOrder order, {
    bool allowPrintDialogFallback = true,
    bool includeCustomerReceipt = true,
    bool? includeBaristaCopy,
    bool? includeKitchenCopy,
  }) async {
    final info = await Printing.info();
    final settings = await _settingsRepository.load();
    final effectiveBaristaCopy = includeBaristaCopy ?? settings.printBaristaCopy;
    final effectiveKitchenCopy = includeKitchenCopy ?? settings.printKitchenCopy;

    if (settings.printerConnectionType == 'bluetooth' &&
        settings.bluetoothPrinterAddress != null) {
      final address = settings.bluetoothPrinterAddress!;
      var connected = await KioskBluetoothPrinter.isConnected();
      if (!connected) connected = await KioskBluetoothPrinter.connect(address);

      if (connected) {
        final printed = await KioskBluetoothPrinter.printOrder(
          order: order,
          paperSize: settings.printerPaperSize,
          includeCustomerReceipt: includeCustomerReceipt,
          includeBaristaCopy: effectiveBaristaCopy,
          includeKitchenCopy: effectiveKitchenCopy,
          openCashDrawer: includeCustomerReceipt &&
              settings.openCashDrawerOnCashPayment &&
              order.paymentMethod.trim().toLowerCase() == 'cash' &&
              order.paymentStatus.trim().toLowerCase() == 'paid',
        );
        if (printed) return true;
      }
    }

    Future<bool> direct(Printer printer) async {
      return await Printing.directPrintPdf(
        printer: printer,
        name: 'Bigger Brew ${order.orderNumber}',
        onLayout: (_) => buildPdf(
          order,
          paperSize: settings.printerPaperSize,
          includeCustomerReceipt: includeCustomerReceipt,
          includeBaristaCopy: effectiveBaristaCopy,
          includeKitchenCopy: effectiveKitchenCopy,
        ),
      );
    }

    if (info.directPrint) {
      final printer = await findConfiguredPrinter();
      if (printer != null) return direct(printer);

      if (settings.printerId == null) {
        final fallbackPrinter = await findDefaultPrinter();
        if (fallbackPrinter != null) return direct(fallbackPrinter);
      }
    }

    if (!allowPrintDialogFallback) return false;

    return await Printing.layoutPdf(
      name: 'Bigger Brew ${order.orderNumber}',
      onLayout: (_) => buildPdf(
        order,
        paperSize: settings.printerPaperSize,
        includeCustomerReceipt: includeCustomerReceipt,
        includeBaristaCopy: effectiveBaristaCopy,
        includeKitchenCopy: effectiveKitchenCopy,
      ),
    );
  }

  static Future<bool> testPrint({
    required Printer printer,
    required String paperSize,
  }) async {
    return await Printing.directPrintPdf(
      printer: printer,
      name: 'Bigger Brew Printer Test',
      onLayout: (_) => buildTestPdf(paperSize: paperSize),
    );
  }

  static Future<Uint8List> buildTestPdf({
    required String paperSize,
  }) async {
    final doc = pw.Document(theme: await _pdfTheme());
    final width = paperSize == '58mm' ? 58.0 : 80.0;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          width * PdfPageFormat.mm,
          140 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'BIGGER BREW',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'PRINTER TEST',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Paper size: $paperSize'),
            pw.Text('Connection: OK'),
            pw.Text('Date: ${_time(DateTime.now())}'),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'TEST SUCCESSFUL',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static String _kitchenItemLine(KioskCartItem item) {
    return '${item.quantity} x ${item.product.name}';
  }

  static List<KioskCartItem> _baristaItems(KioskOrder order) {
    return order.items
        .where((item) => item.product.productType.toLowerCase() == 'drink')
        .toList(growable: false);
  }

  static List<KioskCartItem> _kitchenItems(KioskOrder order) {
    return order.items
        .where(
          (item) =>
              item.product.kitchenPrepared ||
              item.options.any((o) => o.kitchenPrepared),
        )
        .toList(growable: false);
  }

  static Future<Uint8List> buildPdf(
    KioskOrder order, {
    String paperSize = '80mm',
    bool includeCustomerReceipt = true,
    bool includeBaristaCopy = true,
    bool includeKitchenCopy = true,
  }) async {
    final doc = pw.Document(theme: await _pdfTheme());
    final width = paperSize == '58mm' ? 58.0 : 80.0;
    final baristaItems = includeBaristaCopy ? _baristaItems(order) : const <KioskCartItem>[];
    final kitchenItems = includeKitchenCopy ? _kitchenItems(order) : const <KioskCartItem>[];

    // A fixed 180mm page was too short for the combined customer + barista +
    // kitchen receipt. The PDF printer preview therefore clipped the kitchen
    // copy. Give the receipt a dynamic height so all copies stay on ONE
    // continuous receipt/page.
    var productionHeight = 0.0;
    for (final item in baristaItems) {
      productionHeight += 18;
      if (item.variant != null) productionHeight += 8;
      productionHeight += item.options.length * 8;
    }
    for (final item in kitchenItems) {
      productionHeight += 18;
      if (item.variant != null) productionHeight += 8;
      productionHeight += item.options.where((o) => o.kitchenPrepared).length * 8;
    }
    // Customer receipts keep their established 210mm base. Production-only
    // copies use content-driven height so there is no artificial blank space
    // above or below a Barista/Kitchen ticket.
    final copyHeaderHeight =
        (baristaItems.isNotEmpty ? 20.0 : 0.0) +
        (kitchenItems.isNotEmpty ? 20.0 : 0.0);
    final hasProductionCopy = baristaItems.isNotEmpty || kitchenItems.isNotEmpty;
    final pageHeightMm = (includeCustomerReceipt ? 210.0 : 0.0) +
        copyHeaderHeight +
        productionHeight +
        (hasProductionCopy ? _productionBottomFeedMm : 0.0);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          width * PdfPageFormat.mm,
          pageHeightMm * PdfPageFormat.mm,
          // Keep the physical page flush vertically. Any horizontal margin is
          // applied inside the document so Barista/Kitchen copies have no
          // artificial top or bottom page margin.
          marginAll: 0,
        ),
        build: (_) {
          return pw.Padding(
            padding: pw.EdgeInsets.symmetric(
              horizontal: 5 * PdfPageFormat.mm,
            ),
            child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (includeCustomerReceipt) ...[
              pw.Center(
                child: pw.Text(
                  'BIGGER BREW',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'MILKTEA • COFFEE',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  order.orderNumber,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  _time(order.createdAt),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('ORDER TYPE: ${order.orderType}'),
              pw.Text('PAYMENT: ${order.paymentMethod}'),
              pw.Text('ORDER MODE: ${order.orderMode}'),
              pw.Text('STATUS: ${order.paymentStatus.toUpperCase()}'),
              pw.Divider(),
              ...order.items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${item.quantity} x ${item.product.name}',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Text(KioskCurrency.formatCode(item.total)),
                        ],
                      ),
                      if (item.size != null)
                        pw.Text(
                          '  ${item.size!.name}'
                          '${item.size!.displayVolume == null ? '' : ' • ${item.size!.displayVolume}'}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (item.variant != null)
                        pw.Text(
                          '  ${item.variant!.name}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (item.options.isNotEmpty)
                        pw.Text(
                          '  ${item.options.map((o) => o.name).join(' • ')}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    KioskCurrency.formatCode(order.total),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ],
              if (baristaItems.isNotEmpty) ...[
                pw.Divider(thickness: 1.5),
                pw.Center(
                  child: pw.Text(
                    'BARISTA COPY',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'ORDER ${order.orderNumber}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                ...baristaItems.asMap().entries.map(
                  (entry) => pw.Padding(
                    padding: pw.EdgeInsets.only(
                      bottom: entry.key == baristaItems.length - 1 ? 0 : 7,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          '${entry.value.quantity} x ${entry.value.product.name}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        if (entry.value.size != null)
                          pw.Text(
                            '  ${entry.value.size!.name}'
                            '${entry.value.size!.displayVolume == null ? '' : ' • ${entry.value.size!.displayVolume}'}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        if (entry.value.variant != null)
                          pw.Text(
                            '  ${entry.value.variant!.name}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ...entry.value.options.map(
                          (option) => pw.Text(
                            '  + ${option.name}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (kitchenItems.isNotEmpty) ...[
                pw.Divider(thickness: 1.5),
                pw.Center(
                  child: pw.Text(
                    'KITCHEN COPY',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'ORDER ${order.orderNumber}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                ...kitchenItems.asMap().entries.map(
                  (entry) => pw.Padding(
                    padding: pw.EdgeInsets.only(
                      bottom: entry.key == kitchenItems.length - 1 ? 0 : 7,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          _kitchenItemLine(entry.value),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (entry.value.size != null)
                          pw.Text(
                            '  ${entry.value.size!.name}'
                            '${entry.value.size!.displayVolume == null ? '' : ' • ${entry.value.size!.displayVolume}'}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        if (entry.value.variant != null)
                          pw.Text(
                            '  ${entry.value.variant!.name}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ...entry.value.options.where((o) => o.kitchenPrepared).map(
                              (option) => pw.Text(
                                '  + ${option.name}',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                pw.Divider(),
              ],
              if (hasProductionCopy)
                pw.SizedBox(height: _productionBottomFeedMm * PdfPageFormat.mm),
            ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}
