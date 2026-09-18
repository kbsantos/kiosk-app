import 'kiosk_device_recovery.dart';

export 'kiosk_device_recovery.dart';

/// Describes a safe kiosk replacement/re-provisioning operation.
///
/// The target device must already be registered and active in Store
/// Management. This object deliberately contains no database mutation logic.
class KioskDeviceReprovisionPlan {
  const KioskDeviceReprovisionPlan({
    required this.currentStoreId,
    required this.currentDeviceCode,
    required this.targetStoreId,
    required this.targetDeviceCode,
  });

  final String currentStoreId;
  final String currentDeviceCode;
  final String targetStoreId;
  final String targetDeviceCode;

  String get normalizedTargetStoreId => targetStoreId.trim();
  String get normalizedTargetDeviceCode => targetDeviceCode.trim();

  bool get isReplacement =>
      currentStoreId.trim() != normalizedTargetStoreId ||
      currentDeviceCode.trim() != normalizedTargetDeviceCode;

  bool canApply(KioskDeviceRecoveryState state) =>
      isReplacement && state == KioskDeviceRecoveryState.verified;
}
