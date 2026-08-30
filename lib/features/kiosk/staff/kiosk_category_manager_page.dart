import 'package:flutter/material.dart';

import '../../../product_catalog/product_catalog_models.dart';
import '../../../product_catalog/product_catalog_repository.dart';

/// K15.3.2 — Category Manager.
///
/// Category IDs are treated as stable identifiers because products reference
/// them. Staff can edit the display name/subtitle and active state, and can add
/// a new category with a new stable ID. Changes are persisted only after an
/// explicit SAVE action.
class KioskCategoryManagerPage extends StatefulWidget {
  const KioskCategoryManagerPage({super.key});

  @override
  State<KioskCategoryManagerPage> createState() =>
      _KioskCategoryManagerPageState();
}

class _KioskCategoryManagerPageState extends State<KioskCategoryManagerPage> {
  static const _dark = Color(0xFF171717);
  static const _gold = Color(0xFFC69214);
  static const _cream = Color(0xFFF5F2ED);

  static const _categoryIcons = <String>[
    '🧋',
    '🍓',
    '☕',
    '🍫',
    '🍵',
    '🥤',
    '🫧',
    '🧊',
    '🍚',
    '🍔',
    '🍟',
    '🛍️',
    '➕',
    '🍰',
    '🍕',
    '🍦',
    '🥐',
    '⭐',
    '🎁',
    '📦',
  ];

  final _repository = const ProductCatalogRepository();
  ProductCatalog? _catalog;
  List<ProductCategory> _categories = const [];
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _repository.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _categories = List<ProductCategory>.from(catalog.categories);
        _dirty = false;
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

  // void _markDirty() => setState(() => _dirty = true);

  Future<void> _save() async {
    final catalog = _catalog;
    if (catalog == null || _saving) return;

    try {
      setState(() => _saving = true);
      final updated = ProductCatalog(
        catalogVersion: catalog.catalogVersion,
        categories: List<ProductCategory>.unmodifiable(_categories),
        optionDefinitions: catalog.optionDefinitions,
        products: catalog.products,
      );
      ProductCatalogRepository.validate(updated);
      await _repository.save(updated);
      if (!mounted) return;
      setState(() {
        _catalog = updated;
        _categories = List<ProductCategory>.from(updated.categories);
        _dirty = false;
        _saving = false;
      });
      _showMessage('Categories saved successfully.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Unable to save categories: $error');
    }
  }

  Future<void> _addCategory() async {
    final result = await _showCategoryEditor();
    if (result == null) return;

    if (_categories
        .any((category) => category.categoryId == result.categoryId)) {
      _showMessage('Category ID already exists: ${result.categoryId}');
      return;
    }

    setState(() {
      _categories = [..._categories, result];
      _dirty = true;
    });
  }

  Future<void> _editCategory(ProductCategory category) async {
    final result = await _showCategoryEditor(category: category);
    if (result == null) return;

    setState(() {
      _categories = [
        for (final current in _categories)
          if (current.categoryId == category.categoryId) result else current,
      ];
      _dirty = true;
    });
  }

  void _toggleCategory(ProductCategory category) {
    setState(() {
      _categories = [
        for (final current in _categories)
          if (current.categoryId == category.categoryId)
            ProductCategory(
              categoryId: current.categoryId,
              name: current.name,
              subtitle: current.subtitle,
              active: !current.active,
              icon: current.icon,
            )
          else
            current,
      ];
      _dirty = true;
    });
  }

  String _defaultIconForCategory(String? id) {
    switch (id) {
      case 'milk_tea':
        return '🧋';
      case 'fruit_tea':
        return '🍓';
      case 'coffee':
        return '☕';
      case 'chocolate':
        return '🍫';
      case 'matcha':
        return '🍵';
      case 'frappe':
        return '🥤';
      case 'fruity_soda':
        return '🫧';
      case 'slushies':
        return '🧊';
      case 'rice_meals':
        return '🍚';
      case 'burgers':
        return '🍔';
      case 'merienda':
        return '🍟';
      case 'accessories':
        return '🛍️';
      case 'add_ons':
        return '➕';
      default:
        return '📦';
    }
  }

  Future<ProductCategory?> _showCategoryEditor({
    ProductCategory? category,
  }) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final idController =
        TextEditingController(text: category?.categoryId ?? '');
    final subtitleController =
        TextEditingController(text: category?.subtitle ?? '');
    bool active = category?.active ?? true;
    String selectedIcon = category?.icon ?? _defaultIconForCategory(
      category?.categoryId,
    );

    final result = await showDialog<ProductCategory>(
      context: context,
      builder: (dialogContext) {
        final isNew = category == null;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? 'ADD CATEGORY' : 'EDIT CATEGORY'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: idController,
                        enabled: isNew,
                        decoration: const InputDecoration(
                          labelText: 'Category ID',
                          hintText: 'e.g. seasonal_drinks',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CATEGORY ICON',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categoryIcons.map((icon) {
                            final selected = selectedIcon == icon;
                            return InkWell(
                              onTap: () =>
                                  setDialogState(() => selectedIcon = icon),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _gold.withValues(alpha: 0.18)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? _gold : Colors.black12,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  icon,
                                  style: const TextStyle(fontSize: 25),
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Selected: $selectedIcon',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text(
                          'Inactive categories are hidden from the customer kiosk.',
                        ),
                        value: active,
                        onChanged: (value) =>
                            setDialogState(() => active = value),
                      ),
                      if (!isNew)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Category ID is locked because products reference it.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () {
                    final id = idController.text.trim();
                    final name = nameController.text.trim();
                    if (id.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Category ID and name are required.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      ProductCategory(
                        categoryId: id,
                        name: name,
                        subtitle: subtitleController.text.trim(),
                        active: active,
                        icon: selectedIcon,
                      ),
                    );
                  },
                  child: Text(isNew ? 'ADD' : 'SAVE'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    idController.dispose();
    subtitleController.dispose();
    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        title: const Text(
          'CATEGORY MANAGER',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload without unsaved changes',
            onPressed: _loading || _saving || _dirty ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: !_dirty || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('SAVE'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              onPressed: _saving ? null : _addCategory,
              icon: const Icon(Icons.add),
              label: const Text('ADD CATEGORY'),
            ),
      body: _buildBody(),
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
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Unable to load categories.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 620,
              child: Text('$_error', textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('RETRY')),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MENU CATEGORIES',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Edit display names and availability without changing product IDs.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (_dirty)
                  const Chip(
                    avatar: Icon(Icons.circle, size: 9),
                    label: Text('UNSAVED CHANGES'),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            ..._categories.map(_buildCategoryCard),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(ProductCategory category) {
    final productCount = _catalog?.products
            .where((product) => product.categoryId == category.categoryId)
            .length ??
        0;

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: category.active
              ? const Color(0xFFF4E8C5)
              : const Color(0xFFECECEC),
          child: Text(
            category.icon ?? _defaultIconForCategory(category.categoryId),
            style: const TextStyle(fontSize: 25),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        subtitle: Text(
          '${category.categoryId}  •  $productCount products'
          '${category.subtitle.trim().isEmpty ? '' : '\n${category.subtitle}'}',
        ),
        isThreeLine: category.subtitle.trim().isNotEmpty,
        trailing: Wrap(
          spacing: 4,
          children: [
            Switch(
              value: category.active,
              onChanged: _saving ? null : (_) => _toggleCategory(category),
            ),
            IconButton(
              tooltip: 'Edit category',
              onPressed: _saving ? null : () => _editCategory(category),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
