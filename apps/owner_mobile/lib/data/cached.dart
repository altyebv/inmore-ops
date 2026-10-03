import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import 'snapshot_store.dart';

/// A value and how fresh it is.
class Cached<T> {
  const Cached(
    this.value,
    this.updatedAt, {
    this.fromDisk = false,
    this.refreshError,
  });

  final T value;
  final DateTime updatedAt;

  /// Read from the phone, not yet confirmed by the server.
  final bool fromDisk;

  /// The last refresh failed; [value] is what we had before.
  final Object? refreshError;

  bool get isStale => fromDisk || refreshError != null;

  Cached<T> withError(Object e) =>
      Cached(value, updatedAt, fromDisk: fromDisk, refreshError: e);
}

/// Saved-first, then live.
///
/// On a cold start the saved copy is shown at once while the network fetch
/// runs; when it lands it replaces the copy and is saved in turn. If the fetch
/// fails, the saved copy stays on screen marked with its age rather than
/// being replaced by an error page. After that the notifier simply follows
/// [source] — which realtime and pull-to-refresh invalidate as usual.
abstract class CachedNotifier<T> extends AsyncNotifier<Cached<T>> {
  /// The name it is saved under.
  String get name;

  /// The live value — a provider's `.future`.
  ProviderListenable<Future<T>> get source;

  Map<String, dynamic> encode(T value);
  T decode(Map<String, dynamic> json);

  int _generation = 0;

  @override
  Future<Cached<T>> build() async {
    final generation = ++_generation;
    final userId = ref.watch(currentUserIdProvider);
    final store = ref.watch(snapshotStoreProvider);
    // Watched before any await so the dependency is registered.
    final fresh = ref.watch(source);
    final previous = state.valueOrNull;

    Future<Cached<T>> live() async {
      final value = await fresh;
      if (userId != null) unawaited(store.write(userId, name, encode(value)));
      return Cached(value, DateTime.now());
    }

    if (previous == null && userId != null) {
      final saved = await store.read(userId, name);
      Cached<T>? disk;
      if (saved != null) {
        try {
          disk = Cached(decode(saved.data), saved.savedAt, fromDisk: true);
        } catch (_) {
          disk = null; // saved by an older version of the app
        }
      }
      if (disk != null) {
        final shown = disk;
        live().then(
          (c) {
            if (generation == _generation) state = AsyncData(c);
          },
          onError: (Object e, StackTrace _) {
            if (generation == _generation) {
              state = AsyncData(shown.withError(e));
            }
          },
        );
        return shown;
      }
    }

    try {
      return await live();
    } catch (e) {
      if (previous != null) return previous.withError(e);
      rethrow;
    }
  }
}

class _OverviewNotifier extends CachedNotifier<OwnerSnapshot> {
  @override
  String get name => 'overview';
  @override
  ProviderListenable<Future<OwnerSnapshot>> get source =>
      ownerSnapshotProvider.future;
  @override
  Map<String, dynamic> encode(OwnerSnapshot value) => value.toJson();
  @override
  OwnerSnapshot decode(Map<String, dynamic> json) =>
      OwnerSnapshot.fromJson(json);
}

class _MoneyNotifier extends CachedNotifier<MoneySnapshot> {
  @override
  String get name => 'money';
  @override
  ProviderListenable<Future<MoneySnapshot>> get source =>
      moneySnapshotProvider.future;
  @override
  Map<String, dynamic> encode(MoneySnapshot value) => value.toJson();
  @override
  MoneySnapshot decode(Map<String, dynamic> json) =>
      MoneySnapshot.fromJson(json);
}

class _PeopleNotifier extends CachedNotifier<List<Workload>> {
  @override
  String get name => 'people';
  @override
  ProviderListenable<Future<List<Workload>>> get source =>
      workloadProvider.future;
  @override
  Map<String, dynamic> encode(List<Workload> value) => {
        'people': [for (final w in value) w.toJson()]
      };
  @override
  List<Workload> decode(Map<String, dynamic> json) => [
        for (final w in json['people'] as List)
          Workload.fromJson(Map<String, dynamic>.from(w as Map)),
      ];
}

final overviewProvider =
    AsyncNotifierProvider<_OverviewNotifier, Cached<OwnerSnapshot>>(
        _OverviewNotifier.new);

final moneyProvider =
    AsyncNotifierProvider<_MoneyNotifier, Cached<MoneySnapshot>>(
        _MoneyNotifier.new);

final peopleProvider =
    AsyncNotifierProvider<_PeopleNotifier, Cached<List<Workload>>>(
        _PeopleNotifier.new);

/// Pull-to-refresh: refetch from the server, and resolve when it is done so
/// the spinner stays up exactly as long as the fetch.
Future<void> refreshOwner(WidgetRef ref) async {
  ref
    ..invalidate(ownerSnapshotProvider)
    ..invalidate(moneySnapshotProvider)
    ..invalidate(workloadProvider);
  await Future.wait<Object?>([
    ref.read(overviewProvider.future),
    ref.read(peopleProvider.future),
  ]).catchError((_) => <Object?>[]);
}
