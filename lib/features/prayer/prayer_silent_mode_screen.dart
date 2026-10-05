import 'package:flutter/material.dart';

import '../../core/services/prayer_display.dart';
import '../../core/services/prayer_silent_mode_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bi.dart';
import '../../l10n/generated/app_localizations.dart';

/// Settings for silencing the phone around prayer time (Android only).
class PrayerSilentModeScreen extends StatefulWidget {
  const PrayerSilentModeScreen({super.key});

  @override
  State<PrayerSilentModeScreen> createState() => _PrayerSilentModeScreenState();
}

class _PrayerSilentModeScreenState extends State<PrayerSilentModeScreen> with WidgetsBindingObserver {
  static const List<int> _delays = [0, 5, 10, 15, 20, 25, 30];
  static const List<int> _durations = [10, 15, 20, 30, 45, 60];

  bool _loading = true;
  bool _enabled = false;
  bool _hasAccess = false;
  int _delay = 10;
  int _duration = 20;
  String _mode = 'vibrate';
  Set<String> _prayers = PrayerSilentModeService.allPrayers.toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  Future<void> _refreshAccess() async {
    final access = await PrayerSilentModeService.hasPolicyAccess();
    if (!mounted) return;
    setState(() => _hasAccess = access);
    if (access && _enabled) {
      await PrayerSilentModeService.refreshNow();
    }
  }

  Future<void> _load() async {
    final enabled = await PrayerSilentModeService.enabled();
    final delay = await PrayerSilentModeService.startDelayMinutes();
    final duration = await PrayerSilentModeService.durationMinutes();
    final mode = await PrayerSilentModeService.ringerMode();
    final prayers = await PrayerSilentModeService.prayers();
    final access = await PrayerSilentModeService.hasPolicyAccess();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _delay = _delays.contains(delay) ? delay : 10;
      _duration = _durations.contains(duration) ? duration : 20;
      _mode = mode == 'silent' ? 'silent' : 'vibrate';
      _prayers = prayers;
      _hasAccess = access;
      _loading = false;
    });
  }

  Future<void> _apply() async {
    await PrayerSilentModeService.refreshNow();
  }

  Future<void> _toggle(bool value) async {
    await PrayerSilentModeService.setEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = value);
    if (value) {
      await _apply();
    } else {
      await PrayerSilentModeService.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!PrayerSilentModeService.isSupported) {
      return Scaffold(
        appBar: AppBar(title: Text(bi(context, 'الصامت وقت الصلاة', 'Silent During Prayer')), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              bi(context, 'هذه الميزة متاحة على أندرويد فقط.', 'This feature is only available on Android.'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'الصامت وقت الصلاة', 'Silent During Prayer')), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      bi(
                        context,
                        'يحوّل الهاتف إلى الاهتزاز أو الصامت في وقت الصلاة ثم يعيده تلقائيًا إلى وضعه السابق. يبدأ الصامت بعد الأذان بعدد الدقائق الذي تختاره (ليتزامن مع الإقامة)، فلا يُكتم إشعار الأذان نفسه.',
                        'Switches your phone to vibrate or silent around prayer time, then restores the previous mode automatically. The quiet window starts a few minutes after the adhan (to match the iqama), so the adhan notification itself is still heard.',
                      ),
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!_hasAccess)
                  Card(
                    color: Colors.orange.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            bi(
                              context,
                              'يلزم منح التطبيق صلاحية «عدم الإزعاج» من إعدادات النظام حتى يتمكن من تغيير وضع الرنين.',
                              'Android needs you to grant "Do Not Disturb access" to Wirdi so it can change the ringer mode.',
                            ),
                            style: const TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: PrayerSilentModeService.openPolicySettings,
                            child: Text(bi(context, 'فتح الإعدادات', 'Open settings')),
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: SwitchListTile(
                    value: _enabled,
                    onChanged: _toggle,
                    title: Text(bi(context, 'تفعيل الصامت وقت الصلاة', 'Enable silent during prayer')),
                    subtitle: _enabled && !_hasAccess
                        ? Text(bi(context, 'لن يعمل قبل منح الصلاحية', 'Will not work until access is granted'))
                        : null,
                  ),
                ),
                if (_enabled) ...[
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(bi(context, 'يبدأ بعد الأذان بـ (دقيقة)', 'Starts after the adhan (min)')),
                          trailing: DropdownButton<int>(
                            value: _delay,
                            items: [for (final m in _delays) DropdownMenuItem<int>(value: m, child: Text('$m'))],
                            onChanged: (v) async {
                              if (v == null) return;
                              await PrayerSilentModeService.setStartDelayMinutes(v);
                              if (!mounted) return;
                              setState(() => _delay = v);
                              await _apply();
                            },
                          ),
                        ),
                        ListTile(
                          title: Text(bi(context, 'مدة الصامت (دقيقة)', 'Quiet for (min)')),
                          trailing: DropdownButton<int>(
                            value: _duration,
                            items: [for (final m in _durations) DropdownMenuItem<int>(value: m, child: Text('$m'))],
                            onChanged: (v) async {
                              if (v == null) return;
                              await PrayerSilentModeService.setDurationMinutes(v);
                              if (!mounted) return;
                              setState(() => _duration = v);
                              await _apply();
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: SegmentedButton<String>(
                            segments: [
                              ButtonSegment<String>(value: 'vibrate', label: Text(bi(context, 'اهتزاز', 'Vibrate'))),
                              ButtonSegment<String>(value: 'silent', label: Text(bi(context, 'صامت تمامًا', 'Fully silent'))),
                            ],
                            selected: <String>{_mode},
                            onSelectionChanged: (s) async {
                              final v = s.first;
                              await PrayerSilentModeService.setRingerMode(v);
                              if (!mounted) return;
                              setState(() => _mode = v);
                              await _apply();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final prayer in PrayerSilentModeService.allPrayers)
                          CheckboxListTile(
                            value: _prayers.contains(prayer),
                            activeColor: AppColors.primaryEmerald,
                            title: Text(prayerDisplayName(l10n, prayer)),
                            onChanged: (checked) async {
                              final next = {..._prayers};
                              if (checked ?? false) {
                                next.add(prayer);
                              } else {
                                next.remove(prayer);
                              }
                              await PrayerSilentModeService.setPrayers(next);
                              if (!mounted) return;
                              setState(() => _prayers = next);
                              await _apply();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  bi(
                    context,
                    'يُجدول الصامت للأيام السبعة القادمة، ويتجدد كلما فتحت التطبيق. لا يؤثر على صوت الوسائط ولا المنبّهات.',
                    'The quiet windows are scheduled for the next seven days and refreshed whenever you open the app. Media volume and alarms are not affected.',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
    );
  }
}
