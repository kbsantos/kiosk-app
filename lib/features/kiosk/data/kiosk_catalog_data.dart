import '../../../product_catalog/kiosk_catalog_adapter.dart';
import '../../../product_catalog/product_catalog_repository.dart';
import '../models/kiosk_models.dart';

/// Kiosk-side catalog loader.
///
/// The Product Catalog is the single source of truth for commercial product,
/// category, size, variant, and option data. This projection must preserve
/// those values exactly so customer-facing kiosk screens stay synchronized
/// with Catalog Management.
class KioskCatalogData {
  const KioskCatalogData._();

  static const _repository = ProductCatalogRepository();
  static const _adapter = KioskCatalogAdapter();

  static Future<Map<KioskCategory, List<KioskProduct>>> load() async {
    final catalog = await _repository.load();

    // Only active categories are exposed to the customer kiosk. The
    // Category Manager's `active` flag is the source of truth for category
    // visibility; inactive categories must not appear as empty/"Coming soon"
    // tiles.
    final result = <KioskCategory, List<KioskProduct>>{};

    for (final catalogCategory
        in catalog.categories.where((category) => category.active)) {
      final category = KioskCategory.fromCatalog(
        id: catalogCategory.categoryId,
        title: catalogCategory.name,
        icon: catalogCategory.icon,
      );

      final kioskProducts = _adapter.productsForCategory(catalog, category.id);
      final products = <KioskProduct>[];

      for (final product in kioskProducts) {
        // Product-specific assignments take precedence. When none are
        // assigned, fall back to the active shared option definitions that
        // match the product type (for example, shared `drink` add-ons).
        final productOptions = product.options.where((option) => option.active).toList(growable: false);
        final sharedOptions = catalog.optionDefinitions
            .where((option) =>
                option.active &&
                option.productTypes.any(
                  (type) => type.trim().toLowerCase() ==
                      product.productType.trim().toLowerCase(),
                ))
            .toList(growable: false);

        // Never invent a zero selling price for an option. Only options
        // with an explicit catalog price are customer-selectable.
        final effectiveOptions = productOptions.isNotEmpty
            ? productOptions
                .where((option) => option.price != null)
                .map(
                  (option) => KioskCatalogOption(
                    id: option.optionId,
                    name: option.name,
                    price: option.price!.toInt(),
                    kitchenPrepared: option.kitchenPrepared,
                  ),
                )
            : sharedOptions
                .where((option) => option.price != null)
                .map(
                  (option) => KioskCatalogOption(
                    id: option.optionId,
                    name: option.name,
                    price: option.price!.toInt(),
                    kitchenPrepared: option.kitchenPrepared,
                  ),
                );

        products.add(
          KioskProduct(
            id: product.productId,
            name: product.name,
            // Product-level price is authoritative for products without
            // size/variant pricing (for example rice meals and accessories).
            // A single configured variant is retained as a compatibility
            // fallback for legacy catalog records.
            price: product.price?.toInt() ??
                (product.variants
                            .where((v) => v.active && v.price != null)
                            .length ==
                        1
                    ? product.variants
                        .firstWhere((v) => v.active && v.price != null)
                        .price
                        ?.toInt()
                    : null),
            category: category,
            available: product.available,
            recipeRef: product.recipeRef,
            groupId: product.groupId,
            groupName: product.groupName,
            productType: product.productType,
            drinkTemperature: product.drinkTemperature,
            kitchenPrepared: product.kitchenPrepared,
            variants: product.variants
                .where((variant) => variant.active)
                .map(
                  (variant) => KioskVariant(
                    id: variant.variantId,
                    name: variant.name,
                    price: variant.price?.toInt(),
                    active: variant.active,
                  ),
                )
                .toList(growable: false),
            sizes: product.sizes
                .map(
                  (size) => KioskSize(
                    id: size.sizeId,
                    name: size.name,
                    volumeMl: size.volumeMl,
                    displayVolume: size.displayVolume,
                    price: size.price?.toInt(),
                  ),
                )
                .toList(growable: false),
            options: effectiveOptions.toList(growable: false),
          ),
        );
      }

      result[category] = products;
    }

    return result;
  }
}
