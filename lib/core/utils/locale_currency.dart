import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';

/// Resolves the device region’s currency for prices on new posts.
abstract final class LocaleCurrency {
  /// ISO 4217 code from the device locale (e.g. `HUF` in Hungary, `USD` in US).
  static String get code {
    final format = NumberFormat.simpleCurrency(locale: _localeTag);
    return format.currencyName ?? 'USD';
  }

  /// Local symbol for input fields (e.g. `Ft`, `$`, `€`).
  static String get symbol {
    final format = NumberFormat.simpleCurrency(locale: _localeTag);
    final sym = format.currencySymbol.trim();
    return sym.isEmpty ? code : sym;
  }

  /// Prefix shown beside the price field, e.g. `Ft ` or `$ `.
  static String get inputPrefix => '$symbol ';

  static String get _localeTag {
    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${locale.languageCode}_$country';
    }
    return locale.languageCode;
  }
}
