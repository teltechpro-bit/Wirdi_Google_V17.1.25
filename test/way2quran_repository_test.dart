import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
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

  group('Way2QuranRepository HTTP behavior', () {
    test('parses enveloped reciters and sends filters and pagination', () async {
      final repository = Way2QuranRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/api/reciters');
          expect(request.url.queryParameters['recitationSlug'], 'warsh');
          expect(request.url.queryParameters['isTopReciter'], 'true');
          expect(request.url.queryParameters['currentPage'], '2');
          expect(request.url.queryParameters['pageSize'], '10');
          expect(request.url.queryParameters['sort'], '-totalViewers');
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'status': 'success',
              'data': {'reciters': [
                {'slug': 'reader-one', 'arabicName': 'قارئ', 'englishName': 'Reader'}
              ]},
              'pagination': {'totalCount': 21, 'page': 2, 'pages': 3},
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final page = await repository.getRecitersPage(
        recitationSlug: 'warsh',
        isTopReciter: 'true',
        page: 2,
        pageSize: 10,
        sort: 'views',
      );
      expect(page.reciters.single.slug, 'reader-one');
      expect(page.totalCount, 21);
      expect(page.page, 2);
      expect(page.pages, 3);
      expect(page.hasNext, isTrue);
    });

    test('global search parses reciters, recitations, and surahs from envelope', () async {
      final repository = Way2QuranRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/api/search');
          expect(request.url.queryParameters['q'], '  fatihah  '.trim());
          return http.Response(jsonEncode({
            'status': 'success',
            'data': {
              'reciters': [{'slug': 'reader', 'englishName': 'Reader'}],
              'recitations': [{'slug': 'warsh', 'englishName': 'Warsh'}],
              'surahs': [{'slug': 'al-fatihah', 'number': 1, 'englishName': 'Al-Fatihah'}],
            },
          }), 200);
        }),
      );

      final results = await repository.globalSearch('  fatihah  ');
      expect(results.reciters.single.slug, 'reader');
      expect(results.recitations.single.slug, 'warsh');
      expect(results.surahs.single.number, 1);
    });

    test('reciter search falls back to local filtering when API ignores search', () async {
      final repository = Way2QuranRepository(
        client: MockClient((request) async {
          if (request.url.queryParameters['search']?.isNotEmpty == true) {
            return http.Response(jsonEncode({
              'status': 'success',
              'data': {'reciters': <dynamic>[]},
              'pagination': {'totalCount': 0, 'page': 1, 'pages': 1},
            }), 200);
          }
          return http.Response(jsonEncode({
            'status': 'success',
            'data': {'reciters': [
              {'slug': 'sample-reader', 'englishName': 'Sample Reader'},
              {'slug': 'other-reader', 'englishName': 'Other Reader'},
            ]},
            'pagination': {'totalCount': 2, 'page': 1, 'pages': 1},
          }), 200);
        }),
      );

      final page = await repository.getRecitersPage(search: 'sample', pageSize: 20);
      expect(page.reciters, hasLength(1));
      expect(page.reciters.single.slug, 'sample-reader');
    });

    test('empty global search avoids making a network request', () async {
      var requested = false;
      final repository = Way2QuranRepository(
        client: MockClient((_) async {
          requested = true;
          return http.Response('{}', 200);
        }),
      );
      final result = await repository.globalSearch('   ');
      expect(result.reciters, isEmpty);
      expect(result.recitations, isEmpty);
      expect(result.surahs, isEmpty);
      expect(requested, isFalse);
    });

    test('encodes reciter slugs and returns a useful HTTP error', () async {
      final repository = Way2QuranRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/api/reciters/reciter-profile/reader%20one');
          expect(request.url.queryParameters['increaseViews'], 'false');
          return http.Response('Not found', 404);
        }),
      );
      await expectLater(
        repository.getReciter('reader one', increaseViews: false),
        throwsA(isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('404'),
        )),
      );
    });

    test('rejects malformed audio URLs before issuing a request', () async {
      var requested = false;
      final repository = Way2QuranRepository(
        client: MockClient((_) async {
          requested = true;
          return http.Response('audio', 200);
        }),
      );
      await expectLater(repository.downloadBytes('javascript:alert(1)'), throwsFormatException);
      expect(requested, isFalse);
    });

    test('returns downloaded bytes and reports non-success responses', () async {
      final success = Way2QuranRepository(
        client: MockClient((request) async {
          expect(request.url.host, 'audio.example');
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      expect(await success.downloadBytes('https://audio.example/test.mp3'), [1, 2, 3]);

      final failure = Way2QuranRepository(
        client: MockClient((_) async => http.Response('missing', 404)),
      );
      await expectLater(
        failure.downloadBytes('https://audio.example/missing.mp3'),
        throwsA(isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('404'),
        )),
      );
    });
  });


  group('Way2QuranRepository downloads', () {
    test('recognizes a real PDF signature and rejects non-PDF content', () {
      expect(
        Way2QuranRepository.isPdfPayload('%PDF-1.7 sample'.codeUnits),
        isTrue,
      );
      expect(
        Way2QuranRepository.isPdfPayload('<html>error</html>'.codeUnits),
        isFalse,
      );
      expect(Way2QuranRepository.isPdfPayload(const <int>[]), isFalse);
    });

    test('rejects empty download bodies', () async {
      final repository = Way2QuranRepository(
        client: MockClient((request) async => http.Response.bytes([], 200)),
      );
      await expectLater(
        repository.downloadBytes('https://example.com/audio.mp3'),
        throwsFormatException,
      );
    });
  });
}