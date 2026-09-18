/// Safe, non-destructive kiosk/device recovery status.
///
/// This layer verifies that the configured Store ID + Device/Kiosk Code maps
/// to an active device. It never changes device records or local transactions.
enum KioskDeviceRecoveryState {
  invalidConfiguration,
  notFound,
  inactive,
  verified,
}

class KioskDeviceRecoveryStatus {
  const KioskDeviceRecoveryStatus({
    required this.state,
    this.storeId,
    this.deviceCode,
    this.deviceUuid,
  });

  final KioskDeviceRecoveryState state;
  final String? storeId;
  final String? deviceCode;
  final String? deviceUuid;

  bool get isVerified => state == KioskDeviceRecoveryState.verified;

  String get title {
    switch (state) {
      case KioskDeviceRecoveryState.invalidConfiguration:
        return 'DEVICE IDENTITY NOT CONFIGURED';
      case KioskDeviceRecoveryState.notFound:
        return 'DEVICE NOT REGISTERED';
      case KioskDeviceRecoveryState.inactive:
        return 'DEVICE INACTIVE';
      case KioskDeviceRecoveryState.verified:
        return 'DEVICE IDENTITY VERIFIED';
    }
  }

  String get message {
    switch (state) {
      case KioskDeviceRecoveryState.invalidConfiguration:
        return 'Set a valid Store ID UUID and Device / Kiosk Code before recovery operations.';
      case KioskDeviceRecoveryState.notFound:
        return 'The configured Store ID and Device / Kiosk Code do not match a registered kiosk device.';
      case KioskDeviceRecoveryState.inactive:
        return 'The configured kiosk device exists but is inactive. Recovery must not proceed until the device is activated in Store Management.';
      case KioskDeviceRecoveryState.verified:
        return 'This kiosk identity matches an active device. Catalog refresh and transaction recovery can use the existing protected workflows.';
    }
  }

  static KioskDeviceRecoveryStatus fromResponse({
    required String storeId,
    required String deviceCode,
    required Map<String, dynamic>? response,
  }) {
    if (response == null || response['found'] != true) {
      return KioskDeviceRecoveryStatus(
        state: KioskDeviceRecoveryState.notFound,
        storeId: storeId,
        deviceCode: deviceCode,
      );
    }

    final active = response['isActive'] == true;
    final uuid = response['deviceId']?.toString().trim();
    return KioskDeviceRecoveryStatus(
      state: active
          ? KioskDeviceRecoveryState.verified
          : KioskDeviceRecoveryState.inactive,
      storeId: storeId,
      deviceCode: deviceCode,
      deviceUuid: uuid == null || uuid.isEmpty ? null : uuid,
    );
  }
}
