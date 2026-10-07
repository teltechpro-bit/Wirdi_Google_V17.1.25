import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/theme/app_theme.dart';

class RiwayatDirectoryScreen extends StatelessWidget {
  final String? qiraatId;
  const RiwayatDirectoryScreen({super.key, this.qiraatId});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final all = QiraatCatalog.allRiwayat;
    final items = qiraatId == null ? all : all.where((r) => r.qiraatId == qiraatId).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الروايات' : 'Riwayat'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final r = items[index];
          final qiraat = QiraatCatalog.all.firstWhere((q) => q.id == r.qiraatId);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.10),
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text(r.nameFor(ar ? 'ar' : 'en'), textDirection: ar ? TextDirection.rtl : TextDirection.ltr, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(ar ? 'القراءة: ${qiraat.nameAr}' : 'Reading: ${qiraat.nameEn}', textDirection: ar ? TextDirection.rtl : TextDirection.ltr, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}