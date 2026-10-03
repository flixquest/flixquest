# Firebase auth rollback

F2 preserves the pre-migration auth/profile implementations in this directory.
Only imports changed: copied routes and services reference one another here;
shared UI, databases, navigation, and sync services still reference `lib/`.

The public routes select these implementations when
`FLIXQUEST_MIGRATION` does not include `auth`. With `auth` enabled, account
requests and profiles use Laravel and the typed session. Firebase library sync
is disabled in that mode until F5 supplies Laravel sync.

Remove this directory and the route selectors in F7 after the replacement paths
have completed their rollout. Keep rollback behavior working until then.
