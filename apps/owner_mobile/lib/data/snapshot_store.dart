import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The owner's last overview, kept on the phone so the app opens instantly
/// and still answers "what is happening" on a weak signal.
///
/// Encrypted at rest — flutter_secure_storage keeps it under a key held by the
/// Android Keystore — because it contains money: what is owed and by whom.
/// Keyed by user, and wiped entirely on sign-out, so a phone handed to
/// someone else carries nothing over.
///
/// This is a read cache and nothing more. The owner's app never writes, so
/// there is nothing to sync back and no conflict to resolve — which is the
/// only reason a disk cache is cheap enough to have (blueprint decision 16a).
class SnapshotStore {
  SnapshotStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _prefix = 'snapshot';

  String _key(String userId, String name) => '$_prefix.$userId.$name';

  Future<SavedSnapshot?> read(String userId, String name) async {
    try {
      final raw = await _storage.read(key: _key(userId, name));
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return SavedSnapshot(
        savedAt: DateTime.parse(j['saved_at'] as String),
        data: Map<String, dynamic>.from(j['data'] as Map),
      );
    } catch (_) {
      // Unreadable or from an older shape: behave as if nothing was saved.
      return null;
    }
  }

  Future<void> write(
    String userId,
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      await _storage.write(
        key: _key(userId, name),
        value: jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {
      // A cache that cannot be written is just a slower start next time.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}

class SavedSnapshot {
  const SavedSnapshot({required this.savedAt, required this.data});

  final DateTime savedAt;
  final Map<String, dynamic> data;
}

final snapshotStoreProvider = Provider<SnapshotStore>(
    (ref) => SnapshotStore(const FlutterSecureStorage()));
