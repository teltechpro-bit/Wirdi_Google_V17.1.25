import 'package:flutter/material.dart';
import '../../core/services/quran_audio_service.dart';
import 'way2quran_repository.dart';
import 'way2quran_models.dart';
import '../quran/ten_qiraat_screen.dart';
import '../quran/riwayat_directory_screen.dart';
import '../quran/quran_screen.dart';

class Way2QuranHomeScreen extends StatefulWidget {
  const Way2QuranHomeScreen({super.key});
  @override State<Way2QuranHomeScreen> createState() => _Way2QuranHomeScreenState();
}

class _Way2QuranHomeScreenState extends State<Way2QuranHomeScreen> {
  final repo = Way2QuranRepository();
  final search = TextEditingController();
  late Future<List<Way2QuranReciter>> future;
  @override void initState() {
    super.initState();
    future = repo.getReciters(recitationSlug: 'hafs-an-asim');
  }
  @override void dispose() { search.dispose(); super.dispose(); }
  void doSearch() => setState(() => future = repo.getReciters(search: search.text.trim()));

  @override Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: const Text('Way2Quran'), centerTitle: false, actions: [
        IconButton(onPressed: doSearch, icon: const Icon(Icons.search_rounded)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.secondaryContainer],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.menu_book_rounded, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(ar ? 'طريقك إلى القرآن' : 'Your way to the Quran', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(ar ? 'استكشف القراءات والروايات واستمع إلى تلاوات القراء.' : 'Explore Quranic readings and listen to recitations.'),
          ])),
        const SizedBox(height: 20),
        TextField(controller: search, onSubmitted: (_) => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranSearchScreen(initialQuery: search.text.trim()))), decoration: InputDecoration(hintText: ar ? 'ابحث عن قارئ أو سورة...' : 'Search for a reciter or surah...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranSearchScreen(initialQuery: search.text.trim()))), icon: const Icon(Icons.search)), border: const OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranScreen())),
                icon: const Icon(Icons.menu_book_rounded),
                label: Text(ar ? 'قراءة واستماع' : 'Read & Listen'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranRecitersScreen(recitation: Way2QuranRepository.recitations.first)),),
                icon: const Icon(Icons.headphones_rounded),
                label: Text(ar ? 'استمع الآن' : 'Start Listening'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(ar ? 'استمع الآن' : 'Listening now', textAlign: ar ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Align(
          alignment: ar ? Alignment.centerLeft : Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Way2QuranAllRecitersScreen())),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(ar ? 'استكشف كل القراء' : 'Explore all reciters'),
          ),
        ),
        FutureBuilder<List<Way2QuranReciter>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            if (snapshot.hasError) return Card(child: ListTile(leading: const Icon(Icons.cloud_off), title: Text(ar ? 'تعذر الاتصال بمصدر Way2Quran' : 'Way2Quran source unavailable'), trailing: IconButton(onPressed: doSearch, icon: const Icon(Icons.refresh))));
            final list = snapshot.data ?? const <Way2QuranReciter>[];
            return SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final reciter = list[i];
                  return SizedBox(
                    width: 175,
                    child: _ReciterCard(
                      reciter: reciter,
                      ar: ar,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Way2QuranReciterScreen(reciterSlug: reciter.slug),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(ar ? 'الروايات والقراءات' : 'Recitations', textAlign: ar ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: Way2QuranRepository.recitations.map((r) => ActionChip(label: Text(r.name(ar)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranRecitersScreen(recitation: r))))).toList()),
        const SizedBox(height: 28),
        _SectionHeader(title: ar ? 'مكتبة الصوت' : 'Sound Library', subtitle: ar ? 'استكشف القراء والقراءات من مصدر Way2Quran' : 'Explore reciters and Quranic readings from Way2Quran'),
        const SizedBox(height: 12),
        FutureBuilder<List<Way2QuranReciter>>(
          future: future,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <Way2QuranReciter>[];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(children: items.take(5).map((r) => _LibraryTile(reciter: r, ar: ar, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranReciterScreen(reciterSlug: r.slug))))).toList());
          },
        ),
        const SizedBox(height: 16),
        _ExploreCard(icon: Icons.auto_stories_rounded, title: ar ? 'القراءات العشر المتواترة' : 'The Ten Mutawatir Qira’at', subtitle: ar ? 'الوصول السريع إلى دليل القراءات والروايات' : 'Quick access to the Qira’at and Riwayat directory', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenQiraatScreen()))),
        const SizedBox(height: 12),
        _ExploreCard(icon: Icons.menu_book_rounded, title: ar ? 'دليل الروايات' : 'Riwayat Directory', subtitle: ar ? 'استكشف طرق الأداء والروايات المتاحة' : 'Explore the available riwayat and transmission paths', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiwayatDirectoryScreen()))),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: Localizations.localeOf(context).languageCode == 'ar' ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);
}

