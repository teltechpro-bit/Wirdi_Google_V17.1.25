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

    test('throws a useful error for explicit API error envelopes', () {
      expect(
        () => Way2QuranRepository.unwrapApiData({
          'status': 'error',
          'message': 'Reciter not found',
          'data': null,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Reciter not found'),
          ),
        ),
      );
    });

    test('handles failed status spelling variants', () {
      for (final status in ['failed', 'failure']) {
        expect(
          () => Way2QuranRepository.unwrapApiData({
            'status': status,
            'message': 'Request rejected',
          }),
          throwsFormatException,
        );
      }
    });

    test('normalizes API status casing and whitespace', () {
      expect(
        () => Way2QuranRepository.unwrapApiData({
          'status': '  ERROR ',
          'message': 'Temporary outage',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Temporary outage'),
          ),
        ),
      );
    });

    test('uses the API error field when message is absent', () {
      expect(
        () => Way2QuranRepository.unwrapApiData({
          'status': 'error',
          'error': 'Invalid recitation',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Invalid recitation'),
          ),
        ),
      );
    });

    test('preserves legacy unwrapped responses', () {
      final legacy = {'reciters': [{'slug': 'legacy-reader'}]};
      expect(Way2QuranRepository.unwrapApiData(legacy), same(legacy));
    });
  });
}
