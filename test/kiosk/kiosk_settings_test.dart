import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/settings/kiosk_settings_repository.dart';

void main() {
  test('default kiosk settings keep the store open', () {
    const settings = KioskSettings();

    expect(settings.storeOpen, isTrue);
    expect(settings.storeName, 'BIGGER BREW');
    expect(settings.printerPaperSize, '58mm');
    expect(settings.employeeOrderMode, isTrue);
    expect(settings.printCustomerReceipt, isTrue);
    expect(settings.autoPrintReceipt, isTrue);
    expect(settings.printOrderTicket, isTrue);
    expect(settings.printBaristaCopy, isTrue);
    expect(settings.printKitchenCopy, isTrue);
    expect(settings.printSingleItemPerTicket, isFalse);
    expect(settings.groupIdenticalItems, isTrue);
    expect(settings.currencyCode, 'PHP');
    expect(settings.openCashDrawerOnCashPayment, isFalse);
  });

  test('settings copyWith changes only requested values', () {
    const settings = KioskSettings();

    final closed = settings.copyWith(storeOpen: false);
    expect(closed.storeOpen, isFalse);
    expect(closed.storeName, 'BIGGER BREW');
    expect(closed.printerPaperSize, '58mm');

    final narrow = closed.copyWith(printerPaperSize: '58mm');
    expect(narrow.storeOpen, isFalse);
    expect(narrow.printerPaperSize, '58mm');
    expect(narrow.employeeOrderMode, isTrue);

    final employee = narrow.copyWith(employeeOrderMode: true);
    expect(employee.employeeOrderMode, isTrue);
    expect(employee.storeOpen, isFalse);

    final copies = employee.copyWith(
      printBaristaCopy: false,
      printKitchenCopy: false,
    );
    expect(copies.printBaristaCopy, isFalse);
    expect(copies.printKitchenCopy, isFalse);

    final drawer = employee.copyWith(openCashDrawerOnCashPayment: true);
    expect(drawer.openCashDrawerOnCashPayment, isTrue);
    expect(drawer.currencyCode, 'PHP');
  });
}

