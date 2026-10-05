import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_models.dart';
import 'app_logger.dart';
import 'extra_reminders_service.dart';

/// Dart side of the Android-only "silence the phone during prayer" feature.
/// The actual work (alarms + ringer mode) lives in Kotlin:
/// `android_overrides/kotlin/com/wirdi/wirdi/PrayerSilentMode.kt`.
///
/// The window for each prayer starts [startDelayMinutes] after the prayer time
/// (so the adhan notification is still heard and the window roughly matches the
/// congregation prayer) and lasts [durationMinutes].
class PrayerSilentModeService {
  PrayerSilentModeService._();

  static const MethodChannel _channel = MethodChannel('com.wirdi.wirdi/silent_mode');

  static const String _kEnabled = 'silent_mode_enabled';
  static const String _kStartDelay = 'silent_mode_start_delay_min';
  static const String _kDuration = 'silent_mode_duration_min';
  static const String _kRingerMode = 'silent_mode_ringer_mode';
  static const String _kPrayers = 'silent_mode_prayers';

  static const List<String> allPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  static const int _maxDays = 7;

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? false;
  static Future<int> startDelayMinutes() async =>
      (await SharedPreferences.getInstance()).getInt(_kStartDelay) ?? 10;
  static Future<int> durationMinutes() async =>
      (await SharedPreferences.getInstance()).getInt(_kDuration) ?? 20;

  /// 'vibrate' (default) or 'silent'.
  static Future<String> ringerMode() async =>
      (await SharedPreferences.getInstance()).getString(_kRingerMode) ?? 'vibrate';

  static Future<Set<String>> prayers() async {
    final stored = (await SharedPreferences.getInstance()).getStringList(_kPrayers);
    return (stored ?? allPrayers).toSet();
  }

  static Future<void> setEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kEnabled, v);
  static Future<void> setStartDelayMinutes(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_kStartDelay, v);
  static Future<void> setDurationMinutes(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_kDuration, v);
  static Future<void> setRingerMode(String v) async =>
      (await SharedPreferences.getInstance()).setString(_kRingerMode, v);
  static Future<void> setPrayers(Set<String> v) async =>
      (await SharedPreferences.getInstance()).setStringList(_kPrayers, v.toList());

  static Future<bool> hasPolicyAccess() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPolicyAccess') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openPolicySettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('openPolicySettings');
    } catch (e, st) {
      AppLogger.error('Could not open Do Not Disturb settings', error: e, stackTrace: st);
    }
  }

  static Future<void> cancel() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('cancel');
    } on MissingPluginException {
      // Native side not present (e.g. older build) - nothing to cancel.
    } catch (e, st) {
      AppLogger.error('Silent mode cancel failed', error: e, stackTrace: st);
    }
  }

  /// Sends the next days' windows to the native side. No-op when the feature is
  /// off (and cancels anything previously scheduled).
  static Future<void> reschedule(Map<DateTime, List<PrayerItem>> days) async {
    if (!isSupported) return;
    try {
      if (!await enabled()) {
        await cancel();
        return;
      }
      final startDelay = await startDelayMinutes();
      final duration = await durationMinutes();
      final mode = await ringerMode();
      final chosen = await prayers();
      final now = DateTime.now();
      final keys = days.keys.toList()..sort();
      final windows = <Map<String, int>>[];
      for (final day in keys.take(_maxDays)) {
        for (final prayer in days[day]!) {
          if (!chosen.contains(prayer.name)) continue;
          final start = prayer.dateTime.add(Duration(minutes: startDelay));
          final end = start.add(Duration(minutes: duration));
          if (end.isBefore(now)) continue;
          windows.add({
            'start': start.millisecondsSinceEpoch,
            'end': end.millisecondsSinceEpoch,
          });
        }
      }
      await _channel.invokeMethod<bool>('schedule', {'mode': mode, 'windows': windows});
    } on MissingPluginException {
      // Native side not present - the feature simply stays inactive.
    } catch (e, st) {
      AppLogger.error('Silent mode scheduling failed', error: e, stackTrace: st);
    }
  }

  static Future<void> refreshNow() async {
    final days = await ExtraRemindersService.loadDays();
    if (days == null) return;
    await reschedule(days);
  }
}