class _LibraryTile extends StatelessWidget {
  final Way2QuranReciter reciter; final bool ar; final VoidCallback onTap;
  const _LibraryTile({required this.reciter, required this.ar, required this.onTap});
  @override Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(radius: 26, backgroundImage: reciter.photo.isEmpty ? null : NetworkImage(reciter.photo), child: reciter.photo.isEmpty ? const Icon(Icons.person_rounded) : null),
      title: Text(reciter.name(ar), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${reciter.totalViews} ${ar ? 'مشاهدة' : 'views'}'),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class _ExploreCard extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _ExploreCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(radius: 25, child: Icon(icon)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ]),
    )),
  );
}

class _ReciterCard extends StatelessWidget {
  final Way2QuranReciter reciter; final bool ar; final VoidCallback onTap;
  const _ReciterCard({required this.reciter, required this.ar, required this.onTap});
  @override Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(child: reciter.photo.isEmpty ? const Icon(Icons.person, size: 56) : Image.network(reciter.photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 56))),
    Padding(padding: const EdgeInsets.all(8), child: Text(reciter.name(ar), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
  ])));
}


class Way2QuranSearchScreen extends StatefulWidget {
  final String initialQuery;
  const Way2QuranSearchScreen({super.key, this.initialQuery = ''});
  @override State<Way2QuranSearchScreen> createState() => _Way2QuranSearchScreenState();
}
class _Way2QuranSearchScreenState extends State<Way2QuranSearchScreen> {
  final repo = Way2QuranRepository();
  late final TextEditingController query;
  Future<List<Way2QuranReciter>>? future;
  @override void initState() {
    super.initState();
    query = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) future = repo.getReciters(search: widget.initialQuery.trim());
  }
  @override void dispose() { query.dispose(); super.dispose(); }
  void submit() {
    final q = query.text.trim();
    setState(() => future = q.isEmpty ? null : repo.getReciters(search: q));
  }
  @override Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'البحث في الطريق إلى القرآن' : 'Search Way2Quran')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16,16,16,12), child: TextField(
          controller: query, autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search, onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            hintText: ar ? 'ابحث عن قارئ...' : 'Search for a reciter...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(onPressed: submit, icon: const Icon(Icons.search)),
            border: const OutlineInputBorder(),
          ),
        )),
        Expanded(child: future == null
          ? Center(child: Text(ar ? 'اكتب اسم القارئ ثم اضغط بحث' : 'Enter a reciter name and search'))
          : FutureBuilder<List<Way2QuranReciter>>(future: future, builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: FilledButton.icon(onPressed: submit, icon: const Icon(Icons.refresh), label: Text(ar ? 'إعادة البحث' : 'Retry')));
              final list = snapshot.data ?? const <Way2QuranReciter>[];
              if (list.isEmpty) return Center(child: Text(ar ? 'لا توجد نتائج مطابقة' : 'No matching reciters'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16,0,16,24), itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return Card(child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranReciterScreen(reciterSlug: r.slug))),
                    leading: CircleAvatar(radius: 28, backgroundImage: r.photo.isEmpty ? null : NetworkImage(r.photo), child: r.photo.isEmpty ? const Icon(Icons.person) : null),
                    title: Text(r.name(ar), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${r.totalViews} ${ar ? 'مشاهدة' : 'views'}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ));
                },
              );
            })),
      ]),
    );
  }
}

class Way2QuranRecitersScreen extends StatefulWidget {
  final Way2QuranRecitation recitation;
  const Way2QuranRecitersScreen({super.key, required this.recitation});
  @override State<Way2QuranRecitersScreen> createState() => _Way2QuranRecitersScreenState();
}
class _Way2QuranRecitersScreenState extends State<Way2QuranRecitersScreen> {
  late Future<List<Way2QuranReciter>> future;
  @override void initState() { super.initState(); future = Way2QuranRepository().getReciters(recitationSlug: widget.recitation.slug); }
  @override Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(appBar: AppBar(title: Text(widget.recitation.name(ar))), body: FutureBuilder<List<Way2QuranReciter>>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text(ar ? 'تعذر تحميل القراء' : 'Could not load reciters'));
      final list = snapshot.data ?? const <Way2QuranReciter>[];
      return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : MediaQuery.sizeOf(context).width >= 600 ? 3 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .82), itemCount: list.length, itemBuilder: (context, i) => _ReciterCard(reciter: list[i], ar: ar, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranReciterScreen(reciterSlug: list[i].slug)))));
    }));
  }
}

