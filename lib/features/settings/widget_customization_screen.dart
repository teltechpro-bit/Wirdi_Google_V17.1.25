import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

class WidgetCustomizationScreen extends StatefulWidget {
  const WidgetCustomizationScreen({super.key});
  @override
  State<WidgetCustomizationScreen> createState() => _WidgetCustomizationScreenState();
}

class _WidgetCustomizationScreenState extends State<WidgetCustomizationScreen> {
  static const _channel = MethodChannel('wirdi/overlay');
  bool _overlayEnabled = false, _dark = false, _transparent = false, _loading = true;
  String _overlayContent = 'tasbeeh';
  int _count = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>([
        HomeWidget.getWidgetData<bool>('overlay_enabled', defaultValue: false),
        HomeWidget.getWidgetData<bool>('widget_dark_mode', defaultValue: false),
        HomeWidget.getWidgetData<bool>('widget_transparent', defaultValue: false),
        HomeWidget.getWidgetData<String>('overlay_content', defaultValue: 'tasbeeh'),
        HomeWidget.getWidgetData<int>('tasbeeh_count', defaultValue: 0),
      ]);
      if (!mounted) return;
      setState(() {
        _overlayEnabled = values[0] as bool? ?? false;
        _dark = values[1] as bool? ?? false;
        _transparent = values[2] as bool? ?? false;
        _overlayContent = values[3] as String? ?? 'tasbeeh';
        _count = values[4] as int? ?? 0;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _refreshWidgets() async {
    for (final name in ['WirdiWidgetProvider', 'WirdiDailyWidgetProvider', 'WirdiAyahWidgetProvider', 'WirdiTasbeehWidgetProvider']) {
      try { await HomeWidget.updateWidget(androidName: name); } catch (_) {}
    }
  }

  Future<void> _saveStyle() async {
    await HomeWidget.saveWidgetData<bool>('widget_dark_mode', _dark);
    await HomeWidget.saveWidgetData<bool>('widget_transparent', _transparent);
    await _refreshWidgets();
  }

  Future<void> _setOverlay(bool enabled) async {
    try {
      if (enabled) {
        final allowed = await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
        if (!allowed) {
          await _channel.invokeMethod<void>('requestOverlayPermission');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فعّل إذن الظهور فوق التطبيقات من إعدادات أندرويد، ثم ارجع لهذه الشاشة وشغّل النافذة.')));
          return;
        }
        await _channel.invokeMethod<bool>('startOverlay');
      } else {
        await _channel.invokeMethod<bool>('stopOverlay');
      }
      await HomeWidget.saveWidgetData<bool>('overlay_enabled', enabled);
      if (mounted) setState(() => _overlayEnabled = enabled);
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تشغيل النافذة العائمة: ${e.message ?? e.code}')));
    }
  }

  Future<void> _setContent(String value) async {
    setState(() => _overlayContent = value);
    await HomeWidget.saveWidgetData<String>('overlay_content', value);
    await _refreshWidgets();
    if (_overlayEnabled) {
      await _channel.invokeMethod<bool>('stopOverlay');
      await _channel.invokeMethod<bool>('startOverlay');
      await HomeWidget.saveWidgetData<bool>('overlay_enabled', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('مركز الويدجت')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ويدجت الشاشة الرئيسية', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _preview(theme, icon: Icons.menu_book_rounded, title: 'الورد اليومي المتكامل • 4×2', subtitle: 'إنجاز الورد • الأذكار المتبقية • الصلاة القادمة', sample: 'ورد اليوم  3 / 5 صفحات\nالأذكار المتبقية: 4  •  الصلاة القادمة 14:35'),
          _preview(theme, icon: Icons.auto_stories_rounded, title: 'آية وتدبّر • 4×2', subtitle: 'آية قرآنية مع زر الانتقال للآية التالية', sample: 'إِنَّ مَعَ الْعُسْرِ يُسْرًا'),
          _preview(theme, icon: Icons.touch_app_rounded, title: 'السبحة السريعة • 2×2', subtitle: 'العداد الحالي محفوظ على الجهاز', sample: 'سُبْحَانَ الله  •  $_count'),
          const Divider(height: 28),
          Text('تخصيص المظهر', style: theme.textTheme.titleLarge),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('ألوان داكنة'), subtitle: const Text('حفظ اختيار المظهر للويدجت'), value: _dark, onChanged: (v) async { setState(() => _dark = v); await _saveStyle(); }),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('خلفية شفافة'), subtitle: const Text('خلفية خفيفة بدلاً من البطاقة المصمتة'), value: _transparent, onChanged: (v) async { setState(() => _transparent = v); await _saveStyle(); }),
          const Divider(height: 28),
          Text('النافذة العائمة', style: theme.textTheme.titleLarge),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('إظهار دائرة وِرْدِي فوق التطبيقات'), subtitle: const Text('تحتاج إذناً خاصاً من أندرويد وتعرض إشعاراً مستمراً أثناء التشغيل'), value: _overlayEnabled, onChanged: _setOverlay),
          const SizedBox(height: 4),
          Text('المحتوى داخل الدائرة', style: theme.textTheme.titleMedium),
          RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'tasbeeh', groupValue: _overlayContent, title: const Text('عداد التسبيح'), onChanged: (v) { if (v != null) _setContent(v); }),
          RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'dhikr', groupValue: _overlayContent, title: const Text('ذكر متجدد'), onChanged: (v) { if (v != null) _setContent(v); }),
          RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'quran', groupValue: _overlayContent, title: const Text('فتح وِرْدِي'), onChanged: (v) { if (v != null) _setContent(v); }),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _refreshWidgets, icon: const Icon(Icons.refresh), label: const Text('تحديث الويدجت الآن')),
        ],
      ),
    );
  }

  Widget _preview(ThemeData theme, {required IconData icon, required String title, required String subtitle, required String sample}) {
    final dark = _dark;
    final primary = dark ? const Color(0xFFEEDCA7) : const Color(0xFF0C5D4D);
    final body = dark ? const Color(0xFFF4F4EB) : const Color(0xFF173D35);
    final muted = dark ? const Color(0xFFB8CCC2) : const Color(0xFF58716B);
    final surface = _transparent
        ? theme.colorScheme.surface.withValues(alpha: 0.35)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              gradient: _transparent ? null : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF1D3731), Color(0xFF10241F)]
                    : const [Color(0xFFFFFCF5), Color(0xFFEAF4EF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: dark ? const Color(0xFF365B50) : const Color(0xFFD6E5DA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.12 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, color: primary, size: 20),
                    const SizedBox(width: 7),
                    Text('وِرْدِي', style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 13)),
                    const Spacer(),
                    const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFFC5A45A)),
                  ],
                ),
                const SizedBox(height: 7),
                Container(width: 34, height: 2, alignment: Alignment.centerLeft, color: const Color(0xFFC5A45A),
                  child: const SizedBox(width: 34, height: 2)),
                const SizedBox(height: 9),
                Text(sample, textAlign: TextAlign.center,
                  style: TextStyle(color: body, fontSize: 14, height: 1.55, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text('طريقك إلى القرب', textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
