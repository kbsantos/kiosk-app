import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/currency/kiosk_currency.dart';

void main() {
  setUp(() => KioskCurrency.setCode('PHP'));

  test('defaults to PHP', () {
    expect(KioskCurrency.code, 'PHP');
    expect(KioskCurrency.symbol, '₱');
    expect(KioskCurrency.format(124), '₱124');
    expect(KioskCurrency.format(12345), '₱12,345');
  });

  test('formats using selected currency', () {
    KioskCurrency.setCode('USD');
    expect(KioskCurrency.format(124), r'$124');
    expect(KioskCurrency.code, 'USD');
  });

  test('invalid currency falls back to PHP', () {
    KioskCurrency.setCode('XYZ');
    expect(KioskCurrency.code, 'PHP');
  });
}
