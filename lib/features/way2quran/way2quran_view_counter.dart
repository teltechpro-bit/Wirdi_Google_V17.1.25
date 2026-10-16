import 'package:shared_preferences/shared_preferences.dart';

/// Counts reciter profile opens on this device, independently of upstream API
/// metrics. These values are private to Wirdi and start at zero on each install.
class Way2QuranViewCounter {
  Way2QuranViewCounter._();

  static const String _prefix = 'wirdi.reciter_views.v1.';

  static String _key(String slug) => '$_prefix${Uri.encodeComponent(slug.trim())}';

  static Future<int> get(String slug) async {
    if (slug.trim().isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(slug)) ?? 0;
  }

  /// Increment once when a user opens a reciter profile.
  static Future<int> increment(String slug) async {
    if (slug.trim().isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final key = _key(slug);
    final next = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, next);
    return next;
  }
}
