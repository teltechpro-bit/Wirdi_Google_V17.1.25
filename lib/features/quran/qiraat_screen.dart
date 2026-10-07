import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/services/qiraat_service.dart';
import '../../core/theme/app_theme.dart';
import 'qiraat_compare_screen.dart';

class QiraatScreen extends StatefulWidget {
  const QiraatScreen({super.key});

  @override
  State<QiraatScreen> createState() => _QiraatScreenState();
}

class _QiraatScreenState extends State<QiraatScreen> {
  final _service = QiraatService.instance;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final current = _service.selectedRiwayahId;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'القراءات العشر والروايات' : 'Ten Qira’at & Riwayat'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: ar ? 'مقارنة الروايات' : 'Compare riwayat',
            icon: const Icon(Icons.compare_arrows),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const QiraatCompareScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                ar
                    ? 'تظهر هنا القراءات العشر والروايتان المشهورتان لكل قراءة. Wirdi لا يبدّل الصوت إلى حفص بصمت: الرواية لا تُعتبر مدعومة صوتيًا إلا عند وجود مصدر آية-بآية متحقق.'
                    : 'Wirdi lists the ten canonical readings and two famous riwayat for each. Audio is only marked available when a verified verse-by-verse source exists; Wirdi never silently falls back to Hafs.',
                textAlign: ar ? TextAlign.right : TextAlign.left,
                textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final q in QiraatCatalog.all) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                q.nameFor(ar ? 'ar' : 'en'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryEmerald,
                ),
              ),
            ),
            for (final r in q.riwayat)
              Card(
                child: ListTile(
                  title: Text(
                    r.nameFor(ar ? 'ar' : 'en'),
                    textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
                  ),
                  subtitle: Text(
                    _service.audioStatusFor(r, ar ? 'ar' : 'en'),
                  ),
                  leading: Icon(
                    r.hasVerifiedAyahAudio
                        ? Icons.graphic_eq
                        : Icons.info_outline,
                    color: r.hasVerifiedAyahAudio
                        ? AppColors.primaryEmerald
                        : AppColors.mutedText,
                  ),
                  trailing: r.id == current
                      ? Icon(Icons.check_circle, color: AppColors.goldAccent)
                      : null,
                  onTap: r.hasVerifiedAyahAudio
                      ? () async {
                          await _service.setRiwayah(r.id);
                          if (mounted) setState(() {});
                        }
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
