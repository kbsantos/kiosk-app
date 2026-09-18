import 'package:bigger_brew_kiosk/product_catalog/product_catalog_repository.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/catalog_validator.dart';
import 'package:bigger_brew_kiosk/features/kiosk/staff_access.dart';
import 'product_size_variant_manager.dart';
import 'catalog_validation_manager.dart';
import 'package:flutter/material.dart';
import 'product_option_manager.dart';
import 'catalog_backup_restore.dart';
import 'catalog_audit_history.dart';
import 'category_manager.dart';
import 'product_manager.dart';
import 'store_catalog_sync_service.dart';
import 'store_catalog_master_service.dart';
import 'catalog_store_master_gateway.dart';
import 'historical_catalog_recovery.dart';
import '../kiosk/orders/kiosk_order_repository.dart';

class CatalogManagerDashboardPage extends StatefulWidget {
  const CatalogManagerDashboardPage({super.key});

  @override
  State<CatalogManagerDashboardPage> createState() =>
      _CatalogManagerDashboardPageState();
}

class _CatalogManagerDashboardPageState
    extends State<CatalogManagerDashboardPage> {
  final _repository = const ProductCatalogRepository();
  final _catalogSyncService = StoreCatalogSyncService();
  final _masterService = StoreCatalogMasterService();
  final _orderRepository = KioskOrderRepository();
  late final _storeMasterGateway = CatalogStoreMasterGateway(_catalogSyncService);
  ProductCatalog? _catalog;
  CatalogValidationReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _storeMasterGateway.refreshFromMaster();
      final catalog = await _repository.load();
      final report = CatalogValidator().validate(catalog);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _report = report;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recoverHistoricalCatalog() async {
    try {
      final master = await _masterService.loadMasterCatalog();
      final orders = await _orderRepository.getOrders();
      final result = HistoricalCatalogRecovery.recover(master, orders);

      if (!mounted) return;
      if (!result.hasChanges) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('HISTORICAL RECOVERY'),
            content: Text(
              result.conflicts.isEmpty
                  ? 'No missing variants or product options were found in local transaction history.'
                  : 'No safe automatic changes were found. ${result.conflicts.length} historical conflict(s) require manual review.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('RECOVER HISTORICAL CATALOG DATA?'),
          content: SingleChildScrollView(
            child: Text(
              'The current Store Master catalog will be extended using local transaction snapshots.\n\n'
              'Variants to recover: ${result.recoveredVariants}\n'
              'Shared option definitions: ${result.recoveredOptionDefinitions}\n'
              'Product option assignments: ${result.recoveredProductOptions}\n'
              'Conflicts requiring manual review: ${result.conflicts.length}\n\n'
              'Only products that still exist in the current catalog are considered. Existing catalog records are not overwritten.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('RECOVER & PUBLISH'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      await _repository.saveImportRecoveryBackup(master);
      await _repository.saveBackup(master);
      try {
        final published = await _masterService.publishCatalog(
          result.catalog,
          expectedVersion: master.catalogVersion,
          auditAction: 'Recover catalog from historical transactions',
        );
        if (!mounted) return;
        setState(() {
          _catalog = published;
          _report = CatalogValidator().validate(published);
        });
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('RECOVERY COMPLETE'),
            content: Text(
              'Published catalog version ${published.catalogVersion}.\n\n'
              'Recovered ${result.recoveredVariants} variant(s), ${result.recoveredOptionDefinitions} shared option definition(s), and ${result.recoveredProductOptions} product option assignment(s).\n\n'
              '${result.conflicts.length} conflict(s) were left unchanged for manual review.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
      } catch (_) {
        await _repository.clearImportRecoveryBackup();
        rethrow;
      }
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('HISTORICAL RECOVERY FAILED'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    }
  }

  void _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text(
          'CATALOG MANAGEMENT',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh catalog',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _header(_catalog, _report),
            const SizedBox(height: 18),
            _sectionTitle('CATALOG MANAGEMENT'),
            const SizedBox(height: 10),
            _grid([
              _tile(
                Icons.category_outlined,
                'Categories',
                'Manage customer-facing categories',
                '${_catalog?.categories.length ?? 0}',
                () => _open(const CategoryManagerPage()),
              ),
              _tile(
                Icons.inventory_2_outlined,
                'Products',
                'Manage products and availability',
                '${_catalog?.products.length ?? 0}',
                () => _open(const ProductManagerPage()),
              ),
              _tile(
                Icons.straighten,
                'Sizes & Variants',
                'Manage product sizes and variants',
                _sizeVariantSummary(_catalog),
                () => _open(const ProductSizeVariantManagerPage()),
              ),
              _tile(
                Icons.extension_outlined,
                'Options / Add-ons',
                'Manage shared and product options',
                _optionSummary(_catalog),
                () => _open(const ProductOptionManagerPage()),
              ),
              _tile(
                Icons.health_and_safety_outlined,
                'Catalog Health',
                'Validate catalog integrity',
                _report == null
                    ? 'CHECK'
                    : '${_report!.errors} errors • ${_report!.warnings} warnings',
                () => _open(const CatalogValidationPage()),
                emphasize: _report?.errors == 0,
              ),
              _tile(
                Icons.backup_outlined,
                'Backup / Restore',
                'Recover or reset local catalog changes',
                _backupSummary(),
                () => _open(const CatalogBackupRestorePage(
                  role: StaffRole.editor,
                )),
              ),
              _tile(
                Icons.history,
                'Audit History',
                'Review recent catalog changes',
                _auditSummary(),
                () => _open(const CatalogAuditHistoryPage(
                  role: StaffRole.editor,
                )),
              ),
              _tile(
                Icons.restore_page_outlined,
                'Historical Recovery',
                'Recover missing variants and options from local transactions',
                'LOCAL TRANSACTIONS',
                _recoverHistoricalCatalog,
              ),
            ]),
            const SizedBox(height: 24),
            _sectionTitle('QUICK STATUS'),
            const SizedBox(height: 10),
            _statusCard(_catalog, _report),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _loading
                            ? 'Loading the store master catalog...'
                            : 'Catalog changes are committed to the store master first, then cached locally for kiosk operation.',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                    if (_loading) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _backupSummary() => 'RECOVERY';

  String _auditSummary() => 'LOCAL HISTORY';

  Widget _header(ProductCatalog? catalog, CatalogValidationReport? report) {
    final healthy = report != null && report.errors == 0;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('BIGGER BREW',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Text('Catalog Management Hub',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                      catalog == null
                          ? 'Catalog unavailable'
                          : 'Catalog version ${catalog.catalogVersion}',
                      style: const TextStyle(color: Colors.grey)),
                ])),
            if (report != null) _healthBadge(healthy),
          ]),
        ]),
      ),
    );
  }

  Widget _healthBadge(bool healthy) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: healthy ? Colors.green : Colors.red)),
        child: Row(children: [
          Icon(healthy ? Icons.verified : Icons.error_outline,
              size: 20, color: healthy ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(healthy ? 'CATALOG READY' : 'ACTION REQUIRED',
              style: const TextStyle(fontWeight: FontWeight.w900))
        ]),
      );

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.1));

  Widget _grid(List<Widget> children) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                children.map((w) => SizedBox(width: width, child: w)).toList());
      });

  Widget _tile(IconData icon, String title, String subtitle, String value,
          VoidCallback onTap,
          {bool emphasize = false}) =>
      Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: emphasize
                      ? const Color(0xFFC69214)
                      : const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: emphasize ? const Color(0xFFC69214) : null))
                  ])),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );

  Widget _statusCard(
          ProductCatalog? catalog, CatalogValidationReport? report) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            _stat('Products', '${catalog?.products.length ?? 0}'),
            _stat('Active products',
                '${catalog?.products.where((p) => p.active).length ?? 0}'),
            _stat('Categories', '${catalog?.categories.length ?? 0}'),
            _stat('Active categories',
                '${catalog?.categories.where((c) => c.active).length ?? 0}'),
            _stat('Errors', '${report?.errors ?? 0}'),
            _stat('Warnings', '${report?.warnings ?? 0}'),
          ]),
        ),
      );

  Widget _stat(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label)
      ]));

  String _sizeVariantSummary(ProductCatalog? catalog) {
    if (catalog == null) return 'CHECK';
    final sizes = catalog.products.fold<int>(0, (n, p) => n + p.sizes.length);
    final variants =
        catalog.products.fold<int>(0, (n, p) => n + p.variants.length);
    return '$sizes sizes • $variants variants';
  }

  String _optionSummary(ProductCatalog? catalog) {
    if (catalog == null) return 'CHECK';
    final productOptions =
        catalog.products.fold<int>(0, (n, p) => n + p.options.length);
    return '${catalog.optionDefinitions.length} shared • $productOptions assigned';
  }
}
