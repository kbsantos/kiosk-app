import 'package:bigger_brew_kiosk/features/kiosk/kiosk_idle_timeout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timeout controller starts enabled and uses three minute default', () {
    final controller = KioskIdleTimeoutController();

    controller.start(onTimeout: () {});

    expect(controller.enabled, isTrue);
    expect(controller.timeout, const Duration(minutes: 3));

    controller.dispose();
    expect(controller.enabled, isFalse);
  });

  test('stop disables the timeout and touch does not restart it', () {
    var called = false;
    final controller = KioskIdleTimeoutController();

    controller.start(onTimeout: () => called = true);
    controller.stop();
    controller.touch();

    expect(controller.enabled, isFalse);
    expect(called, isFalse);

    controller.dispose();
  });
}
