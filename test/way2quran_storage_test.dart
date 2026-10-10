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
}
