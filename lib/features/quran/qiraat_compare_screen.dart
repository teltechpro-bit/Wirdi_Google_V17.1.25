import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/services/qiraat_service.dart';
import '../../core/theme/app_theme.dart';

class QiraatCompareScreen extends StatefulWidget {
  const QiraatCompareScreen({super.key});

  @override
  State<QiraatCompareScreen> createState() => _QiraatCompareScreenState();
}

class _QiraatCompareScreenState extends State<QiraatCompareScreen> {
  String _leftId = 'hafs';
  String _rightId = 'warsh';

  RiwayahOption get _left => QiraatCatalog.byId(_leftId);
  RiwayahOption get _right => QiraatCatalog.byId(_rightId);

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final options = QiraatCatalog.allRiwayat;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'مقارنة الروايات' : 'Compare Riwayat'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                ar
                    ? 'اختر روايتين للمقارنة. هذه الشاشة تعرض حالة المصدر الصوتي المتحقق لكل رواية، ولن تنسب اختلافًا نصيًا إلا بعد ربط مصدر نصي موثوق.'
                    : 'Choose two riwayat to compare. This screen shows verified audio-source status and does not claim textual differences until a verified text dataset is connected.',
                style: const TextStyle(height: 1.6),
                textAlign: ar ? TextAlign.right : TextAlign.left,
                textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _selector(
            context,
            ar ? 'الرواية الأولى' : 'First riwayah',
            _leftId,
            options,
            (value) => setState(() => _leftId = value),
            ar,
          ),
          const SizedBox(height: 8),
          _selector(
            context,
            ar ? 'الرواية الثانية' : 'Second riwayah',
            _rightId,
            options,
            (value) => setState(() => _rightId = value),
            ar,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _card(context, _left, ar)),
              const SizedBox(width: 10),
              Expanded(child: _card(context, _right, ar)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.compare_arrows, color: AppColors.goldAccent),
              title: Text(ar ? 'المقارنة النصية' : 'Text comparison'),
              subtitle: Text(
                ar
                    ? 'ستُفعّل بعد ربط قاعدة نصية موثقة للروايات.'
                    : 'Will be enabled after a verified riwayah text dataset is connected.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selector(
    BuildContext context,
    String label,
    String value,
    List<RiwayahOption> options,
    ValueChanged<String> onChanged,
    bool ar,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: options
              .map(
                (r) => DropdownMenuItem<String>(
                  value: r.id,
                  child: Text(
                    r.nameFor(ar ? 'ar' : 'en'),
                    textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _card(BuildContext context, RiwayahOption r, bool ar) {
    final qiraah = QiraatCatalog.all.firstWhere((q) => q.id == r.qiraatId);
    final service = QiraatService.instance;
    final selected = service.selectedRiwayahId == r.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.nameFor(ar ? 'ar' : 'en'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
            ),
            const SizedBox(height: 8),
            Text(
              qiraah.nameFor(ar ? 'ar' : 'en'),
              style: const TextStyle(fontSize: 13),
              textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            Icon(
              r.hasVerifiedAyahAudio ? Icons.graphic_eq : Icons.info_outline,
              color: r.hasVerifiedAyahAudio
                  ? AppColors.primaryEmerald
                  : AppColors.mutedText,
            ),
            const SizedBox(height: 6),
            Text(
              r.hasVerifiedAyahAudio
                  ? (ar ? 'صوت آية-بآية متحقق' : 'Verified verse-by-verse audio')
                  : (ar ? 'الصوت غير متاح بعد' : 'Audio not mapped yet'),
              style: const TextStyle(fontSize: 12),
              textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
            ),
            if (r.audioLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                r.audioLabel!,
                style: const TextStyle(fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            if (selected)
              Text(
                ar ? 'محددة حاليًا' : 'Currently selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
