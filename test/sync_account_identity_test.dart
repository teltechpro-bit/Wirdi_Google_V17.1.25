import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/sync_service.dart';

void main() {
  group('SyncService.requiresAccountResolution', () {
    test('allows the account that owns the local sync data', () {
      expect(
        SyncService.requiresAccountResolution(
          currentUid: 'account-a',
          storedOwnerUid: 'account-a',
          localLastSyncedMs: 100,
        ),
        isFalse,
      );
    });

    test('blocks a different account before reconciliation', () {
      expect(
        SyncService.requiresAccountResolution(
          currentUid: 'account-b',
          storedOwnerUid: 'account-a',
          localLastSyncedMs: 100,
        ),
        isTrue,
      );
    });

    test('treats a legacy timestamp without an owner as ambiguous', () {
      expect(
        SyncService.requiresAccountResolution(
          currentUid: 'account-b',
          storedOwnerUid: null,
          localLastSyncedMs: 100,
        ),
        isTrue,
      );
    });

    test('treats the sign-out legacy-owner sentinel as ambiguous', () {
      expect(
        SyncService.requiresAccountResolution(
          currentUid: 'account-b',
          storedOwnerUid: '__legacy_unknown_owner__',
          localLastSyncedMs: null,
        ),
        isTrue,
      );
    });

    test('allows first sync on a device with no prior sync marker', () {
      expect(
        SyncService.requiresAccountResolution(
          currentUid: 'account-a',
          storedOwnerUid: null,
          localLastSyncedMs: null,
        ),
        isFalse,
      );
    });
  });
}
