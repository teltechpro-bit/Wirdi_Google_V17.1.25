import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/azkar_models.dart';
import '../../core/services/azkar_repository.dart';
import '../../core/services/extra_reminders_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/prayer_display.dart';
import '../../core/services/prayer_log_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bi.dart';
import '../../l10n/generated/app_localizations.dart';

/// Guided "azkar after prayer" flow: pick the prayer you just finished, run
/// through the Hisn al-Muslim post-prayer azkar with counters, use the
/// 33/33/34 tasbih helper, and optionally get a reminder after every prayer.
class PostPrayerAzkarScreen extends StatefulWidget {
  const PostPrayerAzkarScreen({super.key});

  @override
  State<PostPrayerAzkarScreen> createState() => _PostPrayerAzkarScreenState();
}

class _PostPrayerAzkarScreenState extends State<PostPrayerAzkarScreen> {
  static const List<String> _prayers = PrayerLogService.prayers;
  static const List<int> _minuteChoices = [5, 10, 15, 20, 30];

  // Tasbih helper: SubhanAllah 33, Alhamdulillah 33, Allahu Akbar 34.
  static const List<int> _tasbihTargets = [33, 33, 34];
  static const List<String> _tasbihAr = ['سبحان الله', 'الحمد لله', 'الله أكبر'];
  static const List<String> _tasbihEn = ['SubhanAllah', 'Alhamdulillah', 'Allahu Akbar'];

  String _selected = _guessPrayer();
  Set<String> _doneToday = <String>{};
  AzkarCategoryModel? _category;
  bool _loading = true;
  bool _failed = false;
  final Map<String, int> _counts = <String, int>{};

  bool _notifyEnabled = false;
  int _minutes = 10;

  int _tasbihStep = 0;
  int _tasbihCount = 0;

