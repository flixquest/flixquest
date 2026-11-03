import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../catalog/media_item.dart';
import '../data/playlists/playlist.dart';
import '../data/playlists/playlist_store.dart';
import '../data/repositories/billing_repository.dart' show newIdempotencyKey;
import '../data/repositories/playlist_repository.dart';
import '../data/sync/library_scope.dart';
import '../data/sync/sync_runner.dart';
import '../data/sync/sync_runtime.dart';

/// Why an edit to a list was not made.
enum PlaylistEditError {
  emptyName,
  tooManyLists,
  listFull,
  missing,
  signInRequired
}

class PlaylistEditException implements Exception {
  const PlaylistEditException(this.error);

  final PlaylistEditError error;
}

/// The signed-in account's (or this device's guest) custom lists.
///
/// Every edit is saved as a queued operation before the lists are re-read, so
/// what the screen shows has already survived a restart; the sync runner then
/// hands the queue to Laravel. Signed out, the lists stay on the device and
/// move to the account the guest signs in to.
class PlaylistProvider extends ChangeNotifier {
  PlaylistProvider({
    Future<PlaylistStore> Function(String owner)? openStore,
    String Function()? now,
    Random? random,
  })  : _openStore = openStore ?? _defaultStore,
        _now = now ?? _utcNow,
        _random = random;

  final Future<PlaylistStore> Function(String owner) _openStore;
  final String Function() _now;
  final Random? _random;

  static Future<PlaylistStore> _defaultStore(String owner) =>
      SyncRuntime.coordinator?.openPlaylists(owner) ??
      PlaylistStore.forOwner(owner);

  static String _utcNow() => DateTime.now().toUtc().toIso8601String();

  List<Playlist> _lists = const <Playlist>[];
  List<Playlist> get lists => _lists;

  bool _loading = false;
  bool get loading => _loading;

  bool _loaded = false;

  /// Whether the lists have been read at least once for this owner.
  bool get loaded => _loaded;

  SyncRunner? _runner;
  Future<void> _edits = Future<void>.value();

  /// The sync runner for lists, when this build syncs them.
  SyncRunner? get runner {
    _bind();
    return _runner;
  }

  /// Repository for imports; null when this build has no Laravel sync.
  PlaylistRepository? get repository =>
      SyncRuntime.enabled ? SyncRuntime.coordinator?.playlistRepository : null;

  void _bind() {
    final next =
        SyncRuntime.enabled ? SyncRuntime.coordinator?.playlists : null;
    if (identical(next, _runner)) return;
    _runner?.status.removeListener(_onSyncStatus);
    _runner = next;
    next?.status.addListener(_onSyncStatus);
  }

  void _onSyncStatus() {
    if (_runner?.status.value == 'success') unawaited(load());
  }

