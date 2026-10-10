import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/data/app_sources.dart';
import 'package:wirdi/core/data/reciters.dart';

void main() {
  group('legacy Quran reciters', () {
    test('contains the original reciters and additional verified editions', () {
      final ids = Reciters.all.map((reciter) => reciter.id).toList();

      expect(ids, contains('ar.alafasy'));
      expect(ids, contains('ar.abdullahbasfar'));
      expect(ids, contains('ar.ahmadalnufais'));
      expect(ids, contains('ar.bandarbalila'));
      expect(ids, contains('ar.faresabbad'));
      expect(ids, contains('ar.ibrahimalakhdar'));
      expect(ids, contains('ar.khalifaaltunaiji'));
      expect(ids, contains('ar.muhammadayyub'));
      expect(ids, contains('ar.nabilarrifai'));
      expect(ids, contains('ar.salahalbudair'));
      expect(ids, contains('ar.omaralkazabri'));
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('new reciters use the same per-ayah CDN URL pattern', () {
      expect(
        AppSources.ayahAudioUrl(262, reciter: 'ar.muhammadayyub'),
        endsWith('/ar.muhammadayyub/262.mp3'),
      );
      expect(
        AppSources.ayahAudioUrl(262, reciter: 'ar.abdullahbasfar'),
        endsWith('/ar.abdullahbasfar/262.mp3'),
      );
    });
  });
}
