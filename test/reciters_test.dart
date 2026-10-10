import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/data/app_sources.dart';
import 'package:wirdi/core/data/reciters.dart';

void main() {
  group('legacy Quran reciters', () {
    test('contains the original reciters and verified per-ayah editions', () {
      final ids = Reciters.all.map((reciter) => reciter.id).toList();

      expect(ids, contains('ar.alafasy'));
      expect(ids, contains('ar.abdullahbasfar'));
      expect(ids, contains('ar.abdulsamad'));
      expect(ids, contains('ar.ibrahimakhbar'));
      expect(ids, contains('ar.muhammadayyoub'));
      expect(ids, contains('ar.parhizgar'));
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('new reciters use the same per-ayah CDN URL pattern', () {
      expect(
        AppSources.ayahAudioUrl(262, reciter: 'ar.muhammadayyoub'),
        endsWith('/ar.muhammadayyoub/262.mp3'),
      );
      expect(
        AppSources.ayahAudioUrl(262, reciter: 'ar.abdullahbasfar'),
        endsWith('/ar.abdullahbasfar/262.mp3'),
      );
    });
  });
}
