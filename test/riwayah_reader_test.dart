import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/models/riwayah_reader.dart';

void main() {
  const reader = RiwayahReader(
    id: 'reader-1',
    name: 'Warsh Reader',
    nameAr: 'قارئ ورش',
    riwayahId: 'warsh',
    source: 'test',
    server: '',
    surahs: <int>{1, 2, 114},
  );

  test('Arabic reader name is localized and English name is preserved', () {
    expect(reader.nameFor('ar'), 'قارئ ورش');
    expect(reader.nameFor('en'), 'Warsh Reader');
  });

  test('blank Arabic name falls back to canonical name', () {
    const fallback = RiwayahReader(
      id: 'reader-2',
      name: 'Reader Name',
      nameAr: '  ',
      riwayahId: 'hafs',
      source: 'test',
      server: '',
      surahs: <int>{1},
    );
    expect(fallback.nameFor('ar'), 'Reader Name');
  });

  test('reader reports only supported surahs', () {
    expect(reader.supportsSurah(1), isTrue);
    expect(reader.supportsSurah(114), isTrue);
    expect(reader.supportsSurah(3), isFalse);
  });
}
