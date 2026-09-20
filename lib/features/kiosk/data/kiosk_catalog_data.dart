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

  static List<KioskCatalogOption> automaticChargesForProduct(
    ProductCatalog catalog,
    KioskCatalogProduct product,
  ) {
    final categoryId = product.categoryId;
    final productType = product.productType.trim().toLowerCase();
    return catalog.automaticCharges
        .where((charge) => charge.active && charge.amount >= 0)
        .where((charge) {
          switch (charge.scope.trim().toLowerCase()) {
            case 'product':
              return charge.productIds.contains(product.productId);
            case 'product_type':
              return charge.productTypes.any(
                (type) => type.trim().toLowerCase() == productType,
              );
            case 'category':
            default:
              return charge.categoryIds.contains(categoryId);
          }
        })
        .map(
          (charge) => KioskCatalogOption(
            id: charge.chargeId,
            name: charge.name,
            price: charge.amount.toInt(),
            automatic: true,
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
        final selectableOptions = productOptions.isNotEmpty
            ? productOptions
                .where((option) => option.price != null)
                .map(
                  (option) => KioskCatalogOption(
                    id: option.optionId,
                    name: option.name,
                    price: option.price!.toInt(),
                    kitchenPrepared: option.kitchenPrepared,
                    autoApply: option.autoApply,
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
        final effectiveOptions = [
          ...selectableOptions,
          ...automaticChargesForProduct(catalog, product),
        ];

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
