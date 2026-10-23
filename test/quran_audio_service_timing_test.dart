import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/quran_audio_service.dart';

void main() {
  const timings = <int, ({int startMs, int endMs})>{
    1: (startMs: 0, endMs: 1000),
    2: (startMs: 1000, endMs: 2200),
    3: (startMs: 2200, endMs: 3500),
  };

  group('QuranAudioService.ayahForPositionFromTimings', () {
    test('uses inclusive start boundary for each ayah', () {
      expect(
        QuranAudioService.ayahForPositionFromTimings(
          timings,
          const Duration(milliseconds: 1000),
        ),
        2,
      );
    });

    test('uses exclusive end boundary for the preceding ayah', () {
      expect(
        QuranAudioService.ayahForPositionFromTimings(
          timings,
          const Duration(milliseconds: 999),
        ),
        1,
      );
      expect(
        QuranAudioService.ayahForPositionFromTimings(
          timings,
          const Duration(milliseconds: 2200),
        ),
        3,
      );
    });

    test('keeps the last ayah after the final timing ends', () {
      expect(
        QuranAudioService.ayahForPositionFromTimings(
          timings,
          const Duration(milliseconds: 9000),
        ),
        3,
      );
    });

    test('returns the first ayah for a position before the first timing', () {
      expect(
        QuranAudioService.ayahForPositionFromTimings(
          timings,
          const Duration(milliseconds: 0),
        ),
        1,
      );
    });

    test('empty timings return the conservative first-ayah fallback', () {
      expect(
        QuranAudioService.ayahForPositionFromTimings(
          const <int, ({int startMs, int endMs})>{},
          const Duration(milliseconds: 400),
        ),
        1,
      );
    });
  });
}
