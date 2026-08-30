import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';

void main() {
  test('KioskCategory.fromCatalog supports dynamically created categories', () {
    final category = KioskCategory.fromCatalog(
      id: 'custom_drinks',
      title: 'Custom Drinks',
    );

    expect(category.id, 'custom_drinks');
    expect(category.title, 'Custom Drinks');
    expect(category.icon, '📦');
  });

  test('KioskCategory.fromCatalog preserves built-in category identity', () {
    final category = KioskCategory.fromCatalog(
      id: 'coffee',
      title: 'Custom Coffee Title',
    );

    expect(category, KioskCategory.coffee);
    expect(category.title, 'Coffee');
    expect(category.icon, '☕');
  });
  test('KioskCategory.fromCatalog uses a configured custom icon', () {
    final category = KioskCategory.fromCatalog(
      id: 'custom_drinks',
      title: 'Custom Drinks',
      icon: '⭐',
    );

    expect(category.id, 'custom_drinks');
    expect(category.title, 'Custom Drinks');
    expect(category.icon, '⭐');
  });

  test('built-in category keeps its default icon when no custom icon is set', () {
    final category = KioskCategory.fromCatalog(
      id: 'coffee',
      title: 'Custom Coffee Title',
    );

    expect(category, KioskCategory.coffee);
    expect(category.icon, '☕');
  });
}
