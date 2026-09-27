# Viewing Insights Firestore rules

FlixQuest stores registered-user Viewing Insights sync data under
`wellness-v1/{firebaseUid}/sessions` and `wellness-v1/{firebaseUid}/daily`.
Merge the following match block into the deployed Firestore rules. The project
does not keep its environment-level Firebase configuration in this repository,
so this snippet is intentionally not an independently deployable ruleset.

```text
match /wellness-v1/{userId} {
  allow read, write: if request.auth != null
    && request.auth.uid == userId
    && request.auth.token.firebase.sign_in_provider != 'anonymous';

  match /{document=**} {
    allow read, write: if request.auth != null
      && request.auth.uid == userId
      && request.auth.token.firebase.sign_in_provider != 'anonymous';
  }
}
```

The client uses document IDs for session upserts. To keep reads down it pulls
only sessions whose server-set `syncedAt` timestamp is newer than the last one
it applied (a single-field range query, covered by Firestore's automatic
indexes), and reads the whole collection once a week to catch writes from older
app versions that do not stamp `syncedAt`. Daily summaries are diffed against a
ledger kept on the device, so the `daily` collection is only read the first
time a device syncs and after each weekly full read. No composite index is
required, but rules must not reject the extra `syncedAt` field.
