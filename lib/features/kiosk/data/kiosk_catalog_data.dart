import 'dart:async';

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

  static List<ProductOption> _orderedProductOptions(
    Iterable<ProductOption> options,
  ) {
    final indexed = options.toList(growable: false).asMap().entries.toList();
    indexed.sort((a, b) {
      final aOrder = a.value.sortOrder;
      final bOrder = b.value.sortOrder;
      if (aOrder != null && bOrder != null) {
        final result = aOrder.compareTo(bOrder);
        return result != 0 ? result : a.key.compareTo(b.key);
      }
      if (aOrder != null) return -1;
      if (bOrder != null) return 1;
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }


  static List<ProductSize> _orderedSizes(Iterable<ProductSize> sizes) {
    final indexed = sizes.toList(growable: false).asMap().entries.toList();
    indexed.sort((a, b) {
      final aOrder = a.value.sortOrder;
      final bOrder = b.value.sortOrder;
      if (aOrder != null && bOrder != null) {
        final result = aOrder.compareTo(bOrder);
        return result != 0 ? result : a.key.compareTo(b.key);
      }
      if (aOrder != null) return -1;
      if (bOrder != null) return 1;
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  static List<ProductVariant> _orderedVariants(Iterable<ProductVariant> variants) {
    final indexed = variants.toList(growable: false).asMap().entries.toList();
    indexed.sort((a, b) {
      final aOrder = a.value.sortOrder;
      final bOrder = b.value.sortOrder;
      if (aOrder != null && bOrder != null) {
        final result = aOrder.compareTo(bOrder);
        return result != 0 ? result : a.key.compareTo(b.key);
      }
      if (aOrder != null) return -1;
      if (bOrder != null) return 1;
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  static List<CatalogOptionDefinition> _orderedOptionDefinitions(
    Iterable<CatalogOptionDefinition> options,
  ) {
    final indexed = options.toList(growable: false).asMap().entries.toList();
    indexed.sort((a, b) {
      final aOrder = a.value.sortOrder;
      final bOrder = b.value.sortOrder;
      if (aOrder != null && bOrder != null) {
        final result = aOrder.compareTo(bOrder);
        return result != 0 ? result : a.key.compareTo(b.key);
      }
      if (aOrder != null) return -1;
      if (bOrder != null) return 1;
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  static Future<Map<KioskCategory, List<KioskProduct>>> load() async {
    // The local catalog is the operational source for the kiosk. Load it
    // first so an unavailable network can never block the product menu.
    final catalog = await _repository.load();

    // Synchronization is best-effort and deliberately kept off the critical
    // menu-loading path. If connectivity is available, a later call to
    // load() will pick up the refreshed local catalog. If connectivity is
    // unavailable, the current last-known-good catalog remains usable.
    unawaited(_storeCatalogSync.refreshIfMasterChanged());

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
        final productOptions = _orderedProductOptions(
          product.options.where((option) => option.active),
        );
        final sharedOptions = _orderedOptionDefinitions(
          catalog.optionDefinitions.where(
            (option) =>
                option.active &&
                option.productTypes.any(
                  (type) => type.trim().toLowerCase() ==
                      product.productType.trim().toLowerCase(),
                ),
          ),
        );

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
                    sortOrder: option.sortOrder,
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
                    sortOrder: option.sortOrder,
                  ),
                );
        // Store Management is the source of truth for add-on order.
        // Explicit sortOrder wins; legacy catalogs fall back to their original
        // array position so existing catalog files remain deterministic.
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
            variants: _orderedVariants(
                product.variants.where((variant) => variant.active),
              )
                .map(
                  (variant) => KioskVariant(
                    id: variant.variantId,
                    name: variant.name,
                    price: variant.price?.toInt(),
                    active: variant.active,
                    sortOrder: variant.sortOrder,
                  ),
                )
                .toList(growable: false),
            sizes: _orderedSizes(product.sizes)
                .map(
                  (size) => KioskSize(
                    id: size.sizeId,
                    name: size.name,
                    volumeMl: size.volumeMl,
                    displayVolume: size.displayVolume,
                    price: size.price?.toInt(),
                    sortOrder: size.sortOrder,
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
