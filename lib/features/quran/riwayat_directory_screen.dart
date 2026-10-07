import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/services/qiraat_service.dart';
import '../../core/theme/app_theme.dart';
import 'riwayah_detail_screen.dart';

class RiwayatDirectoryScreen extends StatelessWidget {
  final String? qiraatId;

  const RiwayatDirectoryScreen({super.key, this.qiraatId});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final service = QiraatService.instance;
    final all = QiraatCatalog.allRiwayat;
    final items = qiraatId == null
        ? all
        : all.where((r) => r.qiraatId == qiraatId).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'الروايات' : 'Riwayat'),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: service.loadReaders(),
        builder: (context, snapshot) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final r = items[index];
              final qiraat = QiraatCatalog.all.firstWhere((q) => q.id == r.qiraatId);
              final readers = service.readersForRiwayah(r.id);

              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiwayahDetailScreen(riwayahId: r.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 10, 13),
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
                                r.nameFor(ar ? 'ar' : 'en'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ar ? 'القراءة: ' + qiraat.nameAr : 'Reading: ' + qiraat.nameEn,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                readers.isEmpty
                                    ? (ar ? 'لا يوجد مصدر قارئ مكتشف' : 'No runtime reader source')
                                    : (ar
                                        ? readers.length.toString() + ' قارئ متاح'
                                        : readers.length.toString() + ' reader sources'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: readers.isEmpty
                                      ? AppColors.mutedText
                                      : AppColors.primaryEmerald,
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
              );
            },
          );
        },
      ),
    );
  }
}
