import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/quran_models.dart';
import '../../core/services/quran_audio_service.dart';
import '../../core/services/quran_repository.dart';
import 'way2quran_models.dart';
import 'way2quran_repository.dart';

class Way2QuranReadListenScreen extends StatefulWidget {
  final int? initialSurah;
  const Way2QuranReadListenScreen({super.key, this.initialSurah});
  @override State<Way2QuranReadListenScreen> createState() => _Way2QuranReadListenScreenState();
}

class _Way2QuranReadListenScreenState extends State<Way2QuranReadListenScreen> {
  final repo = Way2QuranRepository();
  late Future<List<SurahModel>> surahsFuture;
  late Future<Way2QuranRecitersPage> recitersFuture;
  Way2QuranReciter? selectedReciter;
  String? selectedRecitation;
  int? selectedSurah;
  int fromAyah = 1;
  int toAyah = 1;
  double speed = 1.0;
  bool loadingReciter = false;
  bool downloading = false;

  @override
  void initState() {
    super.initState();
    surahsFuture = QuranRepository.load();
    selectedSurah = widget.initialSurah;
    recitersFuture = repo.getRecitersPage(pageSize: 50);
  }

  Future<void> _selectReciter(Way2QuranReciter r) async {
    setState(() {
      selectedReciter = r;
      selectedRecitation = r.recitations.isEmpty ? null : r.recitations.first.slug;
      loadingReciter = true;
    });
    try {
      final detail = await repo.getReciter(r.slug);
      if (!mounted) return;
      setState(() {
        selectedReciter = detail;
        selectedRecitation = detail.recitations.isEmpty ? null : detail.recitations.first.slug;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل تلاوات القارئ')));
    } finally {
      if (mounted) setState(() => loadingReciter = false);
    }
  }

  Way2QuranAudioFile? _audioFor(SurahModel surah) {
    final rec = selectedReciter;
    if (rec == null) return null;
    final r = rec.recitations.where((x) => x.slug == selectedRecitation).firstOrNull;
    if (r == null) return null;
    for (final a in r.audioFiles) {
      if (a.surahNumber == surah.number) return a;
    }
    return null;
  }

  Future<void> _play(SurahModel surah) async {
    final audio = _audioFor(surah);
    final url = audio?.url.isNotEmpty == true ? audio!.url : audio?.downloadUrl ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد تلاوة لهذه السورة عند هذا القارئ')));
      return;
    }
    await quranAudio.setSpeed(speed);
    final title = surah.name + ' — ' + selectedReciter!.name(Localizations.localeOf(context).languageCode == 'ar');
    await quranAudio.playExternalUrl(url, title: title);
  }

  Future<void> _download(SurahModel surah) async {
    final audio = _audioFor(surah);
    final url = audio?.downloadUrl.isNotEmpty == true ? audio!.downloadUrl : audio?.url ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد تلاوة قابلة للتنزيل')));
      return;
    }
    setState(() => downloading = true);
    try {
      final bytes = await repo.downloadBytes(url);
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/way2quran/audio');
      await folder.create(recursive: true);
      final reciterSlug = selectedReciter?.slug ?? 'reciter';
      final recitationSlug = selectedRecitation ?? 'recitation';
      final file = File('${folder.path}/${reciterSlug}_${recitationSlug}_${surah.number}.mp3');
      await file.writeAsBytes(bytes, flush: true);
      if (selectedRecitation != null) await repo.incrementDownload(selectedRecitation!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(arSafe() ? 'تم تنزيل التلاوة داخل Wirdi' : 'Recitation downloaded inside Wirdi')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تنزيل التلاوة')));
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  bool arSafe() => Localizations.localeOf(context).languageCode == 'ar';

  void _setSurah(int value, List<SurahModel> surahs) {
    final s = surahs.firstWhere((x) => x.number == value);
    setState(() {
      selectedSurah = value;
      fromAyah = 1;
      toAyah = s.ayahs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'قراءة واستماع' : 'Read & Listen')),
      body: FutureBuilder<List<SurahModel>>(
        future: surahsFuture,
        builder: (context, surahSnap) {
          if (surahSnap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (surahSnap.hasError || surahSnap.data == null || surahSnap.data!.isEmpty) {
            return Center(child: Text(ar ? 'تعذر تحميل السور' : 'Could not load surahs'));
          }
          final surahs = surahSnap.data!;
          final surah = surahs.firstWhere((s) => s.number == (selectedSurah ?? 1), orElse: () => surahs.first);
          if (selectedSurah == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _setSurah(surah.number, surahs);
            });
          }

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
                        ar ? 'اختر ما تريد قراءته والاستماع إليه' : 'Choose what you want to read and listen to',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedSurah,
                        decoration: InputDecoration(labelText: ar ? 'السورة' : 'Surah', border: const OutlineInputBorder()),
                        items: surahs.map((s) => DropdownMenuItem(value: s.number, child: Text(s.number.toString() + '. ' + s.name))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            _setSurah(v, surahs);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<Way2QuranRecitersPage>(
                        future: recitersFuture,
                        builder: (context, snap) {
                          final items = snap.data?.reciters ?? const <Way2QuranReciter>[];
                          return DropdownButtonFormField<String>(
                            value: selectedReciter?.slug,
                            decoration: InputDecoration(labelText: ar ? 'القارئ' : 'Reciter', border: const OutlineInputBorder()),
                            items: items.map((r) => DropdownMenuItem(value: r.slug, child: Text(r.name(ar)))).toList(),
                            onChanged: (v) {
                              final r = items.where((x) => x.slug == v).firstOrNull;
                              if (r != null) _selectReciter(r);
                            },
                          );
                        },
                      ),
                      if (loadingReciter) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                      if (selectedReciter != null && selectedReciter!.recitations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRecitation,
                          decoration: InputDecoration(labelText: ar ? 'الرواية / القراءة' : 'Recitation / Riwayah', border: const OutlineInputBorder()),
                          items: selectedReciter!.recitations.map((r) => DropdownMenuItem(value: r.slug, child: Text(r.name(ar)))).toList(),
                          onChanged: (v) => setState(() => selectedRecitation = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: fromAyah.clamp(1, surah.ayahs.length),
                              decoration: InputDecoration(labelText: ar ? 'من الآية' : 'From Ayah', border: const OutlineInputBorder()),
                              items: List.generate(surah.ayahs.length, (i) => DropdownMenuItem(value: i + 1, child: Text((i + 1).toString()))),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    fromAyah = v;
                                    if (toAyah < v) {
                                      toAyah = v;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: toAyah.clamp(fromAyah, surah.ayahs.length),
                              decoration: InputDecoration(labelText: ar ? 'إلى الآية' : 'To Ayah', border: const OutlineInputBorder()),
                              items: List.generate(surah.ayahs.length - fromAyah + 1, (i) {
                                final n = fromAyah + i;
                                return DropdownMenuItem(value: n, child: Text(n.toString()));
                              }),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => toAyah = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<double>(
                        value: speed,
                        decoration: InputDecoration(labelText: ar ? 'السرعة' : 'Speed', border: const OutlineInputBorder()),
                        items: const [0.75, 1.0, 1.25, 1.5, 2.0].map((v) => DropdownMenuItem(value: v, child: Text(v.toString() + 'x'))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => speed = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(children: [Expanded(child: FilledButton.icon(onPressed: selectedReciter == null || selectedRecitation == null ? null : () => _play(surah), icon: const Icon(Icons.play_arrow_rounded), label: Text(ar ? 'تشغيل' : 'Play'))), const SizedBox(width: 10), OutlinedButton.icon(onPressed: selectedReciter == null || selectedRecitation == null || downloading ? null : () => _download(surah), icon: downloading ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.download_rounded), label: Text(ar ? 'تنزيل' : 'Download'))]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(ar ? 'التلاوة الأصلية من Way2Quran' : 'Original Way2Quran recitation'),
                  subtitle: Text(ar ? 'اختيار السورة والقارئ والرواية والسرعة مرتبط بمصدر Way2Quran الحقيقي.' : 'Surah, reciter, riwayah and speed are connected to the real Way2Quran source.'),
                ),
              ),
              if (selectedReciter != null && _audioFor(surah) == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    ar ? 'لا توجد تلاوة متاحة لهذه السورة مع الاختيار الحالي.' : 'No audio is available for this surah with the current selection.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
