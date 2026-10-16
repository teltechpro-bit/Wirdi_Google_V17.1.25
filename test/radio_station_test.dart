import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/models/radio_station.dart';
import 'package:wirdi/core/data/radio_stations.dart';

void main() {
  group('RadioStation.isSecureUrl', () {
    test('accepts https streams', () {
      expect(RadioStation.isSecureUrl('https://example.com/stream'), isTrue);
      expect(RadioStation.isSecureUrl('  HTTPS://example.com/stream '), isTrue);
    });

    test('rejects cleartext and empty urls (cleartext traffic is disabled app-wide)', () {
      expect(RadioStation.isSecureUrl('http://example.com/stream'), isFalse);
      expect(RadioStation.isSecureUrl(''), isFalse);
      expect(RadioStation.isSecureUrl('example.com/stream'), isFalse);
    });
  });

  group('Requested Quran radio catalogue', () {
    test('contains only the nine endpoints that passed live stream probes', () {
      expect(kRequestedQuranRadioStations, hasLength(9));
      expect(
        kRequestedQuranRadioStations.map((station) => station.id).toSet(),
        hasLength(9),
      );
      expect(
        kRequestedQuranRadioStations.every((station) => RadioStation.isSecureUrl(station.streamUrl)),
        isTrue,
      );
      expect(
        kRequestedQuranRadioStations.map((station) => station.id),
        containsAll([
          'w2q_radio_egypt',
          'w2q_radio_saudi',
          'w2q_radio_kuwait',
          'w2q_radio_pakistan',
          'w2q_radio_palestine',
          'w2q_radio_sharjah',
          'external_radio_bahrain',
          'external_radio_jordan',
          'external_radio_oman',
        ]),
      );
    });

    test('does not enable endpoints that returned non-audio HTTP 502 responses', () {
      final ids = kRequestedQuranRadioStations.map((station) => station.id).toSet();
      expect(ids, isNot(contains('w2q_radio_main')));
      expect(ids, isNot(contains('w2q_radio_beautiful')));
      expect(ids, isNot(contains('w2q_radio_short')));
      expect(ids, isNot(contains('w2q_radio_serenity')));
      expect(ids, isNot(contains('w2q_radio_tafsir_tabari')));
      expect(ids, isNot(contains('w2q_radio_mp3quran')));
    });
  });
}
