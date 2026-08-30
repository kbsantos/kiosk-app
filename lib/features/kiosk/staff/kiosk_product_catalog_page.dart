import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../../../product_catalog/product_catalog_models.dart';
import '../../../product_catalog/product_catalog_repository.dart';

/// K15.2 staff-facing catalog browser.
///
/// This sprint intentionally focuses on browsing/searching/filtering. Product
/// mutation is introduced in K15.3 so we can keep the catalog editor isolated
/// from the customer ordering flow.
class KioskProductCatalogPage extends StatefulWidget {
  const KioskProductCatalogPage({super.key});

  @override
  State<KioskProductCatalogPage> createState() =>
      _KioskProductCatalogPageState();
}

List<CatalogProduct> filterCatalogProducts(
  ProductCatalog catalog, {
  String query = '',
  String? categoryId,
  bool activeOnly = false,
}) {
  final normalized = query.trim().toLowerCase();
  return catalog.products.where((product) {
    if (categoryId != null && product.categoryId != categoryId) return false;
    if (activeOnly && !product.active) return false;
    if (normalized.isEmpty) return true;
    return product.name.toLowerCase().contains(normalized) ||
        product.productId.toLowerCase().contains(normalized) ||
        product.sku?.toLowerCase().contains(normalized) == true;
  }).toList(growable: false);
}

class _KioskProductCatalogPageState extends State<KioskProductCatalogPage> {
  static const _dark = Color(0xFF171717);
  static const _gold = Color(0xFFC69214);
  static const _cream = Color(0xFFF5F2ED);

  final _repository = const ProductCatalogRepository();
  final _searchController = TextEditingController();

  ProductCatalog? _catalog;
  String? _categoryId;
  bool _activeOnly = false;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _repository.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        title: const Text(
          'PRODUCT CATALOG',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload catalog',
            onPressed: _loading ? null : _loadCatalog,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showK15_3Notice(context),
        backgroundColor: _gold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'ADD PRODUCT',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 54),
            const SizedBox(height: 12),
            const Text('Unable to load the product catalog.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadCatalog, child: const Text('RETRY')),
          ],
        ),
      );
    }

    final catalog = _catalog!;
    final products = filterCatalogProducts(
      catalog,
      query: _searchController.text,
      categoryId: _categoryId,
      activeOnly: _activeOnly,
    );

    return Column(
      children: [
        _buildToolbar(catalog),
        Expanded(
          child: products.isEmpty
              ? const Center(
                  child: Text(
                    'No products match the current filters.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.75,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, index) => _ProductCard(
                    product: products[index],
                    categoryName:
                        _categoryName(catalog, products[index].categoryId),
                    onEdit: () => _showK15_3Notice(context),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(ProductCatalog catalog) {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search product, ID or SKU...',
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: _cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...catalog.categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category.categoryId,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('Active only'),
                  selected: _activeOnly,
                  onSelected: (value) => setState(() => _activeOnly = value),
                ),
                const SizedBox(width: 12),
                Text(
                  '${filterCatalogProducts(catalog, query: _searchController.text, categoryId: _categoryId, activeOnly: _activeOnly).length} products',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _categoryName(ProductCatalog catalog, String categoryId) {
    for (final category in catalog.categories) {
      if (category.categoryId == categoryId) return category.name;
    }
    return categoryId;
  }

  Future<void> _showK15_3Notice(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Catalog Editing'),
        content: const Text(
          'Product editing is reserved for K15.3. K15.2 is the read/search/filter catalog browser and does not modify menu data.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onEdit,
  });

  final CatalogProduct product;
  final String categoryName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final enabled = product.active && product.available;
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F2ED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                product.productType == 'drink'
                    ? Icons.local_cafe_outlined
                    : Icons.restaurant_outlined,
                color: const Color(0xFFC69214),
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryName,
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusChip(
                        label: product.active ? 'ACTIVE' : 'INACTIVE',
                        color: product.active ? Colors.green : Colors.grey,
                      ),
                      _StatusChip(
                        label: product.available ? 'AVAILABLE' : 'UNAVAILABLE',
                        color: product.available ? Colors.blue : Colors.grey,
                      ),
                      if (product.kitchenPrepared)
                        const _StatusChip(
                            label: 'KITCHEN', color: Colors.deepOrange),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  _priceText(product),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onEdit,
                  child: Text(enabled ? 'EDIT' : 'VIEW'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _priceText(CatalogProduct product) {
    if (product.sizes.isNotEmpty) {
      final prices = product.sizes
          .map((size) => size.price)
          .whereType<num>()
          .toList(growable: false);
      if (prices.isEmpty) return 'Price N/A';
      final min = prices.reduce((a, b) => a < b ? a : b);
      final max = prices.reduce((a, b) => a > b ? a : b);
      return min == max
          ? KioskCurrency.format(min)
          : '${KioskCurrency.format(min)}–${KioskCurrency.format(max)}';
    }
    return product.variants.isNotEmpty && product.variants.first.price != null
        ? KioskCurrency.format(product.variants.first.price!)
        : 'Price N/A';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
