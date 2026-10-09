import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/quran_audio_service.dart';

/// Manages only audio files downloaded by Wirdi's Way2Quran integration.
class Way2QuranDownloadsScreen extends StatefulWidget {
  const Way2QuranDownloadsScreen({super.key});

  @override
  State<Way2QuranDownloadsScreen> createState() => _Way2QuranDownloadsScreenState();
}

class _Way2QuranDownloadsScreenState extends State<Way2QuranDownloadsScreen> {
  List<File> _files = const [];
  bool _loading = true;
  String? _error;

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<Directory> _downloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/way2quran/audio');
  }

  Future<void> _loadFiles() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final directory = await _downloadDirectory();
      if (!await directory.exists()) {
        if (mounted) setState(() { _files = const []; _loading = false; });
        return;
      }
      final files = <File>[];
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
          files.add(entity);
        }
      }
      final stats = <String, DateTime>{};
      for (final file in files) {
        try {
          stats[file.path] = (await file.stat()).modified;
        } catch (_) {
          // A file may have been removed by the operating system during scan.
        }
      }
      files.removeWhere((file) => !stats.containsKey(file.path));
      files.sort((a, b) => stats[b.path]!.compareTo(stats[a.path]!));
      if (mounted) setState(() { _files = files; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = _ar ? 'تعذر قراءة التنزيلات على هذا الجهاز.' : 'Could not read downloads on this device.';
          _loading = false;
        });
      }
    }
  }

  String _displayName(File file) {
    final basename = file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last;
    final withoutExtension = basename.replaceFirst(RegExp(r'\.mp3$', caseSensitive: false), '');
    final match = RegExp(r'_(\d+)$').firstMatch(withoutExtension);
    final surahNumber = match?.group(1);
    final source = surahNumber == null
        ? withoutExtension
        : withoutExtension.substring(0, match!.start);
    final readable = source.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (surahNumber == null) return readable;
    return _ar ? '$readable • السورة $surahNumber' : '$readable • Surah $surahNumber';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _play(File file) async {
    try {
      await quranAudio.playExternalFile(file.path, title: _displayName(file));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_ar ? 'تعذر تشغيل الملف. جرّب تنزيله مرة أخرى.' : 'Could not play this file. Try downloading it again.'),
        ));
      }
    }
  }

  Future<void> _delete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ar ? 'حذف التنزيل؟' : 'Delete download?'),
        content: Text(_ar ? 'سيُحذف الملف من هذا الجهاز فقط.' : 'This removes the file from this device only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_ar ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // Files are sourced exclusively from the app's dedicated audio folder.
      final directory = await _downloadDirectory();
      final normalizedParent = file.parent.absolute.path;
      if (normalizedParent != directory.absolute.path) {
        throw const FileSystemException('Refusing to delete a file outside the download directory');
      }
      if (await file.exists()) await file.delete();
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_ar ? 'تم حذف التنزيل.' : 'Download deleted.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_ar ? 'تعذر حذف الملف.' : 'Could not delete the file.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_ar ? 'التنزيلات' : 'Downloads'),
        actions: [
          IconButton(
            tooltip: _ar ? 'تحديث' : 'Refresh',
            onPressed: _loadFiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_off_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loadFiles,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(_ar ? 'إعادة المحاولة' : 'Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _files.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download_for_offline_outlined, size: 64, color: theme.colorScheme.primary),
                            const SizedBox(height: 16),
                            Text(
                              _ar ? 'لا توجد تلاوات منزّلة بعد' : 'No downloaded recitations yet',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _ar
                                  ? 'نزّل أي سورة من صفحة «قراءة واستماع» وستظهر هنا للاستماع دون إنترنت.'
                                  : 'Download a surah from Read & Listen and it will appear here for offline playback.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                          child: Text(
                            _ar ? 'عدد الملفات: ${_files.length}' : '${_files.length} downloaded file(s)',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        ..._files.map((file) => FutureBuilder<FileStat>(
                              future: file.stat(),
                              builder: (context, snapshot) {
                                final size = snapshot.data?.size;
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.audio_file_rounded)),
                                    title: Text(_displayName(file), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(size == null ? (_ar ? 'صوت محفوظ على الجهاز' : 'Saved on this device') : _formatBytes(size)),
                                    onTap: () => _play(file),
                                    trailing: PopupMenuButton<String>(
                                      tooltip: _ar ? 'خيارات الملف' : 'File options',
                                      onSelected: (value) {
                                        if (value == 'play') _play(file);
                                        if (value == 'delete') _delete(file);
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(value: 'play', child: Text(_ar ? 'تشغيل' : 'Play')),
                                        PopupMenuItem(value: 'delete', child: Text(_ar ? 'حذف' : 'Delete')),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )),
                      ],
                    ),
    );
  }
}
