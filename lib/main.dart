import 'package:flutter/material.dart';

import 'features/kiosk/kiosk_idle_timeout.dart';
import 'features/kiosk/pages/kiosk_home_page.dart';
import 'features/kiosk/settings/kiosk_settings_repository.dart';
import 'features/kiosk/currency/kiosk_currency.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await KioskSettingsRepository().load();
  KioskCurrency.setCode(settings.currencyCode);
  runApp(const BiggerBrewKioskApp());
}

class BiggerBrewKioskApp extends StatelessWidget {
  const BiggerBrewKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: KioskCurrency.codeNotifier,
      builder: (context, _, __) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => kioskIdleTimeoutController.touch(),
        child: MaterialApp(
        navigatorKey: kioskNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Bigger Brew Kiosk',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFC69214),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F2ED),
        ),
          home: const KioskHomePage(),
        ),
      ),
    );
  }
}
