import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/services/qiraat_service.dart';
import '../../core/theme/app_theme.dart';

class TenQiraatScreen extends StatefulWidget {
  const TenQiraatScreen({super.key});

  @override
  State<TenQiraatScreen> createState() => _TenQiraatScreenState();
}

class _TenQiraatScreenState extends State<TenQiraatScreen> {
  final _service = QiraatService.instance;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'القراءات العشر' : 'The Ten Qira’at'),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: _service.loadReaders(),
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _IntroCard(ar: ar),
              const SizedBox(height: 14),
              for (var i = 0; i < QiraatCatalog.all.length; i++) ...[
                _QiraatCard(
                  index: i + 1,
                  qiraat: QiraatCatalog.all[i],
                  service: _service,
                  arabic: ar,
                  onRiwayahSelected: () => setState(() {}),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final bool ar;
  const _IntroCard({required this.ar});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ar ? 'القراءات العشر المتواترة' : 'The Ten Canonical Readings',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ar
                  ? 'تصفّح أئمة القراءات العشر، ثم اختر الرواية التي تريدها. بعد اختيار الرواية ستظهر لك القرّاء المرتبطون بها فقط.'
                  : 'Browse the ten canonical readings, then choose a riwayah. Only readers linked to that riwayah are shown.',
              textAlign: ar ? TextAlign.right : TextAlign.left,
              textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _QiraatCard extends StatelessWidget {
  final int index;
  final QiraatReading qiraat;
  final QiraatService service;
  final bool arabic;
  final VoidCallback onRiwayahSelected;

  const _QiraatCard({
    required this.index,
    required this.qiraat,
    required this.service,
    required this.arabic,
    required this.onRiwayahSelected,
  });

  @override
  Widget build(BuildContext context) {
    final readersCount = qiraat.riwayat.fold<int>(
      0,
      (sum, riwayah) => sum + service.readersForRiwayah(riwayah.id).length,
    );
    final current = service.selectedRiwayahId;
    final qiraatName = qiraat.nameFor(arabic ? 'ar' : 'en');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.11),
          child: Text(
            '$index',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          qiraatName,
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          arabic
              ? 'الإمام: ${qiraat.imamAr} • ${qiraat.riwayat.length} روايتان'
              : 'Imam: ${qiraat.imamEn} • ${qiraat.riwayat.length} riwayat',
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        ),
        children: [
          for (final riwayah in qiraat.riwayat)
            _RiwayahRow(
              riwayah: riwayah,
              service: service,
              arabic: arabic,
              selected: riwayah.id == current,
              onTap: () async {
                await service.setRiwayah(riwayah.id);
                onRiwayahSelected();
              },
            ),
          if (readersCount > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4, start: 8, end: 8),
              child: Align(
                alignment: arabic ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  arabic
                      ? '${readersCount} قارئًا متاحًا لهذه القراءة'
                      : '${readersCount} readers available across these riwayat',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RiwayahRow extends StatelessWidget {
  final RiwayahOption riwayah;
  final QiraatService service;
  final bool arabic;
  final bool selected;
  final VoidCallback onTap;

  const _RiwayahRow({
    required this.riwayah,
    required this.service,
    required this.arabic,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final readers = service.readersForRiwayah(riwayah.id);
    final hasSource = readers.isNotEmpty || riwayah.hasVerifiedAyahAudio;
    final title = riwayah.nameFor(arabic ? 'ar' : 'en');

    return Material(
      color: selected
          ? AppColors.primaryEmerald.withValues(alpha: 0.07)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 8, 10),
          child: Row(
            children: [
              Icon(
                hasSource ? Icons.graphic_eq_rounded : Icons.info_outline_rounded,
                size: 21,
                color: hasSource
                    ? AppColors.primaryEmerald
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: arabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      readers.isEmpty
                          ? (arabic
                              ? 'لا يوجد قارئ موثّق مكتشف حاليًا'
                              : 'No verified reader source discovered yet')
                          : (arabic
                              ? '${readers.length} قارئ مرتبط بهذه الرواية'
                              : '${readers.length} reader${readers.length == 1 ? '' : 's'} linked to this riwayah'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Icon(Icons.check_circle_rounded, color: AppColors.goldAccent, size: 20),
              const SizedBox(width: 4),
              Icon(
                arabic ? Icons.chevron_left : Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
