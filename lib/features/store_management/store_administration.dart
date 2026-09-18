class StoreAdministrationDraft {
  const StoreAdministrationDraft({
    required this.name,
    required this.code,
    required this.address,
    required this.active,
  });

  final String name;
  final String code;
  final String address;
  final bool active;

  StoreAdministrationDraft normalized() => StoreAdministrationDraft(
        name: name.trim(),
        code: code.trim(),
        address: address.trim(),
        active: active,
      );

  void validate() {
    final value = normalized();
    if (value.name.isEmpty) {
      throw ArgumentError('Store name is required.');
    }
    if (value.code.isEmpty) {
      throw ArgumentError('Store code is required.');
    }
  }
}

class StoreAdministrationRecord {
  const StoreAdministrationRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.active,
  });

  final String id;
  final String name;
  final String code;
  final String address;
  final bool active;

  factory StoreAdministrationRecord.fromJson(Map<String, dynamic> json) {
    String firstString(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }

    return StoreAdministrationRecord(
      id: firstString(const ['id']),
      name: firstString(const ['name', 'store_name']),
      code: firstString(const ['code', 'store_code']),
      address: firstString(const ['address']),
      active: json['is_active'] == null
          ? true
          : json['is_active'] == true,
    );
  }
}

class StoreAdministrationRules {
  const StoreAdministrationRules._();

  static bool hasIdentityConflict(
    StoreAdministrationRecord first,
    StoreAdministrationRecord second,
  ) {
    if (first.id == second.id) return false;
    final firstCode = first.code.trim().toLowerCase();
    final secondCode = second.code.trim().toLowerCase();
    return firstCode.isNotEmpty && firstCode == secondCode;
  }

  static bool canDeactivate({
    required int activeDeviceCount,
    required bool requestedActive,
  }) {
    if (requestedActive) return true;
    return activeDeviceCount == 0;
  }
}
