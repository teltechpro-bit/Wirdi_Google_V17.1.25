import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wirdi/features/way2quran/way2quran_view_counter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Wirdi-local reciter views start at zero and persist per slug', () async {
    expect(await Way2QuranViewCounter.count('reader-a'), 0);
    expect(await Way2QuranViewCounter.recordOpen('reader-a'), 1);
    expect(await Way2QuranViewCounter.recordOpen('reader-a'), 2);
    expect(await Way2QuranViewCounter.recordOpen('reader-b'), 1);
    expect(await Way2QuranViewCounter.count('reader-a'), 2);
    expect(await Way2QuranViewCounter.count('reader-b'), 1);
  });

  test('empty slugs do not create a counter', () async {
    expect(await Way2QuranViewCounter.recordOpen('  '), 0);
    expect(await Way2QuranViewCounter.all(), isEmpty);
  });
}
