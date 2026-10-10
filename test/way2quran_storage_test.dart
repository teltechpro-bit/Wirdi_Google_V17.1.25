import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/features/way2quran/way2quran_storage.dart';

void main() {
  group('Way2QuranStorage', () {
    test('uses one shared directory for all downloaded recitations', () {
      expect(
        Way2QuranStorage.recitationsRelativePath,
        'way2quran/recitations',
      );
    });

    test('builds the same file path used by download and offline playback', () {
      expect(
        Way2QuranStorage.recitationFilePath('/app/documents', 'reader-surah-001'),
        '/app/documents/way2quran/recitations/reader-surah-001.mp3',
      );
    });

    test('keeps API-derived filename inside the recitations folder', () {
      expect(
        Way2QuranStorage.recitationFilePath('/app/documents', '../../outside/evil'),
        '/app/documents/way2quran/recitations/______outside_evil.mp3',
      );
    });

    test('uses a safe fallback for an empty filename stem', () {
      expect(
        Way2QuranStorage.recitationFilePath('/app/documents', '   '),
        '/app/documents/way2quran/recitations/recitation.mp3',
      );
    });
  });

    test('writes downloads via a completed temporary file', () async {
      final directory = await Directory.systemTemp.createTemp('wirdi-download-test');
      addTearDown(() => directory.delete(recursive: true));
      final target = File('${directory.path}/audio.mp3');
      await Way2QuranStorage.writeBytesAtomically(target, [1, 2, 3, 4]);
      expect(await target.readAsBytes(), [1, 2, 3, 4]);
      expect(
        directory.listSync().where((entity) => entity.path.endsWith('.part')),
        isEmpty,
      );
    });

    test('refuses to persist empty download data', () async {
      final directory = await Directory.systemTemp.createTemp('wirdi-empty-download-test');
      addTearDown(() => directory.delete(recursive: true));
      await expectLater(
        Way2QuranStorage.writeBytesAtomically(File('${directory.path}/empty.mp3'), const []),
        throwsFormatException,
      );
    });
}
