import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads Supabase configuration from the local .env file.
///
/// Keep real credentials and project-specific IDs out of source control.
/// Use .env.example as a template.
class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL']?.trim() ?? '';

  /// Supports the current Supabase publishable key name while remaining
  /// compatible with the older anon key environment variable.
  static String get publishableKey {
    final current = dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
    if (current.isNotEmpty) return current;
    return dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
  }

  static String get storeId =>
      dotenv.env['SUPABASE_STORE_ID']?.trim() ?? '';

  static String get deviceId =>
      dotenv.env['SUPABASE_DEVICE_ID']?.trim() ?? '';

  static bool get isConfigured =>
      url.isNotEmpty && publishableKey.isNotEmpty;

  static bool get isReportingSyncConfigured =>
      isConfigured && storeId.isNotEmpty && deviceId.isNotEmpty;
}
