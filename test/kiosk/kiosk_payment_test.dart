import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/payments/kiosk_payment.dart';

void main() {
  test('payment tagging accepts GCash', () async {
    const processor = CounterPaymentProcessor();

    final result = await processor.startPayment(
      amount: 100,
      method: KioskPaymentMethod.gcash,
    );

    expect(result.status, KioskPaymentStatus.pending);
    expect(result.isSuccessful, isFalse);
  });

  test('payment tagging accepts Cash and Others', () async {
    const processor = CounterPaymentProcessor();

    for (final method in KioskPaymentMethod.values) {
      final result = await processor.startPayment(
        amount: 100,
        method: method,
      );
      expect(result.status, KioskPaymentStatus.pending);
    }
  });

  test('payment methods have customer-facing labels', () {
    expect(KioskPaymentMethod.gcash.label, 'GCash');
    expect(KioskPaymentMethod.cash.label, 'Cash');
    expect(KioskPaymentMethod.others.label, 'Others');
  });
}
