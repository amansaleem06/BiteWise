import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';

/// Display formatting helpers.
abstract final class Formatters {
  /// 1234 → "1.2K", 5600000 → "5.6M"
  static String compactCount(int value) =>
      NumberFormat.compact(locale: 'en').format(value);

  /// Formats [value] in [currencyCode] (e.g. HUF → "Ft 2 500").
  static String price(double value, String currencyCode) {
    final locale = PlatformDispatcher.instance.locale.toString();
    final local = NumberFormat.simpleCurrency(locale: locale);
    if (local.currencyName == currencyCode) {
      return local.format(value);
    }
    return NumberFormat.simpleCurrency(name: currencyCode).format(value);
  }

  /// Short relative time: "now", "5m", "3h", "2d", then "Mar 4".
  static String relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(time);
  }
}
