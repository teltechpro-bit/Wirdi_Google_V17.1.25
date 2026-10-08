import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'way2quran_models.dart';
import 'way2quran_repository.dart';

class Way2QuranMushafScreen extends StatefulWidget {
  const Way2QuranMushafScreen({super.key});
  @override
  State<Way2QuranMushafScreen> createState() => _Way2QuranMushafScreenState();
}

class _Way2QuranMushafScreenState extends State<Way2QuranMushafScreen> {
  final repo = Way2QuranRepository();
  late Future<List<Way2QuranMushaf>> future;
  final downloading = <String>{};

  @override
  void initState() {
    super.initState();
    future = repo.getMushafs();
  }

  Future<File> _localFile(Way2QuranMushaf mushaf) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/way2quran/mushaf/${mushaf.slug}.pdf');
  }

  Future<void> _open(Way2QuranMushaf mushaf, bool ar) async {
    try {
      final file = await _localFile(mushaf);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ar ? 'نزّل المصحف أولًا لفتحه' : 'Download this Mushaf first')),
          );
        }
        return;
      }
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ar ? 'تعذر فتح الملف. تأكد من وجود تطبيق لقراءة PDF.' : 'Could not open the file. Make sure a PDF reader is installed.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ar ? 'تعذر فتح المصحف' : 'Could not open the Mushaf')),
        );
      }
    }
  }

  Future<void> _download(Way2QuranMushaf mushaf, bool ar) async {
    if (mushaf.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? 'رابط تنزيل المصحف غير متاح' : 'Mushaf download link is unavailable')),
      );
      return;
    }
    setState(() => downloading.add(mushaf.slug));
    try {
      final bytes = await repo.downloadBytes(mushaf.downloadUrl);
      final file = await _localFile(mushaf);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await repo.incrementMushafDownload(mushaf.slug);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ar ? 'تم تنزيل المصحف داخل Wirdi' : 'Mushaf downloaded inside Wirdi'),
            action: SnackBarAction(
              label: ar ? 'فتح' : 'Open',
              onPressed: () => _open(mushaf, ar),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ar ? 'تعذر تنزيل المصحف' : 'Could not download the Mushaf')),
        );
      }
    } finally {
      if (mounted) setState(() => downloading.remove(mushaf.slug));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'المصاحف' : 'Mushaf')),
      body: FutureBuilder<List<Way2QuranMushaf>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => setState(() => future = repo.getMushafs()),
                icon: const Icon(Icons.refresh),
                label: Text(ar ? 'إعادة المحاولة' : 'Retry'),
              ),
            );
          }
          final items = snapshot.data ?? const <Way2QuranMushaf>[];
          if (items.isEmpty) {
            return Center(child: Text(ar ? 'لا توجد مصاحف متاحة' : 'No Mushaf available'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final mushaf = items[index];
              final busy = downloading.contains(mushaf.slug);
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: mushaf.imageUrl.isEmpty
                      ? const CircleAvatar(child: Icon(Icons.menu_book_rounded))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            mushaf.imageUrl,
                            width: 52,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const CircleAvatar(child: Icon(Icons.menu_book_rounded)),
                          ),
                        ),
                  title: Text(mushaf.name(ar), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${mushaf.totalDownloads} ${ar ? 'تنزيل' : 'downloads'}'),
                  trailing: busy
                      ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: ar ? 'فتح المصحف المحفوظ' : 'Open downloaded Mushaf',
                              onPressed: () => _open(mushaf, ar),
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                            ),
                            IconButton(
                              tooltip: ar ? 'تنزيل المصحف' : 'Download Mushaf',
                              onPressed: () => _download(mushaf, ar),
                              icon: const Icon(Icons.download_rounded),
                            ),
                          ],
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
