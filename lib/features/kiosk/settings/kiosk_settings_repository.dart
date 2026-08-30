import 'package:shared_preferences/shared_preferences.dart';

class KioskSettings {
  final bool storeOpen;
  final String storeName;
  final String printerPaperSize;
  final String printerConnectionType;
  final String? bluetoothPrinterAddress;
  final String? bluetoothPrinterName;
  final String? printerId;
  final String? printerName;
  final bool employeeOrderMode;
  final bool printCustomerReceipt;
  final bool autoPrintReceipt;
  final bool printOrderTicket;
  final bool printBaristaCopy;
  final bool printKitchenCopy;
  final bool printSingleItemPerTicket;
  final bool groupIdenticalItems;
  final String? eodReportEmail;
  final String currencyCode;
  final bool openCashDrawerOnCashPayment;

  const KioskSettings({
    this.storeOpen = true,
    this.storeName = 'BIGGER BREW',
    this.printerPaperSize = '58mm',
    this.printerConnectionType = 'bluetooth',
    this.bluetoothPrinterAddress,
    this.bluetoothPrinterName,
    this.printerId,
    this.printerName,
    this.employeeOrderMode = true,
    this.printCustomerReceipt = true,
    this.autoPrintReceipt = true,
    this.printOrderTicket = true,
    this.printBaristaCopy = true,
    this.printKitchenCopy = true,
    this.printSingleItemPerTicket = false,
    this.groupIdenticalItems = true,
    this.eodReportEmail,
    this.currencyCode = 'PHP',
    this.openCashDrawerOnCashPayment = false,
  });

  KioskSettings copyWith({
    bool? storeOpen,
    String? storeName,
    String? printerPaperSize,
    String? printerConnectionType,
    String? bluetoothPrinterAddress,
    String? bluetoothPrinterName,
    bool clearBluetoothPrinter = false,
    String? printerId,
    String? printerName,
    bool clearPrinter = false,
    bool? employeeOrderMode,
    bool? printCustomerReceipt,
    bool? autoPrintReceipt,
    bool? printOrderTicket,
    bool? printBaristaCopy,
    bool? printKitchenCopy,
    bool? printSingleItemPerTicket,
    bool? groupIdenticalItems,
    String? eodReportEmail,
    bool clearEodReportEmail = false,
    String? currencyCode,
    bool? openCashDrawerOnCashPayment,
  }) {
    return KioskSettings(
      storeOpen: storeOpen ?? this.storeOpen,
      storeName: storeName ?? this.storeName,
      printerPaperSize: printerPaperSize ?? this.printerPaperSize,
      printerConnectionType: printerConnectionType ?? this.printerConnectionType,
      bluetoothPrinterAddress: clearBluetoothPrinter
          ? null
          : (bluetoothPrinterAddress ?? this.bluetoothPrinterAddress),
      bluetoothPrinterName: clearBluetoothPrinter
          ? null
          : (bluetoothPrinterName ?? this.bluetoothPrinterName),
      printerId: clearPrinter ? null : (printerId ?? this.printerId),
      printerName: clearPrinter ? null : (printerName ?? this.printerName),
      employeeOrderMode: employeeOrderMode ?? this.employeeOrderMode,
      printCustomerReceipt: printCustomerReceipt ?? this.printCustomerReceipt,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      printOrderTicket: printOrderTicket ?? this.printOrderTicket,
      printBaristaCopy: printBaristaCopy ?? this.printBaristaCopy,
      printKitchenCopy: printKitchenCopy ?? this.printKitchenCopy,
      printSingleItemPerTicket:
          printSingleItemPerTicket ?? this.printSingleItemPerTicket,
      groupIdenticalItems: groupIdenticalItems ?? this.groupIdenticalItems,
      eodReportEmail: clearEodReportEmail ? null : (eodReportEmail ?? this.eodReportEmail),
      currencyCode: currencyCode ?? this.currencyCode,
      openCashDrawerOnCashPayment:
          openCashDrawerOnCashPayment ?? this.openCashDrawerOnCashPayment,
    );
  }
}

class KioskSettingsRepository {
  static const _storeOpenKey = 'bigger_brew_kiosk.settings.store_open.v1';
  static const _storeNameKey = 'bigger_brew_kiosk.settings.store_name.v1';
  static const _paperSizeKey = 'bigger_brew_kiosk.settings.paper_size.v1';
  static const _printerConnectionTypeKey =
      'bigger_brew_kiosk.settings.printer_connection_type.v1';
  static const _bluetoothPrinterAddressKey =
      'bigger_brew_kiosk.settings.bluetooth_printer_address.v1';
  static const _bluetoothPrinterNameKey =
      'bigger_brew_kiosk.settings.bluetooth_printer_name.v1';
  static const _printerIdKey = 'bigger_brew_kiosk.settings.printer_id.v1';
  static const _printerNameKey = 'bigger_brew_kiosk.settings.printer_name.v1';
  static const _employeeOrderModeKey =
      'bigger_brew_kiosk.settings.employee_order_mode.v2';
  static const _printCustomerReceiptKey =
      'bigger_brew_kiosk.settings.print_customer_receipt.v1';
  static const _autoPrintReceiptKey =
      'bigger_brew_kiosk.settings.auto_print_receipt.v1';
  static const _printOrderTicketKey =
      'bigger_brew_kiosk.settings.print_order_ticket.v1';
  static const _printBaristaCopyKey =
      'bigger_brew_kiosk.settings.print_barista_copy.v1';
  static const _printKitchenCopyKey =
      'bigger_brew_kiosk.settings.print_kitchen_copy.v1';
  static const _printSingleItemPerTicketKey =
      'bigger_brew_kiosk.settings.print_single_item_per_ticket.v1';
  static const _groupIdenticalItemsKey =
      'bigger_brew_kiosk.settings.group_identical_items.v1';
  static const _eodReportEmailKey =
      'bigger_brew_kiosk.settings.eod_report_email.v1';
  static const _currencyCodeKey =
      'bigger_brew_kiosk.settings.currency_code.v1';
  static const _openCashDrawerOnCashPaymentKey =
      'bigger_brew_kiosk.settings.open_cash_drawer_on_cash_payment.v1';

