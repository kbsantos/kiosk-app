/// Utilities for one-time historical drink-temperature migration.
///
/// Migration rule:
///   1. Never overwrite an item that already has drinkTemperature.
///   2. For legacy drink items without a value, use the current catalog value.
///   3. If the current catalog has no value, legacy Hot Coffee is Hot.
///   4. Otherwise default to Iced.
///
/// The caller owns persistence and backup. This service only computes the
/// safe update so it can be used by a repository/maintenance screen.
class HistoricalDrinkTemperatureSync {
  const HistoricalDrinkTemperatureSync();

  String? resolveTemperature({
    required String productType,
    String? existingTemperature,
    String? currentCatalogTemperature,
    String? productName,
    String? groupName,
    String? groupId,
  }) {
    if (existingTemperature != null &&
        existingTemperature.trim().isNotEmpty) {
      return existingTemperature.trim().toLowerCase();
    }

    if (productType.trim().toLowerCase() != 'drink') {
      return null;
    }

    if (currentCatalogTemperature != null &&
        currentCatalogTemperature.trim().isNotEmpty) {
      return currentCatalogTemperature.trim().toLowerCase();
    }

    final name = productName?.trim().toLowerCase() ?? '';
    final group = groupName?.trim().toLowerCase() ?? '';
    final id = groupId?.trim().toLowerCase() ?? '';

    if (name == 'hot coffee' ||
        group == 'hot coffee' ||
        id == 'hot_coffee') {
      return 'hot';
    }

    return 'iced';
  }

  bool shouldUpdate({
    required String productType,
    String? existingTemperature,
  }) {
    return productType.trim().toLowerCase() == 'drink' &&
        (existingTemperature == null ||
            existingTemperature.trim().isEmpty);
  }
}
