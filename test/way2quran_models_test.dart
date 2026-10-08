import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/features/way2quran/way2quran_models.dart';

void main() {
  group('Way2Quran API models', () {
    test('reciter parses nested recitation and per-surah audio files', () {
      final reciter = Way2QuranReciter.fromJson({
        'slug': 'sample-reciter',
        'arabicName': 'قارئ تجريبي',
        'englishName': 'Sample Reciter',
        'totalViewers': '1234',
        'recitations': [
          {
            'recitationInfo': {
              'slug': 'hafs',
              'arabicName': 'حفص عن عاصم',
              'englishName': 'Hafs an Asim',
            },
            'audioFiles': [
              {
                'url': 'https://audio.example/001.mp3',
                'downloadURL': 'https://audio.example/001-download.mp3',
                'surahInfo': {'number': 1, 'arabicName': 'الفاتحة'},
              },
            ],
          },
        ],
      });

      expect(reciter.slug, 'sample-reciter');
      expect(reciter.name(true), 'قارئ تجريبي');
      expect(reciter.name(false), 'Sample Reciter');
      expect(reciter.totalViews, 1234);
      expect(reciter.recitations, hasLength(1));
      expect(reciter.recitations.single.slug, 'hafs');
      expect(reciter.recitations.single.audioFiles.single.surahNumber, 1);
      expect(reciter.recitations.single.audioFiles.single.url, 'https://audio.example/001.mp3');
      expect(reciter.recitations.single.audioFiles.single.downloadUrl, 'https://audio.example/001-download.mp3');
    });

    test('surah search result accepts numeric strings and preserves page number', () {
      final surah = Way2QuranSearchSurah.fromJson({
        'slug': 'al-fatihah',
        'arabicName': 'الفاتحة',
        'englishName': 'Al-Fatihah',
        'number': '1',
        'pageNumber': '1',
      });

      expect(surah.number, 1);
      expect(surah.pageNumber, 1);
      expect(surah.englishName, 'Al-Fatihah');
    });

    test('Mushaf model accepts either API casing for download and image URLs', () {
      final mushaf = Way2QuranMushaf.fromJson({
        'slug': 'sample-mushaf',
        'arabicName': 'مصحف تجريبي',
        'englishName': 'Sample Mushaf',
        'downloadUrl': 'https://files.example/mushaf.pdf',
        'imageUrl': 'https://files.example/cover.jpg',
        'totalDownloads': '42',
      });

      expect(mushaf.downloadUrl, 'https://files.example/mushaf.pdf');
      expect(mushaf.imageUrl, 'https://files.example/cover.jpg');
      expect(mushaf.totalDownloads, 42);
      expect(mushaf.name(true), 'مصحف تجريبي');
    });

    test('reciter pagination only reports a next page when one exists', () {
      const first = Way2QuranRecitersPage(
        reciters: [],
        totalCount: 100,
        page: 1,
        pages: 2,
      );
      const last = Way2QuranRecitersPage(
        reciters: [],
        totalCount: 100,
        page: 2,
        pages: 2,
      );

      expect(first.hasNext, isTrue);
      expect(last.hasNext, isFalse);
    });
  });
}
