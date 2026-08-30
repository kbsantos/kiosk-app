import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../pages/kiosk_receipt_printer.dart';
import '../pages/kiosk_bluetooth_printer.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../currency/kiosk_currency.dart';
import 'kiosk_settings_repository.dart';
import '../staff/kiosk_staff_access_repository.dart';

class KioskSettingsPage extends StatefulWidget {
  const KioskSettingsPage({super.key});

  @override
  State<KioskSettingsPage> createState() => _KioskSettingsPageState();
}

class _KioskSettingsPageState extends State<KioskSettingsPage> {
  final KioskSettingsRepository _repository = KioskSettingsRepository();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _eodEmailController = TextEditingController();

  KioskSettings _settings = const KioskSettings();
  bool _loading = true;
  bool _savingName = false;
  bool _loadingPrinters = false;
  bool _testingPrinter = false;
  bool _loadingBluetooth = false;
  bool _bluetoothEnabled = false;
  bool _bluetoothPermissionGranted = true;
  String? _bluetoothStatus;
  List<Printer> _printers = const [];
  List<BluetoothInfo> _bluetoothPrinters = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrinters();
    _loadBluetoothPrinters();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _eodEmailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;

    setState(() {
      _settings = settings;
      _nameController.text = settings.storeName;
      _eodEmailController.text = settings.eodReportEmail ?? '';
      KioskCurrency.setCode(settings.currencyCode);
      _loading = false;
    });
  }

  Future<void> _setStoreOpen(bool value) async {
    await _repository.setStoreOpen(value);
    if (!mounted) return;

    setState(() {
      _settings = _settings.copyWith(storeOpen: value);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Kiosk is OPEN for new orders.' : 'Kiosk is CLOSED.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveStoreName() async {
    final value = _nameController.text.trim();
    if (value.isEmpty) return;

    setState(() => _savingName = true);
    await _repository.setStoreName(value);

    if (!mounted) return;
    setState(() {
      _savingName = false;
      _settings = _settings.copyWith(storeName: value);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Store name saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _setEmployeeOrderMode(bool value) async {
    await _repository.setEmployeeOrderMode(value);
    if (!mounted) return;

    setState(() {
      _settings = _settings.copyWith(employeeOrderMode: value);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Employee Order Mode ENABLED. Orders will be PAID + COMPLETED automatically.'
              : 'Employee Order Mode disabled. Normal customer checkout restored.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveCurrency(String code) async {
    await _repository.setCurrencyCode(code);
    KioskCurrency.setCode(code);
    if (!mounted) return;
    setState(() {
      _settings = _settings.copyWith(currencyCode: KioskCurrency.code);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Currency set to ${KioskCurrency.definition.name} (${KioskCurrency.symbol}).'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveEodReportEmail() async {
    final value = _eodEmailController.text.trim();
    if (value.isEmpty) {
      await _repository.clearEodReportEmail();
      if (!mounted) return;
      setState(() {
        _settings = _settings.copyWith(clearEodReportEmail: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EOD report email cleared.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid email address.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _repository.setEodReportEmail(value);
    if (!mounted) return;
    setState(() {
      _settings = _settings.copyWith(eodReportEmail: value);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('EOD report email saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _setPrinterOption({
    required String option,
    required bool value,
  }) async {
    switch (option) {
      case 'customerReceipt':
        await _repository.setPrintCustomerReceipt(value);
        break;
      case 'autoReceipt':
        await _repository.setAutoPrintReceipt(value);
        break;
      case 'orderTicket':
        await _repository.setPrintKitchenCopy(value);
        break;
      case 'baristaCopy':
        await _repository.setPrintBaristaCopy(value);
        break;
      case 'kitchenCopy':
        await _repository.setPrintKitchenCopy(value);
        break;
      case 'singleItem':
        await _repository.setPrintSingleItemPerTicket(value);
        break;
      case 'groupIdentical':
        await _repository.setGroupIdenticalItems(value);
        break;
      case 'cashDrawer':
        await _repository.setOpenCashDrawerOnCashPayment(value);
        break;
    }

    if (!mounted) return;

    setState(() {
      _settings = _settings.copyWith(
        printCustomerReceipt: option == 'customerReceipt' ? value : null,
        autoPrintReceipt: option == 'autoReceipt' ? value : null,
        printOrderTicket: option == 'orderTicket' || option == 'kitchenCopy' ? value : null,
        printBaristaCopy: option == 'baristaCopy' ? value : null,
        printKitchenCopy: option == 'orderTicket' || option == 'kitchenCopy' ? value : null,
        printSingleItemPerTicket: option == 'singleItem' ? value : null,
        groupIdenticalItems: option == 'groupIdentical' ? value : null,
        openCashDrawerOnCashPayment:
            option == 'cashDrawer' ? value : null,
      );
    });
  }

  Future<void> _setPrinterConnectionType(String value) async {
    await _repository.setPrinterConnectionType(value);
    if (!mounted) return;

    setState(() {
      _settings = _settings.copyWith(
        printerConnectionType: value,
      );
    });
  }

  Future<void> _testBluetoothPrinter() async {
    final address = _settings.bluetoothPrinterAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the XP-58H first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _testingPrinter = true);

    try {
      var connected = await KioskBluetoothPrinter.isConnected();
      if (!connected) {
        connected = await KioskBluetoothPrinter.connect(address);
      }

      if (!connected) {
        throw Exception('Unable to connect to the selected XP-58H.');
      }

      final success = await KioskBluetoothPrinter.testPrint(
        paperSize: _settings.printerPaperSize,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test print sent to ${_settings.bluetoothPrinterName ?? 'XP-58H'}.'
                : 'The XP-58H did not accept the test print.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bluetooth test print failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _testingPrinter = false);
    }
  }

  Future<void> _setPaperSize(String value) async {
    await _repository.setPrinterPaperSize(value);
    if (!mounted) return;

    setState(() {
      _settings = _settings.copyWith(printerPaperSize: value);
    });
  }

  Future<void> _loadBluetoothPrinters() async {
    if (_loadingBluetooth) return;

    setState(() {
      _loadingBluetooth = true;
      _bluetoothStatus = null;
    });

    try {
      var permission = await KioskBluetoothPrinter.hasBluetoothPermission();

      if (!permission) {
        permission = await KioskBluetoothPrinter.requestBluetoothPermission();
      }

      if (!permission) {
        if (!mounted) return;
        setState(() {
          _bluetoothEnabled = false;
          _bluetoothPermissionGranted = false;
          _bluetoothPrinters = const [];
          _bluetoothStatus =
              'Nearby devices permission is required. Allow it for Bigger Brew.';
          _loadingBluetooth = false;
        });
        return;
      }

      final enabled = await KioskBluetoothPrinter.isBluetoothEnabled();

      if (!enabled) {
        if (!mounted) return;
        setState(() {
          _bluetoothEnabled = false;
          _bluetoothPermissionGranted = true;
          _bluetoothPrinters = const [];
          _bluetoothStatus =
              'Bluetooth is OFF. Turn on Bluetooth in Android settings.';
          _loadingBluetooth = false;
        });
        return;
      }

      final printers = await KioskBluetoothPrinter.pairedPrinters();
      if (!mounted) return;

      setState(() {
        _bluetoothEnabled = true;
        _bluetoothPermissionGranted = true;
        _bluetoothPrinters = printers;
        _bluetoothStatus = printers.isEmpty
            ? 'No paired Bluetooth printers found. Pair the XP-58H in Android Bluetooth settings first.'
            : '${printers.length} paired Bluetooth device(s) found.';
        _loadingBluetooth = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBluetooth = false;
        _bluetoothStatus = 'Unable to read Bluetooth printers: $error';
      });
    }
  }

  Future<void> _searchBluetoothPrinters() async {
    await _loadBluetoothPrinters();
    if (!mounted) return;

    final selected = await showDialog<BluetoothInfo>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'BLUETOOTH PRINTERS',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 420,
            child: _bluetoothPrinters.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No paired Bluetooth printers were found. Pair the XP-58H in Android Bluetooth settings first, then search again.',
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _bluetoothPrinters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final printer = _bluetoothPrinters[index];
                      final selectedPrinter = printer.macAdress ==
                          _settings.bluetoothPrinterAddress;
                      return ListTile(
                        leading: Icon(
                          Icons.print_outlined,
                          color:
                              selectedPrinter ? const Color(0xFFC69214) : null,
                        ),
                        title: Text(
                          printer.name.isEmpty
                              ? 'Unknown printer'
                              : printer.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(printer.macAdress),
                        trailing: selectedPrinter
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFFC69214))
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(dialogContext).pop(printer),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );

    if (!mounted || selected == null) return;
    await _selectBluetoothPrinter(selected);
  }

  Future<void> _selectBluetoothPrinter(BluetoothInfo printer) async {
    try {
      final connected = await KioskBluetoothPrinter.connect(
        printer.macAdress,
      );

      if (!connected) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to connect to ${printer.name}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await _repository.setBluetoothPrinter(
        address: printer.macAdress,
        name: printer.name,
      );

      await _repository.setPrinterConnectionType('bluetooth');

      if (!mounted) return;

      setState(() {
        _settings = _settings.copyWith(
          printerConnectionType: 'bluetooth',
          bluetoothPrinterAddress: printer.macAdress,
          bluetoothPrinterName: printer.name,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${printer.name} connected and selected.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bluetooth connection failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {}
  }

  Future<void> _clearBluetoothPrinter() async {
    await KioskBluetoothPrinter.disconnect();
    await _repository.clearBluetoothPrinter();

    if (!mounted) return;

    setState(() {
      _settings = _settings.copyWith(
        clearBluetoothPrinter: true,
        printerConnectionType: 'bluetooth',
      );
    });
  }

  Future<void> _loadPrinters() async {
    if (_loadingPrinters) return;

    setState(() => _loadingPrinters = true);

    try {
      final printers = await KioskReceiptPrinter.listAvailablePrinters();
      if (!mounted) return;

      setState(() {
        _printers = printers;
        _loadingPrinters = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingPrinters = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to list printers: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectPrinter(Printer printer) async {
    await _repository.setPrinter(
      printerId: printer.url,
      printerName: printer.name,
    );
    await _repository.setPrinterConnectionType('system');

    if (!mounted) return;

    setState(() {
      _settings = _settings.copyWith(
        printerConnectionType: 'system',
        printerId: printer.url,
        printerName: printer.name,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt printer set to ${printer.name}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testSelectedPrinter() async {
    if (_settings.printerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a receipt printer first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Printer? printer;
    for (final candidate in _printers) {
      if (candidate.url == _settings.printerId) {
        printer = candidate;
        break;
      }
    }

    if (printer == null) {
      await _loadPrinters();
      if (!mounted) return;
      for (final candidate in _printers) {
        if (candidate.url == _settings.printerId) {
          printer = candidate;
          break;
        }
      }
    }

    if (printer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected printer is not currently available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _testingPrinter = true);

    try {
      final success = await KioskReceiptPrinter.testPrint(
        printer: printer,
        paperSize: _settings.printerPaperSize,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test print sent to ${printer.name}.'
                : 'Test print was not completed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test print failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _testingPrinter = false);
    }
  }

  Future<void> _changePin() async {
    final next = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(next) || next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a new 4-digit PIN and matching confirmation.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await KioskStaffAccessRepository().setPin(next);

    _newPinController.clear();
    _confirmPinController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Staff PIN changed successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmClose() async {
    if (!_settings.storeOpen) return;

    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Close kiosk for new orders?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Existing orders will remain available in the Order Queue and Order History. Closing only prevents new customer orders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('KEEP OPEN'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('CLOSE KIOSK'),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      await _setStoreOpen(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text(
          'KIOSK SETTINGS',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _Section(
                  title: 'STORE STATUS',
                  icon: Icons.storefront_outlined,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _settings.storeOpen
                              ? 'STORE IS OPEN'
                              : 'STORE IS CLOSED',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          _settings.storeOpen
                              ? 'Customers can place new orders.'
                              : 'New orders are disabled. Existing orders remain available.',
                        ),
                        value: _settings.storeOpen,
                        onChanged: (value) {
                          if (value) {
                            _setStoreOpen(true);
                          } else {
                            _confirmClose();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'STORE IDENTITY',
                  icon: Icons.badge_outlined,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Store name',
                            hintText: 'BIGGER BREW',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _savingName ? null : _saveStoreName,
                        style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.white,
                        ),
                        child: _savingName
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('SAVE'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'CURRENCY',
                  icon: Icons.payments_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _settings.currencyCode,
                        decoration: const InputDecoration(
                          labelText: 'Display currency',
                          border: OutlineInputBorder(),
                        ),
                        items: KioskCurrency.definitions
                            .map(
                              (currency) => DropdownMenuItem<String>(
                                value: currency.code,
                                child: Text('${currency.code} (${currency.symbol}) — ${currency.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null && value != _settings.currencyCode) {
                            _saveCurrency(value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Display currency only. Prices are not converted.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'ORDER MODE',
                  icon: Icons.badge_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'EMPLOYEE ORDER MODE',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          _settings.employeeOrderMode
                              ? 'ON: PLACE ORDER marks the order PAID and COMPLETED immediately.'
                              : 'OFF: use the normal customer payment and order workflow.',
                        ),
                        value: _settings.employeeOrderMode,
                        onChanged: _setEmployeeOrderMode,
                      ),
                      const Text(
                        'Use this when an employee enters an order on behalf of a customer. The selected payment mode is still recorded for End-of-Day reporting.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'RECEIPT PRINTER',
                  icon: Icons.print_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRINTER CONFIGURATION',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue:
                            _settings.bluetoothPrinterName ?? 'XP-58H',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Printer name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: 'XP-58H',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Printer model',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _settings.printerConnectionType,
                        decoration: const InputDecoration(
                          labelText: 'Interface',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'bluetooth',
                            child: Text('Bluetooth'),
                          ),
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('System printer'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _setPrinterConnectionType(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_settings.printerConnectionType == 'bluetooth') ...[
                        TextFormField(
                          key: ValueKey(_settings.bluetoothPrinterAddress),
                          initialValue: _settings.bluetoothPrinterName ?? '',
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Bluetooth printer',
                            hintText: 'Select a paired XP-58H',
                            border: const OutlineInputBorder(),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(4),
                              child: TextButton(
                                onPressed: _loadingBluetooth
                                    ? null
                                    : _searchBluetoothPrinters,
                                child: _loadingBluetooth
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('SEARCH'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_bluetoothPermissionGranted) ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              final granted = await KioskBluetoothPrinter
                                  .requestBluetoothPermission();
                              if (!mounted) return;
                              if (granted) {
                                await _loadBluetoothPrinters();
                              } else {
                                await KioskBluetoothPrinter
                                    .openBluetoothAppSettings();
                              }
                            },
                            icon: const Icon(Icons.bluetooth),
                            label: const Text('ALLOW NEARBY DEVICES'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(
                              _bluetoothEnabled
                                  ? Icons.bluetooth
                                  : Icons.bluetooth_disabled,
                              color:
                                  _bluetoothEnabled ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                !_bluetoothEnabled
                                    ? 'Bluetooth is OFF'
                                    : !_bluetoothPermissionGranted
                                        ? 'Bluetooth permission required'
                                        : _settings.bluetoothPrinterAddress ==
                                                null
                                            ? 'No printer selected'
                                            : 'Selected: ${_settings.bluetoothPrinterName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_settings.bluetoothPrinterAddress != null)
                              TextButton(
                                onPressed: _clearBluetoothPrinter,
                                child: const Text('FORGET'),
                              ),
                          ],
                        ),
                        if (_bluetoothStatus != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _bluetoothStatus!,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                      if (_settings.printerConnectionType == 'system') ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'System printer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh system printers',
                              onPressed:
                                  _loadingPrinters ? null : _loadPrinters,
                              icon: _loadingPrinters
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        if (_printers.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: _printers.any(
                              (printer) => printer.url == _settings.printerId,
                            )
                                ? _settings.printerId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'System printer',
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('Select system printer'),
                            items: [
                              for (final printer in _printers)
                                DropdownMenuItem<String>(
                                  value: printer.url,
                                  child: Text(
                                    '${printer.name}${printer.isDefault ? ' • DEFAULT' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              final printer = _printers.firstWhere(
                                (item) => item.url == value,
                              );
                              _selectPrinter(printer);
                            },
                          ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _settings.printerPaperSize,
                        decoration: const InputDecoration(
                          labelText: 'Paper width',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '58mm',
                            child: Text('58 mm'),
                          ),
                          DropdownMenuItem(
                            value: '80mm',
                            child: Text('80 mm'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _setPaperSize(value);
                        },
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      const Text(
                        'ADVANCED SETTINGS',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Print customer receipt on checkout'),
                        value: _settings.printCustomerReceipt,
                        onChanged: (value) => _setPrinterOption(
                          option: 'customerReceipt',
                          value: value,
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Print kitchen copy'),
                        subtitle: const Text(
                          'Allow kitchen production copies to print.',
                        ),
                        value: _settings.printKitchenCopy,
                        onChanged: (value) => _setPrinterOption(
                          option: 'kitchenCopy',
                          value: value,
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Print barista copy'),
                        subtitle: const Text(
                          'Allow drink/barista copies to print.',
                        ),
                        value: _settings.printBaristaCopy,
                        onChanged: (value) => _setPrinterOption(
                          option: 'baristaCopy',
                          value: value,
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Automatically print receipt'),
                        value: _settings.autoPrintReceipt,
                        onChanged: (value) => _setPrinterOption(
                          option: 'autoReceipt',
                          value: value,
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Print single item per order ticket'),
                        value: _settings.printSingleItemPerTicket,
                        onChanged: (value) => _setPrinterOption(
                          option: 'singleItem',
                          value: value,
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                            'Group identical items in order tickets'),
                        value: _settings.groupIdenticalItems,
                        onChanged: (value) => _setPrinterOption(
                          option: 'groupIdentical',
                          value: value,
                        ),
                      ),
                      if (_settings.printerConnectionType == 'bluetooth')
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Open cash drawer for cash payments',
                          ),
                          subtitle: const Text(
                            'Requires the cash drawer to be connected to the XP-58H drawer port.',
                          ),
                          value: _settings.openCashDrawerOnCashPayment,
                          onChanged: (value) => _setPrinterOption(
                            option: 'cashDrawer',
                            value: value,
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _testingPrinter
                              ? null
                              : _settings.printerConnectionType == 'bluetooth'
                                  ? _testBluetoothPrinter
                                  : _testSelectedPrinter,
                          icon: _testingPrinter
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.print_outlined),
                          label: Text(
                            _testingPrinter ? 'PRINTING...' : 'PRINT TEST',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _settings.printerConnectionType == 'bluetooth'
                            ? 'XP-58H uses Bluetooth thermal printing. Pair it in Android Bluetooth settings before selecting it here.'
                            : 'System printer is retained as a fallback/development option.',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'EOD REPORT EMAIL',
                  icon: Icons.email_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set the email address that will receive the selected End-of-Day PDF report.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _eodEmailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'EOD report email',
                          hintText: 'reports@example.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _saveEodReportEmail,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('SAVE EMAIL'),
                            style: FilledButton.styleFrom(
                              backgroundColor: gold,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              _eodEmailController.clear();
                              await _saveEodReportEmail();
                            },
                            icon: const Icon(Icons.clear_outlined),
                            label: const Text('CLEAR'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _settings.eodReportEmail == null
                            ? 'No EOD report email is configured.'
                            : 'Current recipient: ${_settings.eodReportEmail}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Email opens the tablet email app with the generated PDF attached. Staff must confirm Send.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'STAFF ACCESS',
                  icon: Icons.lock_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You are already authenticated for this 30-minute staff session. Set a new 4-digit PIN without entering the current PIN again.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _newPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'New PIN',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new PIN',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _changePin,
                        icon: const Icon(Icons.key_outlined),
                        label: const Text('CHANGE STAFF PIN'),
                        style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Staff authentication is requested once per 30-minute in-app session. The PIN is stored locally on this kiosk.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'ORDER DATA',
                  icon: Icons.storage_outlined,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order history is kept locally on this kiosk.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'The daily order number automatically starts at BB-001 when the calendar date changes. No manual sequence reset is provided here because resetting it mid-day could create duplicate order numbers.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'K4.10 OPERATIONAL CONTROLS',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: .45),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFC69214)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
