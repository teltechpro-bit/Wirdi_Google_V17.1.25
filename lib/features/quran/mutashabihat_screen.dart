import 'package:flutter/material.dart';

import '../../core/models/quran_models.dart';
import '../../core/services/arabic_word_match.dart';
import '../../core/services/mutashabihat_repository.dart';
import '../../core/services/quran_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bi.dart';

class _Entry {
  final int surah;
  final int ayah;
  final String text;
  final String normalized;
  final String surahName;
  final List<SimilarVerse> similar;
  const _Entry(this.surah, this.ayah, this.text, this.normalized, this.surahName, this.similar);
}

/// Browse Quran verses that closely resemble other verses (the "mutashabihat"),
/// with the differing words highlighted - a classic memorization pain point.
class MutashabihatScreen extends StatefulWidget {
  const MutashabihatScreen({super.key});

  @override
  State<MutashabihatScreen> createState() => _MutashabihatScreenState();
}

class _MutashabihatScreenState extends State<MutashabihatScreen> {
  List<SurahModel> _surahs = const <SurahModel>[];
  List<_Entry> _entries = const <_Entry>[];
  String _query = '';
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final surahs = await QuranRepository.load();
      final data = await MutashabihatRepository.load();
      final entries = <_Entry>[];
      data.forEach((key, similar) {
        final parts = key.split(':');
        final s = int.tryParse(parts[0]);
        final a = int.tryParse(parts[1]);
        if (s == null || a == null || s < 1 || s > surahs.length) return;
        final surah = surahs[s - 1];
        if (a < 1 || a > surah.ayahs.length) return;
        final text = surah.ayahs[a - 1].text;
        final normalized = ArabicWordMatch.tokens(text).map((e) => e.value).join(' ');
        entries.add(_Entry(s, a, text, normalized, surah.name, similar));
      });
      entries.sort((x, y) => x.surah != y.surah ? x.surah.compareTo(y.surah) : x.ayah.compareTo(y.ayah));
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  List<_Entry> get _filtered {
    final q = _query.trim();
    if (q.isEmpty) return _entries;
    final nq = ArabicWordMatch.tokens(q).map((e) => e.value).join(' ');
    return _entries.where((e) {
      if ('${e.surah}:${e.ayah}' == q) return true;
      if (e.surahName.contains(q)) return true;
      return nq.isNotEmpty && e.normalized.contains(nq);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'متشابهات القرآن', 'Similar Verses')), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? Center(child: Text(bi(context, 'تعذّر تحميل البيانات', 'Could not load the data')))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: bi(context, 'ابحث بكلمة أو اسم سورة أو 2:35', 'Search a word, surah name or 2:35'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        bi(
                          context,
                          'مستخرجة آليًا من نص المصحف بمقارنة الكلمات؛ للمراجعة والتدريب وليست حصرًا شاملًا.',
                          'Extracted automatically by comparing words in the Quran text; a study aid, not an exhaustive list.',
                        ),
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? Center(child: Text(bi(context, 'لا نتائج', 'No results')))
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.of(context).padding.bottom),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final e = list[i];
                                final surahTitle = isArabic(context) ? e.surahName : _surahs[e.surah - 1].englishName;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(
                                      e.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18, height: 1.8),
                                    ),
                                    subtitle: Text('$surahTitle • ${e.ayah}'),
                                    trailing: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.goldAccent.withValues(alpha: 0.2),
                                      child: Text('${e.similar.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                    ),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => _MutashabihatDetail(entry: e, surahs: _surahs),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _MutashabihatDetail extends StatelessWidget {
  final _Entry entry;
  final List<SurahModel> surahs;
  const _MutashabihatDetail({required this.entry, required this.surahs});

  List<InlineSpan> _spans(BuildContext context, String text, String other, {required Color highlight}) {
    final mine = ArabicWordMatch.tokens(text);
    final theirs = ArabicWordMatch.tokens(other).map((e) => e.value).toList();
    final flags = ArabicWordMatch.commonFlags(mine.map((e) => e.value).toList(), theirs);
    final base = DefaultTextStyle.of(context).style.color;
    final spans = <InlineSpan>[];
    for (var i = 0; i < mine.length; i++) {
      final same = flags[i];
      spans.add(TextSpan(
        text: '${mine[i].key} ',
        style: TextStyle(
          color: same ? base : highlight,
          fontWeight: same ? FontWeight.w500 : FontWeight.w800,
        ),
      ));
    }
    return spans;
  }

  Widget _verseCard(BuildContext context, {required String title, required String text, required String other, required Color accent, String? badge}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                if (badge != null)
                  Text(badge, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              textDirection: TextDirection.rtl,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 22,
                  height: 2.0,
                  color: DefaultTextStyle.of(context).style.color,
                ),
                children: _spans(context, text, other, highlight: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(BuildContext context, int surah, int ayah) {
    final s = surahs[surah - 1];
    return '${isArabic(context) ? s.name : s.englishName} • $ayah';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.red.shade600;
    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'مقارنة الآيات', 'Compare verses')), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Text(
            bi(context, 'الكلمات الملوّنة هي مواضع الاختلاف.', 'Coloured words mark where the verses differ.'),
            style: const TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          for (final sim in entry.similar)
            Builder(builder: (context) {
              final other = surahs[sim.surah - 1].ayahs[sim.ayah - 1].text;
              return Column(
                children: [
                  _verseCard(
                    context,
                    title: _label(context, entry.surah, entry.ayah),
                    text: entry.text,
                    other: other,
                    accent: accent,
                  ),
                  _verseCard(
                    context,
                    title: _label(context, sim.surah, sim.ayah),
                    text: other,
                    other: entry.text,
                    accent: accent,
                    badge: '${sim.score}%',
                  ),
                  const Divider(height: 24),
                ],
              );
            }),
        ],
      ),
    );
  }
}
