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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QiraatCompareScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _service.loadReaders(),
        builder: (context, snapshot) {
          final readers = _service.readersForSelectedRiwayah();
          final selectedReader = _service.selectedReaderFor(current) ??
              _service.defaultReaderFor(current);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ar ? 'القراءات العشر والروايات العشرون' :
                            '10 canonical readings • 20 riwayat',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ar
                            ? 'المصادر الصوتية تظهر بحسب ما تم اكتشافه والتحقق منه فعليًا. لا يوجد أي تحويل صامت إلى حفص.'
                            : 'Audio sources are shown from sources actually discovered and verified at runtime. There is no silent fallback to Hafs.',
                        textAlign: ar ? TextAlign.right : TextAlign.left,
                        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (ar ? 'مصادر مكتشفة الآن: ' : 'Runtime sources discovered: ') +
                            _service.discoveredRiwayahCount.toString() + '/20',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (readers.isNotEmpty && selectedReader != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          ar
                              ? 'القارئ — ' + QiraatCatalog.byId(current).nameAr
                              : 'Reader — ' + QiraatCatalog.byId(current).nameEn,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedReader.id,
                          decoration: InputDecoration(
                            labelText: ar ? 'اختر القارئ' : 'Choose reader',
                            border: const OutlineInputBorder(),
                          ),
                          items: readers.map((reader) => DropdownMenuItem<String>(
                            value: reader.id,
                            child: Text(reader.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            await _service.setReader(current, value);
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (ar ? 'الرواية: ' : 'Riwayah: ') +
                              QiraatCatalog.byId(current).nameFor(ar ? 'ar' : 'en') +
                              '\n' +
                              (ar ? 'القارئ: ' : 'Reader: ') + selectedReader.name +
                              '\n' +
                              (ar ? 'المصدر: ' : 'Source: ') + selectedReader.source,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_search),
                    title: Text(ar ? 'قراء هذه الرواية' : 'Readers for this riwayah'),
                    subtitle: Text(
                      ar
                          ? 'لا يظهر القارئ إلا عند توفر مصدر مكتمل وموثّق.'
                          : 'A reader appears only when a complete trusted source is available.',
                    ),
                  ),
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
                      subtitle: Text(_service.audioStatusFor(r, ar ? 'ar' : 'en')),
                      leading: Icon(
                        r.hasVerifiedAyahAudio ? Icons.graphic_eq : Icons.library_music,
                        color: r.hasVerifiedAyahAudio
                            ? AppColors.primaryEmerald
                            : AppColors.goldAccent,
                      ),
                      trailing: r.id == current
                          ? Icon(Icons.check_circle, color: AppColors.goldAccent)
                          : null,
                      onTap: _service.hasRuntimeReaderSource(r.id) || r.id == current
                          ? () async {
                              await _service.setRiwayah(r.id);
                              if (mounted) setState(() {});
                            }
                          : null,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}