  Future<KioskSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    return KioskSettings(
      storeOpen: prefs.getBool(_storeOpenKey) ?? true,
      storeName: prefs.getString(_storeNameKey) ?? 'BIGGER BREW',
      printerPaperSize: prefs.getString(_paperSizeKey) ?? '58mm',
      printerConnectionType:
          prefs.getString(_printerConnectionTypeKey) ?? 'bluetooth',
      bluetoothPrinterAddress:
          prefs.getString(_bluetoothPrinterAddressKey),
      bluetoothPrinterName: prefs.getString(_bluetoothPrinterNameKey),
      printerId: prefs.getString(_printerIdKey),
      printerName: prefs.getString(_printerNameKey),
      employeeOrderMode: prefs.getBool(_employeeOrderModeKey) ?? true,
      printCustomerReceipt: prefs.getBool(_printCustomerReceiptKey) ?? true,
      autoPrintReceipt: prefs.getBool(_autoPrintReceiptKey) ?? true,
      printOrderTicket: prefs.getBool(_printOrderTicketKey) ?? true,
      printBaristaCopy: prefs.getBool(_printBaristaCopyKey) ?? true,
      printKitchenCopy: prefs.getBool(_printKitchenCopyKey) ??
          (prefs.getBool(_printOrderTicketKey) ?? true),
      printSingleItemPerTicket:
          prefs.getBool(_printSingleItemPerTicketKey) ?? false,
      groupIdenticalItems: prefs.getBool(_groupIdenticalItemsKey) ?? true,
      eodReportEmail: prefs.getString(_eodReportEmailKey),
      currencyCode: prefs.getString(_currencyCodeKey) ?? 'PHP',
      openCashDrawerOnCashPayment:
          prefs.getBool(_openCashDrawerOnCashPaymentKey) ?? false,
    );
  }

  Future<void> setStoreOpen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storeOpenKey, value);
  }

  Future<void> setStoreName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final name = value.trim();
    await prefs.setString(
      _storeNameKey,
      name.isEmpty ? 'BIGGER BREW' : name,
    );
  }

  Future<void> setEmployeeOrderMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_employeeOrderModeKey, value);
  }

  Future<void> setPrintCustomerReceipt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_printCustomerReceiptKey, value);
  }

  Future<void> setAutoPrintReceipt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrintReceiptKey, value);
  }

  Future<void> setPrintOrderTicket(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_printOrderTicketKey, value);
    await prefs.setBool(_printKitchenCopyKey, value);
  }

  Future<void> setPrintBaristaCopy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_printBaristaCopyKey, value);
  }

  Future<void> setPrintKitchenCopy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_printKitchenCopyKey, value);
    await prefs.setBool(_printOrderTicketKey, value);
  }

  Future<void> setPrintSingleItemPerTicket(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_printSingleItemPerTicketKey, value);
  }

  Future<void> setGroupIdenticalItems(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_groupIdenticalItemsKey, value);
  }



  Future<void> setOpenCashDrawerOnCashPayment(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_openCashDrawerOnCashPaymentKey, value);
  }

  Future<void> setCurrencyCode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodeKey, value.trim().toUpperCase());
  }

  Future<void> setEodReportEmail(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final email = value.trim();
    if (email.isEmpty) {
      await prefs.remove(_eodReportEmailKey);
      return;
    }
    await prefs.setString(_eodReportEmailKey, email);
  }

  Future<void> clearEodReportEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eodReportEmailKey);
  }

  Future<void> setPrinterPaperSize(String value) async {
    if (value != '58mm' && value != '80mm') {
      throw ArgumentError('Unsupported printer paper size: $value');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paperSizeKey, value);
  }


  Future<void> setBluetoothPrinter({
    required String address,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerConnectionTypeKey, 'bluetooth');
    await prefs.setString(_bluetoothPrinterAddressKey, address);
    await prefs.setString(_bluetoothPrinterNameKey, name);
  }

  Future<void> clearBluetoothPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bluetoothPrinterAddressKey);
    await prefs.remove(_bluetoothPrinterNameKey);
  }

  Future<void> setPrinterConnectionType(String value) async {
    if (value != 'bluetooth' && value != 'system') {
      throw ArgumentError('Unsupported printer connection type: $value');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerConnectionTypeKey, value);
  }

  Future<void> setPrinter({
    required String printerId,
    required String printerName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerIdKey, printerId);
    await prefs.setString(_printerNameKey, printerName);
  }

  Future<void> clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerIdKey);
    await prefs.remove(_printerNameKey);
  }
}
