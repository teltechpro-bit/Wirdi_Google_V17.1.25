import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'way2quran_models.dart';
import 'way2quran_repository.dart';

/// Wirdi-native discovery shelves backed by the live reciter catalogue.
/// Editorial shelves are derived only from records returned by the API.
class Way2QuranDiscoveryScreen extends StatefulWidget {
  final ValueChanged<Way2QuranReciter> onOpenReciter;
  const Way2QuranDiscoveryScreen({super.key, required this.onOpenReciter});

  @override
  State<Way2QuranDiscoveryScreen> createState() => _Way2QuranDiscoveryScreenState();
}

class _Way2QuranDiscoveryScreenState extends State<Way2QuranDiscoveryScreen> {
  final Way2QuranRepository _repository = Way2QuranRepository();
  late Future<List<Way2QuranReciter>> _recitersFuture;

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _recitersFuture = _loadReciters();
  }

  Future<List<Way2QuranReciter>> _loadReciters() async {
    final page = await _repository.getRecitersPage(pageSize: 100, sort: 'arabicName');
    return page.reciters;
  }

  Future<void> _shareRecitation() async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final descriptionController = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ar ? 'شارك تلاوة مع الآخرين' : 'Share a recitation'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _ar ? 'اسم التلاوة أو القارئ' : 'Recitation or reciter name',
              ),
            ),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: _ar ? 'رابط التلاوة (مطلوب)' : 'Recitation URL (required)',
                hintText: 'https://…',
              ),
            ),
            TextField(
              controller: descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _ar ? 'ملاحظة (اختياري)' : 'Note (optional)',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final uri = Uri.tryParse(urlController.text.trim());
              if (uri == null ||
                  (uri.scheme != 'https' && uri.scheme != 'http') ||
                  uri.host.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_ar
                      ? 'أدخل رابطًا صحيحًا يبدأ بـ https:// أو http://'
                      : 'Enter a valid http:// or https:// URL.'),
                ));
                return;
              }
              Navigator.pop(dialogContext, [
                titleController.text.trim(),
                uri.toString(),
                descriptionController.text.trim(),
              ]);
            },
            child: Text(_ar ? 'متابعة المشاركة' : 'Continue to share'),
          ),
        ],
      ),
    );
    titleController.dispose();
    urlController.dispose();
    descriptionController.dispose();
    if (!mounted || values == null) return;

    final title = values[0].isEmpty
        ? (_ar ? 'تلاوة قرآنية مقترحة' : 'Recommended Quran recitation')
        : values[0];
    final note = values[2].isEmpty ? '' : '\n\n${values[2]}';
    final message = '$title$note\n\n${values[1]}\n\n'
        '${_ar ? 'مشاركة من وردي' : 'Shared from Wirdi'}';
    await Share.share(message, subject: title);
  }

  void _openReciter(Way2QuranReciter reciter) {
    widget.onOpenReciter(reciter);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_ar ? 'اكتشف تلاوات جديدة' : 'Discover recitations'),
      ),
      body: FutureBuilder<List<Way2QuranReciter>>(
        future: _recitersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    _ar ? 'تعذر تحميل مكتبة القراء' : 'Could not load the reciter library',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => _recitersFuture = _loadReciters()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_ar ? 'إعادة المحاولة' : 'Try again'),
                  ),
                ]),
              ),
            );
          }

          final reciters = [...?snapshot.data];
          if (reciters.isEmpty) {
            return Center(child: Text(_ar ? 'لا توجد نتائج متاحة الآن.' : 'No reciters are available right now.'));
          }
          final byPopularity = [...reciters]
            ..sort((a, b) => b.totalViews.compareTo(a.totalViews));
          final hiddenGems = [...reciters]
            ..sort((a, b) => a.totalViews.compareTo(b.totalViews));
          final dayIndex = DateTime.now().difference(DateTime(2020, 1, 1)).inDays % reciters.length;
          final spotlight = reciters[dayIndex];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.auto_awesome_rounded, size: 34, color: scheme.primary),
                  const SizedBox(height: 10),
                  Text(
                    _ar ? 'اكتشاف يومي يناسب وِردك' : 'A fresh discovery for your daily wird',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(_ar
                      ? 'استكشف أصواتًا مختلفة، وارجع إلى قارئ جديد كل يوم.'
                      : 'Explore different voices and find a new reciter each day.'),
                ]),
              ),
              const SizedBox(height: 20),
              _ShelfHeader(
                title: _ar ? 'اختيار اليوم' : 'Today’s spotlight',
                subtitle: _ar ? 'قارئ مختار من مكتبة وردي' : 'A daily pick from Wirdi’s reciter library',
              ),
              const SizedBox(height: 8),
              _DiscoveryReciterTile(
                reciter: spotlight,
                ar: _ar,
                onTap: () => _openReciter(spotlight),
                badge: _ar ? 'اختيار اليوم' : 'Daily pick',
              ),
              const SizedBox(height: 20),
              _ShelfHeader(
                title: _ar ? 'استمع بعمق' : 'Deep listens',
                subtitle: _ar ? 'ابدأ من القراء الأكثر استماعًا في المكتبة' : 'Start with widely listened-to voices in the catalogue',
              ),
              const SizedBox(height: 8),
              ...byPopularity.take(8).map((r) => _DiscoveryReciterTile(
                    reciter: r,
                    ar: _ar,
                    onTap: () => _openReciter(r),
                    badge: null,
                  )),
              const SizedBox(height: 20),
              _ShelfHeader(
                title: _ar ? 'جواهر خفية' : 'Hidden gems',
                subtitle: _ar ? 'اكتشف قراء أقل مشاهدة ضمن النتائج المتاحة' : 'Discover less-viewed reciters in the available results',
              ),
              const SizedBox(height: 8),
              ...hiddenGems.take(8).map((r) => _DiscoveryReciterTile(
                    reciter: r,
                    ar: _ar,
                    onTap: () => _openReciter(r),
                    badge: null,
                  )),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(child: Icon(Icons.ios_share_rounded)),
                  title: Text(_ar ? 'شارك تلاوة مع أمتك' : 'Share a recitation with others'),
                  subtitle: Text(_ar
                      ? 'أضف اسم التلاوة ورابطها ثم شاركها عبر التطبيقات المتاحة على جهازك.'
                      : 'Add a recitation title and link, then share it through apps available on your device.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _shareRecitation,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ShelfHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: Localizations.localeOf(context).languageCode == 'ar'
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _DiscoveryReciterTile extends StatelessWidget {
  final Way2QuranReciter reciter;
  final bool ar;
  final VoidCallback onTap;
  final String? badge;
  const _DiscoveryReciterTile({
    required this.reciter,
    required this.ar,
    required this.onTap,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundImage: reciter.photo.isEmpty ? null : NetworkImage(reciter.photo),
            child: reciter.photo.isEmpty ? const Icon(Icons.person_rounded) : null,
          ),
          title: Text(reciter.name(ar), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${reciter.totalViews} ${ar ? 'مشاهدة' : 'views'}'),
          trailing: badge == null
              ? const Icon(Icons.play_circle_outline_rounded)
              : Chip(label: Text(badge!)),
        ),
      );
}
