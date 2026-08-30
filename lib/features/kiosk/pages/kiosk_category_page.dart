import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../models/kiosk_models.dart';
import 'kiosk_order_panel.dart';
import 'kiosk_checkout_page.dart';

class KioskCategoryPage extends StatelessWidget {
  final KioskCategory category;
  final List<KioskProduct> products;
  final KioskCart cart;

  const KioskCategoryPage({
    super.key,
    required this.category,
    required this.products,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: Text(
          '${category.icon}  ${category.title}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          ListenableBuilder(
            listenable: cart,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  cart.itemCount == 0
                      ? 'ORDER IS EMPTY'
                      : '${cart.itemCount} ITEM${cart.itemCount == 1 ? '' : 'S'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showOrderPanel = constraints.maxWidth >= 950;

          final productsView = products.isEmpty
              ? const Center(
                  child: Text(
                    'No products are available in this category yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: constraints.maxWidth > constraints.maxHeight
                      ? const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.45,
                        )
                      : SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 430,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.25,
                        ),
                  itemCount: products.length,
                  itemBuilder: (_, index) {
                    final product = products[index];
                    final canAdd = product.available &&
                        (!product.hasSizes ||
                            product.sizes
                                .any((size) => size.priceConfigured)) &&
                        product.priceConfigured;

                    return Card(
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            if (product.hasSizes)
                              _SizePriceRow(
                                product: product,
                                enabled: canAdd,
                              )
                            else if (product.hasVariants)
                              Text(
                                'From ${KioskCurrency.format(product.activeVariants.where((v) => v.priceConfigured).map((v) => v.price!).reduce((a, b) => a < b ? a : b))}',
                                style: TextStyle(
                                  color: canAdd ? gold : Colors.black54,
                                  fontSize: canAdd ? 27 : 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            else
                              Text(
                                product.priceConfigured
                                    ? KioskCurrency.format(product.price!)
                                    : 'Price not configured',
                                style: TextStyle(
                                  color: canAdd ? gold : Colors.black54,
                                  fontSize: canAdd ? 27 : 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: canAdd
                                    ? () => _addProduct(context, product)
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: gold,
                                ),
                                icon: const Icon(Icons.add_shopping_cart),
                                label: Text(
                                  product.hasSizes
                                      ? 'SELECT SIZE'
                                      : product.hasVariants
                                          ? 'SELECT VARIANT'
                                          : canAdd
                                              ? 'ADD TO ORDER'
                                              : 'PRICE REQUIRED',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

          if (!showOrderPanel) {
            return productsView;
          }

          return Row(
            children: [
              Expanded(child: productsView),
              SizedBox(
                width: 360,
                child: KioskOrderPanel(
                  cart: cart,
                  onCheckout: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KioskCheckoutPage(cart: cart),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addProduct(
    BuildContext context,
    KioskProduct product,
  ) async {
    await addKioskProductToCart(context, product, cart);
  }
}

Future<void> addKioskProductToCart(
  BuildContext context,
  KioskProduct product,
  KioskCart cart,
) async {
  KioskSize? selectedSize;
  KioskVariant? selectedVariant;

  if (product.hasSizes) {
    selectedSize = await showModalBottomSheet<KioskSize>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DrinkSizeSheet(product: product),
    );
    if (!context.mounted) return;
    if (selectedSize == null) return;
  }

  if (product.hasVariants) {
    selectedVariant = await showModalBottomSheet<KioskVariant>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductVariantSheet(product: product),
    );
    if (!context.mounted) return;
    if (selectedVariant == null) return;
  }

  // Product options are product-specific and must be honored regardless of
  // category or product type. This allows food such as burgers to use the
  // same Takeout/Dine In/add-on flow as drinks and rice meals.
  if (product.options.isNotEmpty) {
    final options = await showModalBottomSheet<List<KioskOption>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductAddOnsSheet(product: product),
    );

    if (!context.mounted) return;
    if (options == null) return;
    if (cart.canAdd(product, size: selectedSize, variant: selectedVariant)) {
      cart.add(product,
          size: selectedSize, variant: selectedVariant, options: options);
    }
    return;
  }

  if (cart.canAdd(product, size: selectedSize, variant: selectedVariant)) {
    cart.add(product, size: selectedSize, variant: selectedVariant);
  }
}

class _SizePriceRow extends StatelessWidget {
  final KioskProduct product;
  final bool enabled;

  const _SizePriceRow({
    required this.product,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    final sizes = product.sizes;

    if (sizes.isEmpty) {
      return const Text(
        'Price not configured',
        style: TextStyle(
          color: Colors.black54,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return Row(
      children: sizes.map((size) {
        final configured = size.priceConfigured;
        final volume = size.displayVolume ?? '';
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: size.id == sizes.last.id ? 0 : 7,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: enabled && configured
                  ? const Color(0xFFFFF8E8)
                  : const Color(0xFFF5F2ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled && configured
                    ? const Color(0xFFE8C66B)
                    : const Color(0xFFE2DDD5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  size.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled && configured ? gold : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (volume.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    volume,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  configured ? KioskCurrency.format(size.price!) : 'TBD',
                  style: TextStyle(
                    color: enabled && configured ? gold : Colors.black45,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _ProductAddOnsSheet extends StatefulWidget {
  final KioskProduct product;

  const _ProductAddOnsSheet({required this.product});

  @override
  State<_ProductAddOnsSheet> createState() => _ProductAddOnsSheetState();
}

class _ProductAddOnsSheetState extends State<_ProductAddOnsSheet> {
  final Set<String> _selected = {};
  bool _showAddOns = false;

  @override
  Widget build(BuildContext context) {
    final options = widget.product.options
        .map(
          (option) => KioskOption(
            id: option.id,
            name: option.name,
            price: option.price,
            kitchenPrepared: option.kitchenPrepared,
          ),
        )
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADD-ONS',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose any add-ons for ${widget.product.name}',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAddOns = !_showAddOns;
                    });
                  },
                  icon: Icon(
                    _showAddOns ? Icons.expand_less : Icons.add_circle_outline,
                  ),
                  label: Text(
                    _showAddOns ? 'HIDE ADD-ONS' : 'ADD-ONS',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC69214),
                    side: const BorderSide(
                      color: Color(0xFFC69214),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (_showAddOns) ...[
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...options.map(
                        (option) => CheckboxListTile(
                          value: _selected.contains(option.id),
                          activeColor: const Color(0xFFC69214),
                          title: Text(
                            option.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '+${KioskCurrency.format(option.price)}',
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(option.id);
                              } else {
                                _selected.remove(option.id);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () {
                    final selected = options
                        .where((option) => _selected.contains(option.id))
                        .toList(growable: false);
                    Navigator.of(context).pop(selected);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC69214),
                  ),
                  child: const Text(
                    'ADD TO ORDER',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductVariantSheet extends StatelessWidget {
  final KioskProduct product;

  const _ProductVariantSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    final variants = product.activeVariants
        .where((variant) => variant.priceConfigured)
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECT ${product.name.toUpperCase()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a variant',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (variants.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No priced variants are available for this product.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount: variants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      return SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(variant),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: gold, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  variant.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                KioskCurrency.format(variant.price!),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrinkSizeSheet extends StatelessWidget {
  final KioskProduct product;

  const _DrinkSizeSheet({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final configured = product.sizes.any((size) => size.priceConfigured);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'SELECT SIZE',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 14),
            ...product.sizes.map(
              (size) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: OutlinedButton(
                    onPressed: size.priceConfigured
                        ? () => Navigator.of(context).pop(size)
                        : null,
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${size.name}${size.displayVolume == null ? '' : '  •  ${size.displayVolume}'}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          size.priceConfigured
                              ? KioskCurrency.format(size.price!)
                              : 'PRICE TBD',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: size.priceConfigured
                                ? const Color(0xFFC69214)
                                : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!configured)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Drink prices are not configured yet.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