  Playlist? byId(String id) {
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  /// Ids of the lists holding [item].
  Set<String> listsContaining(MediaItem item) => <String>{
        for (final list in _lists)
          if (list.contains(item)) list.id,
      };

  void resetForOwner() {
    _lists = const <Playlist>[];
    _loaded = false;
    notifyListeners();
  }

  Future<void> load() async {
    _bind();
    final owner = LibraryScope.owner;
    final generation = LibraryScope.generation;
    _loading = true;
    notifyListeners();
    try {
      final lists = await (await _openStore(owner)).read();
      if (generation != LibraryScope.generation) return;
      _lists = lists;
      _loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Syncs now, when signed in; the lists reload when it lands.
  Future<bool> sync() async => await runner?.sync() ?? false;

  /// Syncs unless this account did recently; pulling to refresh still forces
  /// one with [sync].
  Future<void> autoSync() async => await runner?.autoSync();

  /// Makes a list called [name], with [first] (or every one of [items], as
  /// when saving a copy of someone's list) in it, and returns its id.
  Future<String> create(String name,
      {String? description,
      MediaItem? first,
      List<MediaItem> items = const <MediaItem>[]}) async {
    final trimmed = _name(name);
    if (_lists.length >= PlaylistLimits.lists) {
      throw const PlaylistEditException(PlaylistEditError.tooManyLists);
    }
    final id = newIdempotencyKey(_random);
    final note = _description(description);
    await _apply(<PlaylistOperation>[
      _operation(PlaylistOperation.create, id, <String, Object?>{
        'name': trimmed,
        if (note != null) 'description': note,
      }),
      if (first != null) _addition(id, first),
      for (final item in items.take(PlaylistLimits.items)) _addition(id, item),
    ]);
    return id;
  }

  /// The list of this account's that [code] (`fq-…`) shares, if any.
  Playlist? byShareCode(String code) {
    final normalized = code.toUpperCase().replaceFirst('FQ-', '');
    for (final list in _lists) {
      if (list.record.shareCode?.toUpperCase() == normalized) return list;
    }
    return null;
  }

  /// Lets anyone with the link see list [id], or stops them; returns the
  /// link while it is public. Needs a signed-in account, since the link is
  /// served by Laravel, and so the list has to reach it first.
  ///
  /// Throws [PlaylistImportException] when Laravel cannot be reached.
  Future<String?> setPublic(String id, bool public) async {
    _require(id);
    final repository = this.repository;
    final runner = this.runner;
    final owner = LibraryScope.owner;
    if (repository == null || runner == null || !owner.startsWith('user:')) {
      throw const PlaylistEditException(PlaylistEditError.signInRequired);
    }
    final generation = LibraryScope.generation;
    await runner.sync();
    final record =
        await repository.setSharing(id, public: public, owner: owner);
    final store = await _openStore(owner);
    await store.saveRecord(record);
    if (generation == LibraryScope.generation) {
      _lists = await store.read();
      notifyListeners();
    }
    return record.shareUrl;
  }

  Future<void> rename(String id, String name, {String? description}) async {
    final list = _require(id);
    final trimmed = _name(name);
    final note = _description(description);
    if (trimmed == list.name && note == list.description) return;
    await _apply(<PlaylistOperation>[
      _operation(PlaylistOperation.update, id, <String, Object?>{
        'base_version': list.version,
        'name': trimmed,
        'description': note,
      }),
    ]);
  }

  Future<void> delete(String id) async {
    _require(id);
    await _apply(<PlaylistOperation>[_operation(PlaylistOperation.delete, id)]);
  }

  /// Adds [item] to the end of list [id]; nothing happens if it is there.
  Future<void> add(String id, MediaItem item) async {
    final list = _require(id);
    if (list.contains(item)) return;
    if (list.entries.length >= PlaylistLimits.items) {
      throw const PlaylistEditException(PlaylistEditError.listFull);
    }
    await _apply(<PlaylistOperation>[_addition(id, item)]);
  }

  Future<void> remove(String id, MediaItem item) async {
    final list = _require(id);
    if (!list.contains(item)) return;
    await _apply(<PlaylistOperation>[
      _operation(PlaylistOperation.remove, id, <String, Object?>{
        'media_type': playlistMediaType(item.kind),
        'media_id': item.id,
      }),
    ]);
  }

  /// Adds [item] to list [id] or takes it out; returns whether it is in the
  /// list afterwards.
  Future<bool> toggle(String id, MediaItem item) async {
    final inList = _require(id).contains(item);
    inList ? await remove(id, item) : await add(id, item);
    return !inList;
  }

  /// Puts list [id]'s titles in the order of [keys] (see [Playlist.keyOf]).
  Future<void> reorder(String id, List<String> keys) async {
    final list = _require(id);
    if (listEquals(keys, list.entries.map((entry) => entry.key).toList())) {
      return;
    }
    await _apply(<PlaylistOperation>[
      _operation(PlaylistOperation.reorder, id, <String, Object?>{
        'base_version': list.version,
        'items': <Map<String, Object?>>[
          for (final key in keys)
            <String, Object?>{
              'media_type': key.split(':').first,
              'media_id': int.parse(key.split(':').last),
            },
        ],
      }),
    ]);
  }

  Playlist _require(String id) =>
      byId(id) ??
      (throw const PlaylistEditException(PlaylistEditError.missing));

  String _name(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PlaylistEditException(PlaylistEditError.emptyName);
    }
    return trimmed.length > PlaylistLimits.name
        ? trimmed.substring(0, PlaylistLimits.name)
        : trimmed;
  }

  String? _description(String? description) {
    final trimmed = description?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length > PlaylistLimits.description
        ? trimmed.substring(0, PlaylistLimits.description)
        : trimmed;
  }

  PlaylistOperation _operation(String action, String playlistId,
          [Map<String, Object?> fields = const <String, Object?>{}]) =>
      PlaylistOperation(
        id: newIdempotencyKey(_random),
        action: action,
        playlistId: playlistId,
        fields: fields,
        createdAt: _now(),
      );

  PlaylistOperation _addition(String id, MediaItem item) {
    final genres = item.genreIds;
    return _operation(PlaylistOperation.add, id, <String, Object?>{
      'media_type': playlistMediaType(item.kind),
      'media_id': item.id,
      'title': item.title,
      'poster_path': item.posterPath,
      'backdrop_path': item.backdropPath,
      'vote_average': item.rating?.clamp(0, 10),
      'release_date': item.releaseDate,
      if (genres.isNotEmpty) 'genre_ids': genres.take(20).toList(),
    });
  }

  /// Edits run one after another, each saved before the lists are re-read.
  Future<void> _apply(List<PlaylistOperation> operations) {
    final owner = LibraryScope.owner;
    final generation = LibraryScope.generation;
    final work = _edits.then((_) async {
      final store = await _openStore(owner);
      await store.enqueueAll(operations);
      if (generation != LibraryScope.generation) return;
      _lists = await store.read();
      _loaded = true;
      notifyListeners();
      runner?.changed();
    });
    _edits = work.catchError((Object _) {});
    return work;
  }

  @override
  void dispose() {
    _runner?.status.removeListener(_onSyncStatus);
    super.dispose();
  }
}
