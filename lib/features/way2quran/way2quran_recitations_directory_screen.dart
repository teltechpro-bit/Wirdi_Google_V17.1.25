import 'package:flutter/material.dart';
import 'way2quran_models.dart';
import 'way2quran_repository.dart';
import 'way2quran_home_screen.dart';

class Way2QuranRecitationsDirectoryScreen extends StatefulWidget {
  const Way2QuranRecitationsDirectoryScreen({super.key});
  @override
  State<Way2QuranRecitationsDirectoryScreen> createState() => _Way2QuranRecitationsDirectoryScreenState();
}

class _Way2QuranRecitationsDirectoryScreenState extends State<Way2QuranRecitationsDirectoryScreen> {
  final repo = Way2QuranRepository();
  late Future<List<Way2QuranRecitation>> future;

  @override
  void initState() {
    super.initState();
    future = repo.getRecitations();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'القراءات والروايات' : 'Qira’at & Riwayat')),
      body: FutureBuilder<List<Way2QuranRecitation>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => setState(() => future = repo.getRecitations()),
                icon: const Icon(Icons.refresh),
                label: Text(ar ? 'إعادة المحاولة' : 'Retry'),
              ),
            );
          }
          final all = snapshot.data ?? const <Way2QuranRecitation>[];
          if (all.isEmpty) {
            return Center(child: Text(ar ? 'لا توجد قراءات متاحة' : 'No recitations available'));
          }
          final primary = all.take(3).toList();
          final frequent = all.length > 3 ? all.sublist(3) : const <Way2QuranRecitation>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(context, ar ? 'القراءات الأساسية' : 'Core recitations'),
              const SizedBox(height: 10),
              ...primary.map((r) => _tile(context, r, ar)),
              if (frequent.isNotEmpty) ...[
                const SizedBox(height: 24),
                _section(context, ar ? 'التلاوات والقراءات المتنوعة' : 'Frequent & various recitations'),
                const SizedBox(height: 10),
                ...frequent.map((r) => _tile(context, r, ar)),
              ],
              const SizedBox(height: 32),
              Text(
                ar
                    ? 'هذه القائمة مبنية على قائمة القراءات الفعلية من Way2Quran، والضغط على أي قراءة يعرض القراء المرتبطين بها.'
                    : 'This directory uses the actual Way2Quran recitation list. Selecting a recitation opens its real reciter collection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      );

  Widget _tile(BuildContext context, Way2QuranRecitation r, bool ar) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.auto_stories_rounded)),
          title: Text(r.name(ar), style: const TextStyle(fontWeight: FontWeight.w800)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => Way2QuranRecitersScreen(recitation: r)),
          ),
        ),
      );
}
