import 'package:flutter/material.dart';

import '../../product_catalog/product_catalog_repository.dart';
import 'catalog_permissions.dart';
import '../kiosk/staff_access.dart';

class CatalogAuditHistoryPage extends StatefulWidget {
  const CatalogAuditHistoryPage({super.key, required this.role});

  final StaffRole role;

  @override
  State<CatalogAuditHistoryPage> createState() =>
      _CatalogAuditHistoryPageState();
}

class _CatalogAuditHistoryPageState extends State<CatalogAuditHistoryPage> {
  final _repository = const ProductCatalogRepository();
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _repository.loadAudit();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    if (!await requireCatalogPermission(
        context, widget.role, CatalogPermission.clearAudit)) {
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CLEAR AUDIT HISTORY?'),
        content: const Text(
            'This removes the local catalog change history. It does not change any catalog products, categories, options, or prices.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('CLEAR HISTORY')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.clearAudit();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('CATALOG AUDIT HISTORY',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh history'),
          IconButton(
              onPressed: _entries.isEmpty ||
                      !StaffAccessPolicy.can(
                          widget.role, CatalogPermission.clearAudit)
                  ? null
                  : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear history'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No catalog changes recorded yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final e = _entries[index];
                      final timestamp = e['timestamp']?.toString() ?? '';
                      final entityType =
                          e['entityType']?.toString() ?? 'catalog';
                      final entityId = e['entityId']?.toString();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(_icon(entityType))),
                          title: Text(
                              e['action']?.toString() ?? 'Catalog change',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${_formatTime(timestamp)} • ${entityType.toUpperCase()}${entityId == null || entityId.isEmpty ? '' : ' • $entityId'}'),
                                const SizedBox(height: 5),
                                Text('Before: ${e['before'] ?? '-'}'),
                                Text('After: ${e['after'] ?? '-'}'),
                              ],
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'category':
        return Icons.category_outlined;
      case 'product':
        return Icons.inventory_2_outlined;
      case 'option':
        return Icons.extension_outlined;
      default:
        return Icons.history;
    }
  }

  String _formatTime(String raw) => raw.isEmpty
      ? 'Unknown time'
      : raw.replaceFirst('T', ' ').split('.').first;
}
