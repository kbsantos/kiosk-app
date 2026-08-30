import 'package:bigger_brew_kiosk/features/kiosk/pages/kiosk_category_page.dart';
import 'package:flutter/material.dart';

import '../data/kiosk_catalog_data.dart';
import '../kiosk_idle_timeout.dart';
import '../models/kiosk_models.dart';
import '../settings/kiosk_settings_repository.dart';
import '../staff/kiosk_staff_gate.dart';
import '../staff/kiosk_staff_tools_page.dart';
import 'kiosk_cart_page.dart';
import 'kiosk_bluetooth_printer.dart';
import 'kiosk_employee_order_view.dart';
import 'kiosk_transaction_view_page.dart';

class KioskHomePage extends StatefulWidget {
  const KioskHomePage({super.key});

  @override
  State<KioskHomePage> createState() => _KioskHomePageState();
}

class _KioskHomePageState extends State<KioskHomePage> {
  final KioskCart _cart = KioskCart();
  final KioskSettingsRepository _settingsRepository = KioskSettingsRepository();

  late Future<Map<KioskCategory, List<KioskProduct>>> _catalogFuture;
  late Future<KioskSettings> _settingsFuture;

  // Hidden staff access:
  // tap BIGGER BREW five times within four seconds.
  int _logoTapCount = 0;
  DateTime? _firstLogoTapAt;

  @override
  void initState() {
    super.initState();

    kioskIdleTimeoutController.start(
      onTimeout: _handleIdleTimeout,
    );

    _catalogFuture = KioskCatalogData.load();
    _settingsFuture = _settingsRepository.load();
  }

  void _handleIdleTimeout() {
    _cart.clear();

    final navigator = kioskNavigatorKey.currentState;

    if (navigator == null) return;

    navigator.popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    kioskIdleTimeoutController.stop();
    _cart.dispose();
    super.dispose();
  }

