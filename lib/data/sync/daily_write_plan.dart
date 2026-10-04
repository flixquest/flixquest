/// Daily writes needed to bring the acknowledged ledger in line with SQLite.
({List<String> deletes, List<String> sets}) planDailyWrites({
  required Map<String, int?> ledger,
  required Map<String, int?> local,
}) =>
    (
      deletes: [
        for (final day in ledger.keys)
          if (!local.containsKey(day)) day
      ],
      sets: [
        for (final entry in local.entries)
          if (!ledger.containsKey(entry.key) ||
              ledger[entry.key] != entry.value)
            entry.key
      ],
    );
