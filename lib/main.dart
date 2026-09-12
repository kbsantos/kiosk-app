import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';

import 'features/kiosk/kiosk_idle_timeout.dart';
import 'features/kiosk/pages/kiosk_home_page.dart';
import 'features/kiosk/settings/kiosk_settings_repository.dart';
import 'features/kiosk/currency/kiosk_currency.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reporting sync is optional. The kiosk must continue to work even when
  // Supabase is unavailable or the local .env file has not been configured.
  try {
    await dotenv.load(fileName: '.env');

    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      debugPrint('Supabase reporting sync initialized.');
    } else {
      debugPrint('Supabase not configured. Reporting sync is disabled.');
    }
  } catch (error) {
    debugPrint('Supabase initialization skipped: $error');
  }

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
