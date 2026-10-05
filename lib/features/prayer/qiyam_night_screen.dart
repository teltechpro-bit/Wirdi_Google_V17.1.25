import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/azkar_models.dart';
import '../../core/models/prayer_models.dart';
import '../../core/services/azkar_repository.dart';
import '../../core/services/extra_reminders_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/prayer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bi.dart';

/// Night timeline (Maghrib -> Fajr), start of the last third of the night with
/// a live countdown, an optional reminder, and the well-known night prayer dua.
class QiyamNightScreen extends StatefulWidget {
  const QiyamNightScreen({super.key});

  @override
  State<QiyamNightScreen> createState() => _QiyamNightScreenState();
}

class _QiyamNightScreenState extends State<QiyamNightScreen> {
  DateTime? _maghrib;
  DateTime? _fajr;
  bool _loading = true;
  bool _failed = false;
  bool _reminder = false;
  String? _duaText;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_loading) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final today = await PrayerService.fetchUsingSavedPreference();
      final tomorrow = await PrayerService.fetchTomorrowPrayers();
      DateTime? maghrib;
      for (final PrayerItem p in today.prayers) {
        if (p.name == 'Maghrib') maghrib = p.dateTime;
      }
      DateTime? fajr;
      if (tomorrow != null) {
        for (final PrayerItem p in tomorrow) {
          if (p.name == 'Fajr') fajr = p.dateTime;
        }
      }

      // If we are already past tomorrow's-Fajr-of-the-previous-night (i.e. it is
      // after midnight and before today's Fajr), show the night that is ongoing.
      final now = DateTime.now();
      DateTime? todayFajr;
      for (final PrayerItem p in today.prayers) {
        if (p.name == 'Fajr') todayFajr = p.dateTime;
      }
      if (todayFajr != null && now.isBefore(todayFajr)) {
        fajr = todayFajr;
        maghrib = maghrib?.subtract(const Duration(days: 1));
      }

      String? dua;
      try {
        final categories = await AzkarRepository.load();
        for (final AzkarCategoryModel c in categories) {
          if (c.id == 16) {
            for (final item in c.items) {
              if (item.id == 6) dua = item.text.replaceAll('((', '').replaceAll('))', '').trim();
            }
          }
        }
      } catch (_) {
        dua = null;
      }

      final reminder = await ExtraRemindersService.qiyamEnabled();
      if (!mounted) return;
      setState(() {
        _maghrib = maghrib;
        _fajr = fajr;
        _duaText = dua;
        _reminder = reminder;
        _failed = maghrib == null || fajr == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _toggleReminder(bool value) async {
    final arabic = isArabic(context);
    if (value) {
      await NotificationService.requestPermission();
    }
    await ExtraRemindersService.setQiyamEnabled(value);
    if (!mounted) return;
    setState(() => _reminder = value);
    await ExtraRemindersService.refreshNow(isArabic: arabic);
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _countdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'الثلث الأخير وقيام الليل', 'Last Third & Qiyam')), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bi(context, 'تعذّر حساب الليل. تأكد من الموقع والاتصال ثم أعد المحاولة.',
                              'Could not work out the night. Check location and connection, then retry.'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _failed = false;
                            });
                            _load();
                          },
                          child: Text(bi(context, 'إعادة المحاولة', 'Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final start = _maghrib!;
    final end = _fajr!;
    final now = DateTime.now();
    final nightLen = end.difference(start);
    final third = Duration(seconds: nightLen.inSeconds ~/ 3);
    final middle = start.add(Duration(seconds: nightLen.inSeconds ~/ 2));
    final lastThird = end.subtract(third);

    String status;
    Duration? remaining;
    if (now.isBefore(start)) {
      status = bi(context, 'يبدأ الليل بعد', 'Night begins in');
      remaining = start.difference(now);
    } else if (now.isBefore(lastThird)) {
      status = bi(context, 'يبدأ الثلث الأخير بعد', 'Last third begins in');
      remaining = lastThird.difference(now);
    } else if (now.isBefore(end)) {
      status = bi(context, 'أنت الآن في الثلث الأخير — ينتهي بعد', 'You are in the last third — ends in');
      remaining = end.difference(now);
    } else {
      status = bi(context, 'انتهى الليل', 'The night has ended');
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Icon(Icons.nights_stay_rounded, size: 36, color: AppColors.goldAccent),
                const SizedBox(height: 8),
                Text(status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (remaining != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _countdown(remaining),
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primaryEmerald),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _row(bi(context, 'المغرب (بداية الليل)', 'Maghrib (night begins)'), _hm(start), Icons.wb_twilight),
        _row(bi(context, 'منتصف الليل', 'Middle of the night'), _hm(middle), Icons.dark_mode_outlined),
        _row(bi(context, 'بداية الثلث الأخير', 'Last third begins'), _hm(lastThird), Icons.auto_awesome, highlight: true),
        _row(bi(context, 'الفجر (نهاية الليل)', 'Fajr (night ends)'), _hm(end), Icons.wb_sunny_outlined),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            value: _reminder,
            onChanged: _toggleReminder,
            title: Text(bi(context, 'نبّهني عند بداية الثلث الأخير', 'Remind me when the last third begins')),
            subtitle: Text(bi(context, 'كل ليلة للأيام القادمة', 'Every night for the coming days')),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  bi(context, 'حديث النزول', 'The hadith of the descent'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يَنْزِلُ رَبُّنَا تَبَارَكَ وَتَعَالَى كُلَّ لَيْلَةٍ إِلَى السَّمَاءِ الدُّنْيَا حِينَ يَبْقَى ثُلُثُ اللَّيْلِ الآخِرُ، فَيَقُولُ: مَنْ يَدْعُونِي فَأَسْتَجِيبَ لَهُ، مَنْ يَسْأَلُنِي فَأُعْطِيَهُ، مَنْ يَسْتَغْفِرُنِي فَأَغْفِرَ لَهُ',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 17, height: 1.9),
                ),
                const SizedBox(height: 4),
                Text(
                  bi(context, 'متفق عليه', 'Agreed upon (Bukhari & Muslim)'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        if (_duaText != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    bi(context, 'دعاء قيام الليل', 'Night prayer dua'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(_duaText!, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 17, height: 1.9)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String time, IconData icon, {bool highlight = false}) {
    return Card(
      color: highlight ? AppColors.primaryEmerald.withValues(alpha: 0.10) : null,
      child: ListTile(
        leading: Icon(icon, color: highlight ? AppColors.primaryEmerald : AppColors.goldAccent),
        title: Text(label, style: TextStyle(fontWeight: highlight ? FontWeight.w800 : FontWeight.w600)),
        trailing: Text(time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}
