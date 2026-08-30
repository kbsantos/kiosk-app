import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/kiosk_idle_timeout.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/kiosk/payments/kiosk_payment.dart';
import 'package:bigger_brew_kiosk/features/kiosk/settings/kiosk_settings_repository.dart';
import 'package:bigger_brew_kiosk/features/kiosk/staff/kiosk_staff_gate.dart';

void main() {
  tearDown(KioskStaffGate.endSession);

  test('release: size-based drink price and add-on total remain correct', () {
    const drink = KioskProduct(
      id: 'classic_milk_tea',
      name: 'Classic Milk Tea',
      price: null,
      category: KioskCategory.milkTea,
      sizes: [
        KioskSize(
          id: '22oz',
          name: 'Go Big',
          displayVolume: '22oz',
          volumeMl: 650,
          price: 79,
        ),
      ],
    );
    const pearl = KioskOption(
      id: 'pearls',
      name: 'Pearls',
      price: 10,
    );

    final item = KioskCartItem(
      product: drink,
      size: drink.sizes.single,
      quantity: 2,
      options: [pearl],
    );

    expect(item.unitPrice, 89);
    expect(item.total, 178);
  });

  test('release: rice meal retains kitchen preparation metadata', () {
    const meal = KioskProduct(
      id: 'hungarian_sausage_egg',
      name: 'Hungarian Sausage w/ Egg',
      price: 85,
      category: KioskCategory.riceMeals,
      productType: 'food',
      kitchenPrepared: true,
    );
    const extraRice = KioskOption(
      id: 'extra_rice',
      name: 'Extra Rice',
      price: 20,
      kitchenPrepared: true,
    );

    const item = KioskCartItem(
      product: meal,
      options: [extraRice],
    );

    expect(item.product.kitchenPrepared, isTrue);
    expect(item.options.single.kitchenPrepared, isTrue);
    expect(item.total, 105);
  });

  test(
      'release: order JSON round-trip preserves size, options and payment data',
      () {
    const product = KioskProduct(
      id: 'classic_milk_tea',
      name: 'Classic Milk Tea',
      price: null,
      category: KioskCategory.milkTea,
      sizes: [
        KioskSize(
          id: 'regular',
          name: 'Regular',
          displayVolume: '12oz',
          volumeMl: 360,
          price: 59,
        ),
      ],
    );
    final item = KioskCartItem(
      product: product,
      size: product.sizes.single,
      quantity: 2,
      options: const [
        KioskOption(id: 'pearls', name: 'Pearls', price: 10),
      ],
    );

    final original = KioskOrder(
      id: 'release-test',
      orderNumber: '9001',
      createdAt: DateTime(2026, 8, 18, 10, 30),
      orderType: 'Take Out',
      paymentMethod: 'GCash',
      paymentStatus: 'paid',
      orderMode: 'Employee',
      status: KioskOrderStatus.completed,
      items: [item],
      total: 138,
    );

    final restored = KioskOrder.fromJson(original.toJson());
    final restoredItem = restored.items.single;

    expect(restored.orderNumber, '9001');
    expect(restored.paymentMethod, 'GCash');
    expect(restored.paymentStatus, 'paid');
    expect(restored.orderMode, 'Employee');
    expect(restored.status, KioskOrderStatus.completed);
    expect(restoredItem.quantity, 2);
    expect(restoredItem.size?.displayVolume, '12oz');
    expect(restoredItem.size?.price, 59);
    expect(restoredItem.options.single.name, 'Pearls');
    expect(restoredItem.options.single.price, 10);
  });

  test('release: customer defaults remain safe for production', () {
    const settings = KioskSettings();

    expect(settings.storeOpen, isTrue);
    expect(settings.employeeOrderMode, isTrue);
    expect(settings.storeName, 'BIGGER BREW');
    expect(settings.printerPaperSize, '58mm');
  });

  test('release: counter payment processor records pending payment', () async {
    const processor = CounterPaymentProcessor();

    final result = await processor.startPayment(
      amount: 100,
      method: KioskPaymentMethod.cash,
    );

    expect(result.status, KioskPaymentStatus.pending);
    expect(result.isSuccessful, isFalse);
    expect(result.reference, isNull);
  });

  test('release: staff mode starts locked and uses 30-minute session', () {
    KioskStaffGate.endSession();

    expect(KioskStaffGate.isSessionActive, isFalse);
    expect(
      KioskStaffGate.sessionDuration,
      const Duration(minutes: 30),
    );
  });

  test('release: idle timeout can be stopped for staff mode', () {
    final controller = KioskIdleTimeoutController();

    controller.start(onTimeout: () {});
    expect(controller.enabled, isTrue);

    controller.stop();
    expect(controller.enabled, isFalse);

    controller.dispose();
  });

  test('release: kiosk category IDs remain stable for stored orders', () {
    expect(KioskCategory.milkTea.id, 'milk_tea');
    expect(KioskCategory.riceMeals.id, 'rice_meals');
    expect(KioskCategory.slushies.id, 'slushies');
    expect(
      KioskCategory.fromId('rice_meals'),
      KioskCategory.riceMeals,
    );
  });
}
