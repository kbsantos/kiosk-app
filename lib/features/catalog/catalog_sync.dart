import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/catalog_schema_guard.dart';
import '../../product_catalog/product_catalog_repository.dart';
import '../kiosk/staff_access.dart';
import 'catalog_change_guard.dart';
import 'catalog_permissions.dart';

class _CatalogSyncCancelledException implements Exception {
  const _CatalogSyncCancelledException();
}

class CatalogSyncPackage {
  static const int formatVersion = 1;

  final String sourceDeviceId;
  final String createdAt;
  final ProductCatalog catalog;
  final String checksum;

  const CatalogSyncPackage({
    required this.sourceDeviceId,
    required this.createdAt,
    required this.catalog,
    required this.checksum,
  });

  Map<String, dynamic> toJson() => {
        'format': 'bigger_brew_catalog_sync',
        'formatVersion': formatVersion,
        'sourceDeviceId': sourceDeviceId,
        'createdAt': createdAt,
        'catalog': catalog.toJson(),
        'checksum': checksum,
      };

  static CatalogSyncPackage fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'bigger_brew_catalog_sync') {
      throw const FormatException('Not a Bigger Brew catalog sync package.');
    }
    if (json['formatVersion'] != formatVersion) {
      throw FormatException(
          'Unsupported sync package version: ${json['formatVersion']}.');
    }
    final catalogRaw = json['catalog'];
    if (catalogRaw is! Map) {
      throw const FormatException('Sync package catalog is missing.');
    }
    final catalog = CatalogSchemaGuard.decodeAndValidate(
      Map<String, dynamic>.from(catalogRaw),
      source: 'sync package',
    );
    final sourceDeviceId = json['sourceDeviceId']?.toString().trim() ?? '';
    final createdAt = json['createdAt']?.toString().trim() ?? '';
    final checksum = json['checksum']?.toString().trim() ?? '';
    if (sourceDeviceId.isEmpty || createdAt.isEmpty || checksum.isEmpty) {
      throw const FormatException('Sync package metadata is incomplete.');
    }
    if (sourceDeviceId.length > 128) {
      throw const FormatException('Sync package source kiosk ID is too long.');
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw const FormatException(
          'Sync package creation timestamp is invalid.');
    }
    if (checksum.length != 8 ||
        !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(checksum)) {
      throw const FormatException('Sync package checksum format is invalid.');
    }
    final expected = checksumFor(catalog);
    if (checksum != expected) {
      throw const FormatException('Sync package integrity check failed.');
    }
    return CatalogSyncPackage(
      sourceDeviceId: sourceDeviceId,
      createdAt: createdAt,
      catalog: catalog,
      checksum: checksum,
    );
  }

  static CatalogSyncPackage create(
      ProductCatalog catalog, String sourceDeviceId) {
    final createdAt = DateTime.now().toIso8601String();
    return CatalogSyncPackage(
      sourceDeviceId: sourceDeviceId,
      createdAt: createdAt,
      catalog: catalog,
      checksum: checksumFor(catalog),
    );
  }

  /// Lightweight deterministic integrity marker. This is not a security signature;
  /// manager authentication controls who may export/import a sync package.
  static String checksumFor(ProductCatalog catalog) {
    final bytes =
        utf8.encode(const JsonEncoder.withIndent('').convert(catalog.toJson()));
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class CatalogSyncService {
  const CatalogSyncService(this.repository);

  final ProductCatalogRepository repository;

  Future<String> loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'bigger_brew_catalog_sync_device_id_v1';
    final existing = prefs.getString(key)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id =
        'KIOSK-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}-${random.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0').toUpperCase()}';
    await prefs.setString(key, id);
    return id;
  }

  Future<void> exportPackage(ProductCatalog catalog) async {
    final deviceId = await loadOrCreateDeviceId();
    final package = CatalogSyncPackage.create(catalog, deviceId);
    final json = const JsonEncoder.withIndent('  ').convert(package.toJson());
    final bytes = Uint8List.fromList(utf8.encode(json));
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export Bigger Brew Catalog Sync Package',
      fileName: 'bigger_brew_catalog_sync_$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path == null) {
      throw const _CatalogSyncCancelledException();
    }
  }

  Future<CatalogSyncPackage> readPackage(PlatformFile file) async {
    final bytes = await file.readAsBytes();

    if (bytes.length > 2 * 1024 * 1024) {
      throw StateError('Sync package is larger than 2 MB.');
    }

    final raw = utf8.decode(bytes, allowMalformed: false).trim();

    if (raw.isEmpty) {
      throw StateError('The selected sync package is empty.');
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException(
        'Sync package JSON must contain an object.',
      );
    }

    return CatalogSyncPackage.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }
}

