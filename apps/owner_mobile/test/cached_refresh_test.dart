import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/testing.dart';
import 'package:owner_mobile/data/cached.dart';
import 'package:owner_mobile/data/snapshot_store.dart';

/// The overview must follow the server: a request that arrives after the app
/// opened has to reach the screen when realtime or pull-to-refresh invalidates
/// the snapshot, whether the app started cold or from the saved copy.
void main() {
  OwnerSnapshot snapshotOf(int count) => OwnerSnapshot(
        open: Sample.requests.take(count).toList(),
        completedThisWeek: const [],
        arrivedThisWeek: const [],
      );

  for (final saved in [false, true]) {
    test('a new request reaches the overview (saved copy: $saved)', () async {
      var onServer = 2;
      final store = _Store(saved ? snapshotOf(1).toJson() : null);
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(Sample.owner.id),
        snapshotStoreProvider.overrideWithValue(store),
        ownerSnapshotProvider.overrideWith((ref) async => snapshotOf(onServer)),
      ]);
      addTearDown(container.dispose);
      // The screen keeps it alive, as HomeScreen does.
      container.listen(overviewProvider, (_, __) {});

      final first = await container.read(overviewProvider.future);
      expect(first.value.open.length, saved ? 1 : 2);
      await pumpEventQueue();
      expect(container.read(overviewProvider).requireValue.value.open.length, 2);
      expect(container.read(overviewProvider).requireValue.fromDisk, isFalse);

      // What realtime does when a website order lands.
      onServer = 3;
      container.invalidate(ownerSnapshotProvider);
      await pumpEventQueue();
      expect(container.read(overviewProvider).requireValue.value.open.length, 3);

      // And pull-to-refresh.
      onServer = 4;
      container.invalidate(ownerSnapshotProvider);
      final pulled = await container.read(overviewProvider.future);
      expect(pulled.value.open.length, 4);
    });
  }
}

class _Store extends SnapshotStore {
  _Store(this._saved) : super(const FlutterSecureStorage());

  final Map<String, dynamic>? _saved;

  @override
  Future<SavedSnapshot?> read(String userId, String name) async =>
      _saved == null || name != 'overview'
          ? null
          : SavedSnapshot(
              savedAt: DateTime.now().subtract(const Duration(hours: 3)),
              data: _saved,
            );

  @override
  Future<void> write(
    String userId,
    String name,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> clear() async {}
}
