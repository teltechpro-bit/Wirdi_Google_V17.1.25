import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// How a prayer was performed on a given day.
enum PrayerStatus { onTime, late, missed }

/// Local daily prayer log (which of the five prayers were prayed, and how).
///
/// Stored as one JSON object in SharedPreferences:
/// `{"2026-10-05": {"Fajr": "ontime", "Dhuhr": "late"}}`.
class PrayerLogService {
  PrayerLogService._();

  static const String _key = 'prayer_log_v1';
  static const List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _encode(PrayerStatus s) => switch (s) {
        PrayerStatus.onTime => 'ontime',
        PrayerStatus.late => 'late',
        PrayerStatus.missed => 'missed',
      };

  static PrayerStatus? decode(String? raw) => switch (raw) {
        'ontime' => PrayerStatus.onTime,
        'late' => PrayerStatus.late,
        'missed' => PrayerStatus.missed,
        _ => null,
      };

  /// Whole log: day key -> prayer id -> status string.
  static Future<Map<String, Map<String, String>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, Map<String, String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, String>>{};
      final out = <String, Map<String, String>>{};
      decoded.forEach((k, v) {
        if (v is Map) {
          out[k.toString()] = v.map((a, b) => MapEntry(a.toString(), b.toString()));
        }
      });
      return out;
    } catch (e, st) {
      AppLogger.error('Prayer log could not be parsed', error: e, stackTrace: st);
      return <String, Map<String, String>>{};
    }
  }

  static Future<void> setStatus(DateTime day, String prayer, PrayerStatus? status) async {
    final all = await loadAll();
    final key = dayKey(day);
    final dayMap = Map<String, String>.from(all[key] ?? const <String, String>{});
    if (status == null) {
      dayMap.remove(prayer);
    } else {
      dayMap[prayer] = _encode(status);
    }
    if (dayMap.isEmpty) {
      all.remove(key);
    } else {
      all[key] = dayMap;
    }
    // Keep roughly the last 400 days only.
    final cutoff = dayKey(DateTime.now().subtract(const Duration(days: 400)));
    all.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }

  /// Number of prayers marked as prayed (on time or late) in [dayMap].
  static int prayedCount(Map<String, String>? dayMap) {
    if (dayMap == null) return 0;
    var n = 0;
    for (final p in prayers) {
      final s = dayMap[p];
      if (s == 'ontime' || s == 'late') n++;
    }
    return n;
  }

  /// Consecutive days (ending today, or yesterday if today isn't complete yet)
  /// on which all five prayers were prayed.
  static int currentStreak(Map<String, Map<String, String>> all) {
    var day = DateTime.now();
    if (prayedCount(all[dayKey(day)]) < 5) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (prayedCount(all[dayKey(day)]) == 5) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
