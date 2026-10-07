import 'package:flutter_test/flutter_test.dart';

import 'package:wirdi/core/data/qiraat_catalog.dart';

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
}
