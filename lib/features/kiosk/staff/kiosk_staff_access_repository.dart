import 'package:shared_preferences/shared_preferences.dart';

class KioskStaffAccessRepository {
  static const _pinKey = 'bigger_brew_kiosk.staff_pin.v1';
  static const defaultPin = '1234';

  Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? defaultPin;
  }

  Future<bool> verifyPin(String pin) async {
    final savedPin = await getPin();
    return pin == savedPin;
  }

  Future<void> setPin(String pin) async {
    final normalized = pin.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(normalized)) {
      throw ArgumentError('Staff PIN must be exactly 4 digits.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, normalized);
  }
}
