import '../../../product_catalog/kiosk_catalog_adapter.dart';
import '../../catalog/store_catalog_sync_service.dart';
import '../../../product_catalog/product_catalog_repository.dart';
import '../../../product_catalog/product_catalog_models.dart';
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
  static final _storeCatalogSync = StoreCatalogSyncService();

  /// Returns only active, priced options explicitly assigned to [product].
  /// Shared option definitions are intentionally not inherited by product
  /// type; assignment is the gate that makes an option customer-selectable.
  static List<KioskCatalogOption> optionsForProduct(
    ProductCatalog catalog,
    KioskCatalogProduct product,
  ) {
    // The product assignment itself is the source of truth for whether an
    // add-on is exposed. Shared definitions are not inherited implicitly.
    // Keep only assignments whose definitions still exist and are active in
    // the current Store Master catalog.
    final definitionsById = {
      for (final definition in catalog.optionDefinitions)
        definition.optionId: definition,
    };

    return product.options
        .where((option) {
          final definition = definitionsById[option.optionId];
          final normalizedProductType =
              product.productType.trim().toLowerCase();
          final compatibleType = definition == null ||
              definition.productTypes.isEmpty ||
              definition.productTypes.any(
                (type) => type.trim().toLowerCase() == normalizedProductType,
              );
          return option.active &&
              option.price != null &&
              definition != null &&
              definition.active &&
              compatibleType;
        })
        .map(
          (option) => KioskCatalogOption(
            id: option.optionId,
            name: option.name,
            price: option.price!.toInt(),
            kitchenPrepared: option.kitchenPrepared,
          ),
        )
        .toList(growable: false);
  }

  static Future<Map<KioskCategory, List<KioskProduct>>> load() async {
    // Automatically pull a newer store-master catalog when available. Any
    // network/configuration failure is intentionally ignored so the kiosk
    // continues using its last known-good local catalog.
    await _storeCatalogSync.refreshIfMasterChanged();
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
        // Customer-facing add-ons are strictly product-specific. A shared
        // option definition is only a reusable definition in Catalog
        // Management; it must not appear at checkout until it is explicitly
        // assigned to this product.
        final effectiveOptions = optionsForProduct(catalog, product);

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
