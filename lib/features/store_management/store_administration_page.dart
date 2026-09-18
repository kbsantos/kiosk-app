import 'package:flutter/material.dart';

import 'store_administration.dart';
import 'store_administration_service.dart';

class StoreAdministrationPage extends StatefulWidget {
  const StoreAdministrationPage({super.key, this.service});

  final StoreAdministrationService? service;

  @override
  State<StoreAdministrationPage> createState() =>
      _StoreAdministrationPageState();
}

class _StoreAdministrationPageState extends State<StoreAdministrationPage> {
  late final StoreAdministrationService _service =
      widget.service ?? const StoreAdministrationService();
  List<StoreAdministrationRecord> _stores = const [];
  bool _loading = true;
  String? _error;

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
      final stores = await _service.loadStores();
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({StoreAdministrationRecord? store}) async {
    final name = TextEditingController(text: store?.name ?? '');
    final code = TextEditingController(text: store?.code ?? '');
    final address = TextEditingController(text: store?.address ?? '');
    var active = store?.active ?? true;
    try {
      final result = await showDialog<StoreAdministrationDraft>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(store == null ? 'ADD STORE' : 'EDIT STORE'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Store Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Store Code',
                      helperText: 'Store code is retained for administration display; database identity remains the UUID.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ACTIVE'),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(
                  StoreAdministrationDraft(
                    name: name.text,
                    code: code.text,
                    address: address.text,
                    active: active,
                  ),
                ),
                child: Text(store == null ? 'CREATE' : 'SAVE'),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      final draft = result.normalized();
      draft.validate();
      final deviceCount = store == null
          ? 0
          : await _service.activeDeviceCount(store.id);
      if (store == null) {
        await _service.createStore(draft);
      } else {
        await _service.updateStore(
          storeId: store.id,
          draft: draft,
          activeDeviceCount: deviceCount,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store == null ? 'Store created.' : 'Store updated.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Store save failed: $error')),
      );
    } finally {
      name.dispose();
      code.dispose();
      address.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STORE ADMINISTRATION'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _edit(),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('ADD STORE'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 52),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('RETRY')),
                    ],
                  ),
                )
              : _stores.isEmpty
                  ? const Center(child: Text('No stores found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _stores.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final store = _stores[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(store.active
                                  ? Icons.storefront
                                  : Icons.store_outlined),
                            ),
                            title: Text(
                              store.name.isEmpty ? 'Unnamed store' : store.name,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              '${store.id}\n${store.address.isEmpty ? 'No address' : store.address}',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(label: Text(store.active ? 'ACTIVE' : 'INACTIVE')),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Edit store',
                                  onPressed: () => _edit(store: store),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
