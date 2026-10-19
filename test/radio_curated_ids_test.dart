import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/data/radio_stations.dart';

void main() {
  test('curated radio candidates reuse the static catalogue ids for the same URL', () {
    final source = File('lib/core/services/radio_service.dart').readAsStringSync();
    final marker = source.indexOf('_curatedStreamCandidates');
    expect(marker, greaterThanOrEqualTo(0));
    final match = RegExp(r"RadioStation\(id: '([^']+)'[^\n]*?streamUrl: '([^']+)'")
        .allMatches(source.substring(marker));
    final staticIdByUrl = {
      for (final s in kRequestedQuranRadioStations) s.streamUrl: s.id,
    };
    var compared = 0;
    for (final m in match) {
      final expected = staticIdByUrl[m.group(2)];
      if (expected == null) continue;
      compared++;
      expect(m.group(1), expected,
          reason: 'Favourites are keyed by id; ${m.group(2)} must keep one id.');
    }
    expect(compared, greaterThanOrEqualTo(12));
  });
}