class CatalogSyncPage extends StatefulWidget {
  const CatalogSyncPage({super.key, required this.role});

  final StaffRole role;

  @override
  State<CatalogSyncPage> createState() => _CatalogSyncPageState();
}

class _CatalogSyncPageState extends State<CatalogSyncPage> {
  final _repository = const ProductCatalogRepository();
  late final CatalogSyncService _service = CatalogSyncService(_repository);
  ProductCatalog? _catalog;
  String? _deviceId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = await _repository.load();
    final deviceId = await _service.loadOrCreateDeviceId();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _deviceId = deviceId;
    });
  }

  Future<void> _export() async {
    final allowed = await requireCatalogPermission(
      context,
      widget.role,
      CatalogPermission.exportSyncPackage,
    );
    if (!mounted || !allowed) {
      return;
    }
    final catalog = _catalog;
    if (catalog == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.exportPackage(catalog);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catalog sync package exported.')),
        );
      }
    } catch (e) {
      if (e is! _CatalogSyncCancelledException && mounted) {
        _message('Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final allowed = await requireCatalogPermission(
      context,
      widget.role,
      CatalogPermission.importSyncPackage,
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
      final incoming = await _service.readPackage(files.single);
      final current = _catalog ?? await _repository.load();
      final sameDevice = incoming.sourceDeviceId == _deviceId;
      if (sameDevice) {
        throw const FormatException(
          'This sync package was created by this kiosk. '
          'Use Backup / Restore for local recovery instead.',
        );
      }

      if (!mounted) {
        return;
      }

      final confirmed = await CatalogChangeGuard.confirm(
        context,
        title: 'SYNC CATALOG TO THIS KIOSK?',
        message:
            'Source: ${incoming.sourceDeviceId}\nCreated: ${incoming.createdAt}\nCatalog: ${incoming.catalog.catalogVersion}\n\nThe current catalog will be backed up first. The bundled commercial catalog remains unchanged. This sync can be rolled back through Backup / Restore.',
        confirmLabel: 'APPLY SYNC',
      );
      if (!confirmed) {
        return;
      }

      await _repository.saveBackup(current);
      await _repository.saveImportRecoveryBackup(current);
      await _repository.saveCatalog(
        incoming.catalog,
        auditAction: 'Sync catalog from source kiosk',
      );
      if (mounted) {
        setState(() => _catalog = incoming.catalog);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Catalog synchronized successfully.')));
      }
    } catch (e) {
      if (mounted) _message('Sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final canExport =
        StaffAccessPolicy.can(widget.role, CatalogPermission.exportSyncPackage);
    final canImport =
        StaffAccessPolicy.can(widget.role, CatalogPermission.importSyncPackage);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('MULTI-KIOSK CATALOG SYNC',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STORE DISTRIBUTION',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                        'Use a manager-controlled JSON package to distribute a reviewed catalog from one kiosk to another. The receiving kiosk validates the schema and integrity marker, backs up its current catalog, and keeps a rollback point.',
                        style: TextStyle(color: Colors.grey.shade800)),
                    const SizedBox(height: 14),
                    Text('THIS KIOSK: ${_deviceId ?? 'INITIALIZING…'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace')),
                    const SizedBox(height: 6),
                    Text('CATALOG: ${_catalog?.catalogVersion ?? 'LOADING…'}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
            ),
          ),
          const SizedBox(height: 14),
          _action(
              Icons.upload_file,
              'Export Sync Package',
              'Manager only. Create a portable reviewed catalog package for another kiosk.',
              _export,
              enabled: canExport && _catalog != null),
          _action(
              Icons.download,
              'Import Sync Package',
              'Manager only. Validate, back up, apply, and create a rollback point on this kiosk.',
              _import,
              enabled: canImport),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                  'Safety boundary: sync packages do not modify the bundled commercial asset. They replace only local catalog overrides. The receiving kiosk keeps both a general backup and a one-shot pre-sync rollback point.',
                  style: TextStyle(color: Colors.grey.shade800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
          IconData icon, String title, String subtitle, VoidCallback onPressed,
          {required bool enabled}) =>
      Card(
        child: ListTile(
          enabled: enabled && !_busy,
          leading: CircleAvatar(child: Icon(icon)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: FilledButton(
              onPressed: enabled && !_busy ? onPressed : null,
              child: const Text('OPEN')),
        ),
      );
}
