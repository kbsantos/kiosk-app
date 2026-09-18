import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'kiosk_device_lifecycle.dart';

class KioskDeviceLifecycleService {
  const KioskDeviceLifecycleService();

  Future<KioskDeviceLifecycleStatus> loadStatus({
    required String storeId,
    required String deviceCode,
  }) async {
    final normalizedStoreId = storeId.trim();
    final normalizedDeviceCode = deviceCode.trim();
    if (!SupabaseConfig.isConfigured ||
        normalizedStoreId.isEmpty ||
        normalizedDeviceCode.isEmpty) {
      return KioskDeviceLifecycleStatus.fromResponse(
        storeId: normalizedStoreId,
        deviceCode: normalizedDeviceCode,
        response: null,
      );
    }

    final response = await Supabase.instance.client.rpc(
      'get_kiosk_device_lifecycle_status',
      params: {
        'p_store_id': normalizedStoreId,
        'p_device_code': normalizedDeviceCode,
      },
    );

    final map = response is Map
        ? Map<String, dynamic>.from(response)
        : null;
    return KioskDeviceLifecycleStatus.fromResponse(
      storeId: normalizedStoreId,
      deviceCode: normalizedDeviceCode,
      response: map,
    );
  }
}
