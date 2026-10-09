import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wirdi/features/way2quran/way2quran_favorites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Way2QuranFavorites', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts empty', () async {
      expect(await Way2QuranFavorites.all(), isEmpty);
      expect(await Way2QuranFavorites.contains('reader-a'), isFalse);
    });

    test('toggle adds then removes a favorite', () async {
      expect(await Way2QuranFavorites.toggle('reader-a'), isTrue);
      expect(await Way2QuranFavorites.contains('reader-a'), isTrue);
      expect(await Way2QuranFavorites.all(), ['reader-a']);

      expect(await Way2QuranFavorites.toggle('reader-a'), isFalse);
      expect(await Way2QuranFavorites.contains('reader-a'), isFalse);
      expect(await Way2QuranFavorites.all(), isEmpty);
    });

    test('keeps other favorites when toggling one off', () async {
      await Way2QuranFavorites.toggle('reader-a');
      await Way2QuranFavorites.toggle('reader-b');
      await Way2QuranFavorites.toggle('reader-a');

      expect(await Way2QuranFavorites.all(), ['reader-b']);
    });
  });
}
