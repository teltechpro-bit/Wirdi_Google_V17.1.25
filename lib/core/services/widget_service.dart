import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'quran_repository.dart';
import '../models/hadith_models.dart';
import '../models/prayer_models.dart';
import 'app_logger.dart';
import 'settings_service.dart';

class WidgetService {
  WidgetService._();
  static const String _androidWidgetName = 'WirdiWidgetProvider';
  static const String _iosWidgetName = 'WirdiWidget';

  static Future<void> updateHadith(HadithModel hadith) async {
    if (appSettings.widgetLocked) return;
    try {
      await HomeWidget.saveWidgetData<String>('hadith_text', hadith.translatedText);
      await HomeWidget.saveWidgetData<String>('hadith_arabic', hadith.arabicText);
      await _update();
    } catch (e, st) {
      AppLogger.error('Failed to update Hadith home-screen widget', error: e, stackTrace: st);
    }
  }

  static Future<void> updatePrayerTimes(List<PrayerItem> prayers, PrayerItem next) async {
    // BUGFIX: this update path was missing the widgetLocked check that
    // updateHadith() already had, so "Lock home-screen widget" appeared
    // to do nothing -- prayer times (the widget's main, most-frequently
    // refreshed content) kept overwriting the frozen display regardless
    // of the setting.
    if (appSettings.widgetLocked) return;
    try {
      await HomeWidget.saveWidgetData<String>('next_prayer_name', next.name);
      await HomeWidget.saveWidgetData<String>('next_prayer_time', next.timeText);
      await HomeWidget.saveWidgetData<int>('next_prayer_timestamp_ms', next.dateTime.millisecondsSinceEpoch);
      final minutesLeft = next.dateTime.difference(DateTime.now()).inMinutes.clamp(0, 24 * 60);
      final hours = minutesLeft ~/ 60;
      final minutes = minutesLeft % 60;
      final countdown = hours > 0 ? 'متبقي $hours س و $minutes د' : 'متبقي $minutes دقيقة';
      await HomeWidget.saveWidgetData<String>('next_prayer_countdown_text', countdown);
      await _update();
    } catch (e, st) {
      AppLogger.error('Failed to update prayer-times home-screen widget', error: e, stackTrace: st);
    }
  }

  static Future<void> updateProgress(int pagesToday, int wirdTarget, double khatmaRatio) async {
    // Same fix as updatePrayerTimes above -- this path also ignored the lock.
    if (appSettings.widgetLocked) return;
    try {
      final wirdText = wirdTarget == 0 ? '$pagesToday' : '$pagesToday/$wirdTarget';
      final khatmaText = '${(khatmaRatio * 100).round()}%';
      await HomeWidget.saveWidgetData<String>('wird_progress_text', wirdText);
      await HomeWidget.saveWidgetData<String>('khatma_percent_text', khatmaText);
      await _update();
    } catch (e, st) {
      AppLogger.error('Failed to update progress home-screen widget', error: e, stackTrace: st);
    }
  }

  static Future<void> updateAzkarRemaining(int remaining) async {
    if (appSettings.widgetLocked) return;
    try {
      await HomeWidget.saveWidgetData<String>('azkar_remaining_text', 'الأذكار المتبقية: $remaining');
      await _update();
    } catch (e, st) {
      AppLogger.error('Failed to update azkar count on home widgets', error: e, stackTrace: st);
    }
  }

  /// Select a deterministic daily ayah from the bundled, validated Quran dataset.
  /// A small 50-ayah window is shared with Android so the native widget can
  /// advance without storing the entire Quran in SharedPreferences.
  static Future<void> refreshDailyAyah() async {
    try {
      final surahs = await QuranRepository.load();
      final allAyahs = surahs.expand((surah) => surah.ayahs).where((ayah) => ayah.text.trim().isNotEmpty).toList(growable: false);
      if (allAyahs.isEmpty) return;
      final now = DateTime.now();
      final dayOfYear = now.difference(DateTime(now.year)).inDays;
      final start = (dayOfYear * 17) % allAyahs.length;
      final pool = List<String>.generate(
        50,
        (offset) => allAyahs[(start + offset) % allAyahs.length].text,
        growable: false,
      );
      await HomeWidget.saveWidgetData<String>('daily_ayah_pool_json', jsonEncode(pool));
      await HomeWidget.saveWidgetData<int>('daily_ayah_index', 0);
      await HomeWidget.saveWidgetData<String>('daily_ayah_text', pool.first);
      await HomeWidget.saveWidgetData<String>('daily_ayah_date', '${now.year}-${now.month}-${now.day}');
      await _update();
    } catch (e, st) {
      AppLogger.error('Failed to select daily ayah from Quran data', error: e, stackTrace: st);
    }
  }

  static Future<void> updateDailyAyah(String arabicText, {int? index}) async {
    try {
      await HomeWidget.saveWidgetData<String>('daily_ayah_text', arabicText);
      if (index != null) await HomeWidget.saveWidgetData<int>('daily_ayah_index', index);
      await _update();
    } catch (e, st) {
      AppLogger.error('Failed to update daily ayah widget', error: e, stackTrace: st);
    }
  }

  static Future<void> updateTasbeehCount(int count) async {
    try {
      await HomeWidget.saveWidgetData<int>('tasbeeh_count', count);
      await _update();
    } catch (e, st) {
      AppLogger.error('Failed to update tasbeeh widget', error: e, stackTrace: st);
    }
  }

  static Future<void> _update() async {
    await HomeWidget.updateWidget(androidName: _androidWidgetName, iOSName: _iosWidgetName);
    for (final name in const ['WirdiDailyWidgetProvider', 'WirdiAyahWidgetProvider', 'WirdiTasbeehWidgetProvider']) {
      try {
        await HomeWidget.updateWidget(androidName: name);
      } catch (e, st) {
        AppLogger.error('Failed to refresh $name', error: e, stackTrace: st);
      }
    }
  }
}
