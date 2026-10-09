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
  });
}
