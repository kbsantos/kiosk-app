import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import '../../product_catalog/catalog_schema_guard.dart';
import 'catalog_change_guard.dart';
import 'catalog_permissions.dart';
import '../kiosk/staff_access.dart';

class CatalogFileImportExportPage extends StatefulWidget {
  const CatalogFileImportExportPage({super.key, required this.role});

  final StaffRole role;

  @override
  State<CatalogFileImportExportPage> createState() =>
      _CatalogFileImportExportPageState();
}

class _CatalogFileImportExportPageState
    extends State<CatalogFileImportExportPage> {
  static const _maxImportBytes = 2 * 1024 * 1024;
  final _repository = const ProductCatalogRepository();
  ProductCatalog? _catalog;
  bool _busy = false;
  String? _lastFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = await _repository.load();
    if (!mounted) {
      return;
    }
    setState(() => _catalog = catalog);
  }

  Future<void> _export() async {
    final catalog = _catalog;
    if (catalog == null || _busy) return;
    setState(() => _busy = true);
    try {
      final json = const JsonEncoder.withIndent('  ').convert(catalog.toJson());
      final bytes = Uint8List.fromList(utf8.encode(json));
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'bigger_brew_catalog_$timestamp.json';
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export Bigger Brew Catalog',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        setState(() => _lastFile = path.toString());
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Catalog exported successfully.')));
      }
    } catch (e) {
      if (mounted) _message('Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final allowed = await requireCatalogPermission(
      context,
      widget.role,
      CatalogPermission.importCatalog,
    );
    if (!mounted || !allowed) {
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty) {
        return;
      }
      final file = files.single;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImportBytes) {
        throw StateError('Catalog file is larger than 2 MB.');
      }

      final raw = utf8.decode(bytes, allowMalformed: false).trim();
      if (raw.isEmpty) {
        throw StateError('The selected file is empty.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw StateError(
            'Catalog JSON must contain an object at the top level.');
      }

      final imported = CatalogSchemaGuard.decodeAndValidate(
        Map<String, dynamic>.from(decoded),
        source: 'imported catalog',
      );
      _validateImportedCatalog(imported);

      if (!mounted) {
        return;
      }
      final currentCatalog = _catalog!;
      final diff = CatalogImportDiff.build(currentCatalog, imported);
      final selection = await _showSelectiveMerge(
        current: currentCatalog,
        incoming: imported,
        fileName: file.name,
      );
      if (!mounted) {
        return;
      }
      if (selection == null) {
        return;
      }

      final merged = _buildSelectiveMerge(currentCatalog, imported, selection);
      _validateImportedCatalog(merged);

      final summaryConfirmed = await _showMergeSummary(
        current: currentCatalog,
        incoming: imported,
        merged: merged,
        selection: selection,
        fileName: file.name,
      );
      if (!mounted) {
        return;
      }
      if (!summaryConfirmed) {
        return;
      }

      if (diff.hasDestructiveChanges && selection.hasRemovals) {
        final destructiveConfirmed =
            await _showDestructiveImportWarning(diff, selection);
        if (!mounted) {
          return;
        }
        if (!destructiveConfirmed) {
          return;
        }
      }

      final confirmed = await CatalogChangeGuard.confirm(
        context,
        title: 'APPLY SELECTED CATALOG CHANGES?',
        message:
            'Only the changes selected in the merge preview will be applied. Unselected current records will be preserved. The bundled commercial catalog asset will not be modified. A backup will be created first.',
        confirmLabel: 'APPLY SELECTED',
      );
      if (!confirmed) {
        return;
      }

      final current = _catalog;
      if (current != null) {
        // Keep a dedicated rollback point for the most recent accepted import.
        await _repository.saveImportRecoveryBackup(current);
        await _repository.saveBackup(current);
      }
      await _repository.saveCatalog(merged,
          auditAction: 'Selective catalog import');
      await _load();
      if (mounted) {
        setState(() => _lastFile = file.name);
        _message('Catalog imported successfully.');
      }
    } catch (e) {
      if (mounted) {
        _message(
            'Import failed: ${e.toString().replaceFirst('Bad state: ', '')}',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<CatalogImportSelection?> _showSelectiveMerge({
    required ProductCatalog current,
    required ProductCatalog incoming,
    required String fileName,
  }) async {
    final diff = CatalogImportDiff.build(current, incoming);
    return showDialog<CatalogImportSelection>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CatalogSelectiveMergeDialog(
        current: current,
        incoming: incoming,
        fileName: fileName,
        diff: diff,
      ),
    );
  }

  Future<bool> _showMergeSummary({
    required ProductCatalog current,
    required ProductCatalog incoming,
    required ProductCatalog merged,
    required CatalogImportSelection selection,
    required String fileName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CatalogMergeSummaryDialog(
        current: current,
        incoming: incoming,
        merged: merged,
        selection: selection,
        fileName: fileName,
      ),
    );
    return result == true;
  }

  ProductCatalog _buildSelectiveMerge(ProductCatalog current,
      ProductCatalog incoming, CatalogImportSelection selection) {
    Map<String, dynamic> mergeSection(
      List<Map<String, dynamic>> currentItems,
      List<Map<String, dynamic>> incomingItems,
      Set<String> added,
      Set<String> changed,
      Set<String> removed,
      String idKey,
    ) {
      final result = <String, Map<String, dynamic>>{};
      for (final item in currentItems) {
        result[item[idKey].toString()] = item;
      }
      for (final id in removed) {
        result.remove(id);
      }
      for (final item in incomingItems) {
        final id = item[idKey].toString();
        if (added.contains(id) || changed.contains(id)) result[id] = item;
      }
      return result;
    }

    final categories = mergeSection(
      current.categories.map((e) => e.toJson()).toList(),
      incoming.categories.map((e) => e.toJson()).toList(),
      selection.addedCategories,
      selection.changedCategories,
      selection.removedCategories,
      'categoryId',
    ).values.map((e) => ProductCategory.fromJson(e)).toList(growable: false);
    final products = mergeSection(
      current.products.map((e) => e.toJson()).toList(),
      incoming.products.map((e) => e.toJson()).toList(),
      selection.addedProducts,
      selection.changedProducts,
      selection.removedProducts,
      'productId',
    ).values.map((e) => CatalogProduct.fromJson(e)).toList(growable: false);
    final options = mergeSection(
      current.optionDefinitions.map((e) => e.toJson()).toList(),
      incoming.optionDefinitions.map((e) => e.toJson()).toList(),
      selection.addedOptions,
      selection.changedOptions,
      selection.removedOptions,
      'optionId',
    )
        .values
        .map((e) => CatalogOptionDefinition.fromJson(e))
        .toList(growable: false);

    return current.copyWith(
      schemaVersion: incoming.schemaVersion,
      catalogVersion: selection.hasAnySelection
          ? incoming.catalogVersion
          : current.catalogVersion,
      categories: categories,
      products: products,
      optionDefinitions: options,
    );
  }

  Future<bool> _showDestructiveImportWarning(
      CatalogImportDiff diff, CatalogImportSelection selection) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            SizedBox(width: 10),
            Expanded(
                child: Text('DESTRUCTIVE IMPORT WARNING',
                    style: TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'This catalog import will remove records from the current kiosk catalog.',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _destructiveCount(
                  'Products to remove', selection.removedProducts.length),
              _destructiveCount(
                  'Categories to remove', selection.removedCategories.length),
              _destructiveCount('Options / add-ons to remove',
                  selection.removedOptions.length),
              const SizedBox(height: 14),
              const Text(
                  'A recovery backup will be created immediately before the import. The bundled catalog will remain unchanged.',
                  style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('REVIEW & CONTINUE'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _destructiveCount(String label, int count) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline,
              size: 20, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _validateImportedCatalog(ProductCatalog catalog) {
    CatalogSchemaGuard.ensureSupported(catalog.schemaVersion,
        source: 'imported catalog');
    if (catalog.catalogVersion.trim().isEmpty) {
      throw StateError('Catalog version is required.');
    }
    final categoryIds = catalog.categories.map((e) => e.categoryId).toSet();
    if (categoryIds.length != catalog.categories.length) {
      throw StateError('Catalog contains duplicate category IDs.');
    }
    final productIds = catalog.products.map((e) => e.productId).toSet();
    if (productIds.length != catalog.products.length) {
      throw StateError('Catalog contains duplicate product IDs.');
    }
    final optionIds = catalog.optionDefinitions.map((e) => e.optionId).toSet();
    if (optionIds.length != catalog.optionDefinitions.length) {
      throw StateError('Catalog contains duplicate option IDs.');
    }
    for (final product in catalog.products) {
      if (!categoryIds.contains(product.categoryId)) {
        throw StateError(
            'Product ${product.productId} references missing category ${product.categoryId}.');
      }
      final sizeIds = product.sizes.map((e) => e.sizeId).toSet();
      if (sizeIds.length != product.sizes.length) {
        throw StateError(
            'Product ${product.productId} contains duplicate size IDs.');
      }
      final variantIds = product.variants.map((e) => e.variantId).toSet();
      if (variantIds.length != product.variants.length) {
        throw StateError(
            'Product ${product.productId} contains duplicate variant IDs.');
      }
      final productOptionIds = product.options.map((e) => e.optionId).toSet();
      if (productOptionIds.length != product.options.length) {
        throw StateError(
            'Product ${product.productId} contains duplicate option IDs.');
      }
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('CATALOG FILE IMPORT / EXPORT',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
              onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PORTABLE CATALOG TRANSFER',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(
                              'Move the complete current catalog between kiosks using a JSON file. Export includes the catalog schema version plus categories, products, sizes, variants, options, pricing, and catalog metadata.',
                              style: TextStyle(color: Colors.grey.shade800)),
                          const SizedBox(height: 12),
                          Text(
                              'Schema ${catalog.schemaVersion} • Catalog ${catalog.catalogVersion} • ${catalog.products.length} products • ${catalog.categories.length} categories',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          if (_lastFile != null) ...[
                            const SizedBox(height: 6),
                            Text('Last file: $_lastFile',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ]),
                  ),
                ),
                const SizedBox(height: 14),
                _action(
                    'Export Catalog JSON',
                    'Save the current merged catalog as a portable .json file.',
                    Icons.file_upload_outlined,
                    _export),
                _action(
                    'Import Catalog JSON',
                    'Select a Bigger Brew catalog .json file and replace local overrides after validation.',
                    Icons.file_download_outlined,
                    _import),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                        'Safety: schema compatibility and catalog integrity are validated before applying an import. The current catalog is backed up first, and the bundled commercial catalog asset remains read-only.',
                        style: TextStyle(color: Colors.grey.shade800)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _action(String title, String subtitle, IconData icon,
          Future<void> Function() onPressed) =>
      Card(
        child: ListTile(
          enabled: !_busy,
          leading: CircleAvatar(child: Icon(icon)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: FilledButton(
              onPressed: _busy ? null : onPressed, child: const Text('OPEN')),
        ),
      );
}

class CatalogImportSelection {
  final Set<String> addedCategories;
  final Set<String> changedCategories;
  final Set<String> removedCategories;
  final Set<String> addedProducts;
  final Set<String> changedProducts;
  final Set<String> removedProducts;
  final Set<String> addedOptions;
  final Set<String> changedOptions;
  final Set<String> removedOptions;

  const CatalogImportSelection({
    required this.addedCategories,
    required this.changedCategories,
    required this.removedCategories,
    required this.addedProducts,
    required this.changedProducts,
    required this.removedProducts,
    required this.addedOptions,
    required this.changedOptions,
    required this.removedOptions,
  });

  bool get hasAnySelection =>
      addedCategories.isNotEmpty ||
      changedCategories.isNotEmpty ||
      removedCategories.isNotEmpty ||
      addedProducts.isNotEmpty ||
      changedProducts.isNotEmpty ||
      removedProducts.isNotEmpty ||
      addedOptions.isNotEmpty ||
      changedOptions.isNotEmpty ||
      removedOptions.isNotEmpty;
  bool get hasRemovals =>
      removedCategories.isNotEmpty ||
      removedProducts.isNotEmpty ||
      removedOptions.isNotEmpty;
}

class CatalogImportDiff {
  final List<String> addedCategories;
  final List<String> removedCategories;
  final List<String> changedCategories;
  final List<String> addedProducts;
  final List<String> removedProducts;
  final List<String> changedProducts;
  final List<String> addedOptions;
  final List<String> removedOptions;
  final List<String> changedOptions;

  const CatalogImportDiff({
    required this.addedCategories,
    required this.removedCategories,
    required this.changedCategories,
    required this.addedProducts,
    required this.removedProducts,
    required this.changedProducts,
    required this.addedOptions,
    required this.removedOptions,
    required this.changedOptions,
  });

  int get addedCount =>
      addedCategories.length + addedProducts.length + addedOptions.length;
  int get removedCount =>
      removedCategories.length + removedProducts.length + removedOptions.length;
  int get changedCount =>
      changedCategories.length + changedProducts.length + changedOptions.length;
  int get totalChanges => addedCount + removedCount + changedCount;
  bool get hasDestructiveChanges => removedCount > 0;

  static CatalogImportDiff build(
      ProductCatalog current, ProductCatalog incoming) {
    final categories = _diff(
      current.categories.map((e) => MapEntry(e.categoryId, e.toJson())),
      incoming.categories.map((e) => MapEntry(e.categoryId, e.toJson())),
    );
    final products = _diff(
      current.products.map((e) => MapEntry(e.productId, e.toJson())),
      incoming.products.map((e) => MapEntry(e.productId, e.toJson())),
    );
    final options = _diff(
      current.optionDefinitions.map((e) => MapEntry(e.optionId, e.toJson())),
      incoming.optionDefinitions.map((e) => MapEntry(e.optionId, e.toJson())),
    );
    return CatalogImportDiff(
      addedCategories: categories.added,
      removedCategories: categories.removed,
      changedCategories: categories.changed,
      addedProducts: products.added,
      removedProducts: products.removed,
      changedProducts: products.changed,
      addedOptions: options.added,
      removedOptions: options.removed,
      changedOptions: options.changed,
    );
  }

  static _DiffResult _diff(
      Iterable<MapEntry<String, Map<String, dynamic>>> current,
      Iterable<MapEntry<String, Map<String, dynamic>>> incoming) {
    final before = <String, Map<String, dynamic>>{};
    for (final e in current) {
      before[e.key] = e.value;
    }
    final after = <String, Map<String, dynamic>>{};
    for (final e in incoming) {
      after[e.key] = e.value;
    }
    final added = after.keys.where((id) => !before.containsKey(id)).toList()
      ..sort();
    final removed = before.keys.where((id) => !after.containsKey(id)).toList()
      ..sort();
    final changed = after.keys
        .where((id) =>
            before.containsKey(id) &&
            jsonEncode(before[id]) != jsonEncode(after[id]))
        .toList()
      ..sort();
    return _DiffResult(added, removed, changed);
  }
}

class _DiffResult {
  final List<String> added;
  final List<String> removed;
  final List<String> changed;
  const _DiffResult(this.added, this.removed, this.changed);
}

class _CatalogSelectiveMergeDialog extends StatefulWidget {
  final ProductCatalog current;
  final ProductCatalog incoming;
  final String fileName;
  final CatalogImportDiff diff;

  const _CatalogSelectiveMergeDialog({
    required this.current,
    required this.incoming,
    required this.fileName,
    required this.diff,
  });

  @override
  State<_CatalogSelectiveMergeDialog> createState() =>
      _CatalogSelectiveMergeDialogState();
}

class _CatalogSelectiveMergeDialogState
    extends State<_CatalogSelectiveMergeDialog> {
  late final Set<String> _addedCategories = {...widget.diff.addedCategories};
  late final Set<String> _changedCategories = {
    ...widget.diff.changedCategories
  };
  final Set<String> _removedCategories = {};
  late final Set<String> _addedProducts = {...widget.diff.addedProducts};
  late final Set<String> _changedProducts = {...widget.diff.changedProducts};
  final Set<String> _removedProducts = {};
  late final Set<String> _addedOptions = {...widget.diff.addedOptions};
  late final Set<String> _changedOptions = {...widget.diff.changedOptions};
  final Set<String> _removedOptions = {};

  CatalogImportSelection _selection() => CatalogImportSelection(
        addedCategories: {..._addedCategories},
        changedCategories: {..._changedCategories},
        removedCategories: {..._removedCategories},
        addedProducts: {..._addedProducts},
        changedProducts: {..._changedProducts},
        removedProducts: {..._removedProducts},
        addedOptions: {..._addedOptions},
        changedOptions: {..._changedOptions},
        removedOptions: {..._removedOptions},
      );

  void _set(Set<String> set, String id, bool value) {
    setState(() {
      if (value) {
        set.add(id);
      } else {
        set.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SELECTIVE CATALOG MERGE',
          style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.fileName,
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _versionCard('CURRENT',
                          'Schema ${widget.current.schemaVersion}\n${widget.current.catalogVersion}')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _versionCard('INCOMING',
                          'Schema ${widget.incoming.schemaVersion}\n${widget.incoming.catalogVersion}')),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Added and changed records are selected by default. Removals are opt-in for safety.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _section(
                  'CATEGORIES',
                  widget.diff.addedCategories,
                  _addedCategories,
                  '+',
                  widget.diff.changedCategories,
                  _changedCategories,
                  '~',
                  widget.diff.removedCategories,
                  _removedCategories,
                  '-'),
              _section(
                  'PRODUCTS',
                  widget.diff.addedProducts,
                  _addedProducts,
                  '+',
                  widget.diff.changedProducts,
                  _changedProducts,
                  '~',
                  widget.diff.removedProducts,
                  _removedProducts,
                  '-'),
              _section(
                  'OPTIONS / ADD-ONS',
                  widget.diff.addedOptions,
                  _addedOptions,
                  '+',
                  widget.diff.changedOptions,
                  _changedOptions,
                  '~',
                  widget.diff.removedOptions,
                  _removedOptions,
                  '-'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        OutlinedButton(
          onPressed: () => setState(() {
            _addedCategories.addAll(widget.diff.addedCategories);
            _changedCategories.addAll(widget.diff.changedCategories);
            _addedProducts.addAll(widget.diff.addedProducts);
            _changedProducts.addAll(widget.diff.changedProducts);
            _addedOptions.addAll(widget.diff.addedOptions);
            _changedOptions.addAll(widget.diff.changedOptions);
          }),
          child: const Text('SELECT ALL CHANGES'),
        ),
        FilledButton(
          onPressed: _selection().hasAnySelection
              ? () => Navigator.pop(context, _selection())
              : null,
          child: const Text('APPLY SELECTED'),
        ),
      ],
    );
  }

  Widget _section(
    String title,
    List<String> added,
    Set<String> addedSet,
    String addedPrefix,
    List<String> changed,
    Set<String> changedSet,
    String changedPrefix,
    List<String> removed,
    Set<String> removedSet,
    String removedPrefix,
  ) {
    final total = added.length + changed.length + removed.length;
    if (total == 0) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ..._checks(added, addedSet, addedPrefix, false,
                entityType: title == 'CATEGORIES'
                    ? 'category'
                    : title == 'PRODUCTS'
                        ? 'product'
                        : 'option'),
            ..._checks(changed, changedSet, changedPrefix, false,
                entityType: title == 'CATEGORIES'
                    ? 'category'
                    : title == 'PRODUCTS'
                        ? 'product'
                        : 'option'),
            ..._checks(removed, removedSet, removedPrefix, true,
                entityType: title == 'CATEGORIES'
                    ? 'category'
                    : title == 'PRODUCTS'
                        ? 'product'
                        : 'option'),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _checks(
      List<String> ids, Set<String> set, String prefix, bool destructive,
      {String? entityType}) sync* {
    for (final id in ids.take(80)) {
      final changed = prefix == '~';
      yield CheckboxListTile(
        dense: true,
        value: set.contains(id),
        onChanged: (value) => _set(set, id, value == true),
        title: Text('$prefix $id',
            style: const TextStyle(fontFamily: 'monospace')),
        subtitle: changed
            ? const Text('Changed — tap REVIEW to inspect fields')
            : null,
        secondary: destructive
            ? const Icon(Icons.remove_circle_outline, color: Colors.deepOrange)
            : changed
                ? TextButton(
                    onPressed: () => _showFieldReview(entityType!, id),
                    child: const Text('REVIEW'),
                  )
                : null,
        controlAffinity: ListTileControlAffinity.leading,
      );
    }
    if (ids.length > 80) {
      yield Text('… and ${ids.length - 80} more',
          style: TextStyle(color: Colors.grey.shade700));
    }
  }

  Map<String, dynamic>? _record(
      ProductCatalog catalog, String entityType, String id) {
    if (entityType == 'category') {
      for (final item in catalog.categories) {
        if (item.categoryId == id) return item.toJson();
      }
    } else if (entityType == 'product') {
      for (final item in catalog.products) {
        if (item.productId == id) return item.toJson();
      }
    } else {
      for (final item in catalog.optionDefinitions) {
        if (item.optionId == id) return item.toJson();
      }
    }
    return null;
  }

  Future<void> _showFieldReview(String entityType, String id) async {
    final before = _record(widget.current, entityType, id);
    final after = _record(widget.incoming, entityType, id);
    if (before == null || after == null) return;
    final keys = {...before.keys, ...after.keys}.toList()..sort();
    final changedKeys = keys
        .where((key) => jsonEncode(before[key]) != jsonEncode(after[key]))
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${entityType.toUpperCase()} — $id',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: changedKeys.map((key) {
                final oldValue = before[key];
                final newValue = after[key];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(key,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('CURRENT',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w800)),
                        SelectableText(const JsonEncoder.withIndent('  ')
                            .convert(oldValue)),
                        const SizedBox(height: 6),
                        Text('INCOMING',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w800)),
                        SelectableText(const JsonEncoder.withIndent('  ')
                            .convert(newValue)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Widget _versionCard(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _CatalogMergeSummaryDialog extends StatelessWidget {
  final ProductCatalog current;
  final ProductCatalog incoming;
  final ProductCatalog merged;
  final CatalogImportSelection selection;
  final String fileName;

  const _CatalogMergeSummaryDialog({
    required this.current,
    required this.incoming,
    required this.merged,
    required this.selection,
    required this.fileName,
  });

  int get _added =>
      selection.addedCategories.length +
      selection.addedProducts.length +
      selection.addedOptions.length;
  int get _changed =>
      selection.changedCategories.length +
      selection.changedProducts.length +
      selection.changedOptions.length;
  int get _removed =>
      selection.removedCategories.length +
      selection.removedProducts.length +
      selection.removedOptions.length;
  int get _total => _added + _changed + _removed;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('MERGE SUMMARY',
          style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _versionCard('CURRENT',
                          'Schema ${current.schemaVersion}\n${current.catalogVersion}')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _versionCard('INCOMING',
                          'Schema ${incoming.schemaVersion}\n${incoming.catalogVersion}')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _versionCard('RESULT',
                          'Schema ${merged.schemaVersion}\n${merged.catalogVersion}')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('SELECTED CHANGES',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _countCard('+', 'ADDED', _added)),
                  const SizedBox(width: 8),
                  Expanded(child: _countCard('~', 'CHANGED', _changed)),
                  const SizedBox(width: 8),
                  Expanded(child: _countCard('-', 'REMOVED', _removed)),
                  const SizedBox(width: 8),
                  Expanded(child: _countCard('', 'TOTAL', _total)),
                ],
              ),
              const SizedBox(height: 16),
              _breakdown(
                  'CATEGORIES',
                  selection.addedCategories.length,
                  selection.changedCategories.length,
                  selection.removedCategories.length),
              _breakdown(
                  'PRODUCTS',
                  selection.addedProducts.length,
                  selection.changedProducts.length,
                  selection.removedProducts.length),
              _breakdown(
                  'OPTIONS / ADD-ONS',
                  selection.addedOptions.length,
                  selection.changedOptions.length,
                  selection.removedOptions.length),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'This is the final review of the selected merge. No catalog data has been changed yet. A backup will be created immediately before persistence.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_removed > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.deepOrange),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_removed selected removal${_removed == 1 ? '' : 's'} will require the destructive-change warning on the next step.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BACK TO MERGE')),
        FilledButton(
            onPressed: _total == 0 ? null : () => Navigator.pop(context, true),
            child: const Text('CONTINUE')),
      ],
    );
  }

  Widget _breakdown(String title, int added, int changed, int removed) {
    if (added + changed + removed == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('+ $added'),
          const SizedBox(width: 16),
          Text('~ $changed'),
          const SizedBox(width: 16),
          Text('- $removed'),
        ],
      ),
    );
  }

  Widget _countCard(String prefix, String label, int count) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text('$prefix$count',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _versionCard(String label, String value) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
