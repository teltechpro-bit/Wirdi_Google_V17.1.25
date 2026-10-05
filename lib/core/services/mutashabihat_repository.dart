import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class SimilarVerse {
  final int surah;
  final int ayah;

  /// Word-level similarity, 0-100.
  final int score;
  const SimilarVerse(this.surah, this.ayah, this.score);
}

/// Pre-computed list of Quran verses that are textually very close to other
/// verses (assets/data/mutashabihat.json). Generated automatically from the
/// bundled Quran text by word-level similarity; it is a study aid, not a
/// scholarly, exhaustive catalogue.
class MutashabihatRepository {
  MutashabihatRepository._();

  static Map<String, List<SimilarVerse>>? _cache;

  static Future<Map<String, List<SimilarVerse>>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/mutashabihat.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, List<SimilarVerse>>{};
    decoded.forEach((key, value) {
      final list = <SimilarVerse>[];
      for (final item in value as List<dynamic>) {
        final row = item as List<dynamic>;
        list.add(SimilarVerse(row[0] as int, row[1] as int, row[2] as int));
      }
      out[key] = list;
    });
    _cache = out;
    return out;
  }
}
