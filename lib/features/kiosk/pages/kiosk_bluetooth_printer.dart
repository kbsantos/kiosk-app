import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../currency/kiosk_currency.dart';

import '../orders/kiosk_order.dart';

/// Bluetooth thermal-printer integration used by the XP-58H.
///
/// The XP-58H must first be paired with the Android tablet. This service then
/// works with the paired Bluetooth Classic printer and sends ESC/POS bytes.
class KioskBluetoothPrinter {
  const KioskBluetoothPrinter._();

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Returns true when the Android Bluetooth permissions needed by the kiosk
  /// have been granted.
  static Future<bool> hasBluetoothPermission() async {
    if (!_isAndroid) return false;

    try {
      final connect = await Permission.bluetoothConnect.status;
      final scan = await Permission.bluetoothScan.status;
      return connect.isGranted && scan.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Requests the Android 12+ Nearby devices permissions used to access the
  /// paired XP-58H. On older Android versions the legacy Bluetooth permission
  /// is handled by the OS/package and this request is harmless.
  static Future<bool> requestBluetoothPermission() async {
    if (!_isAndroid) return false;

    try {
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();

      final connect = statuses[Permission.bluetoothConnect];
      final scan = statuses[Permission.bluetoothScan];

      return connect?.isGranted == true && scan?.isGranted == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openBluetoothAppSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the native Bluetooth adapter is enabled.
  static Future<bool> isBluetoothEnabled() async {
    if (!_isAndroid) return false;

    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Returns paired Bluetooth devices. The XP-58H should be paired in Android
  /// Settings first; this is not an in-app Bluetooth pairing flow.
  static Future<List<BluetoothInfo>> pairedPrinters() async {
    if (!_isAndroid) return const [];

    if (!await hasBluetoothPermission()) {
      return const [];
    }

    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> connect(String macAddress) async {
    if (!_isAndroid || macAddress.trim().isEmpty) return false;

    try {
      if (!await hasBluetoothPermission()) {
        final granted = await requestBluetoothPermission();
        if (!granted) return false;
      }

      if (!await isBluetoothEnabled()) return false;

      return await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isConnected() async {
    if (!_isAndroid) return false;

    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> disconnect() async {
    if (!_isAndroid) return false;

    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> writeBytes(List<int> bytes) async {
    if (!_isAndroid || bytes.isEmpty) return false;

    try {
      if (!await isConnected()) return false;
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  /// Manually opens the cash drawer connected to the XP-58H drawer port.
  ///
  /// This is intentionally independent of the automatic cash-payment setting
  /// so staff can open the drawer from the main menu when needed.
  static Future<bool> openCashDrawer() async {
    if (!_isAndroid) return false;

    try {
      if (!await isConnected()) return false;

      // ESC/POS cash-drawer kick: ESC p m t1 t2.
      // m=0 targets the common XP-58H pin-2 drawer output.
      return await writeBytes([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    } catch (_) {
      return false;
    }
  }

  /// Prints the existing Bigger Brew order directly as ESC/POS.
  static Future<bool> printOrder({
    required KioskOrder order,
    required String paperSize,
    bool includeCustomerReceipt = true,
    bool includeBaristaCopy = true,
    bool includeKitchenCopy = true,
    bool openCashDrawer = false,
  }) async {
    if (!_isAndroid) return false;

    var connected = await isConnected();
    if (!connected) return false;

    final width = paperSize == '58mm' ? 32 : 42;
    final bytes = <int>[];

    void add(String value) => bytes.addAll(value.codeUnits);
    void line([String value = '']) => add('$value\n');

    final baristaItems = order.items
        .where((item) => item.product.productType.toLowerCase() == 'drink')
        .toList(growable: false);
    final kitchenItems = order.items
        .where(
          (item) =>
              item.product.kitchenPrepared ||
              item.options.any((option) => option.kitchenPrepared),
        )
        .toList(growable: false);

    add('\x1B@');
    add('\x1Ba\x01');

    if (includeCustomerReceipt) {
      add('\x1BE\x01');
      line('BIGGER BREW');
      add('\x1BE\x00');
      line('MILKTEA - COFFEE');
      line();
      line(order.orderNumber);
      line(_time(order.createdAt));
      add('\x1Ba\x00');
      line();
      line('ORDER TYPE: ${order.orderType}');
      line('PAYMENT: ${order.paymentMethod}');
      line('STATUS: ${order.paymentStatus.toUpperCase()}');
      line('-' * width);

      for (final item in order.items) {
        final name = '${item.quantity} x ${item.product.name}';
        line(_fitLine(name, KioskCurrency.formatCode(item.total), width));
        if (item.size != null) {
          line('  ${item.size!.name}'
              '${item.size!.displayVolume == null ? '' : ' - ${item.size!.displayVolume}'}');
        }
        if (item.variant != null) {
          line('  ${item.variant!.name}');
        }
        for (final option in item.options) {
          line('  + ${option.name}');
        }
      }

      line('-' * width);
      add('\x1BE\x01');
      line(_fitLine('TOTAL', KioskCurrency.formatCode(order.total), width));
      add('\x1BE\x00');
    }

    // Keep production copies tight: no blank feed lines before or after
    // Barista/Kitchen copies. The separator lines provide the visual boundary.
    if (includeBaristaCopy && baristaItems.isNotEmpty) {
      line('-' * width);
      add('\x1BE\x01');
      line('BARISTA COPY');
      add('\x1BE\x00');
      line('ORDER ${order.orderNumber}');
      line('-' * width);

      for (final item in baristaItems) {
        line('${item.quantity} x ${item.product.name}');
        if (item.size != null) {
          line('  ${item.size!.name}'
              '${item.size!.displayVolume == null ? '' : ' - ${item.size!.displayVolume}'}');
        }
        if (item.variant != null) line('  ${item.variant!.name}');
        for (final option in item.options) {
          line('  + ${option.name}');
        }
      }
    }

    if (includeKitchenCopy && kitchenItems.isNotEmpty) {
      line('-' * width);
      add('\x1BE\x01');
      line('KITCHEN COPY');
      add('\x1BE\x00');
      line('ORDER ${order.orderNumber}');
      line('-' * width);

      for (final item in kitchenItems) {
        line('${item.quantity} x ${item.product.name}');
        if (item.size != null) {
          line('  ${item.size!.name}'
              '${item.size!.displayVolume == null ? '' : ' - ${item.size!.displayVolume}'}');
        }
        if (item.variant != null) line('  ${item.variant!.name}');
        for (final option in item.options.where((o) => o.kitchenPrepared)) {
          line('  + ${option.name}');
        }
      }
    }

    // Keep the production copy compact, but leave a small trailing feed so
    // the thermal printer advances the paper far enough for a clean tear/cut.
    final hasProductionCopy =
        (includeBaristaCopy && baristaItems.isNotEmpty) ||
        (includeKitchenCopy && kitchenItems.isNotEmpty);
    if (hasProductionCopy) {
      line();
      line();
      line();
    } else {
      line();
    }

    if (openCashDrawer && includeCustomerReceipt) {
      bytes.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    }

    connected = await isConnected();
    if (!connected) return false;

    return writeBytes(bytes);
  }

  /// Sends a small text-only test receipt to the connected XP-58H.
  static Future<bool> testPrint({required String paperSize}) async {
    if (!_isAndroid) return false;

    var connected = await isConnected();
    if (!connected) return false;

    final separator = paperSize == '58mm'
        ? '--------------------------------\n'
        : '------------------------------------------\n';

    final parts = <String>[
      '\x1B@',
      '\x1Ba\x01',
      '\x1BE\x01',
      'BIGGER BREW\n',
      '\x1BE\x00',
      'PRINTER TEST\n',
      '\x1Ba\x00',
      separator,
      'Printer: XP-58H\n',
      'Connection: Bluetooth\n',
      'Paper: $paperSize\n',
      separator,
      'Bluetooth connection: OK\n',
      'ESC/POS communication: OK\n',
      separator,
      '\x1Ba\x01',
      '\x1BE\x01',
      'TEST PRINT SUCCESSFUL\n',
      '\x1BE\x00',
      '\x1Ba\x00',
      '\n\n\n',
    ];

    final bytes = <int>[];
    for (final part in parts) {
      bytes.addAll(part.codeUnits);
    }

    final result = await writeBytes(bytes);
    connected = await isConnected();
    return result && connected;
  }

  static String _fitLine(String left, String right, int width) {
    final gap = width - left.length - right.length;
    if (gap >= 1) {
      return '$left${' ' * gap}$right';
    }

    final maxLeft = width - right.length - 1;
    if (maxLeft <= 0) return right;
    final shortened = left.length > maxLeft ? left.substring(0, maxLeft) : left;
    return '$shortened $right';
  }

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}
