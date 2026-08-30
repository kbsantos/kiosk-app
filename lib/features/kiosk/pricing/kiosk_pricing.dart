import '../models/kiosk_models.dart';

/// Central commercial pricing resolver for the kiosk.
///
/// The Product Catalog is the single source of truth. This class intentionally
/// contains no hard-coded selling-price table. Kiosk products already carry
/// their catalog-approved base/size/variant prices after loading through
/// KioskCatalogData.
class KioskPricing {
  const KioskPricing();

  /// Returns the product-level price.
  ///
  /// This is used when the product does not have a selected size or variant.
  int? productPrice(KioskProduct product) => product.price;

  /// Returns the configured price for a product size.
  ///
  /// The supplied [size] is only valid when that size is configured on the
  /// product. Otherwise, null is returned.
  int? sizePrice(KioskProduct product, KioskSize size) {
    final configured = product.sizes.where(
      (candidate) => candidate.id == size.id,
    );

    if (configured.isEmpty) {
      return null;
    }

    return configured.first.price;
  }

  /// Returns the configured price for a product variant.
  ///
  /// Inactive variants are not sellable and therefore return null.
  int? variantPrice(
    KioskProduct product,
    KioskVariant variant,
  ) {
    final configured = product.variants.where(
      (candidate) => candidate.id == variant.id,
    );

    if (configured.isEmpty || !configured.first.active) {
      return null;
    }

    return configured.first.price;
  }

  /// Resolves the final unit selling price.
  ///
  /// Price precedence:
  ///
  /// 1. Configured size price
  /// 2. Configured active variant price
  /// 3. Product base price
  ///
  /// Any configured option/add-on prices are then added to the base price.
  int? resolveUnitPrice(
    KioskProduct product, {
    KioskSize? size,
    KioskVariant? variant,
    List<KioskOption> options = const [],
  }) {
    final base = size != null
        ? sizePrice(product, size)
        : variant != null
            ? variantPrice(product, variant)
            : productPrice(product);

    if (base == null) {
      return null;
    }

    return base +
        options.fold<int>(
          0,
          (sum, option) => sum + option.price,
        );
  }
}
