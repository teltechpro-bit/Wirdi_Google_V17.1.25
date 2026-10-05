import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_models.dart';
import 'app_logger.dart';
import 'notification_service.dart';
import 'prayer_service.dart';

/// Two optional reminder families that are independent from the main prayer
/// notifications:
///  * "Azkar after prayer" - a notification N minutes after each prayer.
///  * "Qiyam / last third of the night" - a notification when the last third
///    of the night (Maghrib -> next Fajr) begins.
///
/// IDs live in their own ranges so they never collide with the ids used by
/// `PrayerNotificationScheduler` (days * 30 + ...).
class ExtraRemindersService {
  ExtraRemindersService._();

  static const String _kAzkarEnabled = 'extra_post_prayer_azkar_enabled';
  static const String _kAzkarMinutes = 'extra_post_prayer_azkar_minutes';
  static const String _kQiyamEnabled = 'extra_qiyam_reminder_enabled';
  static const String _kIds = 'extra_reminder_ids_v1';

  static const int _azkarBase = 7000000;
  static const int _qiyamBase = 7100000;

  static Future<bool> azkarEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kAzkarEnabled) ?? false;

  static Future<int> azkarMinutes() async =>
      (await SharedPreferences.getInstance()).getInt(_kAzkarMinutes) ?? 10;

  static Future<bool> qiyamEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kQiyamEnabled) ?? false;

  static Future<void> setAzkarEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_kAzkarEnabled, value);

  static Future<void> setAzkarMinutes(int minutes) async =>
      (await SharedPreferences.getInstance()).setInt(_kAzkarMinutes, minutes);

  static Future<void> setQiyamEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_kQiyamEnabled, value);

  static int _dayIndex(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(DateTime(2020, 1, 1)).inDays;

  static Future<void> cancelAll() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kIds) ?? const <String>[];
    for (final raw in ids) {
      final id = int.tryParse(raw);
      if (id != null) await NotificationService.cancelById(id);
    }
    await prefs.setStringList(_kIds, <String>[]);
  }

  /// Rebuilds both reminder families from [days] (date -> that day's five
  /// prayers). Safe to call often: it cancels its own previous ids first.
  static Future<void> reschedule({
    required Map<DateTime, List<PrayerItem>> days,
    required bool isArabic,
  }) async {
    try {
      await cancelAll();
      final azkarOn = await azkarEnabled();
      final qiyamOn = await qiyamEnabled();
      if (!azkarOn && !qiyamOn) return;

      final minutes = await azkarMinutes();
      final now = DateTime.now();
      final scheduled = <String>[];
      final keys = days.keys.toList()..sort();

      if (azkarOn) {
        for (final day in keys) {
          final prayers = days[day]!;
          for (var i = 0; i < prayers.length && i < 5; i++) {
            final fireAt = prayers[i].dateTime.add(Duration(minutes: minutes));
            if (fireAt.isBefore(now)) continue;
            final id = _azkarBase + _dayIndex(day) * 10 + i;
            await NotificationService.scheduleOneTime(
              id: id,
              title: isArabic ? 'أذكار بعد الصلاة' : 'Azkar after prayer',
              body: isArabic
                  ? 'حان وقت أذكار ما بعد الصلاة. تقبّل الله طاعتك.'
                  : 'Time for your post-prayer remembrance. May Allah accept your prayer.',
              fireAt: fireAt,
            );
            scheduled.add('$id');
          }
        }
      }

      if (qiyamOn) {
        for (var k = 0; k + 1 < keys.length; k++) {
          final today = days[keys[k]]!;
          final tomorrow = days[keys[k + 1]]!;
          final start = nightStart(today);
          final end = nightEnd(tomorrow);
          if (start == null || end == null || !end.isAfter(start)) continue;
          final fireAt = lastThirdStart(start, end);
          if (fireAt.isBefore(now)) continue;
          final id = _qiyamBase + _dayIndex(keys[k]);
          await NotificationService.scheduleOneTime(
            id: id,
            title: isArabic ? 'الثلث الأخير من الليل' : 'Last third of the night',
            body: isArabic
                ? 'بدأ الثلث الأخير من الليل: وقت الدعاء والاستغفار وقيام الليل.'
                : 'The last third of the night has begun: a time for dua, istighfar and qiyam.',
            fireAt: fireAt,
          );
          scheduled.add('$id');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kIds, scheduled);
    } catch (e, st) {
      AppLogger.error('Extra reminders scheduling failed', error: e, stackTrace: st);
    }
  }

  /// Today + the coming days of prayer times (date -> five prayers), or null
  /// if they cannot be fetched right now.
  static Future<Map<DateTime, List<PrayerItem>>?> loadDays() async {
    try {
      final today = await PrayerService.fetchUsingSavedPreference();
      final upcoming = await PrayerService.fetchUpcomingPrayers(days: 14);
      final all = <DateTime, List<PrayerItem>>{};
      final t = DateTime.now();
      all[DateTime(t.year, t.month, t.day)] = today.prayers;
      upcoming.forEach((k, v) {
        all[DateTime(k.year, k.month, k.day)] = v;
      });
      return all;
    } catch (e, st) {
      AppLogger.error('Could not load prayer days for extra reminders', error: e, stackTrace: st);
      return null;
    }
  }

  /// Fetches today + the coming days itself and reschedules. Used by the
  /// screens right after the user flips a switch.
  static Future<void> refreshNow({required bool isArabic}) async {
    final all = await loadDays();
    if (all == null) return;
    await reschedule(days: all, isArabic: isArabic);
  }

  /// Night starts at Maghrib.
  static DateTime? nightStart(List<PrayerItem> prayersOfDay) {
    for (final p in prayersOfDay) {
      if (p.name == 'Maghrib') return p.dateTime;
    }
    return null;
  }

  /// Night ends at the next day's Fajr.
  static DateTime? nightEnd(List<PrayerItem> prayersOfNextDay) {
    for (final p in prayersOfNextDay) {
      if (p.name == 'Fajr') return p.dateTime;
    }
    return null;
  }

  /// Start of the last third of the night between [start] and [end].
  static DateTime lastThirdStart(DateTime start, DateTime end) {
    final third = end.difference(start).inSeconds ~/ 3;
    return end.subtract(Duration(seconds: third));
  }
}
