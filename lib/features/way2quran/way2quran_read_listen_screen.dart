import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/quran_models.dart';
import '../../core/services/quran_audio_service.dart';
import '../../core/services/quran_repository.dart';
import 'way2quran_models.dart';
import 'way2quran_repository.dart';
import 'way2quran_recitations_directory_screen.dart';
import 'way2quran_storage.dart';

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
  String selectedTranslation = 'en.sahih';
  Map<int, String> translatedAyahs = {};
  bool loadingTranslation = false;
  String? translationError;
  int _translationRequestId = 0;
  bool loadingReciter = false;
  bool downloading = false;

  @override
  void initState() {
    super.initState();
    surahsFuture = QuranRepository.load();
    selectedSurah = widget.initialSurah;
    recitersFuture = repo.getRecitersPage(pageSize: 50);
  }

  Future<Map<int, String>?> _readCachedTranslation(
    int surahNumber,
    String edition,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(Way2QuranStorage.translationFilePath(
        directory.path,
        surahNumber,
        edition,
      ));
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final result = <int, String>{};
      decoded.forEach((key, value) {
        final number = int.tryParse(key.toString());
        if (number != null && number > 0 && value is String && value.isNotEmpty) {
          result[number] = value;
        }
      });
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadTranslation(int surahNumber, String edition) async {
    final requestId = ++_translationRequestId;
    setState(() {
      loadingTranslation = true;
      translationError = null;
    });

    // Serve a saved edition immediately so Read & Listen remains useful offline.
    final cached = await _readCachedTranslation(surahNumber, edition);
    if (!mounted || requestId != _translationRequestId) return;
    if (cached != null) {
      setState(() {
        translatedAyahs = cached;
        loadingTranslation = false;
      });
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/surah/$surahNumber/$edition'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('Translation request failed');
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = decoded is Map ? decoded['data'] : null;
      final ayahs = data is Map && data['ayahs'] is List
          ? data['ayahs'] as List
          : const [];
      final result = <int, String>{};
      for (var i = 0; i < ayahs.length; i++) {
        final item = ayahs[i];
        if (item is Map) {
          final number = int.tryParse('${item['numberInSurah'] ?? i + 1}') ?? i + 1;
          final text = (item['text'] ?? '').toString();
          if (number > 0 && text.isNotEmpty) result[number] = text;
        }
      }
      if (result.isEmpty) throw Exception('No translation data');

      // A cache write must never turn a successful network response into an error.
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File(Way2QuranStorage.translationFilePath(
          directory.path,
          surahNumber,
          edition,
        ));
        final encoded = jsonEncode({
          for (final entry in result.entries) entry.key.toString(): entry.value,
        });
        await Way2QuranStorage.writeBytesAtomically(file, utf8.encode(encoded));
      } catch (_) {
        // Keep the fetched translation usable even if local storage is unavailable.
      }

      if (!mounted || requestId != _translationRequestId) return;
      setState(() {
        translatedAyahs = result;
        loadingTranslation = false;
      });
    } catch (_) {
      if (!mounted || requestId != _translationRequestId) return;
      final fallback = await _readCachedTranslation(surahNumber, edition);
      if (!mounted || requestId != _translationRequestId) return;
      setState(() {
        if (fallback != null) {
          translatedAyahs = fallback;
          translationError = null;
        } else {
          translatedAyahs = {};
          translationError = arSafe()
              ? 'تعذر تحميل الترجمة. تحقق من الاتصال وحاول تغيير الترجمة.'
              : 'Could not load translation. Check your connection or try another edition.';
        }
        loadingTranslation = false;
      });
    }
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
    final dir = await getApplicationDocumentsDirectory();
    final reciterSlug = selectedReciter?.slug ?? 'reciter';
    final recitationSlug = selectedRecitation ?? 'recitation';
    final fileStem = '${reciterSlug}_${recitationSlug}_${surah.number}';
    final fileName = '${Way2QuranStorage.safeFileStem(fileStem)}.mp3';
    final localFile = File(Way2QuranStorage.recitationFilePath(dir.path, fileStem));
    // Keep playback working for files downloaded by older app versions.
    final legacyFile = File('${dir.path}/way2quran/audio/$fileName');
    final localExists = await localFile.exists();
    final legacyExists = !localExists && await legacyFile.exists();
    final playableFile = localExists ? localFile : legacyFile;
    final url = audio?.url.isNotEmpty == true ? audio!.url : audio?.downloadUrl ?? '';
    if (!localExists && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد تلاوة لهذه السورة عند هذا القارئ')));
      return;
    }
    await quranAudio.setSpeed(speed);
    final title = surah.name + ' — ' + selectedReciter!.name(Localizations.localeOf(context).languageCode == 'ar');
    if (localExists || legacyExists) { await quranAudio.playExternalFile(playableFile.path, title: title); } else { await quranAudio.playExternalUrl(url, title: title); }
  }

  Future<void> _download(SurahModel surah) async {
    final audio = _audioFor(surah);
    final url = audio?.downloadUrl.isNotEmpty == true ? audio!.downloadUrl : audio?.url ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(arSafe() ? 'لا توجد تلاوة قابلة للتنزيل' : 'No downloadable audio is available for this selection.'),
      ));
      return;
    }
    setState(() => downloading = true);
    try {
      final bytes = await repo.downloadBytes(url);
      final dir = await getApplicationDocumentsDirectory();
      // Use the shared directory read by Wirdi's Downloads and playlists.
      final reciterSlug = selectedReciter?.slug ?? 'reciter';
      final recitationSlug = selectedRecitation ?? 'recitation';
      final fileStem = '${reciterSlug}_${recitationSlug}_${surah.number}';
      final file = File(Way2QuranStorage.recitationFilePath(dir.path, fileStem));
      await Way2QuranStorage.writeBytesAtomically(file, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(arSafe() ? 'تم تنزيل التلاوة داخل Wirdi' : 'Recitation downloaded inside Wirdi'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(arSafe() ? 'تعذر تنزيل التلاوة' : 'Could not download the recitation.'),
        ));
      }
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
      translatedAyahs = {};
      translationError = null;
    });
    _loadTranslation(value, selectedTranslation);
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
          if (selectedSurah != null && translatedAyahs.isEmpty && !loadingTranslation && translationError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadTranslation(surah.number, selectedTranslation);
            });
          }
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedTranslation,
                        decoration: InputDecoration(
                          labelText: ar ? 'الترجمة' : 'Translation',
                          border: const OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en.sahih', child: Text('English — Sahih International')),
                          DropdownMenuItem(value: 'en.pickthall', child: Text('English — Pickthall')),
                          DropdownMenuItem(value: 'en.yusufali', child: Text('English — Yusuf Ali')),
                          DropdownMenuItem(value: 'ur.jalandhry', child: Text('اردو — جالندھری')),
                          DropdownMenuItem(value: 'fr.hamidullah', child: Text('Français — Hamidullah')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              selectedTranslation = v;
                              translatedAyahs = {};
                              translationError = null;
                            });
                            _loadTranslation(surah.number, v);
                          }
                        },
                      ),
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
                      Row(children: [Expanded(child: FilledButton.icon(onPressed: selectedReciter == null || selectedRecitation == null ? null : () => _play(surah), icon: const Icon(Icons.play_arrow_rounded), label: Text(ar ? 'تشغيل السورة' : 'Play Surah'))), const SizedBox(width: 10), OutlinedButton.icon(onPressed: selectedReciter == null || selectedRecitation == null || downloading ? null : () => _download(surah), icon: downloading ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.download_rounded), label: Text(ar ? 'تنزيل' : 'Download'))]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(ar ? 'نص الآيات المحددة' : 'Selected ayah range',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(ar ? 'من الآية $fromAyah إلى الآية $toAyah' : 'Ayah $fromAyah through $toAyah',
                        style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      ...surah.ayahs.asMap().entries
                          .where((entry) => entry.key + 1 >= fromAyah && entry.key + 1 <= toAyah)
                          .map((entry) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  '${entry.value.text}  ﴿${entry.key + 1}﴾',
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(fontSize: 22, height: 1.9),
                                ),
                              )),
                      const Divider(),
                      Text(
                        ar
                            ? 'تنبيه: مصدر الصوت يوفر ملف السورة كاملة؛ تحديد الآيات يحدد النص المعروض، لكنه لا يقص ملف الصوت.'
                            : 'Note: the source provides full-surah audio. The ayah range filters the displayed text, but does not trim the audio file.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(ar ? 'ترجمة معاني الآيات' : 'Translation of meanings',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      if (loadingTranslation)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (translationError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(translationError!),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton.icon(
                                onPressed: () => _loadTranslation(surah.number, selectedTranslation),
                                icon: const Icon(Icons.refresh),
                                label: Text(ar ? 'إعادة المحاولة' : 'Retry'),
                              ),
                            ),
                          ],
                        )
                      else if (translatedAyahs.isEmpty)
                        Text(ar ? 'اختر الترجمة لتحميل معاني الآيات.' : 'Choose an edition to load translated meanings.')
                      else
                        ...List.generate(toAyah - fromAyah + 1, (index) {
                          final number = fromAyah + index;
                          final text = translatedAyahs[number];
                          if (text == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('$number. $text',
                                textDirection: selectedTranslation.startsWith('ur') ? TextDirection.rtl : TextDirection.ltr,
                                style: const TextStyle(fontSize: 16, height: 1.6)),
                          );
                        }),
                      const SizedBox(height: 4),
                      Text(
                        ar ? 'الترجمات تُحمّل عبر الإنترنت من خدمة AlQuran Cloud.' : 'Translations are fetched online from AlQuran Cloud.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Way2QuranRecitationsDirectoryScreen())),
                icon: const Icon(Icons.auto_stories_rounded),
                label: Text(ar ? 'دليل القراءات والروايات' : 'Qira’at & Riwayat Directory'),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(ar ? 'التلاوة المختارة' : 'Selected recitation'),
                  subtitle: Text(ar ? 'اختر السورة والقارئ والرواية واضبط سرعة التلاوة.' : 'Choose a surah, reciter and riwayah, then adjust playback speed.'),
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