class Way2QuranReciterScreen extends StatefulWidget {
  final String reciterSlug;
  const Way2QuranReciterScreen({super.key, required this.reciterSlug});
  @override State<Way2QuranReciterScreen> createState() => _Way2QuranReciterScreenState();
}
class _Way2QuranReciterScreenState extends State<Way2QuranReciterScreen> {
  late Future<Way2QuranReciter> future; int selected = 0;
  String? _playingUrl;
  bool _loadingAudio = false;
  @override void initState() { super.initState(); future = Way2QuranRepository().getReciter(widget.reciterSlug); }
  @override void dispose() { super.dispose(); }
  Future<void> _play(Way2QuranAudioFile audio, bool ar) async {
    final url = audio.url.isNotEmpty ? audio.url : audio.downloadUrl;
    if (url.isEmpty) return;
    final same = _playingUrl == url;
    setState(() { _playingUrl = url; _loadingAudio = true; });
    try {
      if (same && !quranAudio.isPaused && quranAudio.playingAyah == null) {
        await quranAudio.pause();
      } else {
        await quranAudio.playExternalUrl(url, title: audio.surahName.isEmpty ? 'Surah ${audio.surahNumber}' : audio.surahName);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تعذر تشغيل الملف الصوتي' : 'Could not play this audio file')));
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }
  @override Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(appBar: AppBar(title: Text(ar ? 'القارئ' : 'Reciter')), body: FutureBuilder<Way2QuranReciter>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text(ar ? 'تعذر تحميل بيانات القارئ' : 'Could not load reciter'));
      final r = snapshot.data!; if (r.recitations.isEmpty) return Center(child: Text(ar ? 'لا توجد روايات' : 'No recitations'));
      final index = selected.clamp(0, r.recitations.length - 1); final rec = r.recitations[index];
      return ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(leading: r.photo.isEmpty ? const CircleAvatar(child: Icon(Icons.person)) : CircleAvatar(backgroundImage: NetworkImage(r.photo)), title: Text(r.name(ar)), subtitle: Text((ar ? 'المشاهدات: ' : 'Views: ') + r.totalViews.toString()))),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(value: index, decoration: InputDecoration(labelText: ar ? 'الرواية' : 'Riwayah', border: const OutlineInputBorder()), items: List.generate(r.recitations.length, (i) => DropdownMenuItem(value: i, child: Text(r.recitations[i].name(ar)))), onChanged: (v) { if (v != null) setState(() => selected = v); }),
        const SizedBox(height: 12),
        ...rec.audioFiles.map((a) {
          final url = a.url.isNotEmpty ? a.url : a.downloadUrl;
          final playing = _playingUrl == url && !quranAudio.isPaused && quranAudio.playingAyah == null;
          return Card(child: ListTile(
            onTap: () => _play(a, ar),
            leading: CircleAvatar(child: _loadingAudio && _playingUrl == url ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
            title: Text(a.surahName.isEmpty ? 'سورة ' + a.surahNumber.toString() : a.surahName),
            subtitle: Text(ar ? 'اضغط للاستماع' : 'Tap to listen'),
          ));
        }),
        if (rec.downloadUrl.isNotEmpty) FilledButton.icon(onPressed: () => Way2QuranRepository().incrementDownload(rec.slug), icon: const Icon(Icons.download), label: Text(ar ? 'تحميل المصحف' : 'Download Mushaf')),
      ]);
    }));
  }
}
class Way2QuranAllRecitersScreen extends StatefulWidget {
  const Way2QuranAllRecitersScreen({super.key});
  @override State<Way2QuranAllRecitersScreen> createState() => _Way2QuranAllRecitersScreenState();
}
class _Way2QuranAllRecitersScreenState extends State<Way2QuranAllRecitersScreen> {
  final repo = Way2QuranRepository();
  final search = TextEditingController();
  late Future<List<Way2QuranReciter>> future;
  @override void initState() { super.initState(); future = repo.getReciters(); }
  @override void dispose() { search.dispose(); super.dispose(); }
  void _load() => setState(() => future = repo.getReciters(search: search.text.trim()));
  @override Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'كل القراء' : 'All Reciters')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: search, onSubmitted: (_) => _load(), decoration: InputDecoration(hintText: ar ? 'ابحث عن قارئ...' : 'Search reciters...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.search)), border: const OutlineInputBorder()))),
        Expanded(child: FutureBuilder<List<Way2QuranReciter>>(future: future, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(ar ? 'تعذر تحميل القراء' : 'Could not load reciters'));
          final list = snapshot.data ?? const <Way2QuranReciter>[];
          return GridView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : MediaQuery.sizeOf(context).width >= 600 ? 3 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .82), itemCount: list.length, itemBuilder: (context, i) => _ReciterCard(reciter: list[i], ar: ar, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranReciterScreen(reciterSlug: list[i].slug)))));
        }))
      ])
    );
  }
}