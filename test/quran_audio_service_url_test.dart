import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/quran_audio_service.dart';

void main() {
  group('QuranAudioService.isValidExternalAudioUrl', () {
    test('rejects empty URLs', () {
      expect(QuranAudioService.isValidExternalAudioUrl(''), isFalse);
      expect(QuranAudioService.isValidExternalAudioUrl('   '), isFalse);
    });

    test('rejects HTTP URLs and malformed HTTPS URLs', () {
      expect(
        QuranAudioService.isValidExternalAudioUrl('http://example.com/audio.mp3'),
        isFalse,
      );
      expect(QuranAudioService.isValidExternalAudioUrl('https:///audio.mp3'), isFalse);
      expect(QuranAudioService.isValidExternalAudioUrl('https://'), isFalse);
    });

    test('accepts an absolute HTTPS URL with a host', () {
      expect(
        QuranAudioService.isValidExternalAudioUrl('https://example.com/audio.mp3'),
        isTrue,
      );
    });

    test('rejects URLs containing user information', () {
      expect(
        QuranAudioService.isValidExternalAudioUrl('https://user:pass@example.com/audio.mp3'),
        isFalse,
      );
    });

    test('rejects whitespace in the host', () {
      expect(
        QuranAudioService.isValidExternalAudioUrl('https://bad host.example/audio.mp3'),
        isFalse,
      );
    });
  });
}
