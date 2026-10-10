import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-installation Wirdi reciter profile views.
///
/// This deliberately does not read or increment the source website's
/// totalViewers counter. A shared cross-user counter requires a trusted
/// Wirdi backend; a client-only Firestore increment would be easy to abuse.
class Way2QuranViewCounter {
  static const _key = 'way2quran.wirdi_reciter_views.v1';

  static Future<Map<String, int>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return <String, int>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map((key, value) => MapEntry(
            key.toString(),
            int.tryParse(value.toString()) ?? 0,
          ));
    } catch (_) {
      return <String, int>{};
    }
  }

  static Future<int> count(String slug) async {
    final counts = await all();
    return counts[slug] ?? 0;
  }

  static Future<int> recordOpen(String slug) async {
    if (slug.trim().isEmpty) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final counts = await all();
      final next = (counts[slug] ?? 0) + 1;
      counts[slug] = next;
      await prefs.setString(_key, jsonEncode(counts));
      return next;
    } catch (_) {
      return count(slug);
    }
  }
}
