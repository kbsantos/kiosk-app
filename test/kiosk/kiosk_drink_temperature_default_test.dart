import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/services/kiosk_historical_drink_temperature_sync.dart';

void main() {
  const sync = HistoricalDrinkTemperatureSync();

  test('drink catalog products default to iced when temperature is absent', () {
    expect(
      sync.resolveTemperature(
        productType: 'drink',
        currentCatalogTemperature: null,
        productName: 'Latte',
      ),
      'iced',
    );
  });

  test('explicit transaction temperature is preserved', () {
    expect(
      sync.resolveTemperature(
        productType: 'drink',
        existingTemperature: 'hot',
        currentCatalogTemperature: 'iced',
        productName: 'Latte',
      ),
      'hot',
    );
  });

  test('legacy Hot Coffee is classified as hot', () {
    expect(
      sync.resolveTemperature(
        productType: 'drink',
        productName: 'Hot Coffee',
        groupName: 'Hot Coffee',
        groupId: 'hot_coffee',
      ),
      'hot',
    );
  });

  test('legacy drinks use current catalog temperature when available', () {
    expect(
      sync.resolveTemperature(
        productType: 'drink',
        productName: 'Latte',
        currentCatalogTemperature: 'hot',
      ),
      'hot',
    );

    expect(
      sync.resolveTemperature(
        productType: 'drink',
        productName: 'Latte',
        currentCatalogTemperature: 'iced',
      ),
      'iced',
    );
  });

  test('unknown legacy drinks fall back to iced', () {
    expect(
      sync.resolveTemperature(
        productType: 'drink',
        productName: 'Legacy Drink',
      ),
      'iced',
    );
  });

  test('non-drinks never receive a drink temperature', () {
    expect(
      sync.resolveTemperature(
        productType: 'meal',
        currentCatalogTemperature: 'hot',
        productName: 'Fried Chicken',
      ),
      isNull,
    );

    expect(
      sync.shouldUpdate(
        productType: 'accessory',
      ),
      isFalse,
    );
  });
}
