import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'way2quran_models.dart';

class Way2QuranFavorites {
  static const _key = 'way2quran.favorite_reciter_slugs';

  static const _cachePrefix = 'way2quran.favorite_reciter_summary.v1.';

  static String _cacheKey(String slug) => '$_cachePrefix${Uri.encodeComponent(slug)}';

  /// Cache only the profile summary needed by the favorites grid. Audio
  /// catalogues can be large and are fetched again when a profile is opened.
  static Future<void> cacheReciter(Way2QuranReciter reciter) async {
    final slug = reciter.slug.trim();
    if (slug.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(slug), jsonEncode({
      'slug': slug,
      'arabicName': reciter.nameAr,
      'englishName': reciter.nameEn,
      'photo': reciter.photo,
      'totalViews': reciter.totalViews,
      'recitations': const <dynamic>[],
    }));
  }

  static Future<Way2QuranReciter?> cachedReciter(String slug) async {
    final normalized = _normalizeSlug(slug);
    if (normalized.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(normalized));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final reciter = Way2QuranReciter.fromJson(Map<String, dynamic>.from(decoded));
      return reciter.slug.isEmpty ? null : reciter;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeSlug(String slug) => slug.trim();

  static List<String> _normalizeFavorites(List<String>? stored) {
    if (stored == null || stored.isEmpty) return <String>[];
    final seen = <String>{};
    return stored
        .map(_normalizeSlug)
        .where((slug) => slug.isNotEmpty && seen.add(slug))
        .toList(growable: true);
  }

  static Future<List<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    final favorites = _normalizeFavorites(stored);
    // Repair stale/duplicate entries created by older app versions.
    if (stored != null &&
        (stored.length != favorites.length ||
            !_sameOrder(stored, favorites))) {
      await prefs.setStringList(_key, favorites);
    }
    return favorites;
  }

  static bool _sameOrder(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }

  static Future<bool> contains(String slug) async {
    final normalized = _normalizeSlug(slug);
    if (normalized.isEmpty) return false;
    return (await all()).contains(normalized);
  }

  /// Returns true when the reciter is now a favorite, false when removed.
  /// Empty slugs are ignored so a malformed API item cannot pollute storage.
  static Future<bool> toggle(String slug) async {
    final normalized = _normalizeSlug(slug);
    if (normalized.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final favorites = _normalizeFavorites(prefs.getStringList(_key));
    final wasFavorite = favorites.remove(normalized);
    if (!wasFavorite) favorites.add(normalized);
    await prefs.setStringList(_key, favorites);
    return !wasFavorite;
  }
}
