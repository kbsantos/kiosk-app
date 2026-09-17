import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import 'catalog_change_guard.dart';
import 'catalog_permissions.dart';
import '../kiosk/staff_access.dart';

class CatalogBackupRestorePage extends StatefulWidget {
  const CatalogBackupRestorePage({super.key, required this.role});

  final StaffRole role;

  @override
  State<CatalogBackupRestorePage> createState() =>
      _CatalogBackupRestorePageState();
}

class _CatalogBackupRestorePageState extends State<CatalogBackupRestorePage> {
  final _repository = const ProductCatalogRepository();
  ProductCatalog? _catalog;
  ProductCatalog? _backup;
  String? _backupTime;
  String? _importRecoveryTime;
  ProductCatalog? _importRecovery;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final catalog = await _repository.load();
    final backup = await _repository.loadBackup();
    final time = await _repository.backupTimestamp();
    final importRecovery = await _repository.loadImportRecoveryBackup();
    final importRecoveryTime = await _repository.importRecoveryTimestamp();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _backup = backup;
      _backupTime = time;
      _importRecovery = importRecovery;
      _importRecoveryTime = importRecoveryTime;
      _loading = false;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup() async {
    final catalog = _catalog;
    if (catalog == null) return;
    await _run(() => _repository.saveBackup(catalog));
  }

  Future<void> _copyBackupJson() async {
    final catalog = _backup ?? _catalog;
    if (catalog == null) return;
    await Clipboard.setData(ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(catalog.toJson())));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup JSON copied to clipboard.')));
    }
  }

  Future<void> _restoreLocal() async {
    if (!await requireCatalogPermission(
        context, widget.role, CatalogPermission.restoreBackup)) {
      return;
    }
    final backup = _backup;
    if (backup == null) return;
    if (!mounted) return;
    final confirmed = await CatalogChangeGuard.confirm(
      context,
      title: 'RESTORE CATALOG BACKUP?',
      message:
          'The current local catalog overrides will be replaced by the saved backup. The bundled commercial catalog will not be changed.',
      confirmLabel: 'RESTORE BACKUP',
    );
    if (!confirmed) return;
    await _run(() => _repository.saveCatalog(backup));
  }

  Future<void> _rollbackLastImport() async {
    final recovery = _importRecovery;
    if (recovery == null) return;
    final confirmed = await CatalogChangeGuard.confirm(
      context,
      title: 'ROLL BACK LAST CATALOG IMPORT?',
      message:
          'The kiosk will restore the exact catalog state captured immediately before the most recent accepted catalog import. Changes made after that import will be replaced. The bundled commercial catalog will not be changed.',
      confirmLabel: 'ROLL BACK IMPORT',
    );
    if (!confirmed) return;

    await _run(() async {
      // Preserve the current state as the general backup before recovery.
      final current = await _repository.load();
      await _repository.saveBackup(current);
      await _repository.saveCatalog(recovery,
          auditAction: 'Rollback last catalog import');
      await _repository.clearImportRecoveryBackup();
    });
  }

  Future<void> _restoreFromClipboard() async {
    if (!await requireCatalogPermission(
        context, widget.role, CatalogPermission.restoreBackup)) {
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim();
    if (raw == null || raw.isEmpty) return;
    ProductCatalog parsed;
    try {
      parsed = ProductCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Clipboard does not contain a valid Bigger Brew catalog backup.')));
      }
      return;
    }
    if (!mounted) return;
    final confirmed = await CatalogChangeGuard.confirm(
      context,
      title: 'RESTORE FROM CLIPBOARD?',
      message:
          'This replaces the current local catalog overrides with the catalog JSON currently on the clipboard.',
      confirmLabel: 'RESTORE',
    );
    if (!confirmed) return;
    await _run(() => _repository.saveCatalog(parsed));
  }

  Future<void> _resetToBundled() async {
    if (!await requireCatalogPermission(
        context, widget.role, CatalogPermission.resetCatalog)) {
      return;
    }
    if (!mounted) return;
    final confirmed = await CatalogChangeGuard.confirm(
      context,
      title: 'RESET TO BUNDLED CATALOG?',
      message:
          'All local category, product, and option overrides will be removed. The kiosk will return to the bundled commercial catalog baseline. Create a backup first if you may need to recover these edits.',
      confirmLabel: 'RESET CATALOG',
    );
    if (!confirmed) return;
    await _run(_repository.clearAllOverrides);
  }

  String _timeLabel() {
    if (_backupTime == null) return 'No local backup created';
    return 'Last backup: ${_backupTime!.replaceFirst('T', ' ').split('.').first}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('CATALOG BACKUP / RESTORE',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
              onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _loading
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
                          const Text('RECOVERY CONTROL',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(
                              'Create a recovery snapshot before making major catalog changes. Backups contain the current merged catalog state and never modify the bundled commercial baseline.',
                              style: TextStyle(color: Colors.grey.shade800)),
                          const SizedBox(height: 12),
                          Text(_timeLabel(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                  ),
                ),
                const SizedBox(height: 14),
                _action(
                    'Create Backup',
                    'Save the current catalog as a local recovery snapshot.',
                    Icons.backup_outlined,
                    _createBackup,
                    enabled: _catalog != null),
                _action(
                    'Copy Backup JSON',
                    'Copy a complete catalog backup to the clipboard for external storage.',
                    Icons.content_copy,
                    _copyBackupJson,
                    enabled: _backup != null || _catalog != null),
                _action(
                    'Restore Local Backup',
                    'Manager only: restore the most recently saved local recovery snapshot.',
                    Icons.restore,
                    _restoreLocal,
                    enabled: _backup != null &&
                        StaffAccessPolicy.can(
                            widget.role, CatalogPermission.restoreBackup)),
                _action(
                    'Restore From Clipboard',
                    'Manager only: restore a Bigger Brew catalog JSON backup.',
                    Icons.input,
                    _restoreFromClipboard,
                    enabled: StaffAccessPolicy.can(
                        widget.role, CatalogPermission.restoreBackup)),
                _action(
                  'Roll Back Last Import',
                  _importRecoveryTime == null
                      ? 'No accepted catalog import has a rollback point.'
                      : 'Restore the state captured before the last accepted import. ${_importRecoveryTime!.replaceFirst('T', ' ').split('.').first}',
                  Icons.history_toggle_off,
                  _rollbackLastImport,
                  enabled: _importRecovery != null,
                ),
                const SizedBox(height: 10),
                _action(
                    'Reset To Bundled Catalog',
                    'Manager only: remove all local overrides and return to the bundled commercial baseline.',
                    Icons.restart_alt,
                    _resetToBundled,
                    enabled: StaffAccessPolicy.can(
                        widget.role, CatalogPermission.resetCatalog),
                    danger: true),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                        'Safety rule: backup and restore operate on local catalog overrides only. The bundled product catalog asset is never overwritten.',
                        style: TextStyle(color: Colors.grey.shade800)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _action(
      String title, String subtitle, IconData icon, VoidCallback onPressed,
      {bool enabled = true, bool danger = false}) {
    return Card(
      child: ListTile(
        enabled: enabled && !_busy,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: FilledButton(
            onPressed: enabled && !_busy ? onPressed : null,
            child: const Text('OPEN')),
      ),
    );
  }
}
