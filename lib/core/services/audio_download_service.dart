import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/app_sources.dart';
import '../models/quran_models.dart';
import 'app_logger.dart';

/// Downloads ayah audio to local app storage for fully offline playback
/// — no more waiting on a network fetch, even for the first play. Uses
/// the same per-ayah CDN endpoint already confirmed working for
/// streaming, so a downloaded file is guaranteed to be the same audio
/// the user has already heard play correctly, just cached locally.
///
/// Storage: app-private documents directory (no runtime storage
/// permission needed on Android, unlike writing to public storage),
/// under `quran_audio/<reciterId>/<globalAyahNumber>.mp3`.
class AudioDownloadService {
  AudioDownloadService._();

  static Future<Directory> _reciterDir(String reciterId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/quran_audio/$reciterId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _fileFor(String reciterId, int globalAyahNumber) async {
    final dir = await _reciterDir(reciterId);
    return File('${dir.path}/$globalAyahNumber.mp3');
  }

  /// Accept an MP3 frame sync or ID3 tag; reject HTML/error bodies even
  /// when a server mistakenly returns HTTP 200.
  static bool hasValidMp3Header(List<int> bytes) {
    if (bytes.length < 3) return false;
    final hasId3 = bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33;
    final hasMpegFrame = bytes.length >= 2 &&
        bytes[0] == 0xFF &&
        (bytes[1] & 0xE0) == 0xE0;
    return hasId3 || hasMpegFrame;
  }

  static Future<bool> isAyahDownloaded(String reciterId, int globalAyahNumber) async {
    return (await localPathFor(reciterId, globalAyahNumber)) != null;
  }

  static Future<String?> localPathFor(String reciterId, int globalAyahNumber) async {
    final file = await _fileFor(reciterId, globalAyahNumber);
    if (!await file.exists()) return null;
    try {
      final size = await file.length();
      if (size < 1024 || !hasValidMp3Header(await file.openRead(0, 3).fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      ))) {
        // Remove interrupted or non-audio files so a future download can repair them.
        await file.delete();
        return null;
      }
    } catch (_) {
      return null;
    }
    return file.path;
  }

  static int globalAyahOffsetFor(SurahModel surah, List<SurahModel> allSurahs) {
    return allSurahs.where((s) => s.number < surah.number).fold(0, (sum, s) => sum + s.ayahs.length);
  }

  /// Downloads every ayah of [surah] for [reciterId] that isn't already
  /// downloaded. Calls [onProgress] after each ayah (done, total).
  /// Cooperatively cancellable via [isCancelled] — checked between each
  /// ayah, not mid-download, so a cancel takes effect promptly without
  /// corrupting a partially-written file.
  static Future<void> downloadSurah({
    required String reciterId,
    required SurahModel surah,
    required List<SurahModel> allSurahs,
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final offset = globalAyahOffsetFor(surah, allSurahs);
    final total = surah.ayahs.length;

    for (var i = 0; i < total; i++) {
      if (isCancelled()) return;

      final ayahNumber = i + 1;
      final globalNumber = offset + ayahNumber;
      final file = await _fileFor(reciterId, globalNumber);

      // Existing files are trusted only after size and header validation.
      if (await localPathFor(reciterId, globalNumber) == null) {
        final partFile = File('${file.path}.part');
        try {
          if (await partFile.exists()) await partFile.delete();
          final response = await http
              .get(Uri.parse(AppSources.ayahAudioUrl(globalNumber, reciter: reciterId)))
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            final declaredLength = int.tryParse(response.headers['content-length'] ?? '');
            final lengthMatches = declaredLength == null || declaredLength == bytes.length;
            final contentType = (response.headers['content-type'] ?? '').toLowerCase();
            final looksLikeHtml = contentType.contains('text/html') ||
                contentType.contains('application/json');
            if (bytes.length >= 1024 &&
                lengthMatches &&
                !looksLikeHtml &&
                hasValidMp3Header(bytes)) {
              await partFile.writeAsBytes(bytes, flush: true);
              // Same-directory rename makes the completed download visible
              // atomically; an interrupted .part is never treated as audio.
              if (await file.exists()) await file.delete();
              await partFile.rename(file.path);
            } else {
              AppLogger.error('Rejected invalid/incomplete MP3 response for ayah $globalNumber');
              if (await partFile.exists()) await partFile.delete();
            }
          } else {
            AppLogger.error('Ayah download failed: HTTP ${response.statusCode} for ayah $globalNumber');
          }
        } catch (e, st) {
          if (await partFile.exists()) {
            try { await partFile.delete(); } catch (_) {}
          }
          AppLogger.error('Ayah download failed', error: e, stackTrace: st);
          // Continue to the next ayah rather than aborting the whole surah.
        }
      }

      onProgress(i + 1, total);
    }
  }

  static Future<int> downloadedAyahCount(String reciterId, SurahModel surah, List<SurahModel> allSurahs) async {
    final offset = globalAyahOffsetFor(surah, allSurahs);
    var count = 0;
    for (var i = 1; i <= surah.ayahs.length; i++) {
      if (await isAyahDownloaded(reciterId, offset + i)) count++;
    }
    return count;
  }

  static Future<void> deleteSurahDownload(String reciterId, SurahModel surah, List<SurahModel> allSurahs) async {
    final offset = globalAyahOffsetFor(surah, allSurahs);
    for (var i = 1; i <= surah.ayahs.length; i++) {
      final file = await _fileFor(reciterId, offset + i);
      if (await file.exists()) await file.delete();
    }
  }

  /// Total bytes used by all downloaded audio, across all reciters —
  /// for a real storage-usage display, not a guess.
  static Future<int> totalStorageUsedBytes() async {
    final base = await getApplicationDocumentsDirectory();
    final root = Directory('${base.path}/quran_audio');
    if (!await root.exists()) return 0;

    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static Future<void> deleteAllDownloads() async {
    final base = await getApplicationDocumentsDirectory();
    final root = Directory('${base.path}/quran_audio');
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
