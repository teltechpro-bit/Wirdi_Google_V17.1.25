import 'package:flutter_test/flutter_test.dart';

import 'package:wirdi/core/data/qiraat_catalog.dart';
import 'package:wirdi/core/models/riwayah_reader.dart';

void main() {
  test('Qiraat catalog contains exactly ten readings and twenty riwayat', () {
    expect(QiraatCatalog.all.length, 10);
    expect(QiraatCatalog.allRiwayat.length, 20);
    expect(
      QiraatCatalog.allRiwayat.map((r) => r.id).toSet().length,
      20,
    );
  });

  test('every riwayah points to a known canonical reading', () {
    final readingIds = QiraatCatalog.all.map((q) => q.id).toSet();
    expect(
      QiraatCatalog.allRiwayat.every(
        (r) => readingIds.contains(r.qiraatId),
      ),
      isTrue,
    );
  });

  test('only intentionally verified ayah sources are marked as ayah audio', () {
    final verifiedAyahIds = QiraatCatalog.allRiwayat
        .where((r) => r.hasVerifiedAyahAudio)
        .map((r) => r.id)
        .toSet();

    expect(verifiedAyahIds, containsAll(<String>['hafs', 'warsh']));
    expect(verifiedAyahIds.length, 2);
  });

  test('reader names fall back safely when Arabic localization is missing', () {
    const reader = RiwayahReader(
      id: 'reader-1',
      name: 'Warsh Reader',
      riwayahId: 'warsh',
      source: 'test',
      server: '',
      surahs: <int>{1, 2, 114},
    );

    expect(reader.nameFor('ar'), 'Warsh Reader');
    expect(reader.nameFor('en'), 'Warsh Reader');
    expect(reader.supportsSurah(114), isTrue);
    expect(reader.supportsSurah(3), isFalse);
  });

  test('reader uses Arabic display name only when it is non-empty', () {
    const localized = RiwayahReader(
      id: 'reader-2',
      name: 'Warsh Reader',
      nameAr: 'قارئ ورش',
      riwayahId: 'warsh',
      source: 'test',
      server: '',
      surahs: <int>{1},
    );
    const blankLocalized = RiwayahReader(
      id: 'reader-3',
      name: 'Warsh Reader',
      nameAr: '  ',
      riwayahId: 'warsh',
      source: 'test',
      server: '',
      surahs: <int>{1},
    );

    expect(localized.nameFor('ar'), 'قارئ ورش');
    expect(blankLocalized.nameFor('ar'), 'Warsh Reader');
  });
}
