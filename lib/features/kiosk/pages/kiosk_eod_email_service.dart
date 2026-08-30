import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

import '../orders/kiosk_order.dart';
import 'kiosk_eod_pdf_report_page.dart';

class KioskEodEmailService {
  static Future<void> sendReport({
    required String recipient,
    required DateTime date,
    required List<KioskOrder> orders,
    required String storeName,
  }) async {
    final pdfBytes = await KioskEodPdfReportPage(
      date: date,
      orders: orders,
    ).buildPdf();

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${_fileName(date)}');
    await file.writeAsBytes(pdfBytes, flush: true);

    final email = Email(
      body:
          'Attached is the End-of-Day report for ${_dateLabel(date)} from $storeName.',
      subject: '$storeName EOD Report - ${_dateLabel(date)}',
      recipients: [recipient],
      attachmentPaths: [file.path],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);

  }

  static String _fileName(DateTime date) =>
      'Bigger_Brew_EOD_${_safeDate(date)}.pdf';

  static String _safeDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime date) {
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
}
