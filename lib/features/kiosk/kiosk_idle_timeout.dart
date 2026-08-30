import 'dart:async';

import 'package:flutter/material.dart';

/// Controls the customer-session idle timeout for the kiosk.
///
/// The controller is intentionally independent from the cart so it can be
/// mounted at the application root and observe touch/mouse activity across
/// category, customization, checkout, and customer queue pages.
final GlobalKey<NavigatorState> kioskNavigatorKey =
    GlobalKey<NavigatorState>();
final KioskIdleTimeoutController kioskIdleTimeoutController =
    KioskIdleTimeoutController();

class KioskIdleTimeoutController {
  static const Duration defaultTimeout = Duration(minutes: 3);

  Timer? _timer;
  bool _enabled = false;
  VoidCallback? _onTimeout;
  Duration _timeout = defaultTimeout;

  bool get enabled => _enabled;
  Duration get timeout => _timeout;

  void start({
    VoidCallback? onTimeout,
    Duration timeout = defaultTimeout,
  }) {
    _enabled = true;
    _onTimeout = onTimeout ?? _onTimeout;
    _timeout = timeout;
    _restartTimer();
  }

  void stop() {
    _enabled = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Call this from the application root whenever the customer interacts
  /// with the kiosk. Pointer-down is sufficient for the touchscreen kiosk.
  void touch() {
    if (!_enabled) return;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_enabled || _onTimeout == null) return;

    _timer = Timer(_timeout, () {
      _timer = null;
      if (!_enabled) return;
      _enabled = false;
      final callback = _onTimeout;
      _onTimeout = null;
      callback?.call();
    });
  }

  void dispose() {
    stop();
    _onTimeout = null;
  }
}
