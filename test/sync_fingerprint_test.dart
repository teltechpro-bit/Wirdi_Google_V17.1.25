import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/sync_service.dart';

void main() {
  group('SyncService fingerprints', () {
    test('fingerprints are stable when map key order changes', () {
      expect(
        SyncService.fingerprintForTesting({'b': 2, 'a': 1}),
        SyncService.fingerprintForTesting({'a': 1, 'b': 2}),
      );
    });

    test('fingerprints change when section values change', () {
      expect(
        SyncService.fingerprintForTesting({'lastAyahNumber': 2}),
        isNot(SyncService.fingerprintForTesting({'lastAyahNumber': 3})),
      );
    });

    test('nested map keys are canonicalized', () {
      expect(
        SyncService.fingerprintForTesting({'progress': {'b': 2, 'a': 1}}),
        SyncService.fingerprintForTesting({'progress': {'a': 1, 'b': 2}}),
      );
    });
  });

  group('SyncService automatic sync cooldown', () {
    test('skips another automatic sync inside ten minutes', () {
      expect(
        SyncService.shouldSkipAutomaticSync(
          nowMs: 700000,
          lastAttemptMs: 100000,
        ),
        isTrue,
      );
    });

    test('allows automatic sync after ten minutes', () {
      expect(
        SyncService.shouldSkipAutomaticSync(
          nowMs: 700001,
          lastAttemptMs: 100000,
        ),
        isFalse,
      );
    });

    test('allows the first automatic sync', () {
      expect(
        SyncService.shouldSkipAutomaticSync(nowMs: 100000, lastAttemptMs: null),
        isFalse,
      );
    });
  });
}
