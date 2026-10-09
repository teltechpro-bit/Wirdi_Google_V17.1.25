import 'package:shared_preferences/shared_preferences.dart';

class Way2QuranFavorites {
  static const _key = 'way2quran.favorite_reciter_slugs';

  static Future<List<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? <String>[];
  }

  static Future<bool> contains(String slug) async => (await all()).contains(slug);

  static Future<bool> toggle(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_key) ?? <String>[];
    final wasFavorite = favorites.remove(slug);
    if (!wasFavorite) favorites.add(slug);
    await prefs.setStringList(_key, favorites);
    return !wasFavorite;
  }
}
