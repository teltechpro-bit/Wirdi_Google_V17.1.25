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

  group('External Quran radio candidates', () {
    test('all requested candidates use HTTPS and stable stream endpoints', () {
      expect(kExternalRadioCandidates, hasLength(16));
      for (final station in kExternalRadioCandidates) {
        expect(RadioStation.isSecureUrl(station.streamUrl), isTrue,
            reason: station.id);
        expect(station.streamUrl.toLowerCase(), isNot(contains('.ts')),
            reason: 'Do not add transient TS segments: ${station.id}');
        expect(station.streamUrl.toLowerCase(), isNot(contains('.aac')),
            reason: 'Do not add transient AAC segments: ${station.id}');
      }
    });
  });
