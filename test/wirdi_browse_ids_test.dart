import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/wirdi_browse_ids.dart';

void main() {
  group('WirdiBrowseIds', () {
    test('round-trips surah ids', () {
      expect(WirdiBrowseIds.parseSurah(WirdiBrowseIds.surah(1)), 1);
      expect(WirdiBrowseIds.parseSurah(WirdiBrowseIds.surah(114)), 114);
    });
    test('rejects out-of-range and malformed surah ids', () {
      expect(WirdiBrowseIds.parseSurah('wirdi:surah:0'), isNull);
      expect(WirdiBrowseIds.parseSurah('wirdi:surah:115'), isNull);
      expect(WirdiBrowseIds.parseSurah('wirdi:surah:abc'), isNull);
      expect(WirdiBrowseIds.parseSurah('wirdi:radio:2'), isNull);
    });
    test('round-trips station ids and rejects empty ones', () {
      expect(WirdiBrowseIds.parseStation(WirdiBrowseIds.station('w2q_main')), 'w2q_main');
      expect(WirdiBrowseIds.parseStation('wirdi:radio:'), isNull);
      expect(WirdiBrowseIds.parseStation('wirdi:surah:2'), isNull);
    });
    test('folder ids are neither surahs nor stations', () {
      expect(WirdiBrowseIds.parseSurah(WirdiBrowseIds.surahs), isNull);
      expect(WirdiBrowseIds.parseStation(WirdiBrowseIds.radio), isNull);
    });
  });
}
