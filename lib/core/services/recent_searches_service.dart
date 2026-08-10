import 'package:shared_preferences/shared_preferences.dart';

/// Device-local recent search history (most recent first, max 10).
class RecentSearchesService {
  static const _key = 'recent_searches';
  static const _max = 10;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<List<String>> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return load();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current
      ..removeWhere((e) => e.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    final trimmed = current.take(_max).toList();
    await prefs.setStringList(_key, trimmed);
    return trimmed;
  }

  Future<List<String>> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.removeWhere((e) => e == query);
    await prefs.setStringList(_key, current);
    return current;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