  static String _guessPrayer() {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 9) return 'Fajr';
    if (h >= 9 && h < 15) return 'Dhuhr';
    if (h >= 15 && h < 18) return 'Asr';
    if (h >= 18 && h < 20) return 'Maghrib';
    return 'Isha';
  }

  String get _doneKey => 'post_prayer_azkar_done_${PrayerLogService.dayKey(DateTime.now())}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categories = await AzkarRepository.load();
      AzkarCategoryModel? found;
      for (final c in categories) {
        if (c.id == 25) {
          found = c;
          break;
        }
      }
      if (found == null) {
        for (final c in categories) {
          if (c.category.contains('بعد السلام')) {
            found = c;
            break;
          }
        }
      }
      final enabled = await ExtraRemindersService.azkarEnabled();
      final minutes = await ExtraRemindersService.azkarMinutes();
      if (!mounted) return;
      setState(() {
        _category = found;
        _doneToday = (prefs.getStringList(_doneKey) ?? const <String>[]).toSet();
        _notifyEnabled = enabled;
        _minutes = _minuteChoices.contains(minutes) ? minutes : 10;
        _loading = false;
        _failed = found == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _selectPrayer(String prayer) {
    setState(() {
      _selected = prayer;
      _counts.clear();
      _tasbihStep = 0;
      _tasbihCount = 0;
    });
  }

  Future<void> _markDone() async {
    final prefs = await SharedPreferences.getInstance();
    final next = {..._doneToday, _selected};
    await prefs.setStringList(_doneKey, next.toList());
    if (!mounted) return;
    setState(() => _doneToday = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(bi(context, 'تقبّل الله منك', 'May Allah accept it from you'))),
    );
  }

  Future<void> _toggleNotify(bool value) async {
    final arabic = isArabic(context);
    if (value) {
      await NotificationService.requestPermission();
    }
    await ExtraRemindersService.setAzkarEnabled(value);
    if (!mounted) return;
    setState(() => _notifyEnabled = value);
    await ExtraRemindersService.refreshNow(isArabic: arabic);
  }

  Future<void> _setMinutes(int minutes) async {
    final arabic = isArabic(context);
    await ExtraRemindersService.setAzkarMinutes(minutes);
    if (!mounted) return;
    setState(() => _minutes = minutes);
    if (_notifyEnabled) {
      await ExtraRemindersService.refreshNow(isArabic: arabic);
    }
  }

  void _tasbihTap() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_tasbihStep >= _tasbihTargets.length) return;
      _tasbihCount++;
      if (_tasbihCount >= _tasbihTargets[_tasbihStep]) {
        _tasbihStep++;
        _tasbihCount = 0;
        HapticFeedback.mediumImpact();
      }
    });
  }

  String _clean(String text) => text.replaceAll('((', '').replaceAll('))', '').trim();

  Widget _prayerChips(AppLocalizations l10n) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _prayers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final prayer = _prayers[i];
          final done = _doneToday.contains(prayer);
          return ChoiceChip(
            selected: _selected == prayer,
            avatar: done ? const Icon(Icons.check_circle, size: 18) : null,
            label: Text(prayerDisplayName(l10n, prayer)),
            onSelected: (_) => _selectPrayer(prayer),
          );
        },
      ),
    );
  }

  Widget _tasbihCard() {
    final arabic = isArabic(context);
    final finished = _tasbihStep >= _tasbihTargets.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              bi(context, 'التسبيح 33 • 33 • 34', 'Tasbih 33 • 33 • 34'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (finished) ...[
              Icon(Icons.verified_rounded, color: AppColors.primaryEmerald, size: 40),
              const SizedBox(height: 8),
              Text(
                bi(
                  context,
                  'تمام المئة: لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير',
                  'To complete one hundred: La ilaha illallah wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa huwa ala kulli shay-in qadir',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.7),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _tasbihStep = 0;
                  _tasbihCount = 0;
                }),
                child: Text(bi(context, 'إعادة', 'Restart')),
              ),
            ] else ...[
              Text(
                arabic ? _tasbihAr[_tasbihStep] : _tasbihEn[_tasbihStep],
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryEmerald),
              ),
              const SizedBox(height: 4),
              Text('$_tasbihCount / ${_tasbihTargets[_tasbihStep]}', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              SizedBox(
                width: 120,
                height: 120,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const CircleBorder()),
                  onPressed: _tasbihTap,
                  child: const Icon(Icons.touch_app_rounded, size: 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemCard(AzkarItemModel item) {
    final count = _counts[item.uid] ?? 0;
    final target = item.targetCount;
    final complete = count >= target;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: complete ? AppColors.primaryEmerald.withValues(alpha: 0.10) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (complete) return;
          HapticFeedback.selectionClick();
          setState(() => _counts[item.uid] = count + 1);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _clean(item.text),
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 18, height: 1.9),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    complete ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: complete ? AppColors.primaryEmerald : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text('$count / $target', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (!complete)
                    Text(
                      bi(context, 'اضغط للعدّ', 'Tap to count'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reminderCard() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: _notifyEnabled,
            onChanged: _toggleNotify,
            title: Text(bi(context, 'تذكير بأذكار بعد كل صلاة', 'Remind me after every prayer')),
            subtitle: Text(bi(context, 'إشعار بعد وقت الصلاة بدقائق', 'A notification a few minutes after each prayer time')),
          ),
          if (_notifyEnabled)
            ListTile(
              title: Text(bi(context, 'بعد الصلاة بـ', 'Minutes after prayer')),
              trailing: DropdownButton<int>(
                value: _minutes,
                items: [
                  for (final m in _minuteChoices) DropdownMenuItem<int>(value: m, child: Text('$m')),
                ],
                onChanged: (v) {
                  if (v != null) _setMinutes(v);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'أذكار بعد الصلاة', 'Azkar After Prayer')), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                _prayerChips(l10n),
                const SizedBox(height: 14),
                _tasbihCard(),
                const SizedBox(height: 14),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(bi(context, 'تعذّر تحميل الأذكار', 'Could not load the azkar'))),
                  )
                else ...[
                  for (final item in _category!.items) _itemCard(item),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _doneToday.contains(_selected) ? null : _markDone,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _doneToday.contains(_selected)
                          ? bi(context, 'تم لهذه الصلاة اليوم', 'Done for this prayer today')
                          : bi(context, 'أتممت الأذكار', 'I finished the azkar'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _reminderCard(),
              ],
            ),
    );
  }
}
