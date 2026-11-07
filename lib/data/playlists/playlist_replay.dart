import 'playlist.dart';

List<Playlist> replayPlaylists(
  Iterable<PlaylistRecord> records,
  Iterable<PlaylistEntry> entries,
  Iterable<PlaylistOperation> operations,
) {
  final lists = <String, PlaylistRecord>{
    for (final record in records) record.id: record,
  };
  final titles = <String, List<PlaylistEntry>>{
    for (final record in records) record.id: <PlaylistEntry>[],
  };
  for (final entry in entries) {
    titles[entry.playlistId]?.add(entry);
  }
  for (final list in titles.values) {
    list.sort((a, b) => a.position.compareTo(b.position));
  }

  for (final operation in operations) {
    final id = operation.playlistId;
    final record = lists[id];
    final fields = operation.fields;
    switch (operation.action) {
      case PlaylistOperation.create:
        if (record != null) break;
        lists[id] = PlaylistRecord(
          id: id,
          name: fields['name'] as String? ?? '',
          description: fields['description'] as String?,
          createdAt: operation.createdAt,
        );
        titles[id] = <PlaylistEntry>[];
      case PlaylistOperation.update:
        if (record == null || fields['base_version'] != record.version) break;
        lists[id] = record.copyWith(
          name: fields['name'] as String?,
          description: fields['description'] as String?,
          clearDescription: fields.containsKey('description') &&
              fields['description'] == null,
          version: record.version + 1,
        );
      case PlaylistOperation.delete:
        lists.remove(id);
        titles.remove(id);
      case PlaylistOperation.reorder:
        final current = titles[id];
        if (record == null ||
            current == null ||
            fields['base_version'] != record.version) {
          break;
        }
        titles[id] = reorderEntries(
          current,
          <String>[
            for (final item in fields['items'] as List? ?? const <Object>[])
              if (item is Map)
                playlistEntryKey(
                    '${item['media_type']}', (item['media_id'] as num).toInt()),
          ],
        );
        lists[id] = record.copyWith(version: record.version + 1);
      case PlaylistOperation.add:
        final current = titles[id];
        if (record == null || current == null) break;
        final key = playlistEntryKey(
            '${fields['media_type']}', (fields['media_id'] as num).toInt());
        if (current.any((entry) => entry.key == key) ||
            current.length >= PlaylistLimits.items) {
          break;
        }
        current.add(PlaylistEntry.fromJson(<String, dynamic>{
          ...fields,
          'playlist_id': id,
          'position': current.isEmpty ? 0 : current.last.position + 1,
          'added_at': operation.createdAt,
        }));
      case PlaylistOperation.remove:
        final key = playlistEntryKey(
            '${fields['media_type']}', (fields['media_id'] as num).toInt());
        titles[id]?.removeWhere((entry) => entry.key == key);
    }
  }

  final result = <Playlist>[
    for (final record in lists.values)
      Playlist(record, List<PlaylistEntry>.unmodifiable(titles[record.id]!)),
  ];
  // ISO-8601 dates sort as text; a list with none (just arrived) goes first.
  result.sort((a, b) => (b.record.createdAt ?? '\u{10FFFF}')
      .compareTo(a.record.createdAt ?? '\u{10FFFF}'));
  return result;
}

/// [entries] with the titles named in [order] first, in that order, and the
/// rest after them as they were: a reorder never loses a title it did not
/// know about.
List<PlaylistEntry> reorderEntries(
    List<PlaylistEntry> entries, List<String> order) {
  final byKey = <String, PlaylistEntry>{
    for (final entry in entries) entry.key: entry,
  };
  final ordered = <PlaylistEntry>[
    for (final key in order)
      if (byKey.remove(key) case final entry?) entry,
    for (final entry in entries)
      if (byKey.containsKey(entry.key)) entry,
  ];
  return <PlaylistEntry>[
    for (var index = 0; index < ordered.length; index++)
      ordered[index].at(index),
  ];
}
