import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/models/radio_station.dart';

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

  group('curated Quran radio stream endpoints', () {
    test('Bahrain Quran direct HLS URL is HTTPS and playlist-based', () {
      const url = 'https://5c7b683162943.streamlock.net/live/ngrp:bahrainquran_all/playlist.m3u8';
      expect(RadioStation.isSecureUrl(url), isTrue);
      expect(Uri.parse(url).path, endsWith('/playlist.m3u8'));
    });
  });
}
