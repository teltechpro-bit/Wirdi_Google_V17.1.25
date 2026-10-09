import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wirdi/features/way2quran/way2quran_playlists_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Way2QuranPlaylistStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts empty', () async {
      expect(await Way2QuranPlaylistStore.all(), isEmpty);
    });

    test('trims playlist names and rejects duplicates', () async {
      expect(await Way2QuranPlaylistStore.create('  Night Recitations  '), isTrue);
      expect(await Way2QuranPlaylistStore.create('Night Recitations'), isFalse);
      expect(await Way2QuranPlaylistStore.all(), {'Night Recitations': <String>[]});
    });

    test('removes a track without deleting the playlist', () async {
      await Way2QuranPlaylistStore.create('Favorites');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'way2quran.playlists.v1',
        '{"Favorites":["/tmp/one.mp3","/tmp/two.mp3"]}',
      );

      await Way2QuranPlaylistStore.removeTrack('Favorites', '/tmp/one.mp3');

      expect(await Way2QuranPlaylistStore.all(), {
        'Favorites': ['/tmp/two.mp3'],
      });
    });

    test('deleting a playlist does not delete audio files', () async {
      await Way2QuranPlaylistStore.create('Study');
      await Way2QuranPlaylistStore.delete('Study');

      expect(await Way2QuranPlaylistStore.all(), isEmpty);
    });

    test('recovers safely from malformed stored JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('way2quran.playlists.v1', '{not-json');

      expect(await Way2QuranPlaylistStore.all(), isEmpty);
    });
  });
}
