import 'package:flutter/material.dart';

import '../../core/data/qiraat_catalog.dart';
import '../../core/services/qiraat_service.dart';
import '../../core/theme/app_theme.dart';
import 'riwayah_detail_screen.dart';

class QiraatDetailScreen extends StatelessWidget {
  final String qiraatId;

  const QiraatDetailScreen({super.key, required this.qiraatId});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final qiraat = QiraatCatalog.all.firstWhere((q) => q.id == qiraatId);
    final index = QiraatCatalog.all.indexWhere((q) => q.id == qiraatId);
    final service = QiraatService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(qiraat.nameFor(ar ? 'ar' : 'en')),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: service.loadReaders(),
        builder: (context, snapshot) {
          final runtimeCount = qiraat.riwayat
              .map((r) => service.readersForRiwayah(r.id).length)
              .fold<int>(0, (sum, count) => sum + count);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              _HeroCard(
                title: qiraat.nameFor(ar ? 'ar' : 'en'),
                subtitle: ar
                    ? 'القراءة \${index + 1} من القراءات العشر المتواترة'
                    : 'Reading \${index + 1} of the ten canonical Qira’at',
                body: ar ? qiraat.descriptionAr : qiraat.descriptionEn,
              ),
              const SizedBox(height: 12),
              _StatsCard(
                ar: ar,
                riwayatCount: qiraat.riwayat.length,
                readerCount: runtimeCount,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: ar ? 'تاريخ القراءة' : 'History of the reading',
                text: ar ? qiraat.historyAr : qiraat.historyEn,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                title: ar ? 'مناطق الانتشار' : 'Historical spread',
                text: ar ? qiraat.regionsAr : qiraat.regionsEn,
              ),
              const SizedBox(height: 18),
              _SectionTitle(
                icon: Icons.record_voice_over_outlined,
                text: ar ? 'رواياته' : 'Its riwayat',
              ),
              const SizedBox(height: 8),
              ...qiraat.riwayat.map(
                (riwayah) => _RiwayahCard(
                  riwayah: riwayah,
                  ar: ar,
                  service: service,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiwayahDetailScreen(
                        riwayahId: riwayah.id,
                      ),
                    ),
                  ),
                ),
              ),
              if (QiraatCatalog.secondaryRoutesFor(qiraat.id).isNotEmpty) ...[
                const SizedBox(height: 14),
                _SectionTitle(
                  icon: Icons.alt_route_rounded,
                  text: ar ? 'إضافات وطرق فرعية' : 'Additional routes',
                ),
                const SizedBox(height: 8),
                ...QiraatCatalog.secondaryRoutesFor(qiraat.id).map(
                  (route) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.alt_route_rounded),
                      title: Text(route.nameFor(ar ? 'ar' : 'en')),
                      subtitle: Text(route.routeFor(ar ? 'ar' : 'en')),
                    ),
                  ),
                ),
              ],
              if (index > 0 || index < QiraatCatalog.all.length - 1) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QiraatDetailScreen(
                                qiraatId: QiraatCatalog.all[index - 1].id,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: Text(ar ? 'السابقة' : 'Previous'),
                        ),
                      ),
                    if (index > 0 && index < QiraatCatalog.all.length - 1)
                      const SizedBox(width: 10),
                    if (index < QiraatCatalog.all.length - 1)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QiraatDetailScreen(
                                qiraatId: QiraatCatalog.all[index + 1].id,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(ar ? 'التالية' : 'Next'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle, style: TextStyle(color: AppColors.primaryEmerald, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(height: 1.7)),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final bool ar;
  final int riwayatCount;
  final int readerCount;

  const _StatsCard({
    required this.ar,
    required this.riwayatCount,
    required this.readerCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                value: '\$riwayatCount',
                label: ar ? 'رواية أساسية' : 'Core riwayat',
              ),
            ),
            Container(width: 1, height: 42, color: AppColors.divider),
            Expanded(
              child: _Stat(
                value: '\$readerCount',
                label: ar ? 'مصدر قارئ مكتشف' : 'Runtime reader sources',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;

  const _InfoCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(height: 1.65)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.goldAccent),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _RiwayahCard extends StatelessWidget {
  final RiwayahOption riwayah;
  final bool ar;
  final QiraatService service;
  final VoidCallback onTap;

  const _RiwayahCard({
    required this.riwayah,
    required this.ar,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final readers = service.readersForRiwayah(riwayah.id);
    final available = readers.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 13, 12, 13),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.10),
          child: Icon(
            available ? Icons.graphic_eq_rounded : Icons.library_music_outlined,
            color: available ? AppColors.primaryEmerald : AppColors.mutedText,
          ),
        ),
        title: Text(
          riwayah.nameFor(ar ? 'ar' : 'en'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            available
                ? (ar ? '\${readers.length} قارئ متاح في وردي' : '\${readers.length} reader sources in Wirdi')
                : (ar ? 'لا يوجد مصدر قارئ مكتشف حاليًا' : 'No runtime reader source discovered yet'),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
