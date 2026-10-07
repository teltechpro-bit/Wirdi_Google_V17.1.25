import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/services/qiraat_service.dart';
import '../../core/theme/app_theme.dart';
import 'qiraat_detail_screen.dart';

class TenQiraatScreen extends StatelessWidget {
  const TenQiraatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final service = QiraatService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'القراءات العشر' : 'The Ten Qira’at'),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: service.loadReaders(),
        builder: (context, _) {
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
                        ar ? 'القراءات العشر المتواترة' : 'The ten canonical Qira’at',
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ar
                            ? 'تصفح كل قراءة، ثم رواياتها، ثم القراء المتاحين لها. هذا الدليل منفصل عن منطق تشغيل المصحف حتى لا يتغير الصوت الحالي لمجرد التصفح.'
                            : 'Browse each reading, then its riwayat, then the available readers. This directory is separate from Quran playback, so browsing never changes the current audio by itself.',
                        style: const TextStyle(height: 1.7),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...QiraatCatalog.directoryReadings.asMap().entries.map((entry) {
                final index = entry.key;
                final q = entry.value;
                final readerCount = q.riwayat
                    .map((r) => service.readersForRiwayah(r.id).length)
                    .fold<int>(0, (sum, count) => sum + count);

                final narratorNames = ar
                    ? q.riwayat.map((r) => r.nameAr.split(' عن ').first).join(' و ')
                    : q.riwayat.map((r) => r.nameEn.split(' ʿan ').first).join(' & ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QiraatDetailScreen(qiraatId: q.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.10),
                              child: Text(
                                (index + 1).toString(),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    q.nameFor(ar ? 'ar' : 'en'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (ar ? 'الراويان: ' : 'Narrators: ') + narratorNames,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    readerCount == 0
                                        ? (ar
                                            ? 'لا توجد مصادر قارئين مكتشفة حاليًا'
                                            : 'No runtime reader sources yet')
                                        : readerCount.toString() +
                                            (ar
                                                ? ' مصدر قارئ في وردي'
                                                : ' reader sources in Wirdi'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: readerCount > 0
                                          ? AppColors.primaryEmerald
                                          : AppColors.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
