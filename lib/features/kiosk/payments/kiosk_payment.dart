enum KioskPaymentMethod {
  gcash,
  cash,
  others,
}

enum KioskPaymentStatus {
  pending,
  paid,
  failed,
  cancelled,
}

extension KioskPaymentMethodX on KioskPaymentMethod {
  String get label {
    switch (this) {
      case KioskPaymentMethod.gcash:
        return 'GCash';
      case KioskPaymentMethod.cash:
        return 'Cash';
      case KioskPaymentMethod.others:
        return 'Others';
    }
  }

  String get value => name;
}

extension KioskPaymentStatusX on KioskPaymentStatus {
  String get value => name;

  static KioskPaymentStatus fromValue(String value) {
    return KioskPaymentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => KioskPaymentStatus.pending,
    );
  }
}

/// Payment tagging boundary for the kiosk.
///
/// At this stage the kiosk records the customer's selected payment mode.
/// Actual GCash/card gateway processing can be added behind this interface
/// later without changing the checkout flow.
abstract interface class KioskPaymentProcessor {
  Future<KioskPaymentResult> startPayment({
    required int amount,
    required KioskPaymentMethod method,
  });
}

class KioskPaymentResult {
  final KioskPaymentStatus status;
  final String? reference;

  const KioskPaymentResult({
    required this.status,
    this.reference,
  });

  bool get isSuccessful => status == KioskPaymentStatus.paid;
}

/// Current kiosk behavior: record the selected payment mode as pending.
/// Payment can be completed/verified by the store workflow later.
class CounterPaymentProcessor implements KioskPaymentProcessor {
  const CounterPaymentProcessor();

  @override
  Future<KioskPaymentResult> startPayment({
    required int amount,
    required KioskPaymentMethod method,
  }) async {
    return const KioskPaymentResult(
      status: KioskPaymentStatus.pending,
      reference: null,
    );
  }
}
