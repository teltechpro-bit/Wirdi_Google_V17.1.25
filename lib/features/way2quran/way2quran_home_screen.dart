import 'package:flutter/material.dart';
import 'way2quran_repository.dart';
import 'way2quran_models.dart';

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
      appBar: AppBar(title: Text(ar ? 'Way2Quran — القراءات' : 'Way2Quran — Recitations'), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Icon(Icons.menu_book_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(ar ? 'طريقك إلى القرآن' : 'Your way to the Quran', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(ar ? 'استمع إلى تلاوات القرآن الكريم من كبار القراء.' : 'Listen to Quran recitations from renowned reciters.', textAlign: TextAlign.center),
        ]))),
        const SizedBox(height: 20),
        TextField(controller: search, onSubmitted: (_) => doSearch(), decoration: InputDecoration(hintText: ar ? 'ابحث عن قارئ...' : 'Search for a reciter...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: doSearch, icon: const Icon(Icons.search)), border: const OutlineInputBorder())),
        const SizedBox(height: 24),
        Text(ar ? 'استمع الآن' : 'Listening now', textAlign: ar ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        FutureBuilder<List<Way2QuranReciter>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            if (snapshot.hasError) return Card(child: ListTile(leading: const Icon(Icons.cloud_off), title: Text(ar ? 'تعذر الاتصال بمصدر Way2Quran' : 'Way2Quran source unavailable'), trailing: IconButton(onPressed: doSearch, icon: const Icon(Icons.refresh))));
            final list = snapshot.data ?? const <Way2QuranReciter>[];
            return SizedBox(height: 230, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: list.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (context, i) => SizedBox(width: 175, child: _ReciterCard(reciter: list[i], ar: ar, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranReciterScreen(reciterSlug: list[i].slug))))));
          },
        ),
        const SizedBox(height: 24),
        Text(ar ? 'الروايات والقراءات' : 'Recitations', textAlign: ar ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: Way2QuranRepository.recitations.map((r) => ActionChip(label: Text(r.name(ar)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Way2QuranRecitersScreen(recitation: r))))).toList()),
      ]),
    );
  }
}

class _ReciterCard extends StatelessWidget {
  final Way2QuranReciter reciter; final bool ar; final VoidCallback onTap;
  const _ReciterCard({required this.reciter, required this.ar, required this.onTap});
  @override Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(child: reciter.photo.isEmpty ? const Icon(Icons.person, size: 56) : Image.network(reciter.photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 56))),
    Padding(padding: const EdgeInsets.all(8), child: Text(reciter.name(ar), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
  ])));
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
  @override void initState() { super.initState(); future = Way2QuranRepository().getReciter(widget.reciterSlug); }
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
        ...rec.audioFiles.map((a) => Card(child: ListTile(leading: const Icon(Icons.play_circle_outline), title: Text(a.surahName.isEmpty ? 'سورة ' + a.surahNumber.toString() : a.surahName), subtitle: Text(a.url.isEmpty ? a.downloadUrl : a.url)))),
        if (rec.downloadUrl.isNotEmpty) FilledButton.icon(onPressed: () => Way2QuranRepository().incrementDownload(rec.slug), icon: const Icon(Icons.download), label: Text(ar ? 'تحميل المصحف' : 'Download Mushaf')),
      ]);
    }));
  }
}