import 'package:flutter/material.dart';

import '../../core/services/prayer_display.dart';
import '../../core/services/prayer_log_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bi.dart';
import '../../l10n/generated/app_localizations.dart';

/// Daily prayer tracker: mark each of the five prayers as on time / late /
/// missed, see today's progress, the all-five streak, and the last 28 days.
class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({super.key});

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  Map<String, Map<String, String>> _all = <String, Map<String, String>>{};
  DateTime _day = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await PrayerLogService.loadAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  Future<void> _set(String prayer, PrayerStatus status) async {
    final current = PrayerLogService.decode(_all[PrayerLogService.dayKey(_day)]?[prayer]);
    await PrayerLogService.setStatus(_day, prayer, current == status ? null : status);
    await _reload();
  }

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

  void _shiftDay(int delta) {
    final next = _day.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
  }

  Color _heat(int prayed) {
    if (prayed == 0) return Colors.grey.withValues(alpha: 0.18);
    return AppColors.primaryEmerald.withValues(alpha: 0.2 + 0.16 * prayed);
  }

  Widget _statusButton(String prayer, PrayerStatus status, String label, IconData icon, Color color) {
    final selected = PrayerLogService.decode(_all[PrayerLogService.dayKey(_day)]?[prayer]) == status;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: selected ? Colors.white : color,
            backgroundColor: selected ? color : null,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          ),
          onPressed: () => _set(prayer, status),
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dayMap = _all[PrayerLogService.dayKey(_day)];
    final prayed = PrayerLogService.prayedCount(dayMap);
    final streak = PrayerLogService.currentStreak(_all);

    var onTimeThisMonth = 0;
    var loggedThisMonth = 0;
    final now = DateTime.now();
    _all.forEach((key, map) {
      if (key.startsWith('${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}')) {
        for (final p in PrayerLogService.prayers) {
          final s = map[p];
          if (s != null) loggedThisMonth++;
          if (s == 'ontime') onTimeThisMonth++;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'متتبّع الصلوات', 'Prayer Tracker')), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(onPressed: () => _shiftDay(-1), icon: const Icon(Icons.chevron_left)),
                            Text(
                              _isToday
                                  ? bi(context, 'اليوم', 'Today')
                                  : '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            IconButton(
                              onPressed: _isToday ? null : () => _shiftDay(1),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: prayed / 5,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.primaryEmerald,
                        ),
                        const SizedBox(height: 8),
                        Text('$prayed / 5', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _stat(Icons.local_fire_department_rounded, '$streak', bi(context, 'أيام متتالية', 'Day streak')),
                            _stat(
                              Icons.access_time_filled_rounded,
                              loggedThisMonth == 0 ? '-' : '${(onTimeThisMonth * 100 / loggedThisMonth).round()}%',
                              bi(context, 'في وقتها (الشهر)', 'On time (month)'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final prayer in PrayerLogService.prayers)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prayerDisplayName(l10n, prayer),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _statusButton(prayer, PrayerStatus.onTime, bi(context, 'في وقتها', 'On time'), Icons.check_circle_outline, AppColors.primaryEmerald),
                              _statusButton(prayer, PrayerStatus.late, bi(context, 'متأخرة', 'Late'), Icons.schedule, Colors.orange.shade800),
                              _statusButton(prayer, PrayerStatus.missed, bi(context, 'فاتتني', 'Missed'), Icons.cancel_outlined, Colors.red.shade700),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  bi(context, 'آخر 28 يومًا', 'Last 28 days'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 27; i >= 0; i--) _heatCell(DateTime.now().subtract(Duration(days: i))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  bi(
                    context,
                    'السجل محفوظ على جهازك فقط.',
                    'The log is stored on this device only.',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
    );
  }

  Widget _heatCell(DateTime d) {
    final prayed = PrayerLogService.prayedCount(_all[PrayerLogService.dayKey(d)]);
    return GestureDetector(
      onTap: () => setState(() => _day = d),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _heat(prayed),
          borderRadius: BorderRadius.circular(8),
          border: PrayerLogService.dayKey(d) == PrayerLogService.dayKey(_day)
              ? Border.all(color: AppColors.goldAccent, width: 2)
              : null,
        ),
        child: Text('${d.day}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.goldAccent),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
