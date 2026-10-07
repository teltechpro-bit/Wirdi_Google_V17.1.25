import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/theme/app_theme.dart';
import 'riwayat_directory_screen.dart';

class TenQiraatScreen extends StatelessWidget {
  const TenQiraatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'القراءات العشر' : 'The Ten Qira’at'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        itemCount: QiraatCatalog.all.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final q = QiraatCatalog.all[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.10),
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text(q.nameFor(ar ? 'ar' : 'en'), textDirection: ar ? TextDirection.rtl : TextDirection.ltr, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(ar ? 'الإمام: ${q.imamAr} • روايتان' : 'Imam: ${q.imamEn} • 2 riwayat', textDirection: ar ? TextDirection.rtl : TextDirection.ltr),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiwayatDirectoryScreen(qiraatId: q.id))),
            ),
          );
        },
      ),
    );
  }
}