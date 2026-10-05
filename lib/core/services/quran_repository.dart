import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_sources.dart';
import '../models/quran_models.dart';
import 'app_logger.dart';
import 'local_cache_service.dart';

/// Offline-first repository for the Quran text.
///
/// The Quran text is treated as an immutable bundled dataset. Cached data is
/// returned immediately and is never silently replaced by a network response.
/// Network refreshes are still available through [load(forceRefresh: true)].
/// This keeps the text deterministic and also matches the app's privacy claim
/// that ordinary Quran reading does not require a network request.
class QuranRepository {
  static Future<Map<String, dynamic>?> getSurahSummary(int surahNumber) async {
    final summaries = {
      1: {'name': 'Al-Fatiha', 'verses': 7, 'type': 'Meccan', 'theme': 'Opening chapter'},
      2: {'name': 'Al-Baqarah', 'verses': 286, 'type': 'Medinan', 'theme': 'The Cow'},
      3: {'name': 'Aal-i-Imran', 'verses': 200, 'type': 'Medinan', 'theme': 'Family of Imran'},
    };
    return summaries[surahNumber];
  }

  static Future<Map<String, dynamic>?> getLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_read_position');
    return raw != null ? jsonDecode(raw) as Map<String, dynamic> : null;
  }

  static Future<void> saveLastReadPosition(int surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    final position = {
      'surah': surah,
      'ayah': ayah,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('last_read_position', jsonEncode(position));
  }

  QuranRepository._();

  static const String _cacheKey = 'cache_quran_json_v1';
  static const String _bundledAsset = 'assets/data/quran.json';

  static Future<String?> _loadBundled() async {
    try {
      return await rootBundle.loadString(_bundledAsset);
    } catch (e, st) {
      AppLogger.error(
        'Bundled Quran asset could not be read',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static List<SurahModel>? _memoryCache;

  static Future<List<SurahModel>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) return _memoryCache!;

    final surahs = await _loadUncached(forceRefresh: forceRefresh);
    _memoryCache = surahs;
    return surahs;
  }

  static Future<List<SurahModel>> _parseAsync(String raw) =>
      compute(_parse, raw);

  static Future<List<SurahModel>> _loadUncached({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await LocalCacheService.getString(_cacheKey);
      if (cached != null) {
        return _parseAsync(cached);
      }

      final bundled = await _loadBundled();
      if (bundled != null) {
        // Seed the cache once from the bundled, pinned dataset.
        try {
          await LocalCacheService.setString(_cacheKey, bundled);
        } catch (e, st) {
          AppLogger.error(
            'Could not seed Quran cache from bundled asset',
            error: e,
            stackTrace: st,
          );
        }
        return _parseAsync(bundled);
      }
    }

    try {
      final raw = await _fetchRaw();
      final parsed = await _parseAsync(raw);

      // Never replace a known-good dataset with malformed/incomplete data.
      if (parsed.length != 114 ||
          parsed.fold<int>(0, (sum, s) => sum + s.ayahs.length) != 6236) {
        throw Exception('Fetched Quran dataset failed completeness validation');
      }

      await LocalCacheService.setString(_cacheKey, raw);
      return parsed;
    } catch (e, st) {
      final cached = await LocalCacheService.getString(_cacheKey);
      if (cached != null) {
        AppLogger.error(
          'Quran fetch failed, falling back to cache',
          error: e,
          stackTrace: st,
        );
        return _parseAsync(cached);
      }

      final bundled = await _loadBundled();
      if (bundled != null) {
        AppLogger.error(
          'Quran fetch failed, falling back to bundled copy',
          error: e,
          stackTrace: st,
        );
        return _parseAsync(bundled);
      }

      AppLogger.error(
        'Quran fetch failed with no cache available',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static Future<String> _fetchRaw() async {
    final response = await http
        .get(Uri.parse(AppSources.quranJsonUrl))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Failed to load Quran (HTTP ${response.statusCode})');
    }

    return utf8.decode(response.bodyBytes);
  }

  static Future<DateTime?> cachedAt() =>
      LocalCacheService.getCachedAt(_cacheKey);

  static List<SurahModel> _parse(String raw) {
    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      throw Exception('Unexpected Quran JSON format');
    }

    return decoded.map<SurahModel>((item) {
      final map = item as Map<String, dynamic>;
      final versesRaw = (map['verses'] as List<dynamic>? ?? []);

      final ayahs = versesRaw.map<AyahModel>((verse) {
        final verseMap = verse as Map<String, dynamic>;
        return AyahModel(
          number: _readInt(verseMap, ['id', 'number']),
          text: _readString(verseMap, ['text']),
        );
      }).toList();

      return SurahModel(
        number: _readInt(map, ['id', 'number']),
        name: _readString(map, ['name']),
        englishName: _readString(map, ['transliteration']),
        ayahs: ayahs,
      );
    }).toList();
  }

  static int _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String _readString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) return value.toString();
    }
    return '';
  }
}
