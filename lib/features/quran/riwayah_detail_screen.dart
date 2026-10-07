import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/models/riwayah_reader.dart';
import '../../core/services/qiraat_service.dart';
import '../../core/theme/app_theme.dart';

class RiwayahDetailScreen extends StatefulWidget {
  final String riwayahId;

  const RiwayahDetailScreen({super.key, required this.riwayahId});

  @override
  State<RiwayahDetailScreen> createState() => _RiwayahDetailScreenState();
}

class _RiwayahDetailScreenState extends State<RiwayahDetailScreen> {
  final service = QiraatService.instance;
  int _page = 0;
  static const _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final riwayah = QiraatCatalog.byId(widget.riwayahId);
    final qiraat = QiraatCatalog.all.firstWhere((q) => q.id == riwayah.qiraatId);

    return Scaffold(
      appBar: AppBar(
        title: Text(riwayah.nameFor(ar ? 'ar' : 'en')),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: service.loadReaders(),
        builder: (context, snapshot) {
          final readers = service.readersForRiwayah(widget.riwayahId);
          final pages = readers.isEmpty ? 1 : (readers.length / _pageSize).ceil();
          final currentPage = _page.clamp(0, pages - 1);
          final start = currentPage * _pageSize;
          final visible = readers.skip(start).take(_pageSize).toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        riwayah.nameFor(ar ? 'ar' : 'en'),
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ar ? 'القراءة: ' + qiraat.nameAr : 'Reading: ' + qiraat.nameEn,
                        style: TextStyle(
                          color: AppColors.primaryEmerald,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ar
                            ? 'القراء المعروضون هنا هم مصادر الصوت التي اكتشفها وردي لهذه الرواية تحديدًا. لا يتم نقل قارئ من رواية أخرى.'
                            : 'Readers shown here are the audio sources discovered by Wirdi for this exact riwayah. No reader is copied from another riwayah.',
                        style: const TextStyle(height: 1.65),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _CountCard(ar: ar, count: readers.length),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people_alt_outlined, color: AppColors.goldAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ar ? 'القراء المسجلون' : 'Registered reader sources',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (readers.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      ar
                          ? 'لا يوجد قارئ متاح حاليًا'
                          : 'No reader source is currently available',
                    ),
                    subtitle: Text(
                      ar
                          ? 'الرواية موجودة في الدليل، لكن مصدرًا صوتيًا موثوقًا لم يُكتشف بعد.'
                          : 'The riwayah is present in the directory, but no trusted audio source has been discovered yet.',
                    ),
                  ),
                )
              else
                ...visible.map(
                  (reader) => _ReaderCard(
                    reader: reader,
                    ar: ar,
                    selected: service.selectedReaderFor(widget.riwayahId)?.id == reader.id,
                    onUse: () => _useReader(reader),
                  ),
                ),
              if (pages > 1) ...[
                const SizedBox(height: 12),
                _Pager(
                  ar: ar,
                  page: currentPage,
                  pages: pages,
                  onPrevious: currentPage == 0
                      ? null
                      : () => setState(() => _page = currentPage - 1),
                  onNext: currentPage >= pages - 1
                      ? null
                      : () => setState(() => _page = currentPage + 1),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _useReader(RiwayahReader reader) async {
    await service.setRiwayah(widget.riwayahId);
    await service.setReader(widget.riwayahId, reader.id);
    if (!mounted) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final riwayah = QiraatCatalog.byId(widget.riwayahId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ar
              ? 'تم اختيار ' + reader.nameFor('ar') + ' مع ' + riwayah.nameAr
              : reader.name + ' selected for ' + riwayah.nameEn,
        ),
      ),
    );
    setState(() {});
  }
}

class _CountCard extends StatelessWidget {
  final bool ar;
  final int count;

  const _CountCard({required this.ar, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Column(
          children: [
            Text(count.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(ar ? 'قارئ/مصدر متاح في وردي' : 'reader sources available in Wirdi'),
          ],
        ),
      ),
    );
  }
}

class _ReaderCard extends StatelessWidget {
  final RiwayahReader reader;
  final bool ar;
  final bool selected;
  final VoidCallback onUse;

  const _ReaderCard({
    required this.reader,
    required this.ar,
    required this.selected,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.10),
              child: const Icon(Icons.person_outline_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reader.nameFor(ar ? 'ar' : 'en'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (ar ? 'المصدر: ' : 'Source: ') + reader.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.goldAccent)
            else
              OutlinedButton(
                onPressed: onUse,
                child: Text(ar ? 'اختيار' : 'Use'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final bool ar;
  final int page;
  final int pages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _Pager({
    required this.ar,
    required this.page,
    required this.pages,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPrevious,
            child: Text(ar ? 'السابق' : 'Previous'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text((page + 1).toString() + ' / ' + pages.toString()),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: onNext,
            child: Text(ar ? 'التالي' : 'Next'),
          ),
        ),
      ],
    );
  }
}
