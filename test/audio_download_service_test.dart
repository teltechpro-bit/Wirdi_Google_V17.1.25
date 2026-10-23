import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/audio_download_service.dart';

void main() {
  group('AudioDownloadService.hasValidMp3Header', () {
    test('accepts an ID3 tag', () {
      expect(
        AudioDownloadService.hasValidMp3Header(<int>[0x49, 0x44, 0x33, 0x04]),
        isTrue,
      );
    });

    test('accepts an MPEG audio frame sync', () {
      expect(
        AudioDownloadService.hasValidMp3Header(<int>[0xFF, 0xFB, 0x90, 0x64]),
        isTrue,
      );
    });

    test('rejects HTML or arbitrary payloads', () {
      expect(
        AudioDownloadService.hasValidMp3Header('<html>'.codeUnits),
        isFalse,
      );
      expect(
        AudioDownloadService.hasValidMp3Header(<int>[0x00, 0x01, 0x02]),
        isFalse,
      );
    });

    test('rejects buffers too short to contain an MP3 header', () {
      expect(
        AudioDownloadService.hasValidMp3Header(<int>[0x49, 0x44]),
        isFalse,
      );
    });
  });
}
