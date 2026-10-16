import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wirdi/features/way2quran/way2quran_view_counter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('local reciter views start at zero without importing API counts', () async {
    expect(await Way2QuranViewCounter.get('reciter-a'), 0);
  });

  test('increments only the selected reciter on this device', () async {
    expect(await Way2QuranViewCounter.increment('reciter-a'), 1);
    expect(await Way2QuranViewCounter.increment('reciter-a'), 2);
    expect(await Way2QuranViewCounter.get('reciter-a'), 2);
    expect(await Way2QuranViewCounter.get('reciter-b'), 0);
  });

  test('blank slugs do not create counters', () async {
    expect(await Way2QuranViewCounter.increment('  '), 0);
    expect(await Way2QuranViewCounter.get('  '), 0);
  });
}
