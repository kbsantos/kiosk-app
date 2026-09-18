import '../../product_catalog/product_catalog_models.dart';
import '../kiosk/orders/kiosk_order.dart';

/// Builds a safe catalog-recovery proposal from historical kiosk transaction
/// snapshots. It only reconstructs variants/options for products that still
/// exist in the current catalog; missing products are deliberately excluded.
class HistoricalCatalogRecoveryResult {
  final ProductCatalog catalog;
  final int recoveredVariants;
  final int recoveredOptionDefinitions;
  final int recoveredProductOptions;
  final List<String> conflicts;

  const HistoricalCatalogRecoveryResult({
    required this.catalog,
    this.recoveredVariants = 0,
    this.recoveredOptionDefinitions = 0,
    this.recoveredProductOptions = 0,
    this.conflicts = const [],
  });

  bool get hasChanges =>
      recoveredVariants > 0 ||
      recoveredOptionDefinitions > 0 ||
      recoveredProductOptions > 0;
}

class HistoricalCatalogRecovery {
  const HistoricalCatalogRecovery._();

  static HistoricalCatalogRecoveryResult recover(
    ProductCatalog current,
    List<KioskOrder> orders,
  ) {
    final products = current.products.toList(growable: true);
    final productIndex = <String, int>{};
    for (var i = 0; i < products.length; i++) {
      productIndex[products[i].productId] = i;
    }

    final definitions = current.optionDefinitions.toList(growable: true);
    final definitionIds = definitions.map((e) => e.optionId).toSet();
    final conflicts = <String>[];

    final variantObservations = <String, _VariantObservation>{};
    final variantConflicts = <String>{};
    final optionObservations = <String, List<_OptionObservation>>{};
    final optionConflicts = <String>{};

    for (final order in orders) {
      for (final item in order.items) {
        final productId = item.product.id.trim();
        final productPosition = productIndex[productId];
        if (productPosition == null) continue;

        final product = products[productPosition];
        final existingVariantIds = product.variants.map((e) => e.variantId).toSet();
        final variant = item.variant;
        if (variant != null) {
          final variantId = variant.id.trim();
          if (variantId.isEmpty || !RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(variantId)) {
            conflicts.add('variant:$productId:$variantId');
          } else if (!existingVariantIds.contains(variantId)) {
          final key = '$productId:$variantId';
          final observation = _VariantObservation(
            productId: productId,
            variantId: variantId,
            name: variant.name,
            price: variant.price,
          );
          final previous = variantObservations[key];
          if (previous != null && !previous.matches(observation)) {
            variantConflicts.add(key);
          } else {
            variantObservations[key] = observation;
          }
          }
        }

        final existingOptionIds = product.options.map((e) => e.optionId).toSet();
        for (final option in item.options) {
          final optionId = option.id.trim();
          if (optionId.isEmpty || !RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(optionId)) {
            conflicts.add('option-definition:$optionId');
            continue;
          }
          final observation = _OptionObservation(
            productId: productId,
            productType: product.productType,
            optionId: optionId,
            name: option.name,
            price: option.price,
            kitchenPrepared: option.kitchenPrepared,
          );
          optionObservations.putIfAbsent(optionId, () => []).add(observation);

          if (existingOptionIds.contains(optionId)) continue;
          // A product assignment can only be recovered from an unambiguous
          // historical observation for that product.
          final assignmentKey = '$productId:$optionId';
          final sameProduct = optionObservations[optionId]!
              .where((candidate) => candidate.productId == productId)
              .toList(growable: false);
          if (sameProduct.length > 1 &&
              sameProduct.any((candidate) => !candidate.matches(observation))) {
            optionConflicts.add(assignmentKey);
          }
        }
      }
    }

    var recoveredVariants = 0;
    for (final entry in variantObservations.entries) {
      if (variantConflicts.contains(entry.key)) {
        conflicts.add('variant:${entry.key}');
        continue;
      }
      final observation = entry.value;
      final index = productIndex[observation.productId];
      if (index == null) continue;
      final product = products[index];
      if (product.variants.any((v) => v.variantId == observation.variantId)) continue;

      products[index] = product.copyWith(
        variants: [
          ...product.variants,
          ProductVariant(
            variantId: observation.variantId,
            name: observation.name,
            price: observation.price,
            active: true,
          ),
        ],
      );
      recoveredVariants++;
    }

    var recoveredOptionDefinitions = 0;
    for (final entry in optionObservations.entries) {
      final optionId = entry.key;
      if (definitionIds.contains(optionId)) continue;

      final observations = entry.value;
      final names = observations.map((e) => e.name.trim()).toSet();
      final kitchenFlags = observations.map((e) => e.kitchenPrepared).toSet();
      if (names.length != 1 || kitchenFlags.length != 1) {
        conflicts.add('option-definition:$optionId');
        continue;
      }

      final prices = observations.map((e) => e.price).toSet();
      final productTypes = observations
          .map((e) => e.productType.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      definitions.add(
        CatalogOptionDefinition(
          optionId: optionId,
          name: observations.first.name,
          productTypes: productTypes,
          price: prices.length == 1 ? prices.single : null,
          active: true,
          kitchenPrepared: kitchenFlags.single,
        ),
      );
      definitionIds.add(optionId);
      recoveredOptionDefinitions++;
    }

    var recoveredProductOptions = 0;
    for (final entry in optionObservations.entries) {
      final optionId = entry.key;
      CatalogOptionDefinition? definition;
      for (final candidate in definitions) {
        if (candidate.optionId == optionId) {
          definition = candidate;
          break;
        }
      }
      if (definition == null) continue;

      final byProduct = <String, List<_OptionObservation>>{};
      for (final observation in entry.value) {
        byProduct.putIfAbsent(observation.productId, () => []).add(observation);
      }

      for (final productEntry in byProduct.entries) {
        final index = productIndex[productEntry.key];
        if (index == null) continue;
        final product = products[index];
        if (product.options.any((option) => option.optionId == optionId)) continue;
        if (!definition.productTypes.contains(product.productType)) {
          conflicts.add('option-assignment:${productEntry.key}:$optionId');
          continue;
        }

        final assignmentKey = '${productEntry.key}:$optionId';
        if (optionConflicts.contains(assignmentKey)) {
          conflicts.add('option-assignment:$assignmentKey');
          continue;
        }

        final observations = productEntry.value;
        final names = observations.map((e) => e.name.trim()).toSet();
        final kitchenFlags = observations.map((e) => e.kitchenPrepared).toSet();
        final prices = observations.map((e) => e.price).toSet();
        if (names.length != 1 || kitchenFlags.length != 1 || prices.length != 1) {
          conflicts.add('option-assignment:$assignmentKey');
          continue;
        }

        products[index] = product.copyWith(
          options: [
            ...product.options,
            ProductOption(
              optionId: optionId,
              name: observations.first.name,
              price: observations.first.price,
              active: true,
              kitchenPrepared: observations.first.kitchenPrepared,
            ),
          ],
        );
        recoveredProductOptions++;
      }
    }

    return HistoricalCatalogRecoveryResult(
      catalog: current.copyWith(
        categories: current.categories,
        optionDefinitions: definitions,
        products: products,
      ),
      recoveredVariants: recoveredVariants,
      recoveredOptionDefinitions: recoveredOptionDefinitions,
      recoveredProductOptions: recoveredProductOptions,
      conflicts: List.unmodifiable(conflicts.toSet().toList()..sort()),
    );
  }
}

class _VariantObservation {
  final String productId;
  final String variantId;
  final String name;
  final num? price;

  const _VariantObservation({
    required this.productId,
    required this.variantId,
    required this.name,
    required this.price,
  });

  bool matches(_VariantObservation other) =>
      name.trim() == other.name.trim() && price == other.price;
}

class _OptionObservation {
  final String productId;
  final String productType;
  final String optionId;
  final String name;
  final num price;
  final bool kitchenPrepared;

  const _OptionObservation({
    required this.productId,
    required this.productType,
    required this.optionId,
    required this.name,
    required this.price,
    required this.kitchenPrepared,
  });

  bool matches(_OptionObservation other) =>
      name.trim() == other.name.trim() &&
      price == other.price &&
      kitchenPrepared == other.kitchenPrepared;
}
