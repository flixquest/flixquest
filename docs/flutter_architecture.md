# Flutter migration architecture

F0 supplies the Laravel foundations. F1 wires the injector into `main.dart` and
migrates shared phone/TV networking and caching. Feature cutovers belong to F2–F6. The implementation
plan is `docs/flutter_laravel_migration_phases.md`.

## Layers and dependency ownership

- `lib/core/`: deployment configuration, migration flags, Result/Failure, tolerant
  JSON reads, secure tokens, namespaced preferences, server clock, and Dio clients.
- `lib/data/`: generated backend DTOs; sources/repositories arrive in their owning
  phases. Repositories convert wire payloads to domain objects and return
  `Result<T>`; widgets and ViewModels do not depend on transport/storage libraries.
- `lib/presentation/`: Provider/ChangeNotifier ViewModels and Freezed UI states
  arrive with the features they own. Existing providers retain their public APIs.

`await buildInjector()` returns one `AppInjector` for an app lifecycle, exposed by
Provider above the phone/TV UI. Dependencies can be supplied for tests; injected
Dio clients transfer lifecycle ownership to the injector. Await `dispose()` when
that lifecycle ends. Public and Laravel clients must be separate instances.
`NetworkRuntime` bridges existing top-level functions to these app-owned clients;
standalone widgets/tests get a volatile cache until explicitly configured.

Both clients use headers, GET retries (two, 300/600 ms), cache policies, debug-only
logging and typed error mapping. Public requests apply the TMDB proxy centrally.
Logs omit headers, query values and bodies. Authentication belongs to F2.

## Response caching

`dio_cache_interceptor` handles HTTP validation and response serialization. The
app supplies endpoint policies, normalized keys, scope management, single-flight
GET sharing, and `ResponseCacheStore`. SQLite stores responses in
`flixquest_http_cache_v1.db`, bounded to 5,000 entries / 50 MiB of response bodies
and headers; its memory LRU holds up to 300 entries / 16 MiB. Store failures cannot
make a successful network response fail. If SQLite cannot open, the injector uses
a volatile memory cache. `sqflite_common_ffi` is test-only.

TMDB keys sort query parameters and omit API keys/proxy wrappers, retaining
language/page/query values. Laravel cacheable requests with credentials must set
`extra['authScope'] = 'user:<id>'`; requests without an owner bypass caching.
The endpoint TTLs and offline limits are in `core/cache/cache_policies.dart` and
the migration plan. `extra['cache']` reports `hit`, `miss`, `stale` or `revalidated`.
Set `extra['refreshStale'] = true` to serve stale data while refreshing in the
background. Reading a cache entry never extends its offline expiration deadline.

Only eligible GET 200 responses persist. Streams, writes, error statuses,
`no-store`, cookie-setting responses and `Vary: *` bypass storage. Errors from
HTTP responses never use offline fallback; transport failures can use entries
within their deadline. Clearing invalidates in-flight writes, including retries.
`HttpCache.clearScope('tmdb'|'scraper'|'laravel'|'user'|'user:<id>')`, `clearAll()`
and `sizeBytes()` provide management. Boot prunes expired entries at idle; the
existing Settings clear-cache action also clears HTTP responses.

Legacy `functions/network.dart` signatures delegate through `TmdbRepository`.
Title logos use the same TMDB cache, and remote SVG logos use a long-lived bytes
policy with XML validation retained. Raster image caching stays with
`cached_network_image`. `ScraperApi(baseUrl, {Dio? dio})` uses this shared client:
providers/health/subtitle searches cache; streams/size requests never do, with
60-second streams and 45-second subtitle timeouts. Scraper ads stay until F4.

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
