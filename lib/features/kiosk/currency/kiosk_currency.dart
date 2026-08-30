import 'package:flutter/foundation.dart';

class KioskCurrencyDefinition {
  final String code;
  final String symbol;
  final String name;

  const KioskCurrencyDefinition({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

class KioskCurrency {
  static final ValueNotifier<String> codeNotifier = ValueNotifier<String>('PHP');
  static const definitions = <KioskCurrencyDefinition>[
    KioskCurrencyDefinition(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
    KioskCurrencyDefinition(code: 'USD', symbol: r'$', name: 'US Dollar'),
    KioskCurrencyDefinition(code: 'SGD', symbol: r'S$', name: 'Singapore Dollar'),
    KioskCurrencyDefinition(code: 'AUD', symbol: r'A$', name: 'Australian Dollar'),
    KioskCurrencyDefinition(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  ];

  static String _code = 'PHP';

  static String get code => _code;

  static KioskCurrencyDefinition get definition => definitions.firstWhere(
        (currency) => currency.code == _code,
        orElse: () => definitions.first,
      );

  static String get symbol => definition.symbol;

  static void setCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (definitions.any((currency) => currency.code == normalized)) {
      _code = normalized;
    } else {
      _code = 'PHP';
    }
    if (codeNotifier.value != _code) {
      codeNotifier.value = _code;
    }
  }

  static String format(num amount) {
    final value = amount.toDouble();
    final negative = value < 0;
    final absolute = value.abs();
    final whole = absolute.truncate();
    final fraction = ((absolute - whole) * 100).round();
    final adjustedWhole = fraction == 100 ? whole + 1 : whole;
    final adjustedFraction = fraction == 100 ? 0 : fraction;
    final grouped = _groupThousands(adjustedWhole);
    final decimal = adjustedFraction == 0
        ? ''
        : '.${adjustedFraction.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}$symbol$grouped$decimal';
  }

  static String formatCode(num amount) => '$code ${format(amount).substring(symbol.length)}';

  static String _groupThousands(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}
