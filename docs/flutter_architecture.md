# Flutter migration architecture

F0 introduces the Laravel foundations without connecting them to `main.dart` or
changing existing phone/TV providers. Cutovers belong to F1–F6. The implementation
plan is `docs/flutter_laravel_migration_phases.md`.

## Layers and dependency ownership

- `lib/core/`: deployment configuration, migration flags, Result/Failure, tolerant
  JSON reads, secure tokens, namespaced preferences, server clock, and Dio clients.
- `lib/data/`: generated backend DTOs; sources/repositories arrive in their owning
  phases. Repositories convert wire payloads to domain objects and return
  `Result<T>`; widgets and ViewModels do not depend on transport/storage libraries.
- `lib/presentation/`: Provider/ChangeNotifier ViewModels and Freezed UI states
  arrive with the features they own. Existing providers retain their public APIs.

`await buildInjector()` returns one `AppInjector` for an app lifecycle. Later phases
will expose that object with Provider and add repositories to it. Dependencies can
be supplied at construction for tests; injected Dio clients transfer lifecycle
ownership to the injector. Call `dispose()` when that lifecycle ends. Public and
Laravel clients must be different instances. F0 configures timeouts/Accept/base URL;
auth, retry, caching and logging interceptors belong to later phases. The SQLite
response cache is F1 work; F0 does not introduce a placeholder cache engine.

## Deployment configuration

`LARAVEL_API_URL` resolves from `--dart-define` first, then loaded `.env`, then the
debug-only Android emulator default `http://10.0.2.2:8000`. An unconfigured release
fails configuration construction. A host URL or an existing `/api/v1` URL is accepted;
the normalized base URL ends with `/api/v1/`. Endpoints use relative paths such as
`auth/login`, without a leading slash.

`.env.example` lists existing environment keys with empty/public sample values.
The bundled `.env` retains its existing values and adds the development Laravel URL.
Use public configuration only; Sanctum tokens are never bundled into assets.
`--dart-define=FLIXQUEST_MIGRATION=auth,config,ads,sync,notifications,telemetry` selects
future feature cutovers. All flags default off and F0 does not consume them in UI.

Tokens use `flutter_secure_storage` under `flixquest.laravel.v1.sanctum_token`.
Preferences use `flixquest.laravel.v1.` so new account cursors cannot be mistaken
for Firebase checkpoints. `ServerClock` persists an offset in milliseconds; await
`recordServerTimeUtc()` before retrying a sync. It corrects wall-clock timestamps,
not elapsed playback durations. Native secure-storage backup/keychain setup and
device persistence/logout smoke checks remain part of the F2 auth integration.

## DTOs and code generation

New DTOs/unions use Freezed and json_serializable. `AppUser` mirrors Laravel's
`UserResource`, accepts its camel/snake aliases, and rejects invalid user identities.
`ApiError` preserves validation fields, retry metadata and authoritative clock-skew
details. `Result.map` transforms a successful value; `when` branches on success or
failure; `getOrElse` supplies an error fallback. Failure and Result support JSON
round trips. Runtime session tokens must still stay exclusively in secure storage.

Generated `.freezed.dart`/`.g.dart` files are included in the worktree for the user's
eventual commit. Do not hand-edit them. `build.yaml` enables `explicit_to_json`:

```sh
.fvm/flutter_sdk/bin/dart run build_runner build --delete-conflicting-outputs
```

## Verification

Tests exercise public interfaces with real Dio transforms and a scripted transport
(`test/support/fake_dio.dart`). Store/clock fakes live in `test/support/fakes.dart`.
Sanitized JSON fixtures and their backend origins are documented in
`test/support/fixtures/README.md`. The normal suite makes no live Laravel requests.

```sh
.fvm/flutter_sdk/bin/flutter analyze
.fvm/flutter_sdk/bin/flutter test test/core test/data
.fvm/flutter_sdk/bin/flutter test
```

An explicit read-only smoke test verifies the Herd server's bootstrap/ETag,
ads/messages contracts, and unauthenticated profile rejection:

```sh
.fvm/flutter_sdk/bin/flutter test integration/laravel_foundation_smoke_test.dart \
  --dart-define=LARAVEL_SMOKE_URL=http://flixquest-backend.test
```

The measured pre-F0 baseline is 761 passes and two existing failures, in
`player_menu_route_test.dart` and `subtitle_options_test.dart`. Analysis starts at
zero issues. These existing failures are not skipped, replaced or weakened.
