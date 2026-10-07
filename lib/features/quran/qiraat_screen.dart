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
                    ? 'تظهر هنا القراءات العشر والروايتان المشهورتان لكل قراءة. حفص وورش يدعمان الصوت آية-بآية، وبقية الروايات تستخدم مصدر السورة الحقيقي عند توفره، ولا يوجد أي تحويل صامت إلى حفص.'
                    : 'Wirdi lists all ten canonical readings and twenty riwayat. Hafs and Warsh have verified verse-by-verse sources; the other riwayat use a real full-surah source when available. Wirdi never silently falls back to Hafs.',
                textAlign: ar ? TextAlign.right : TextAlign.left,
                textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<void>(
            future: _service.loadReaders(),
            builder: (context, snapshot) {
              final readers = _service.readersForSelectedRiwayah();
              final selectedReader = _service.selectedReaderFor(current) ?? _service.defaultReaderFor(current);
              if (readers.isEmpty) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_search),
                    title: Text(ar ? 'قراء هذه الرواية' : 'Readers for this riwayah'),
                    subtitle: Text(ar ? 'سيتم إظهار القارئ فقط عند توفر مصدر موثّق.' : 'A reader appears only when a verified source is available.'),
                  ),
                );
              }
              final readerForDisplay = selectedReader != null && readers.any((r) => r.id == selectedReader.id)
                  ? selectedReader
                  : readers.first;
              final selectedValue = readerForDisplay.id;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ar ? 'القارئ — ${QiraatCatalog.byId(current).nameAr}' : 'Reader — ${QiraatCatalog.byId(current).nameEn}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedValue,
                        decoration: InputDecoration(
                          labelText: ar ? 'اختر القارئ' : 'Choose reader',
                          border: const OutlineInputBorder(),
                        ),
                        items: readers.map((reader) => DropdownMenuItem<String>(
                          value: reader.id,
                          child: Text(reader.name),
                        )).toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          await _service.setReader(current, value);
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ar ? 'المصدر: ${readerForDisplay.source} • مرتبط بهذه الرواية فقط' : 'Source: ${readerForDisplay.source} • linked to this riwayah only',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          for (final q in QiraatCatalog.all) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                q.nameFor(ar ? 'ar' : 'en'),
                style: TextStyle(
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
                        : Icons.library_music,
                    color: r.hasVerifiedAyahAudio
                        ? AppColors.primaryEmerald
                        : AppColors.goldAccent,
                  ),
                  trailing: r.id == current
                      ? Icon(Icons.check_circle, color: AppColors.goldAccent)
                      : null,
                  onTap: r.hasSurahAudio
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
