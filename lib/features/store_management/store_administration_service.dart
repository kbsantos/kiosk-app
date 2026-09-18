import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'store_administration.dart';

/// Store administration is intentionally isolated from kiosk-local settings.
/// The `stores` table remains the backend authority; this service never writes
/// kiosk transaction or catalog data.
class StoreAdministrationService {
  const StoreAdministrationService();

  Future<List<StoreAdministrationRecord>> loadStores() async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    final response = await Supabase.instance.client
        .from('stores')
        .select('*')
        .order('created_at', ascending: true);
    return response
        .map((row) => StoreAdministrationRecord.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .where((store) => store.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<int> activeDeviceCount(String storeId) async {
    final id = storeId.trim();
    if (id.isEmpty || !SupabaseConfig.isConfigured) return 0;
    final response = await Supabase.instance.client
        .from('devices')
        .select('id')
        .eq('store_id', id)
        .eq('is_active', true);
    return response.length;
  }

  Future<StoreAdministrationRecord> createStore(
    StoreAdministrationDraft draft,
  ) async {
    final value = draft.normalized();
    value.validate();
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }

    final row = await Supabase.instance.client
        .from('stores')
        .insert({
          'name': value.name,
          'address': value.address,
          'is_active': value.active,
        })
        .select('*')
        .single();
    final record = StoreAdministrationRecord.fromJson(
      Map<String, dynamic>.from(row),
    );
    await _writeAudit(record, 'CREATE');
    return record;
  }

  Future<StoreAdministrationRecord> updateStore({
    required String storeId,
    required StoreAdministrationDraft draft,
    required int activeDeviceCount,
  }) async {
    final value = draft.normalized();
    value.validate();
    if (storeId.trim().isEmpty) {
      throw ArgumentError('Store ID is required.');
    }
    if (!StoreAdministrationRules.canDeactivate(
      activeDeviceCount: activeDeviceCount,
      requestedActive: value.active,
    )) {
      throw StateError(
        'A store with active kiosk devices cannot be deactivated. Deactivate or reassign its active devices first.',
      );
    }
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }

    final row = await Supabase.instance.client
        .from('stores')
        .update({
          'name': value.name,
          'address': value.address,
          'is_active': value.active,
        })
        .eq('id', storeId.trim())
        .select('*')
        .single();
    final record = StoreAdministrationRecord.fromJson(
      Map<String, dynamic>.from(row),
    );
    await _writeAudit(record, 'UPDATE');
    return record;
  }

  Future<void> _writeAudit(
    StoreAdministrationRecord record,
    String action,
  ) async {
    try {
      await Supabase.instance.client.from('store_administration_audit').insert({
        'store_id': record.id,
        'action': action,
        'store_name': record.name,
        'is_active': record.active,
      });
    } catch (_) {
      // Store changes remain authoritative even if audit logging is unavailable.
    }
  }
}
