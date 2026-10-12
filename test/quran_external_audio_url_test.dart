import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/quran_audio_service.dart';

void main() {
  group('QuranAudioService.isValidExternalAudioUrl', () {
    test('accepts an absolute HTTPS audio URL', () {
      expect(
        QuranAudioService.isValidExternalAudioUrl(
          'https://cdn.example.org/audio/recitation.mp3',
        ),
        isTrue,
      );
    });

    test('rejects non-HTTPS and hostless URLs', () {
      expect(QuranAudioService.isValidExternalAudioUrl('http://cdn.example.org/a.mp3'), isFalse);
      expect(QuranAudioService.isValidExternalAudioUrl('https:///audio.mp3'), isFalse);
      expect(QuranAudioService.isValidExternalAudioUrl('/audio.mp3'), isFalse);
    });

    test('rejects whitespace in the host and embedded user information', () {
      expect(QuranAudioService.isValidExternalAudioUrl('https://bad host/audio.mp3'), isFalse);
      expect(QuranAudioService.isValidExternalAudioUrl('https://user:pass@cdn.example.org/a.mp3'), isFalse);
    });

    test('rejects an empty URL', () {
      expect(QuranAudioService.isValidExternalAudioUrl('  '), isFalse);
    });
  });
}
