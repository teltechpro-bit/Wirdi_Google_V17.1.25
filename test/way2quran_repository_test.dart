import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/features/way2quran/way2quran_repository.dart';

void main() {
  group('Way2QuranRepository.unwrapApiData', () {
    test('unwraps the current success envelope containing a list', () {
      final result = Way2QuranRepository.unwrapApiData({
        'status': 'success',
        'data': [
          {'slug': 'sample-reciter', 'arabicName': 'قارئ تجريبي'}
        ],
      });

      expect(result, isA<List<dynamic>>());
      expect((result as List).single['slug'], 'sample-reciter');
    });

    test('unwraps the current success envelope containing an object', () {
      final result = Way2QuranRepository.unwrapApiData({
        'status': 'success',
        'data': {'recitations': [{'slug': 'hafs-an-asim'}]},
      });

      expect(result, isA<Map>());
      expect((result as Map)['recitations'], hasLength(1));
    });

    test('preserves legacy unwrapped responses', () {
      final legacy = {'reciters': [{'slug': 'legacy-reader'}]};
      expect(Way2QuranRepository.unwrapApiData(legacy), same(legacy));
    });
  });
}
