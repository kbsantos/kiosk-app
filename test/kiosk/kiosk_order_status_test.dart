import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('queue status labels cover the kiosk lifecycle', () {
    expect(KioskOrderStatus.values, contains(KioskOrderStatus.pending));
    expect(KioskOrderStatus.values, contains(KioskOrderStatus.preparing));
    expect(KioskOrderStatus.values, contains(KioskOrderStatus.ready));
    expect(KioskOrderStatus.values, contains(KioskOrderStatus.completed));
    expect(KioskOrderStatus.values, contains(KioskOrderStatus.cancelled));
  });

  test('status serialization round trips', () {
    for (final status in KioskOrderStatus.values) {
      expect(
        KioskOrderStatusX.fromValue(status.value),
        status,
      );
    }
  });
}