  Future<void> _openStaffMode(BuildContext context) async {
    // Capture NavigatorState BEFORE the async gap.
    // This avoids using BuildContext after await.
    final navigator = Navigator.of(context);

    kioskIdleTimeoutController.stop();

    final unlocked = await KioskStaffGate.requirePin(context);

    if (!mounted) return;

    if (!unlocked) {
      kioskIdleTimeoutController.start(
        onTimeout: _handleIdleTimeout,
      );
      return;
    }

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => const KioskStaffToolsPage(),
      ),
    );

    if (!mounted) return;

    kioskIdleTimeoutController.start(
      onTimeout: _handleIdleTimeout,
    );

    // Refresh the customer-facing state after
    // staff changes settings/catalog.
    setState(() {
      _settingsFuture = _settingsRepository.load();
      _catalogFuture = KioskCatalogData.load();
    });
  }

  void _handleLogoTap(BuildContext context) {
    final now = DateTime.now();
    final firstTap = _firstLogoTapAt;

    if (firstTap == null ||
        now.difference(firstTap) > const Duration(seconds: 4)) {
      _firstLogoTapAt = now;
      _logoTapCount = 1;
      return;
    }

    _logoTapCount += 1;

    if (_logoTapCount < 5) return;

    _logoTapCount = 0;
    _firstLogoTapAt = null;

    _openStaffMode(context);
  }

  void _reloadCatalog() {
    setState(() {
      _catalogFuture = KioskCatalogData.load();
    });
  }

  void _reloadSettings() {
    setState(() {
      _settingsFuture = _settingsRepository.load();
    });
  }

  void _openCategory(
    KioskCategory category,
    List<KioskProduct> products,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KioskCategoryPage(
          category: category,
          products: products,
          cart: _cart,
        ),
      ),
    );
  }

  // Opens the full order list.
  // The order list is intentionally not shown inline
  // on the portrait home screen so the menu remains fully visible.
  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KioskCartPage(cart: _cart),
      ),
    );
  }

  Future<void> _openTodayTransactions() async {
    // Today's Transactions is directly accessible from the main menu.
    // Keep the kiosk idle timeout paused while the transaction view is open.
    kioskIdleTimeoutController.stop();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KioskTransactionViewPage(),
      ),
    );

    if (!mounted) return;

    kioskIdleTimeoutController.start(
      onTimeout: _handleIdleTimeout,
    );
  }

  Future<void> _openCashDrawer() async {
    final settings = await _settingsFuture;
    if (!mounted) return;

    if (settings.bluetoothPrinterAddress == null ||
        settings.bluetoothPrinterAddress!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect the XP-58H printer first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    var connected = await KioskBluetoothPrinter.isConnected();
    if (!connected) {
      connected = await KioskBluetoothPrinter.connect(
        settings.bluetoothPrinterAddress!,
      );
    }

    if (!connected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to connect to the XP-58H printer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final opened = await KioskBluetoothPrinter.openCashDrawer();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened ? 'Cash drawer opened.' : 'Unable to open the cash drawer.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        centerTitle: true,
        leading: IconButton(
          tooltip: "TODAY'S TRANSACTIONS",
          onPressed: _openTodayTransactions,
          icon: const Icon(
            Icons.receipt_long_outlined,
            size: 28,
          ),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleLogoTap(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            child: Text(
              'BIGGER BREW',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'OPEN CASH DRAWER',
            onPressed: _openCashDrawer,
            icon: const Icon(
              Icons.point_of_sale_outlined,
              size: 28,
            ),
          ),
          ListenableBuilder(
            listenable: _cart,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Badge(
                  isLabelVisible: _cart.itemCount > 0,
                  label: Text('${_cart.itemCount}'),
                  child: IconButton(
                    tooltip: 'YOUR ORDER',
                    onPressed: _openCart,
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 30,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<KioskSettings>(
          future: _settingsFuture,
          builder: (context, settingsSnapshot) {
            if (settingsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (settingsSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load kiosk settings.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reloadSettings,
                      icon: const Icon(Icons.refresh),
                      label: const Text('RETRY'),
                    ),
                  ],
                ),
              );
            }

            final settings = settingsSnapshot.data ?? const KioskSettings();

            return FutureBuilder<Map<KioskCategory, List<KioskProduct>>>(
              future: _catalogFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Unable to load the menu.',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _reloadCatalog,
                          icon: const Icon(Icons.refresh),
                          label: const Text('RETRY'),
                        ),
                      ],
                    ),
                  );
                }

                final catalog = snapshot.data ??
                    const <KioskCategory, List<KioskProduct>>{};

                final categories = catalog.keys.toList(growable: false);

                if (categories.isEmpty) {
                  return const Center(
                    child: Text(
                      'No active categories are configured.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final categoriesView = GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            constraints.maxWidth >= 1200 ? 300 : 380,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (_, index) {
                        final category = categories[index];

                        final products =
                            catalog[category] ?? const <KioskProduct>[];

                        final enabled = products.isNotEmpty;

                        return Material(
                          color: Colors.white,
                          elevation: enabled ? 3 : 0,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            onTap: enabled
                                ? () => _openCategory(
                                      category,
                                      products,
                                    )
                                : null,
                            borderRadius: BorderRadius.circular(22),
                            child: Opacity(
                              opacity: enabled ? 1 : .45,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: enabled ? gold : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      category.icon,
                                      style: const TextStyle(
                                        fontSize: 34,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      category.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: dark,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (!enabled)
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          top: 5,
                                        ),
                                        child: Text(
                                          'Coming soon',
                                          style: TextStyle(
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    // Employee Order Mode gets its own fast product
                    // selection view. Customer mode keeps the existing
                    // category-first menu untouched.
                    final content = settings.employeeOrderMode
                        ? KioskEmployeeOrderView(
                            catalog: catalog,
                            cart: _cart,
                          )
                        : categoriesView;

                    if (settings.storeOpen) {
                      return content;
                    }

                    return Stack(
                      children: [
                        IgnorePointer(
                          child: Opacity(
                            opacity: .45,
                            child: content,
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 24,
                          right: 24,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF7A1F1F),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.storefront_outlined,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'STORE CLOSED — NEW ORDERS ARE TEMPORARILY DISABLED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'STAFF: TAP LOGO 5 TIMES',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
