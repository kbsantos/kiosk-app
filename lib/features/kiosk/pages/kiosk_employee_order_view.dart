import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../models/kiosk_models.dart';
import 'kiosk_category_page.dart';
import 'kiosk_order_panel.dart';
import 'kiosk_checkout_page.dart';

/// Employee-facing product selection view.
///
/// This intentionally uses the kiosk catalog projection already loaded by the
/// home page, while reusing the existing product customization/order flow.
class KioskEmployeeOrderView extends StatefulWidget {
  const KioskEmployeeOrderView({
    super.key,
    required this.catalog,
    required this.cart,
  });

  final Map<KioskCategory, List<KioskProduct>> catalog;
  final KioskCart cart;

  @override
  State<KioskEmployeeOrderView> createState() => _KioskEmployeeOrderViewState();
}

class _KioskEmployeeOrderViewState extends State<KioskEmployeeOrderView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<KioskProduct> get _allProducts => widget.catalog.values
      .expand((products) => products)
      .toList(growable: false);

  List<KioskProduct> get _filteredProducts {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _allProducts;

    return _allProducts.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.title.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  int? _startingPrice(KioskProduct product) {
    final prices = <int>[];
    if (product.price != null) prices.add(product.price!);
    prices.addAll(
      product.sizes
          .where((size) => size.price != null)
          .map((size) => size.price!),
    );
    prices.addAll(
      product.variants
          .where((variant) => variant.active && variant.price != null)
          .map((variant) => variant.price!),
    );
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }

  bool _canAdd(KioskProduct product) {
    return product.available && product.priceConfigured;
  }

  Future<void> _addProduct(KioskProduct product) async {
    final itemCountBefore = widget.cart.itemCount;

    await addKioskProductToCart(context, product, widget.cart);

    if (!mounted) return;

    // Only clear the search after an item was actually added. If the
    // customization/variant dialog was cancelled, keep the user's search.
    if (widget.cart.itemCount > itemCountBefore) {
      _searchController.clear();
      setState(() => _search = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    //const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);

    return LayoutBuilder(
      builder: (context, constraints) {
        final products = _filteredProducts;
        final showOrderPanel = constraints.maxWidth >= 950;

        final productsView = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  // Clear the controller value explicitly so the
                                  // visible TextField is reset immediately.
                                  _searchController.value = const TextEditingValue(
                                    text: '',
                                    selection: TextSelection.collapsed(offset: 0),
                                    composing: TextRange.empty,
                                  );
                                  setState(() => _search = '');
                                },
                                icon: const Icon(Icons.clear),
                                tooltip: 'Clear search',
                              ),
                        labelText: 'Search product or category',
                        border: const OutlineInputBorder(),
                      ),
                      controller: _searchController,
                      onChanged: (value) => setState(() => _search = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(label: Text('${products.length} products')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Text(
                        _search.trim().isEmpty
                            ? 'No products are available.'
                            : 'No products found.',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            constraints.maxWidth >= 1200 ? 235 : 260,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, index) {
                        final product = products[index];
                        final canAdd = _canAdd(product);
                        final price = _startingPrice(product);

                        return Material(
                          color: Colors.white,
                          elevation: canAdd ? 2 : 0,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: canAdd ? () => _addProduct(product) : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Opacity(
                              opacity: canAdd ? 1 : .48,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          product.category.icon,
                                          style: const TextStyle(fontSize: 21),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            product.category.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            price == null
                                                ? 'PRICE REQUIRED'
                                                : product.hasSizes
                                                    ? 'FROM ${KioskCurrency.format(price)}'
                                                    : KioskCurrency.format(price),
                                            style: TextStyle(
                                              color: canAdd
                                                  ? gold
                                                  : Colors.black54,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          canAdd
                                              ? Icons.add_circle
                                              : Icons.block,
                                          color: canAdd ? gold : Colors.black45,
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                    if (!product.available)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 3),
                                        child: Text(
                                          'UNAVAILABLE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );

        if (!showOrderPanel) return productsView;

        return Row(
          children: [
            Expanded(child: productsView),
            SizedBox(
              width: 360,
              child: KioskOrderPanel(
                cart: widget.cart,
                onCheckout: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KioskCheckoutPage(cart: widget.cart),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
