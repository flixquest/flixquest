# FlixQuest Flutter — Laravel Migration Implementation Plan

**Document Version:** 1.1
**Branch:** `feat/laravel`
**Status:** F0 implemented and verified against the measured baseline (2026-10-03); F1 implemented and automatically verified (2026-10-03), device smoke pending; F2 implemented and automatically verified (2026-10-03), staging/device smoke pending; original F3 implemented and automatically verified (2026-10-03), device/Filament smoke pending, F3.5 server-controlled source selection implemented (2026-10-04), automated verification recorded below and device smoke pending; F4 implemented and automatically verified (2026-10-04), device/Filament smoke pending; F5 implemented (2026-10-04), automated verification recorded below and two-device/staging smoke pending; F6 implemented (2026-10-04), automated verification recorded below and phone/TV Google reporting + push smoke pending; F7–F8 pending
**Sources of truth:**
- `docs/migration_prd_firebase_to_laravel.md` (this repo)
- `~/Documents/web/phplaravel/flixquest-backend` — backend + `docs/migration_phases.md` (Phases 1 & 3 complete)
- `~/Documents/web/flixquest-scraper` — the extraction service covered by Part B
- `docs/firebase_remote_config.md` — exact Remote Config key + occasional-theme v2 semantics
- `docs/codex_handover.md` — repo/working conventions that still apply

**User decisions — 2026-10-04 (override conflicting PRD/removal instructions):**

- Laravel decides whether the app uses **Firebase Remote Config or Laravel config** at every configuration refresh. Both implementations remain available after cutover; the production source is not chosen by a build-time flag.
- **Firebase Crashlytics and Google Analytics for Firebase remain enabled under the existing collection/consent settings.** Keep their Flutter packages, initialization, reporting/event calls and native integrations. Do not replace them with Sentry or Laravel, or copy their crashes, non-fatal reports, breadcrumbs, analytics events or streaming-duration events to Laravel.
- F3.5 implements server-controlled source selection on `feat/laravel-f3-config-source`. Its automated verification is recorded below; the same-build phone/TV and Google reporting smoke remains user-run before production cutover.

**Verified baseline on `feat/laravel` (2026-10-03):**

| Check | Result |
|---|---|
| `.fvm/flutter_sdk/bin/flutter analyze` | 0 issues |
| Full suite | Measured before F0 (2026-10-03): 95 files, 761 passing / 2 existing failures (763 executed); `player_menu_route_test.dart` and `subtitle_options_test.dart` fail as documented in the handover. The earlier 699 declaration estimate was inaccurate. |
| Backend API | Auth, config/bootstrap, ads, all 3 sync engines, devices, announcements, telemetry, Filament — all implemented and Pest-tested |

---

## 0. How this plan works

1. Execute phases in order unless the dependency table says a phase is parallelizable.
2. One branch per phase, branched from `feat/laravel` (e.g. `feat/laravel-f1-cache`). Do not commit, push, or open PRs unless the user asks.
3. At the end of every phase, run:
   ```bash
   .fvm/flutter_sdk/bin/flutter analyze                     # must stay 0 issues
   .fvm/flutter_sdk/bin/flutter test 2>&1 | tr '\r' '\n' | grep -E "Some tests failed|All tests passed" | tail -1
   .fvm/flutter_sdk/bin/dart run build_runner build --delete-conflicting-outputs
   ```
   The full tally before F0 is the regression baseline; F-work must not reduce it (except tests deliberately migrated in the same phase, which must be renamed/replaced 1:1).
4. Use `.fvm/flutter_sdk/bin/flutter` and `.fvm/flutter_sdk/bin/dart` — Flutter is not on PATH (see `docs/codex_handover.md` §2.1).
5. Never run `dart format` on existing hand-formatted files; only on files created in the phase.
6. TV parity is required: every migration phase lists its `lib/tv/**` touchpoints. Phone and TV must use the same Laravel-controlled config-source selection and retain Firebase Messaging, Remote Config, Crashlytics and Analytics. Migrate Auth/Firestore only in their owning phases.
7. Each phase ends with a short report (what changed, files, test numbers, anything the user must do) and then stops.

This plan has two parts:

- **Part A — Flutter client** (phases F0–F8, §4): the app migration.
- **Part B — `flixquest-scraper` modernization** (repo `~/Documents/web/flixquest-scraper`, phases S0–S4, §5): the scraper stays a pure extraction service, but becomes layered, typed, validated, cache-validator-friendly and ad-free. "Modern architecture" for a TypeScript service means layered modules, typed config + request validation, a consistent error envelope, and HTTP cache validators — not Provider/MVVM/Freezed, which are Flutter concepts. The client-side `ScraperApi` migration is already covered in F1.4/F4.

Cross-repo rules:
- Scraper changes must keep every currently shipped `/api/v2/*` contract working. Wire additions (ETag, extra error fields, new endpoints) are backward-compatible.
- Remove no scraper endpoint before the Flutter phase that stops using it has shipped (ads removal: Flutter F4 → scraper S4).
- One release train per cutover: backend (Laravel) + client (Flutter) + scraper changes that depend on each other ship together.

### Phase dependency graph

```mermaid
graph LR
  F0[F0 Foundations] --> F1[F1 Network + Cache]
  F0 --> F2[F2 Auth]
  F0 --> F3[F3 Config]
  F0 --> F4[F4 Ads]
  F2 --> F5[F5 Sync]
  F2 --> F6[F6 Notifications]
  F3 --> F4
  F1 --> F4
  F1 --> F5
  F5 --> F6
  F3 -->|F3.5 source selection| F6
  F1 --> F7[F7 Firebase cleanup]
  F2 --> F7
  F3 --> F7
  F4 --> F7
  F5 --> F7
  F6 --> F7
  F7 --> F8[F8 QA + Cutover]
```

F1 and F3/F4 can run in parallel with F2 (different files), but F5 must wait for F2 (it needs bearer tokens), and F6 must wait for F5 (it uses session + sync status).

Scraper phases run in parallel with F0–F2 and join the train at two points: **S3** (cache contract) should land before/with **F1** so the client cache can revalidate, and **S4** (ads removal) must wait for **F4** to ship. All of Part B is independent of the Firebase work.

---

## 1. Target architecture

### 1.1 Layers

```
UI (screens/widgets, unchanged public APIs where possible)
  │  Provider (ChangeNotifierProvider / ProxyProvider)
  ▼
Presentation  lib/presentation/
  ViewModels (ChangeNotifier) + Freezed UI state unions
  │
  ▼
Data          lib/data/
  Repositories — one per backend capability; return Result<T, Failure>
  │
  ├── Sources  remote: LaravelApi · TmdbApi · ScraperApi (Dio)
  │            local:  SQLite controllers (existing) · KVDatabase (SharedPreferences)
  ▼
Core          lib/core/
  Dio factory + interceptors (auth · cache · retry · logging · proxy)
  ResponseCacheStore (SQLite + memory LRU) · CachePolicy registry
  SecureTokenStore · ServerClock · Failure/Result · JsonReader · DI factory
```

Rules:
- Screens never call `http`/`Dio`/Firestore directly (existing violations are removed as each phase touches the file).
- Repositories are the only place that knows backend payload shapes; they convert DTOs ⇄ domain models and map errors to `Failure`.
- ViewModels hold screen state and call repositories. They never import `dio` or `sqflite`.
- `lib/services/*` files become thin adapters while screens migrate, then are deleted.

### 1.2 New directory layout

```
lib/core/
  config/app_environment.dart        # Laravel base URL, timeouts, debug flags
  config/migration_flags.dart        # per-feature cutover switches (development aid)
  di/injector.dart                   # builds stores/clients/repositories once
  error/failure.dart                 # Freezed Failure union
  error/result.dart                  # Freezed Result<T> (Ok/Err)
  json/json_reader.dart              # firstOf() helpers for snake+camel payloads
  network/dio_factory.dart
  network/interceptors/auth_interceptor.dart
  network/interceptors/cache_interceptor.dart
  network/interceptors/retry_interceptor.dart
  network/interceptors/logging_interceptor.dart
  network/interceptors/tmdb_proxy_interceptor.dart
  cache/cache_policy.dart
  cache/cache_policies.dart          # the TTL registry in §1.6
  cache/response_cache_store.dart    # sqflite + memory LRU
  storage/secure_token_store.dart    # flutter_secure_storage
  storage/kv_store.dart              # namespaced SharedPreferences
  time/server_clock.dart             # server_time_utc offset
lib/data/
  models/…                           # Freezed + json_serializable DTOs
  sources/laravel_api.dart
  sources/tmdb_api.dart
  sources/scraper_api.dart
  repositories/auth_repository.dart
  repositories/config_repository.dart
  repositories/ads_repository.dart
  repositories/bookmark_repository.dart
  repositories/recently_watched_repository.dart
  repositories/wellness_repository.dart
  repositories/announcement_repository.dart
  repositories/device_repository.dart
  repositories/tmdb_repository.dart
lib/presentation/
  session/session_view_model.dart
  bootstrap/bootstrap_view_model.dart
  config/config_source_controller.dart # F3.5 runtime selector
  ...
```

### 1.3 State management: Provider + MVVM

- Keep `provider` — it is already the app's convention and the user asked for Provider.
- New screens/features get a `ChangeNotifier` ViewModel exposed with `ChangeNotifierProvider`; cross-viewmodel dependencies use `ProxyProvider`.
- ViewModel state is a Freezed union, not a pile of nullable booleans:
  ```dart
  @freezed
  sealed class Loadable<T> with _$Loadable<T> {
    const factory Loadable.initial() = LoadableInitial<T>;
    const factory Loadable.loading() = LoadableLoading<T>;
    const factory Loadable.data(T value) = LoadableData<T>;
    const factory Loadable.error(Failure failure) = LoadableError<T>;
  }
  ```
- Existing `ChangeNotifier` providers (`SettingsProvider`, `BookmarkProvider`, `RecentProvider`, `AppDependencyProvider`, `WellnessProvider`, `OfflineDownloadProvider`) are **not rewritten**: they keep their public API and delegate to the new repositories. This keeps 699 tests and every screen working during the migration.

### 1.4 Freezed policy (incremental, not a big-bang rewrite)

Add Freezed now, but apply it where it pays:

| Area | Policy |
|---|---|
| New backend DTOs (`AppUser`, `AuthSession`, `BootstrapConfig`, theme catalog, `BannerAdDto`, sync DTOs, announcements) | **Freezed + json_serializable**, committed generated files |
| ViewModel state (`Loadable<T>`, `SessionState`, `SyncState`) | **Freezed sealed unions** |
| Existing hand-written TMDB/UI models (`Movie`, `TV`, `MovieDetails`, `WellnessViewingSession`, `RecentMovie`…) | Convert **only when the owning phase touches them**; keep `toMap/fromMap` compatibility during conversion |
| SQLite row structs | Stay mutable/manual until their controller is touched (Freezed is awkward for rows updated in place) |

Conventions:
- Enable `explicit_to_json: true` in `build.yaml`.
- Repository/API layer uses `fromJson`; SQLite layer keeps `toMap`/`fromMapObject` (add them to the Freezed class as extension methods where needed).
- Never rename existing model fields in the same step as a Freezed conversion; do it in a separate commit-sized change.
- Generated files are committed. Add to `analysis_options.yaml`:
  ```yaml
  analyzer:
    exclude:
      - "**/*.g.dart"
      - "**/*.freezed.dart"
  ```
- CI/verification runs `build_runner` and fails if the tree is dirty afterwards.

### 1.5 Networking

- Declare `dio` (currently only a transitive dependency) and make it the single HTTP engine.
- Two Dio clients from one factory:
  - **Laravel client** — `AuthInterceptor` (Bearer from `SecureTokenStore`), `ErrorInterceptor`, `RetryInterceptor` (idempotent GET only), `CacheInterceptor` (bootstrap/ads/messages only).
  - **Public client** — TMDB + scraper; cache + retry + logging + `TmdbProxyInterceptor`; no auth.
- Timeouts: connect 10 s. Receive: 20 s metadata, 60 s scraper stream endpoints, 45 s subtitles.
- Legacy `lib/functions/network.dart` keeps its exported function signatures; internals delegate to `TmdbRepository`. This is what makes TMDB caching apply to all 50+ call sites without touching them.
- `ScraperApi` keeps its class name, file and constructor shape (`ScraperApi(baseUrl, {Dio? dio})`) but moves onto Dio + policies. `getAds()` is removed in F4, not earlier.
- `http` stays in `pubspec.yaml` until F7 so untouched files keep compiling; each phase migrates the files it touches.

### 1.6 API response cache (TMDB + scraper + Laravel GETs)

This is the core of the user requirement. One cache engine, per-endpoint policies.

**Store:** `flixquest_http_cache_v1.db` (sqflite, already in the dependency tree)

```sql
CREATE TABLE http_cache (
  key           TEXT PRIMARY KEY,   -- METHOD + normalized URL (params sorted)
  scope         TEXT NOT NULL,      -- 'tmdb' | 'scraper' | 'laravel'
  auth_scope    TEXT NOT NULL DEFAULT 'public', -- 'public' | 'user:<id>'
  status_code   INTEGER NOT NULL,
  headers       TEXT,               -- JSON
  body          BLOB NOT NULL,
  etag          TEXT,
  last_modified TEXT,
  fetched_at    INTEGER NOT NULL,   -- epoch ms (server-corrected where available)
  max_age_ms    INTEGER NOT NULL,
  max_stale_ms  INTEGER NOT NULL
);
CREATE INDEX idx_http_cache_scope ON http_cache(scope, fetched_at);
```

Plus an in-memory LRU (300 entries / 16 MB) in front of SQLite for hot rows.

**Key normalization:** sort query parameters, strip `api_key` and proxy `destination` wrappers (the cache key is computed from the original TMDB URL, so rotating the API key does **not** invalidate the cache). Authenticated Laravel responses include `auth_scope` so user A never receives user B's cached body.

**Interceptor behavior:**
1. Fresh hit → resolve from cache immediately (`extra['cache'] = 'hit'`), no network.
2. Stale hit + network available → send conditional request (`If-None-Match`/`If-Modified-Since`); `304` refreshes `fetched_at` and serves cache; `200` replaces the entry. A background refresh variant (`refreshStale: true`) serves stale now and replaces on completion.
3. Network failure + stale entry within `max_stale` → serve stale (`extra['cache'] = 'stale'`); otherwise rethrow as `Failure`.
4. Never cache: non-GET, status ≠ 200, `Cache-Control: no-store`, `401/403/404/409/422/429/5xx`, stream endpoints.
5. Concurrent identical GETs share one in-flight `Future`.

**Policy registry:**

| Scope | URL pattern (matched in order) | Fresh | Max stale | ETag |
|---|---|---|---|---|
| tmdb | `trending/*`, `discover/*`, `movie/popular`, `movie/upcoming`, `movie/now_playing`, `tv/on_the_air`, `tv/airing_today` | 15 min | 7 d | yes |
| tmdb | `movie/{id}`, `tv/{id}`, credits / videos / images / recommendations / similar / reviews / watch/providers | 24 h | 30 d | yes |
| tmdb | `search/*` | 5 min | 1 d | no |
| tmdb | `genre/*/list`, `configuration/*`, `person/{id}` (24 h) | 7 d / 24 h | 30 d | yes |
| scraper | `providers` | 5 min | 1 d | no |
| scraper | `providers/status` | 60 s | 10 min | no |
| scraper | `subtitles/search` | 24 h | 7 d | no |
| scraper | `stream-movie`, `stream-tv`, `stream-size` | **no cache** | — | — |
| laravel | `config/bootstrap` | revalidate on launch/resume (ETag), offline fallback indefinitely | ∞ | yes |
| laravel | `ads` | 5 min | 24 h | yes |
| laravel | `messages/active` | 15 min | 7 d | yes |
| laravel | all other GETs and every POST/PUT/DELETE | **no cache** | — | — |

**Invalidation API:** `HttpCache.clearScope('tmdb'|'scraper'|'laravel'|'user')`, `clearAll()`, `sizeBytes()`. Settings gains a "Clear cache" row in F1 (small, optional).

**Image caching is unchanged:** `cached_network_image` + `flutter_cache_manager` already handle images; this layer is only JSON responses.

### 1.7 Error handling

All repository methods return `Result<T, Failure>` (Freezed). `Failure` kinds: `network`, `timeout`, `unauthorized`, `forbidden`, `notFound`, `conflict`, `validation(fields)`, `rateLimited(retryAfter)`, `server(status)`, `clockSkew(serverTimeUtc, driftMs)`, `cache`, `unknown`. The Laravel envelope (`success`, `message`, `errors`) is parsed centrally in `LaravelApi`.

### 1.8 Testing strategy

- Baseline suite stays green; each phase adds tests, it does not replace coverage.
- New seams: `Dio` injected into every source/repository; `SecureTokenStore`, `KvStore`, `ServerClock`, `HttpCacheStore` are constructor-injected and faked in tests. New test support lives in `test/support/` (fake Dio adapter, fixtures, fakes).
- Repository tests run against a scripted fake adapter — no network.
- ViewModel tests inject fake repositories.
- Widget tests follow the existing scaffolding (see `docs/codex_handover.md` §7.2) and cover the migrated screens.
- Each sync phase adds a manual two-device smoke script documented in the phase report (no device access from the agent — the user runs it).

### 1.9 Cutover flags and rollback

- `lib/core/config/migration_flags.dart` (read from `--dart-define=FLIXQUEST_MIGRATION=auth,config,ads,sync,...`) controls per-feature cutover during development so both code paths can be tested side by side.
- Production cutover remains a single release (F8). Laravel's runtime config selector controls Firebase-versus-Laravel configuration in staging and production. Changing it in Filament switches the source on the next refresh without an app release; app-version rollback remains available for code changes.
- The development `config` flag may enable/test the new source-selection controller, but must not force a production source or bypass the Laravel decision. Neither client provider adapter may override Laravel's selection.
- Each phase must be revertible by reverting its commits. Delete the replaced Firebase Auth/Firestore paths only in F7; retain Remote Config, Crashlytics, Analytics and Messaging permanently under this plan.

### 1.10 Laravel-controlled configuration source

- On every cold launch, app resume, config push hint, explicit refresh and Firebase realtime-config update, revalidate Laravel's public bootstrap endpoint before applying a fresh configuration. Remove the existing one-hour resume throttle for this selector. Concurrent refreshes may share an in-flight request; a new update hint during it schedules a follow-up validation.
- The response field is `data.config_source` (`firebase` or `laravel`). Laravel/Filament owns this setting, with `laravel` as the migrated environment's seeded default. Include it in the bootstrap ETag so a source change produces a new response; a 304 confirms the cached Laravel choice remains current. F3.5 implements this backend/client contract.
- When `firebase` is selected, fetch/activate Firebase Remote Config and map its values into `AppDependencyProvider`. When `laravel` is selected, apply the Laravel bootstrap configuration. The selected source owns the whole configuration snapshot (features, branding, updates, network, ads settings and seasonal themes); do not merge values from competing active sources. Laravel auth, sync and ads endpoints remain Laravel endpoints whichever config source is selected.
- Keep a single consumer/API for phone and TV and separate source caches. Persist the last valid Laravel selection and each source's last good snapshot. Render the matching cached snapshot while revalidating and when offline; retain that selection on errors or invalid/missing selector values. With no valid selection/cache on first offline launch, use bundled safe defaults until Laravel is reachable. Do not silently select a different provider on a fetch failure.
- Cancel or ignore requests/listeners from the previously selected source so delayed updates cannot overwrite the current snapshot. Preserve user-selected themes, effect preferences and existing key/schema compatibility across switches.
- The Laravel bootstrap URL comes from deployment configuration and must remain reachable independently of the selected provider's network settings. Firebase cannot override the selector or that control endpoint. Source selection does not disable or reroute Crashlytics/Analytics collection.

---

## 2. Backend contract reference (as implemented)

Base URL: `/api/v1`; all responses include top-level `success`; resources emit **both snake_case and camelCase** aliases.

### Auth
| Method | URI | Request | Response |
|---|---|---|---|
| POST | `/auth/register` | `name, email, username, password, profile_id/profileId, photo_url/photoUrl` | `201 {success, token, user}` |
| POST | `/auth/login` | `email, password` | `{success, token, user}` · 401 invalid · 422 `requires_password_setup` |
| POST | `/auth/google` | `{access_token}` | `{success, token, user}` · 401 invalid · 409 email exists without google_id |
| POST | `/auth/forgot-password` | `{email}` | generic success (enumeration-safe) |
| POST | `/auth/reset-password` | `{email, token, password/newPassword/new_password}` | success · 422 invalid token |
| GET | `/users/check-username?username=` | — | `{success, available}` |
| GET/PUT | `/user/profile` | `name/fullName, username, profile_id/profileId, photo_url/photoUrl` | `{success, user}` |
| POST | `/user/change-password` | `current_password, password` | success (revokes all tokens) |
| POST | `/user/change-email` | `current_password, email` | success (resets verification) |
| POST | `/auth/logout` | — | success (revokes current token) |
| DELETE | `/user/account` | — | success (cascades all remote data) |

`user`: `{id, name, fullName, email, username, profileId, profile_id, photoUrl, photo_url, provider, isVerified, verified, joinedAt, createdAt, updatedAt}`. Sanctum tokens never expire server-side; they are revoked on password/email change, disable, and account deletion.

### Config
- `GET /config/bootstrap` → `{success, data:{features, branding, updates, network, ads, banners, occasional_theme}}`; supports ETag/304; `Cache-Control: public, no-cache`.
- **F3.5 addition:** `data.config_source: 'firebase' | 'laravel'`, editable in Filament and included in ETag calculation; see §1.10. Retain the existing config blocks for the Laravel-selected path.

### Ads
- `GET /ads` (optional `?placement=`) → `{success, ads:[{id (string), key, name, imageUrl, targetUrl, altText, shape, aspectRatio, width, height, placements}]}`; ETag/304.
- `POST /ads/{id}/impression`, `POST /ads/{id}/click` → `{success}`; `{id}` accepts numeric id or string key; throttle 120/min.

### Sync
- `POST /sync/bookmarks` — request `{movies[], tvShows[]/tv_shows[], deleted_media[]}`; transactional delete-then-upsert; response `{success, movies, tvShows, tv_shows}` (full merged state).
- `DELETE /sync/bookmarks/{type}/{id}` — `{success, deleted}`.
- `POST /sync/recently-watched` — request `{since_revision? | since_utc?, client_time_utc?, movies[], episodes[]}`; LWW on `updated_at_utc`; 90-day server-side tombstone purge; response `{success, server_revision, serverRevision, server_time_utc, serverTimeUtc, movies[], episodes[]}`; future timestamps > 24 h drift → `422 {error:'clock_skew_detected', server_time_utc, max_drift_ms}`.
- `POST /sync/wellness` — same envelope plus `sessions[]` (client UUID `id`), `daily[]`; pagination `cursor`, `limit` (default 450, max 1000) with `has_more`/`next_cursor`; **uploads are rejected while paginating**; checkpoint ahead of server → 422 requiring a full sync.

### Notifications
- `POST /devices/register` (Bearer) — `{fcm_token/fcmToken, platform, app_version/appVersion}`.
- `GET /messages/active` (public) — `{success, messages:[{id, title, body, image_url, action_url, button_text, display_type}]}`.
- Existing backend capability, **excluded from this client migration:** `POST /telemetry/errors`. Do not call it for Crashlytics reports or analytics, create a client `TelemetryRepository`, or add Laravel copies of Google reporting. Backend endpoint existence does not authorize integrating it.

### Reference resources
`app/Http/Resources/V1/*` and `tests/Feature/*` in the backend are the executable contract. When a payload question comes up during implementation, read the resource + its Pest test rather than the PRD.

---

## 3. Gap analysis — things that must change before/during migration

These are concrete conflicts found between the PRD, the backend as implemented, and the client as it exists today. They are tasks in the phases below; they are listed here because ignoring any of them breaks the migration.

| # | Gap | Impact | Resolution owner | Phase |
|---|---|---|---|---|
| **G1** | **Placement names drifted.** Client uses `home_all_hero/trending/genres`, `home_movies_*`, `home_series_*`, `new_and_hot`, `stream_loading`, `live_tv_top`, `live_tv_list_a/b/c`, `title_detail`, `live_tv_strip`, plus the PRD's legacy 19. Backend `BannerPlacement` enum only contains the legacy 19, so Filament cannot target the newer slots and `?placement=` validation rejects them. | Revenue slots stop being fillable | Backend enum + Filament options; client stops sending invalid `?placement=` | F4 |
| **G2** | **Retained Firebase services require their SDKs/native setup.** Messaging, Remote Config, Crashlytics and Analytics remain in scope. | Removing core/plugins/pods breaks retained services; original size/startup targets are overstated | Keep all five Firebase packages and required native hooks; measure actual KPIs | F7/F8 |
| **G3** | **Start.io/hosted-ads keys missing server-side.** Client reads `hosted_banner_mode`, `startio_banner_enabled`, `startio_interstitial_enabled`, `startio_interstitial_interval_seconds`, `startio_tv_interstitial_mode`; backend bootstrap/seed does not include them. | Ads engine changes behavior after config cutover | Backend seeder + `ConfigController` mapping | F3 |
| **G4** | **No user model.** Profile is raw Firestore maps read in ~7 screens. | Can't type the new API | Introduce Freezed `AppUser` | F0/F2 |
| **G5** | **`SyncCheckpoint` is Firestore-coupled** (`Timestamp`, `syncedAt`). | Blocks sync migration | Replace with revision-based `SyncCursor` | F5 |
| **G6** | **Clock skew (24 h) is enforced by the backend** but the client has no server-time concept. Blindly pushing local `updated_at_utc` can 422 forever on a wrong device clock. | Sync stalls on skewed devices | `ServerClock` + offset correction + retry-once handler | F0/F5 |
| **G7** | **Wellness cursor rule:** uploads are rejected while paginating. Current client pushes/pulls in one pass. | First large-history sync fails | Repository drains pages, then uploads | F5 |
| **G8** | **Guest→account merge:** today guest wellness uses owner key `guest`; bookmarks/recents sync only when signed in. On first Laravel login, local data must be uploaded and owner remapped. | User loses guest history on signup | Explicit merge step in repositories | F5 |
| **G9** | **Google email collision returns 409** (deliberate backend design, unlike PRD). Client must show "sign in with your password first". | Confusing login failure | Auth screen handling | F2 |
| **G10** | **Firebase uid → Laravel id.** Owner namespace `user:<uid>` and checkpoint keys must not mix old and new data. | False "already synced" state / data loss | New owner namespace + fresh checkpoints on first Laravel login | F2/F5 |
| **G11** | **`AuthSessionController` is a plain UID notifier**, not a session model. | No token/user state for repositories | `SessionViewModel` + adapter | F2 |
| **G12** | **`messages/active` is public** (PRD says Bearer). | Minor | Use public endpoint as implemented | F6 |
| **G13** | **Original telemetry/removal plan conflicts with the user's decision.** | Loss or duplication of Google crash/analytics reporting | Resolved D2: keep Crashlytics/Analytics; exclude Laravel telemetry integration and replacement reporting | F6/F7 |
| **G14** | **Scraper `/api/v2/ads` still exists** (`src/routes/ads.ts`, mount, test, root catalog, boot log) and the repo has no layered architecture: `src/index.ts` is 1,247 lines owning routing + orchestration + caching + validation. | The PRD Phase 2 goal (pure extraction service) is unmet; new client architecture has no service-side counterpart | Part B phases S1/S4 | S4 (after F4) |
| **G15** | **No HTTP cache validators on the scraper** (no `ETag`/`If-None-Match`; core stream routes set no `Cache-Control`; `providers` responses have no explicit policy) and Redis stats/flush use blocking `KEYS`. The Flutter cache layer cannot revalidate. | F1 cache can't do conditional requests against the scraper | Part B phase S3 | S3 (with F1) |
| **G16** | **Scraper repo is mid-merge** (`Merge branch 'v2' into optimize`, resolved but uncommitted, plus staged/unstaged Viv/VidUp work) and CI never runs tests (Node 18/20 vs required Node 22, no `test` script). | Any refactor starts from a dirty, untested tree | Land/stash the merge; Part B S0 adds the test script + CI test step | S0 (before any Part B work) |
| **G17** | **Original F3 chose the config path at build time and throttled resume refresh for an hour.** | Laravel cannot choose the source on every refresh | Resolved by F3.5: bootstrap/Filament selector and shared runtime controller per §1.10; both providers retained | F3.5 before F6 |

**Coordinated backend tasks (do in the backend repo, before the matching Flutter phase):**
1. F3: add `hosted_banner_mode`, `startio_*` keys to `AppConfigurationSeeder` + `ConfigController` bootstrap (`ads` block).
   F3.5 follow-up: add/validate `config_source`, its Filament select, seeded default and ETag coverage; add tests for both choices and selector-only changes. Do not add crash/analytics tracking.
2. F4: extend `BannerPlacement` enum and the Filament multi-select with every placement in G1; optionally normalize existing `home_movies_*` seeds.
3. F5: no backend change required — revisions/cursors are ready.
4. F6: ensure `FIREBASE_CREDENTIALS` is configured in the target environment.
5. F8: staging + production environments on MySQL 8 + Redis (the local SQLite/database-cache config is dev-only).

---

## 4. Part A — Flutter client phase overview

| Phase | Name | Depends on | Size | Primary deliverable |
|---|---|---|---|---|
| **F0** | Architecture foundation | — | S | Dio/Freezed/secure storage/DI/cache scaffolding; zero behavior change |
| **F1** | Network + response cache (TMDB & scraper) | F0 | M | All TMDB + safe scraper GETs cached; `network.dart` delegating to Dio |
| **F2** | Auth, session & account screens | F0 | L | Firebase Auth replaced by Sanctum bearer sessions on phone + TV |
| **F3** | Config source selection & seasonal themes | F0 | M | Laravel chooses Firebase/Laravel config at every refresh; both providers retained (ETag, offline) |
| **F4** | Ads cutover & placement reconciliation | F1, F3 + backend G1 | M | Ads served from Laravel; impressions/clicks tracked |
| **F5** | Sync engine | F2 + F1 | L | Bookmarks/recents/wellness on Laravel with revisions, cursors, skew |
| **F6** | Notifications, in-app messages & reporting preservation | F2, F5, F3.5 | M | FCM registration, announcements polling; existing Crashlytics/Google Analytics retained with no Laravel mirror |
| **F7** | Firebase cleanup & native slimming | F1–F6 | S | Auth/Firestore/in-app-messaging removed; core, Messaging, Remote Config, Crashlytics and Analytics retained |
| **F8** | QA, staging & cutover | F7 | M | Staging rehearsal, integration matrix, production release |

---

## Phase F0 — Architecture foundation (no behavior change)

### Goal
Land the scaffolding every later phase needs, without changing a single user-visible behavior or the existing provider APIs.

### Milestones

**F0.1 Dependencies & codegen**
- [x] Add `dio`, `flutter_secure_storage`, `freezed_annotation`, `json_annotation`.
- [x] Add dev deps `build_runner`, `freezed`, `json_serializable`.
- [x] `build.yaml`: enable `explicit_to_json: true`; exclude generated files in `analysis_options.yaml`.
- [x] Generate files in the worktree for the user’s eventual commit; document `dart run build_runner build --delete-conflicting-outputs`.
- [x] Run the baseline: record `flutter analyze` (expect 0) and the full `flutter test` tally in this file's header before touching code.

**F0.2 Core primitives** (new files under `lib/core/`)
- [x] `error/failure.dart` — Freezed `Failure` with the kinds in §1.7.
- [x] `error/result.dart` — Freezed `Result<T>` (`Ok`/`Err`) with `map`/`when`/`getOrElse`.
- [x] `json/json_reader.dart` — `firstOf`, `asInt`, `asDouble`, `asBool`, `asString`, `asList`, `asMap`, null-safe and tolerant of snake+camel.
- [x] `config/app_environment.dart` — Laravel base URL from `--dart-define=LARAVEL_API_URL` → `.env` `LARAVEL_API_URL` → debug default `http://10.0.2.2:8000`; add the key to `.env` (there is no `.env.example` today; create one and list all non-secret keys). Note `.env` is bundled as an asset — only non-secret values (the URL) belong there; the existing TMDB key handling stays as-is.
- [x] `config/migration_flags.dart` — per-feature booleans from `--dart-define=FLIXQUEST_MIGRATION` (default: none).
- [x] `storage/kv_store.dart` — namespaced wrapper over `SharedPreferencesSingleton` (typed get/set, `removePrefix`, JSON helpers)
- [x] `storage/secure_token_store.dart` — `flutter_secure_storage` wrapper with `read/write/clear`; constructor-injectable storage backend for tests.
- [x] `time/server_clock.dart` — `recordServerTimeUtc(int)`, `offsetMs`, `nowUtcMs()`, `toServerMs(DateTime)`; offset persisted in `KvStore`.
- [x] `di/injector.dart` — one `Future<AppInjector> buildInjector()` returning an `AppInjector` object holding clients/stores; repositories and Provider wiring are added by their owning phases. No service locator package.

**F0.3 First Freezed DTOs**
- [x] `lib/data/models/app_user.dart` (fields from `UserResource`).
- [x] `lib/data/models/api_error.dart` (`code/message/errors/retryAfter/clockSkew`).
- [x] One smoke Freezed union (`Result`/`Failure`) with round-trip tests.

**F0.4 Test harness**
- [x] `test/support/fake_dio.dart` — scripted `HttpClientAdapter` (queue of `Response`, records requests, can throw `DioException`).
- [x] `test/support/fakes.dart` — `FakeSecureTokenStore`, `FakeKvStore`, `FakeServerClock`.
- [x] `test/support/fixtures/` — auth/user/bootstrap/ads/sync JSON fixtures copied from backend Pest expectations (sanitized).

**F0.5 Verification & docs**
- [x] `analyze` = 0; all pre-F0 passing tests preserved, with the same two pre-existing failures.
- [x] `build_runner` produces generated output kept in the worktree and a second run is a no-op.
- [x] Short doc `docs/flutter_architecture.md` describing the layers/DI/testing conventions (kept small).

### Exit criteria
No behavior change; `dio`, Freezed, secure storage, core primitives, DI and the test harness exist and are unit-tested; the measured existing suite is untouched.

### F0 verification report — 2026-10-03

**Branch:** `feat/laravel-f0-foundation`. No commits, pushes, or PRs were created.

- Added direct Dio, secure storage, Freezed/JSON dependencies and codegen configuration.
- Added environment/flags, Result/Failure, JSON readers, namespaced KV storage,
  secure token storage, persisted server clock, separate public/Laravel clients,
  and injectable lifecycle ownership. Runtime phone/TV providers still use their
  existing paths; the cache engine and feature interceptors belong to F1/F2.
- Added `AppUser`, `ApiError` and nested clock-skew DTOs; all 8 generated files are
  present. Added scripted HTTP/store/clock fakes and sanitized backend fixtures.
- Added architecture and fixture-origin documentation. The ignored local `.env`
  now includes the development Laravel URL; `.env.example` contains placeholders.

| Verification | Result |
|---|---|
| Pre-F0 analysis | 0 issues |
| Pre-F0 full suite | 95 test files; 761 passing / 2 failing (763 executed) |
| New foundation tests | 11 test files; 28/28 passing |
| Final analysis | 0 issues |
| Final full suite | 106 test files; 789 passing / the same 2 failing (791 executed) |
| Live Laravel smoke via Herd | 1/1 passing: bootstrap, ETag/304, ads, messages, profile 401 |
| Repeated `build_runner` | 0 outputs; all 8 generated file hashes unchanged |
| Diff whitespace check | clean |

The complete suite remains red solely because of the pre-existing
`player_menu_route_test.dart` and `subtitle_options_test.dart` failures already
recorded in the handover. Those files and all other existing tests are untouched.
This report verifies F0 against the measured baseline; it does not claim a fully
green global suite. No backend source changes or device interaction were needed.

Reproduce the explicit read-only backend smoke with:

```bash
.fvm/flutter_sdk/bin/flutter test integration/laravel_foundation_smoke_test.dart \
  --dart-define=LARAVEL_SMOKE_URL=http://flixquest-backend.test
```

No app restart or backend setup is required for F0. Configure a device-reachable
Laravel URL when wiring feature cutovers. F1 is the next phase; work stops here as
specified by the phase boundary.

### Rollback
Revert the phase branch. Nothing in the running app imports the new code yet.

---

## Phase F1 — Network stack + API response cache (TMDB & scraper)

### Goal
Every TMDB metadata call and every cache-safe scraper call goes through one Dio client with a persistent, policy-driven response cache. Stream endpoints remain uncached and untouched.

### Milestones

**F1.1 Dio foundation**
- [x] `core/network/dio_factory.dart`: `createPublicDio(...)` and `createLaravelDio(...)`.
- [x] `HeaderInterceptor` (Accept, gzip, platform UA), `RetryInterceptor` (GET + idempotent only; 2 retries; 300 ms × 2ⁿ; gives up on 4xx), `LoggingInterceptor` (debug builds only, redacts tokens), `ErrorInterceptor` (`DioException` → `Failure`).
- [x] `TmdbProxyInterceptor` — centralizes the current `?destination=$proxyUrl` logic from `lib/functions/network.dart`; applies only to TMDB hosts.
- [x] Keep the existing `retryOptions` behavior semantics (`SocketException`/`TimeoutException` retried).

**F1.2 Response cache**
- [x] `core/cache/cache_policy.dart` + `cache_policies.dart` (exact table in §1.6).
- [x] `core/cache/response_cache_store.dart` — sqflite `flixquest_http_cache_v1.db`, schema + migrations, memory LRU, `get/put/touch/evict/clearScope/clearAll/sizeBytes`, `pruneExpired()`.
- [x] `core/cache/cache_interceptor.dart` — fresh-hit, conditional revalidation, stale-serve-on-failure, `refreshStale` background mode, in-flight dedupe, cache-key normalization (sorted params, strip `api_key`/`destination`), `auth_scope`, and `extra['cache']` diagnostics.
- [x] Unit tests for store + interceptor with the fake adapter: fresh/stale/expired, ETag 304, offline fallback, non-GET bypass, error-status bypass, scope clearing, concurrent dedupe, API-key rotation, param-order normalization.

**F1.3 TMDB migration**
- [x] `data/sources/tmdb_api.dart` — `getJson(String url, {CachePolicy policy})` (URLs still built by `Endpoints`).
- [x] `data/repositories/tmdb_repository.dart` — thin wrapper used by `network.dart` and `catalog/*`.
- [x] Rewrite `lib/functions/network.dart` internals to delegate (public function signatures unchanged). All `fetchMovies/fetchTV/fetchGenre/...` call sites are automatically cached.
- [x] Route `lib/catalog/title_logos.dart` and `lib/widgets/app_logo.dart` through Dio + long TTL.
- [x] Tests: the second identical `fetchMovies` call hits cache (fake adapter called once); offline second call returns cached data; proxy still applied; `TMDB_API_KEY` rotation served from cache.

**F1.4 Scraper migration**
- [x] Refactor `video_providers/scraper_api.dart` onto Dio with per-endpoint policies. Stream/`stream-size` requests set `CachePolicy.noStore`.
- [x] `providers`, `providers/status`, `subtitles/search` cached per §1.6.
- [x] Tests: stream endpoints never cached; providers cached; 60 s stream timeout preserved; existing `test/scraper_api_test.dart` migrated to the Dio seam.

**F1.5 Cache management**
- [x] `HttpCache.pruneExpired()` at boot (idle).
- [x] Existing Settings clear-cache action also clears HTTP responses. No additional size row was added (optional).
- [x] Bounded cache: max 5 000 entries / 50 MB, LRU eviction.

**F1.6 Verification**
- [x] No new full-suite failures against the measured baseline; `test/tv_*.dart` green.
- [ ] Manual: fetch Home, kill network, relaunch → cached rows render; Play still loads streams (uncached).

### Exit criteria
No new network call bypasses Dio in touched files; TMDB and safe scraper GETs are served from a persistent cache with offline fallback; analyze 0; no new failures against the measured suite baseline. Device smoke remains a user-run check.

### F1 verification report — 2026-10-03

**Branch:** `feat/laravel-f1-cache`, based on the user's committed F0. No commits,
pushes, PRs, backend edits or device interaction were performed.

- Selected `dio_cache_interceptor` for HTTP validation/serialization (D3).
  FlixQuest adds the endpoint TTL registry, SQLite persistence, bounded memory LRU,
  user namespaces, normalized keys, background refresh and shared in-flight GETs.
- Wired the shared injector/Provider and legacy network bridge at boot. Phone and
  TV use the same TMDB/scraper engine. Public TMDB function signatures and DTO
  parsing remain compatible; title logos and validated remote SVGs use Dio.
- Migrated all nine existing scraper tests and the existing logo/TV browse seams
  to injected Dio, preserving their assertions. Streams/size requests bypass the
  cache, with stream/subtitle timeouts preserved. Vix retains its original single
  attempt; metadata gets the planned two retries instead of unbounded retries.
- Added tests for fresh/stale/expired responses, ETag 304 (both Dio status paths),
  offline fallback after SQLite reopen, API-key/proxy/query normalization,
  non-GET/error/no-store bypass, user clearing, concurrent cancellation, background
  refresh, in-flight clearing/retries, entry/byte bounds and LRU timestamp ties.
- Herd smoke now also verifies automatic bootstrap revalidation returns the
  cached JSON after Laravel's 304. No backend source changes are required.

| Verification | Result |
|---|---|
| New F1 tests | 6 files; 45/45 passing |
| Final analysis | 0 issues |
| Final full suite | 112 files; 834 passing / the same 2 existing failures (836 executed) |
| TV tests (`test/tv_*.dart`, within full suite) | 129/129 passing |
| Live Herd smoke | 1/1 passing, including automatic bootstrap ETag revalidation |
| Repeated `build_runner` | 0 outputs; all 10 tracked generated files unchanged from F0 HEAD |
| Diff whitespace check | clean |

The two existing failures remain `player_menu_route_test.dart` (episodes route)
and `subtitle_options_test.dart` (incoming subtitle order). Neither file was
modified, skipped or weakened. A playback-loader layout test now uses its existing
fake-ad seam so the newly asynchronous Dio transport does not leave timers pending;
all its layout assertions and test names are preserved.

F1's automated implementation is complete. The device check below remains
unchecked, and work stops at this phase boundary.

User-run device smoke (no device access by the agent):

1. After fetching dependencies, hot restart with **R**. Browse Home and title
   details online on phone and TV.
2. Disable networking, close/relaunch the app, and confirm previously visited
   metadata renders from SQLite within the configured offline limit.
3. Restore networking and play a movie/TV episode; confirm stream extraction still
   runs. Use Settings → Clear cache, restart offline, and confirm HTTP rows have
   been cleared.

The deterministic offline/restart test verifies the persistence path; it does
not claim this device smoke was performed. F2 auth is the next phase.

### Rollback
Revert. Firebase paths are untouched in this phase.

---

## Phase F2 — Auth, session & account screens

### Goal
Replace `firebase_auth` and the raw Firestore profile reads with Laravel Sanctum sessions and a typed `AppUser`, on phone and TV, including guest browsing.

### Milestones

**F2.1 Data layer**
- [x] Freezed DTOs: `AppUser`, `AuthSession {token, user}`, `RegisterRequest`, `LoginRequest`, `UpdateProfileRequest`, `ChangePasswordRequest`, `ChangeEmailRequest`.
- [x] `data/sources/laravel_api.dart` — all auth/profile endpoints from §2; central envelope parsing; `Failure` mapping incl. `requires_password_setup`, 409 Google conflict, 403 disabled, 429 throttle with `Retry-After`.
- [x] `data/repositories/auth_repository.dart` — thin methods returning `Result<T>`.
- [x] Tests: repository contract with fixtures for every status above; token never logged.

**F2.2 Session**
- [x] `presentation/session/session_view_model.dart` — Freezed `SessionState {initializing, guest, authenticated(AppUser), expired}`.
  - `restore()` at boot: token present → `GET /user/profile`; 401 → clear + guest.
  - `signIn`, `signUp` (then guest-data merge hook, wired in F5), `signInWithGoogle(accessToken)`, `signOut`, `deleteAccount`.
  - Persist token in `SecureTokenStore`; expose `ValueNotifier<String?>` for owner-key consumers.
- [x] `AuthInterceptor` attaches `Authorization: Bearer`; on 401 clears token and flips state to `expired` once (no retry storm).
- [x] Rebuild `AuthSessionController` as an adapter over `SessionViewModel` (`userId` ValueNotifier, `setAuthenticatedUserId` no-op shim) so untouched screens keep compiling.
- [x] Owner namespace decision: persisted owner id becomes `user:<laravelId>`; old `user:<firebaseUid>` local rows are left in place and handled by the F5 merge (never silently reused).

**F2.3 Google Sign-In**
- [x] `google_sign_in` → `accessToken` (fallback `idToken`) → `POST /auth/google` `{access_token}`.
- [x] Handle 409 with a clear message: "This email already has a password account. Sign in with your password first." (backend does not auto-link).
- [x] Keep `GoogleSignIn.signOut()` on sign-out; remove `FirebaseAuthProvider` credential code.
- [x] Tests with a fake Google client.

**F2.4 Screens (phone + TV)**
- [x] Phone: `landing_screen.dart`, `login_screen.dart`, `signup_screen.dart`, `forgot_password.dart`, `password_change.dart`, `email_change.dart`, `delete_account.dart`, `edit_profile.dart`, `sync_screen.dart`, `my_flixquest_screen.dart`, `user_state.dart`/`auth_navigation_service.dart` wiring.
- [x] TV: `tv_landing_screen.dart`, `tv_auth_screen.dart`, `tv_profile_screen.dart`.
- [x] Replace every raw Firestore `users` read (`edit_profile`, `email_change`, `delete_account`, `tv_profile_screen`, `my_flixquest_screen`) with `SessionViewModel`/`AuthRepository`.
- [x] Forgot password uses `POST /auth/forgot-password`; the email links to the backend web form — no in-app token screen is needed.
- [x] Username availability uses `GET /users/check-username`.
- [x] Delete account: `DELETE /user/account` + local wipe (existing local wipe logic reused).
- [x] Remove `FirebaseAuth` imports from all touched screens; `firebase_auth` stays in `pubspec.yaml` until F7.
- [x] Widget tests: login success/401, signup username taken, forgot flow, expired session routes to landing, TV auth smoke, guest browse.

**F2.5 Backend-first verification**
- [ ] On staging, log in with a migrated Firebase-Scrypt account; confirm `users.password` became `$2y$…` after first login and the second login is Bcrypt (backend Pest already covers this; the client test proves the request shape).
- [x] Confirm 401 from a revoked token (password change) routes the app to landing.

### Exit criteria
No `firebase_auth` or Firestore-profile call remains on the auth/profile/TV paths; sessions persist across restarts; expired tokens log out cleanly; suite green.

### F2 verification report — 2026-10-03

**Branch:** `feat/laravel-f2-auth`, based on the user's committed F1. No commits,
pushes, PRs, backend source changes or device interaction were performed.

- Added typed auth requests/session, the Laravel auth repository, Google token
  exchange, secure token persistence, profile persistence, and a shared session
  gate for phone and TV. Account endpoints explicitly bypass HTTP caching.
- Boot validates a stored token against `/user/profile`; an offline boot can use
  only the profile matching its persisted Laravel owner. Guest browsing requires
  no request or anonymous account. Owners use `user:<laravelId>`.
- Protected 401 responses expire the session once and dismiss account routes.
  Public login failures do not expire a current session. Revision checks prevent
  late storage reads, writes, logout responses, or old-token rejections from
  overwriting a newer login. Password changes clear the revoked session;
  email changes retain it, matching the actual backend contract.
- Migrated the specified phone/TV auth and profile routes. Username checks and
  password-reset emails use Laravel. Profile editing uses `AppUser` and updates
  the mounted account header. Account deletion wipes local libraries and the
  deleted Laravel owner's wellness rows, then reloads the providers.
- Preserved all 15 original auth/profile files under `lib/legacy/firebase_auth/`;
  verified their bodies match F1 exactly apart from imports. Public routes choose
  them when the auth flag is off. With Laravel auth enabled, Firebase sync cannot
  run; libraries remain local until F5. Legacy Firebase and guest wellness rows
  stay separate and are not silently merged into Laravel owners.

| Verification | Result |
|---|---|
| New F2 tests | 7 files; 70/70 passing (including 8 widget flows) |
| Final analysis | 0 issues |
| Full suite | 119 files; 904 passing / the same 2 existing failures (906 executed) |
| Herd backend auth tests | 29/29; 128 assertions, including first Scrypt login → Bcrypt and second login |
| Backend account/reset compatibility tests | 42/42; 212 assertions across `MigrationReadinessTest`, `MobileCompatibilityTest`, and `PasswordResetTest` |
| Live Herd read-only checks | username availability 200; unauthenticated profile 401 |
| Generated files | 5 new Freezed/JSON files; all 10 pre-existing generated files unchanged |
| Diff whitespace check | clean |

The existing failures remain `player_menu_route_test.dart` (episodes route) and
`subtitle_options_test.dart` (incoming subtitle order). Neither file was modified,
skipped or weakened. The backend tests use the configured isolated SQLite
in-memory test database; no real accounts were created or changed.

F2's automated implementation is complete. The migrated-account staging login
and phone/TV device checks remain pending; no staging credentials were provided.
The fake Google plugin verifies access-token preference, ID-token fallback,
cancellation, and logout; an actual Google login still needs device verification.
The backend's Socialite exchange expects an OAuth access token, so the ID-token
fallback has only been verified at the client request boundary.

User-run smoke (no device access by the agent):

1. Start a phone/TV build with `--dart-define=FLIXQUEST_MIGRATION=auth` and
   `--dart-define=LARAVEL_API_URL=<reachable backend URL>`. Herd's local `.test`
   hostname needs a reachable host/network address on a physical device.
2. Sign in with a migrated account; verify the backend password becomes `$2y$…`
   after the first login and confirm the second login. Close/relaunch the app and
   confirm the session restores. Check Google sign-in and the password-account
   conflict message on a supported device.
3. Edit the profile and email, send a password-reset email, and complete its
   backend web form. Change the password and confirm the app returns to landing.
   Check local guest browsing offline. Use a disposable account for deletion.
4. Restart with `auth` removed from the migration flag and verify Firebase
   rollback. Cloud sync under Laravel remains unavailable until F5.

Work stops at F2; F3 config bootstrap is the next phase.

### Rollback
`migration_flags.auth` off → old Firebase auth path still present until F7 (do not delete Firebase auth code in F2; delete in F7).

---

## Phase F3 — Config source selection & seasonal themes

### Goal
Let Laravel choose Firebase Remote Config or Laravel bootstrap configuration on every refresh, with ETag validation and offline snapshots, keeping `AppDependencyProvider` as the single consumer. Retain `firebase_remote_config` and both provider implementations after cutover.

F3.1–F3.4 below record the original bootstrap implementation and verification.
The 2026-10-04 user decision adds F3.5, implemented below. It replaces the
original build-time routing and one-hour resume throttle with the runtime
behavior in §1.10.

### Prerequisite (backend repo)
- [x] **G3:** add `hosted_banner_mode`, `startio_banner_enabled`, `startio_interstitial_enabled`, `startio_interstitial_interval_seconds`, `startio_tv_interstitial_mode` to `AppConfigurationSeeder` and the `ads` block of `ConfigController@bootstrap`; ship seed tests.

### Milestones

**F3.1 DTOs & repository**
- [x] Freezed `BootstrapConfig` with `FeaturesConfig`, `BrandingConfig`, `UpdateConfig`, `NetworkConfig`, `AdsConfig`, `BannerDisplayConfig`, `OccasionalThemeCatalog` + `OccasionalTheme` + `ThemeEffect`.
- [x] Parsing must preserve the exact v2 semantics in `docs/firebase_remote_config.md`: aliases (`xmas`, `ethiopian-new-year`, `enkutatash`, `valentine`…), `starts_at`/`ends_at`, priority, `user_selectable`, `default_theme_id`, `active_theme_id`, dual-color `colors[]` entries, `effect.enabled`, `effect_type` list, presets for invalid entries.
- [x] `data/repositories/config_repository.dart` — `GET /config/bootstrap` with ETag persisted in `KvStore` (`config.bootstrap.etag`), raw JSON persisted under the existing `AppDependencies` keys (`FLIXQUEST_LOGO_URL`, `FLIXQUEST_API_URL(S)`, `TMDB_PROXY`, `OCCASIONAL_THEME*`, update keys) so rollback and offline boot keep working.
- [x] `RefreshController`: refresh on boot, on app resume if older than 1 h, and after a push-data config hint; 304 keeps the persisted payload.
- [x] Tests: parse fixture from the backend contract test; 304 path; offline uses last payload; empty cache uses safe defaults (`features.* = true`); theme window/priority/alias parity tests ported from `test/occasional_theme_provider_test.dart`.

**F3.2 Consume in `AppDependencyProvider`**
- [x] Replace `AppRemoteConfig.apply(config, provider)` with `BootstrapViewModel` pushing into the existing setters (`setBannerConfigs`, `setBannerAdNetwork`, `setHostedBannerMode`, `setUnityAdsConfig`, `setStartIoAdsConfig`, `setFlixquestApiConfig`, `setUpdateConfiguration`) — this is the single choke point identified in `lib/provider/app_dependency_provider.dart`.
- [x] TMDB key: keep `TMDB_API_KEY` runtime setter in `lib/constants/api_constants.dart`; bootstrap supplies the same key as Remote Config did.
- [x] `bootstrap` also feeds the **network config** (scraper instances list) used by `HostedAdsRepository`/`ScraperApi` callers.
- [x] Original implementation: rewire `flixquest_main.dart` `_initConfig` to the bootstrap controller and isolate Firebase setup in its own controller. **Revised retention:** keep `firebase_remote_config` and the Firebase controller in F7 and beyond; F3.5 selects between both at runtime.

**F3.3 Theme engine**
- [x] Keep `AmbientThemeService` and the particle overlay; feed them from the new catalog.
- [x] Preserve user selection persistence and boundary timers; honor server-computed `active_theme_id` (the backend already resolves windows/priority).
- [x] Tests: existing theme tests migrated 1:1; add offline theme boot.

**F3.4 Verification**
- [ ] Airplane-mode cold boot: cached config renders, features default true, no blank screens.
- [ ] Change a feature toggle in Filament → refresh → app reflects it; ETag 304 on second launch (verify via logs).

**F3.5 Server-controlled source selection (implemented; before F6)**

- [x] Backend: add `config_source` (`firebase`/`laravel`) to configuration storage, seeder, Filament and `GET /config/bootstrap`; include it in the ETag. Default migrated environments to `laravel`, with an operator-editable choice.
- [x] Extend the bootstrap DTO/repository and add one runtime source-selection controller implementing §1.10. Revalidate Laravel on every boot/resume/config refresh, including Firebase realtime hints; the previous one-hour resume throttle must not hide selector changes.
- [x] Keep the Firebase SDK, `AppRemoteConfig` mapping and Firebase controller as a supported provider, alongside the Laravel provider. Both feed the same phone/TV `AppDependencyProvider`; Laravel alone chooses which snapshot applies.
- [x] Cache the valid server decision and source snapshots independently; use matching last-good config offline, and safe bundled defaults on a first offline launch. Prevent late updates from the previous source from applying.
- [x] Tests: both server choices, switching in both directions without rebuilding, selector-only ETag changes, 304, every-resume revalidation, offline/invalid-response retention, first-launch defaults, old-source race rejection, schema/theme parity and phone/TV behavior.
- [ ] Manual smoke: change `config_source` in Filament and resume the same phone/TV build to switch both directions; then verify offline boot. Confirm Crashlytics/Analytics still report only through their existing Google SDK paths.

### Exit criteria
Laravel selects the source on every refresh; Firebase and Laravel config both work on phone/TV without rebuilding; offline boot uses the last valid server selection and matching snapshot; Crashlytics/Analytics remain intact; analyze 0; suite preserves the documented baseline.

### F3.5 implementation handover — 2026-10-04

Implemented on `feat/laravel-f3-config-source`, continuing the committed F5 work.
F6 had not started at this handover. No commits, pushes or PRs were created.

- Laravel bootstrap now returns `data.config_source`. `AppConfigurationSeeder`
  creates a `laravel` default without replacing an operator's existing choice.
  Filament uses a Firebase/Laravel select and restricts the setting to string;
  model writes also reject unsupported providers/types. Source edits invalidate
  the bootstrap cache and ETag.
- `ConfigSourceController` implements the shared lifecycle contract. Every boot,
  resume, explicit `refresh()`, FCM config hint and Firebase realtime hint first
  revalidates Laravel. Concurrent HTTP validations coalesce; a hint during one
  schedules another validation. An old Firebase fetch cannot block a Laravel
  switch or apply/persist its response after the decision changes or disposal.
- Profile/release builds always use this controller. Debug builds enable it with
  the development `config` migration flag; omitting that flag keeps the legacy
  Firebase development rollback. No build flag chooses the production provider.
- The bootstrap snapshot stores the valid decision, Laravel settings and matching
  ETag. Firebase's normalized snapshot has its own `config.firebase.snapshot` key.
  Invalid/missing choices preserve the last valid decision and validator; an
  orphaned 304 retries unconditionally. Offline hydration uses the selected
  provider's snapshot, or bundled defaults when its cache/decision is absent.
  Laravel candidates do not write Firebase-selected legacy preferences.
- `SdkFirebaseConfigSource` retains `AppRemoteConfig.configure`, maps published
  flat Firebase keys through the same bootstrap DTO, and preserves `enable_ott`,
  legacy logo, banner and theme schema compatibility. SDK defaults cannot mask
  published legacy keys. An empty successful template restores bundled defaults;
  unavailable or malformed Firebase payloads retain the selected Firebase cache.
- Both providers use the same phone/TV mapper. Network/ads/branding/features are
  replaced as a whole snapshot. A theme omitted by the current provider resolves
  automatically while its saved user selection and effect preferences survive
  source changes and cold restarts. The deployment Laravel URL is independent
  of either provider's scraper/proxy settings.
- Crashlytics, Google Analytics, native reporting setup, existing event calls and
  Mixpanel remain unchanged. No Laravel crash/analytics submissions were added.

Files added: `lib/data/sources/firebase_config_source.dart`,
`lib/presentation/config/config_source_controller.dart`,
`test/presentation/config_source_controller_test.dart`, and backend
`tests/Feature/ConfigSourceTest.php`.

Files updated: bootstrap DTO and its two generated files, config repository,
shared bootstrap/lifecycle mapper, `main.dart`, `flixquest_main.dart`,
`AppDependencyProvider`, the existing refresh test (one-for-one replacement of
hourly throttle coverage), and the shared bootstrap fixture in both repositories.
Backend changes are in `ConfigController`, `AppConfiguration`,
`AppConfigurationForm`, and `AppConfigurationSeeder`. Existing backend F3/F4/F5
uncommitted work was retained.

Verification:

| Check | Result |
|---|---|
| Flutter analyze | 0 issues |
| Full Flutter suite | 141 files, 996 executed: 995 passed, 1 existing failure (`subtitle_options_test.dart`, incoming preference order). The known player-menu test passed this run. Neither known test was edited, skipped or weakened. |
| New config-source/SDK tests | 21 passed; real repository, DTO, mapper/provider and preference storage, with only HTTP transport and Firebase SDK boundaries faked |
| Existing refresh-controller tests | All 6 retained; one hourly-throttle test migrated one-for-one to every-resume validation |
| Backend full suite | 229 passed, 1,115 assertions, using isolated test databases |
| Backend formatting | Pint passed; only the new selector form/test needed formatting |
| Live Herd bootstrap | Read-only HTTP 200 with `config_source: laravel`, then conditional 304; no real database seeding or account writes |
| Code generation | Successful final build, 0 outputs written. Of 19 tracked generated files, only the two bootstrap DTO outputs differ from pre-F3.5; the other 17 hashes are unchanged. |

No phone/TV device or Google reporting smoke was run. `test/_preview/` was not
created; nothing is committed.

Manual smoke remains unchecked. Apply the backend configuration seeder when
updating the target environment (`herd php artisan db:seed
--class=AppConfigurationSeeder --no-interaction` from the backend). For a debug
build include `config` in `FLIXQUEST_MIGRATION`; press **R** in the existing
Flutter terminal. Change `config_source` in Filament and resume the same phone/TV
build in both directions, then test offline boot. Confirm existing Google
reporting/consent behavior. No device run/install/input was performed here.

### F3 verification report — 2026-10-03 (original implementation)

Historical results below do not verify the new F3.5 selector. References to the
config migration flag describe the original development path. Firebase Remote
Config is now retained permanently rather than removed in F7.

**Branch:** `feat/laravel-f3-config`, based on the user's committed F2. The
Laravel G3 prerequisite is implemented in the backend checkout. No commits,
pushes, PRs, real database seeding, or device interaction were performed.

- Added typed bootstrap DTOs, a config repository, a bootstrap view model, and
  one controller for boot/resume/push refresh. `AppDependencyProvider` remains
  the consumer for phone, tablet and TV, including scraper instances, TMDB
  key/proxy, updates, banner display rules, and Start.io pacing.
- Hydrates the persisted snapshot before rendering and fetches asynchronously
  at boot. Resume refreshes after one hour; `type=config_updated`,
  `type=config_refresh`, or `refresh_config=true` FCM data requests an immediate
  refresh. Concurrent lifecycle calls share a request; a hint during a request
  schedules another validation. Disposed controllers ignore late UI updates.
- The repository owns its persistent payload/ETag pair and bypasses the HTTP
  response cache to avoid competing validators. It mirrors the ETag at
  `config.bootstrap.etag` and config into existing `AppDependencies` keys.
  A 304 retains the payload; transport/envelope failures retain the snapshot.
  Without a Laravel snapshot, offline startup reads legacy config and defaults
  all features to true. Invalid seasonal updates retain the previous catalog
  while valid feature changes apply. Empty backend catalogs are supported.
- Kept the existing theme engine, ambient service, particle overlay, selection
  persistence and boundary timers. DTOs use the same parser for aliases,
  custom dual-color palettes, presets, effects, dates and priority. A server
  active theme guides automatic selection until the next local boundary;
  explicit user selection still wins. The original theme/provider tests are
  retained unchanged, preserving every assertion 1:1, with additional Laravel
  DTO parity and offline restart coverage.
- Removed Firebase Remote Config setup/listeners from `flixquest_main.dart`.
  The isolated `lib/legacy/firebase_config_controller.dart` retains the
  `AppRemoteConfig` rollback when the config migration flag is off. Firebase
  Auth/Firestore cleanup remains scheduled for F7; Remote Config, Crashlytics,
  Analytics and Messaging are retained. F4 hosted-ad transport is unchanged.
- Backend G3 adds the five hosted/Start.io fields to the bootstrap response and
  default seeder. Defaults keep Start.io disabled and use hosted `stack` mode.
  Seed tests verify operator values survive reseeding. Both repositories keep
  the same sanitized fixture, verified by Laravel's exact JSON response test
  and Flutter's typed parser.

| Verification | Result |
|---|---|
| New F3 tests | 5 files; 31/31 passing |
| F3 plus retained theme/provider tests | 49/49 passing; 18 existing tests unchanged |
| Final analysis | 0 issues |
| Full suite | 124 files; 935 passing / the same 2 existing failures (937 executed) |
| Herd backend config tests | 22/22; 244 assertions across `BootstrapAdsConfigTest` and `ConfigBootstrapTest` |
| Live Herd read-only checks | bootstrap 200 with all five G3 fields; conditional GET 304 with empty body |
| Code generation | two new outputs; repeat build wrote 0 outputs; all 15 pre-existing generated files unchanged |
| Diff whitespace checks | clean in both repositories |

The existing failures remain `player_menu_route_test.dart` (episodes route) and
`subtitle_options_test.dart` (incoming subtitle order). Neither file was changed,
skipped or weakened. The four repository lint fixes after the full run only
added braces; final analysis and all 49 focused tests passed afterward.
The backend tests used the isolated SQLite in-memory test database. No real
configuration, theme or account was created/changed. `test/_preview/` is absent;
no visual/device previews were performed because the phase keeps the existing
mobile/TV theme rendering. F3's automated implementation is complete; the two
manual F3.4 checks remain pending.

Flutter files added: `lib/data/models/bootstrap_config.dart` and its two
Freezed/JSON outputs; `lib/data/repositories/config_repository.dart`;
`lib/presentation/config/bootstrap_view_model.dart`;
`lib/presentation/config/refresh_controller.dart`;
`lib/legacy/firebase_config_controller.dart`; five test files under `test/data`,
`test/presentation` and `test/core`; `test/support/fixtures/bootstrap_config.json`.
Changed: `lib/core/di/injector.dart`, `lib/main.dart`, `lib/flixquest_main.dart`,
`lib/models/occasional_theme.dart`, `lib/services/in_app_messaging_service.dart`,
and this plan. No files deleted.

Backend files changed: `app/Http/Controllers/Api/V1/ConfigController.php` and
`database/seeders/AppConfigurationSeeder.php`. Added:
`tests/Feature/BootstrapAdsConfigTest.php` and
`tests/Fixtures/bootstrap_config.json`. Existing unrelated backend changes
remain untouched.

User-run smoke (pending; no device access by the agent):

1. Start a phone/TV build with `--dart-define=FLIXQUEST_MIGRATION=auth,config`
   and `--dart-define=LARAVEL_API_URL=<reachable backend URL>`. A changed
   dart-define requires restarting the Flutter process; **R** suffices only
   if the running process already has these defines. Do not use Herd's local
   `.test` hostname on a physical device unless it resolves there.
2. Confirm online bootstrap, updates, scraper selection and seasonal theme;
   choose another available theme and turn its effects off. Disable networking,
   close/relaunch and confirm config and user preferences are retained.
3. Change a feature in Filament, resume after an hour or send the documented
   config hint, and confirm the provider updates. Relaunch unchanged config
   and confirm an HTTP 304 in the debug network logs.
4. For admin editing, run `herd php artisan db:seed --class=AppConfigurationSeeder`
   in the backend checkout on the intended environment to create the five
   new settings. The API supplies safe defaults
   even before seeding; no real database was seeded during this phase.
5. Remove `config` from the migration flag to verify the Firebase rollback.

Original F3 work stopped before F4. F3.5 is implemented; its device smoke remains open before production cutover.

### Rollback
Current debug development rollback: `migration_flags.config` off uses `AppRemoteConfig`.
With F3.5, operators switch `config_source` in Laravel to select Firebase or
Laravel config; retain both providers after F7. A code regression may still
require reverting the app version.

---

## Phase F4 — Ads cutover & placement reconciliation

### Goal
Serve all hosted banners from Laravel, track impressions/clicks, and delete the scraper `/ads` path — without losing a single revenue slot.

### Prerequisite (backend repo)
- [x] **G1:** extend `BannerPlacement` with every live client placement (list below) and add them to the Filament multi-select; deploy before the client switches.
  `home_all_hero`, `home_all_trending`, `home_all_genres`, `home_movies_hero`, `home_movies_trending`, `home_movies_genres`, `home_series_hero`, `home_series_trending`, `home_series_genres`, `movie_list`, `tv_list`, `streaming_movies`, `streaming_tv`, `movie_detail`, `tv_detail`, `season_detail`, `episode_detail`, `collection_detail`, `person_detail`, `bookmarks`, `downloads`, `new_and_hot`, `stream_loading`, `live_tv_top`, `live_tv_list_a`, `live_tv_list_b`, `live_tv_list_c`, `discover_movies`, `discover_tv`, `genre_movies`, `genre_tv`, plus TV tags `title_detail_tv`, `live_tv_strip_tv`.
- [x] Compatibility policy: keep both sets (recommended assumption; no aliases). Legacy `home_movies`/`home_tv` campaigns remain separate from new `home_*_*` slots. Production deployment remains a rollout prerequisite.

### Milestones

**F4.1 Ads data layer**
- [x] `BannerAdDto` Freezed; `AdsRepository` (one shared `GET /ads` fetch per app session, 5 min fresh / 24 h stale via cache; local `appliesTo` filtering unchanged, so one fetch serves every slot).
- [x] `reportImpression(id)` / `reportClick(id)` — fire-and-forget with an offline queue in SQLite (`ad_events`: id, ad_id, type, created_at, sent); flush at boot and on reconnect; drop events older than 7 days.
- [x] Tests: shared fetch, queue flush, dedupe impression per ad per screen view, click on tap, 404 tolerated.

**F4.2 Widget refactor**
- [x] `HostedAdsRepository` delegates to `AdsRepository` (keep `useFetcherForTesting`); `RemoteHostedAdsBanner` behavior unchanged (carousel, `HostedBannerMode`, Start.io coexistence).
- [x] Add visibility-based impression (≥50% visible for ≥1 s, once per ad per mount) and click reporting in `HostedAdsBanner._open`.
- [x] Port `test/hosted_ads_coexistence_test.dart` and the placement-matching tests.

**F4.3 Scraper cleanup**
- [x] Delete `ScraperApi.getAds()` and its parsing code (`lib/video_providers/scraper_api.dart`).
- [x] Remove active scraper ads references; retain the isolated flag-off rollback below. No scraper-specific ads fixture existed. The scraper repo's `/ads` removal is backend Phase 2 (separate repo, coordinate).
- [x] Add a regression test that no `RemoteHostedAdsBanner` placement string is missing from a checked-in placement manifest (`lib/data/ads/placements.dart`), and a test that compares it to the backend enum values copied into `test/support/fixtures/banner_placements.json`.

**F4.4 Verification**
- [ ] Filament shows impression/click increments from a debug device.
- [ ] Every placement renders its intended ad or nothing (never a broken slot); TV `_tv` tags still match.
- [x] `grep -rn "getAds" lib` returns nothing.

### Exit criteria
Hosted ads come exclusively from Laravel; impressions/clicks recorded; placement manifest matches backend; scraper no longer serves ads from the client's perspective.

### F4 implementation handover (2026-10-04)

Implemented on `feat/laravel-f4-ads`; neither repository committed or pushed.
The `ads` flag selects Laravel independently of `auth` and `config`. All slots
share the unfiltered catalog; their existing placement matching, coexistence
modes, carousel and TV interaction rules remain intact. The backend and client
manifest contain 36 tags: 33 shipped placements plus three legacy tags.

The SQLite queue records impressions/clicks before delivery, serializes flushes,
retries at boot/reconnect/resume and on new events, expires rows after seven
days, and acknowledges 404s for deleted campaigns. Throttling and server errors
retain pending rows. Impressions require a loaded creative, at least 50%
visibility for one continuous second, foreground/current-route eligibility,
and deduplicate each ad for the carousel's mounted lifetime. API counters do
not accept idempotency keys: an accepted request whose response is lost can
be retried, so delivery is at least once rather than exactly once.

The rollback requirement takes precedence over deleting every scraper reference:
`ScraperApi.getAds()` and its import are removed, while the temporary fallback
lives in `lib/legacy/scraper_ads_fetcher.dart` until F7. The existing `ads.json`
is a Laravel fixture and is retained. The scraper repository is untouched.
The original 18 coexistence/matching tests are preserved without changes.

| Verification | Result |
| --- | --- |
| Flutter targeted checks | 48 passing (15 new F4 tests plus retained ads, scraper and injector coverage) |
| Flutter analysis | No issues |
| Full Flutter suite | 130 files; 950 passing / the same 2 existing failures (952 executed) |
| Laravel complete suite | 223 passing / 1,082 assertions |
| Laravel formatter | Pint completed |
| Herd smoke | Catalog 200, empty-body 304, representative new Home/Live/TV tags 200 |
| Cleanup | No `getAds` references in `lib`; no `test/_preview`; original 17 generated files unchanged |

The two unchanged failures are `player_menu_route_test.dart` (episodes route
from navigator overlay) and `subtitle_options_test.dart` (incoming subtitle
order). No tests were deleted, skipped or weakened.

Added client files: `lib/data/models/banner_ad_dto.dart` and its two generated
parts; `lib/data/repositories/ads_repository.dart`; `lib/data/ads/{placements,
ad_event_queue,ad_events_controller}.dart`; `lib/legacy/scraper_ads_fetcher.dart`;
`lib/widgets/ad_impression_tracker.dart`; six test files and the placement JSON
fixture. Changed client files: injector, both app entrypoints, `BannerAd`,
`HostedAdsRepository`, `ScraperApi`, hosted banner widget, pubspec/lock and this
plan. No files deleted.

Changed backend files for F4: `BannerPlacement`, `BannerAdForm` and
`BannerAdTest`; added `BannerPlacementCompatibilityTest` and the placement JSON
fixture. Existing F3 backend changes and unrelated local files remain intact.
No real campaigns or counters were created/modified, and no real database was
seeded. Herd currently has zero active campaigns.

User-run smoke remains pending (no device or UI preview by the agent):

1. Deploy the backend placement/form updates first. In Filament, target a
   campaign at the desired new Home/Live tags; TV requires `title_detail_tv`
   or `live_tv_strip_tv`. Empty placement lists apply globally on handheld.
2. Restart the Flutter run process with
   `--dart-define=FLIXQUEST_MIGRATION=auth,config,ads` and
   `--dart-define=LARAVEL_API_URL=<device-reachable backend URL>`. A full process
   restart is necessary for the new connectivity plugin and changed defines;
   **R** can be used for subsequent Dart-only edits. Herd's local `.test`
   hostname usually does not resolve on physical devices.
3. Keep a banner at least half visible for a second, then revisit it within
   the same mount: its impression should increment once. Tap on handheld:
   the click should increment and open the destination. Confirm TV displays
   explicitly tagged campaigns with no tap/focus target.
4. Go offline, generate events, close/relaunch, then reconnect; confirm pending
   counters flush in Filament. Check every intended slot with an actual
   campaign and verify empty/disabled slots preserve Start.io behavior.
5. Remove `ads` from the migration flag and restart to verify rollback.

F4 implementation is complete. F5 status follows below.

### Rollback
`migration_flags.ads` off restores the scraper fetcher (keep it until F7).

---

## Phase F5 — Sync engine (bookmarks, recently watched, wellness)

### Goal
Replace Firestore's union-merge/LWW sync with the Laravel batch endpoints, using revisions + cursors + clock-skew handling, and migrate guest data on first login.

### Milestones

**F5.1 Bookmarks**
- [x] Freezed `BookmarkDto` (or keep the legacy `Movie`/`TV` models with explicit mapping) + `BookmarkRepository`.
- [x] `sync(movies, tvShows, deletedMedia)` → `POST /sync/bookmarks`; response union-merged into SQLite with the existing genre-backfill behavior (`_keepGenres`).
- [x] `deleteMedia(type, id)` → `DELETE /sync/bookmarks/{type}/{id}`.
- [x] Keep `BookmarkSyncService` public API (`init`, `onBookmarkChanged`, `statusNotifier`, `lastSyncedNotifier`) as an adapter; delete Firestore internals.
- [x] Debounce 3 s, auto-sync 10 min (existing constants preserved).

**F5.2 Recently watched**
- [x] Convert `RecentMovie`/`RecentEpisode` mapping to the backend field names (add `sync_revision`, `synced_at_utc` handling); keep SQLite columns.
- [x] `RecentlyWatchedRepository.sync(...)` → `POST /sync/recently-watched` with `since_revision` (preferred) and `client_time_utc`.
- [x] Replace `SyncCheckpoint` with `SyncCursor` in `KvStore` (per user): `serverRevision`, `lastServerTimeUtc`, `lastSyncAt`, `lastFullPullAt`; full pull every 7 days, or when the server replies `since_revision` ahead / requires full sync.
- [x] `ServerClock.record(serverTimeUtc)` on every sync; outgoing `updated_at_utc` stamped through the corrected clock; on `422 clock_skew_detected` record server time, recompute offset, retry once, then surface an error.
- [x] Keep debounce 5 s, auto-sync 2 min, flush on background (`flushPending`), 450-row batches, local tombstone pruning (server prunes at 90 d).
- [x] Port `test/recent_watched_sync_test.dart` and `test/sync_checkpoint_test.dart` to the new cursor/revision semantics; add skew-retry and revision-ahead full-sync tests.

**F5.3 Wellness**
- [x] `WellnessRepository`:
  1. Upload pass: pending sessions (`synced=0`) + daily ledger diff (`planDailyWrites` unchanged).
  2. Pull pass: paginate `cursor`/`limit: 450` until `has_more == false` (never upload while paginating); LWW-merge; reseed the daily ledger after a full pull.
- [x] `WellnessProvider` owner key derived from `SessionViewModel` (`guest` / `user:<laravelId>`); session-level Freezed conversion of `WellnessViewingSession` optional — keep `toMap/fromMap` and add backend mapping only.
- [x] `deleteRemoteAccountData` becomes `DELETE /user/account` (server cascade) + local wipe.
- [x] Tests: pagination drain, upload-after-drain ordering, LWW, tombstone handling, ledger reseed, `network_bytes` round-trip.

**F5.4 Guest → account first-login merge**
- [x] On successful register/login with existing guest data: remap local owner (`guest` → `user:<laravelId>`), mark rows pending, run bookmarks + recents + wellness sync immediately, then clear the guest namespace.
- [x] Verify deletion of an account removes server data (cascade) and does not resurrect on next login.

**F5.5 Adapters & cleanup**
- [x] `RecentlyWatchedSyncService`/`WellnessSyncService` become adapters; remove `cloud_firestore` imports from all three services and from `sync_screen.dart`.
- [x] `sync_checkpoint.dart` deleted after all callers move (grep first).
- [x] `RecentlyWatchedSyncService` pull/push lifecycle callbacks in `flixquest_main.dart` re-pointed at repositories.

**F5.6 Two-device verification (user-run)**
- [ ] Device A and B signed into the same account; play different titles; confirm both devices converge with LWW (newest `updated_at_utc` wins).
- [ ] Delete an item on A → B removes it after sync (tombstone).
- [ ] Set A's clock 25 h fast → sync returns 422, app records server time and recovers on the next sync without data loss.

### Exit criteria
No Firestore import remains in `lib/services/*sync*`, `lib/provider/wellness_provider.dart`, or `sync_screen.dart`; LWW/delta/pagination verified on staging; guest merge works; suite green.

### F5 implementation handover (2026-10-04)

F5.1–F5.5 are implemented on `feat/laravel-f5-sync`. Enable the Laravel
path with `FLIXQUEST_MIGRATION=auth,config,ads,sync`; `sync` requires Laravel
`auth`. F6 had not started at this handover. F5.6 and authenticated staging/device verification
remain user-run; automated tests use scripted Dio responses and real temporary
SQLite databases, plus isolated Laravel feature tests.

- `BookmarkRepository` and the SQLite engine map the existing Movie/TV models,
  preserve save dates and genres, and persist acknowledged IDs and offline
  deletes per account. Delete and sync requests are serialized so re-adding a
  title cannot race a pending DELETE. A deletion during an account transition
  remains queued for its original owner. Only local additions are uploaded
  again. Laravel returns
  the full union, so a title deleted elsewhere is removed locally after it has
  previously been acknowledged, rather than being uploaded on every sync.
- Recent history uses snake-case payloads, per-account revision cursors, 7-day
  full pulls, revision-ahead/explicit-full recovery and 450-row uploads. Rows
  are acknowledged only if their submitted version is still current. The
  corrected clock stamps subsequent local writes; one skew retry adjusts
  future version/tombstone stamps, including batches uploaded after that retry.
  Synced tombstones are locally pruned after 90 days. `sync_revision` and
  `synced_at_utc` are decoded without altering the legacy SQLite columns.
- Wellness finishes all pending session/daily uploads before opening its pull
  snapshot, then drains every cursor page without another upload. A failed
  later page leaves the durable cursor/ledger unchanged. Merged sessions retain
  `network_bytes`; daily summaries are rebuilt from them and the daily ledger
  is reseeded from full responses. `planDailyWrites` keeps its prior semantics.
  The API has no daily DELETE endpoint, so removed days are sent as newer zero
  aggregates; a null ledger stamp remembers an acknowledged zero day.
- Login, registration and Google login copy guest bookmarks/recents into account
  files and remap wellness ownership. Failed sync stays authenticated with
  durable pending rows and a claimed guest snapshot. A later successful sync
  clears only unchanged copied guest rows. Account switching captures database
  handles, invalidates old responses, resets providers, and rejects old-owner
  requests before attaching a different account's token. Streaming, live and
  offline players capture the library generation; delayed wellness saves after
  a switch or wipe are discarded. Account deletion uses
  the Laravel account cascade and wipes that owner's files, cursor, daily
  ledger and next-episode hints.
- The public services are adapters and the Sync screen shows each collection's
  state with manual sync. Player debounce/background flush and resume throttles
  continue through these adapters. Firestore implementation and its checkpoint
  are retained only in `lib/legacy/firebase_sync/` for rollback until F7;
  `lib/services/sync_checkpoint.dart` was removed after caller migration.

Laravel adjustment: explicit `since_revision: 0` now includes retained
recent/wellness tombstones and imported revision-zero rows. Omitting the revision
keeps legacy full-pull behavior (active rows only). This closes the full-pull
resurrection gap without changing the legacy clients' contract. The backend
changes are confined to `RecentlyWatchedSyncService`, `WellnessSyncService` and
`RevisionFullPullTest`; earlier F3/F4 backend changes remain untouched.

| Check | Result |
|---|---|
| Flutter analyze | **0 issues** (`/tmp/f5-analyze-final.log`) |
| Full Flutter suite | **140 files, 975 executed: 974 passed / 1 existing failure** (`/tmp/flixquest-f5-full-suite-final.log`). `subtitle_options_test.dart` still fails its incoming-order assertion. The other baseline failure, `player_menu_route_test.dart`, passed in this run. |
| Added Flutter coverage | **23 new tests** across 10 files; all passed in the full run. The existing 14 recent-history and 11 checkpoint/daily-plan tests were migrated without reducing their count. Coverage includes 450-row batches, skew retries, revision recovery, paginated failure/restart, LWW/tombstones, durable deletes and re-add ordering, guest merge/retry, owner transitions, delayed player saves, account wipe and ledger cleanup. |
| Code generation | Successful full rebuild: **25 builder outputs**; all **19 tracked generated files** retain their pre-F5 hashes (`/tmp/f5-codegen-final.log`). |
| Full Laravel suite | **224 passed, 1,090 assertions** (`/tmp/f5-backend-full.log`); memory-database feature tests include the new revision-zero/tombstone compatibility test. |
| Laravel formatter | Pint completed successfully on dirty files. |
| Live Herd smoke | Unauthenticated `POST http://flixquest-backend.test/api/v1/sync/recently-watched` returned **401**, confirming the running API's auth boundary. Authenticated staging convergence remains pending. |
| Diff checks | Flutter and Laravel `git diff --check` clean; generated files have no diff. No commit, push or PR. |

The first full run exposed an owner-binding initialization regression and a test
compilation mismatch while source was still changing. Both were corrected before
the final run above. Additional regression tests were first observed failing for
the delete/re-add race, cross-account deletion/journaling and delayed player save;
they now pass. The pre-existing subtitle-order failure was left unchanged.

F5's implementation and automated verification are complete. Its staging and
two-device exit checks remain open; F6 had not started at this handover.

User-run F5.6 checklist: run both devices with the migration flags and a reachable
Laravel URL, sign into the same account, sync distinct progress, verify newest
versions converge, remove a bookmark/history entry on A and sync B, then set A
25 hours fast and verify the skew retry recovers. Also verify guest login while
offline followed by reconnect, and account deletion followed by a new login.
Use `--dart-define=FLIXQUEST_MIGRATION=auth,config,ads,sync` and set
`--dart-define=LARAVEL_API_URL=<device-reachable Laravel base URL>` when starting
the app; the URL is normalized to `/api/v1/`. Hot restart alone does not change
compile-time defines. Apply the two Laravel service changes before this smoke.
No devices, real accounts, production data, or scraper files were modified here.

### Rollback
Revert the phase branch; Firestore code remains until F7.

---

## Phase F6 — Notifications, in-app messages & reporting preservation

### Goal
Register FCM tokens with Laravel and poll announcements while preserving FCM data payloads, Firebase Crashlytics and Google Analytics for Firebase. Laravel does not collect or mirror these crash/analytics reports. Complete F3.5 first.

### Milestones

**F6.1 Device push registration**
- [x] `DeviceRepository.register(fcmToken, platform, appVersion)` → `POST /devices/register`; call after login and on `FirebaseMessaging.onTokenRefresh`; skip when guest.
- [x] Persist last registered token in `KvStore` to avoid duplicate calls; re-register on boot when signed in.
- [x] Keep `FirebaseMessaging.onBackgroundMessage` in `main.dart` (retained FCM).
- [x] Tests: payload shape (snake + camel accepted), no-op for guests, refresh re-registers.

**F6.2 In-app messages**
- [x] `AnnouncementRepository.fetchActive()` → `GET /messages/active` (15 min cache); poll on resume + cold start (throttled), and still accept FCM `data.type == 'in_app_message'` payloads.
- [x] `InAppMessagingService` builds `InAppMessagePayload` from either source; dedupe by announcement `id` in `KvStore` so a message is not shown twice.
- [x] `InAppMessageDialog` unchanged.
- [x] Tests: both sources, dedupe, display types modal/bottom_sheet/banner.

**F6.3 Preserve Google reporting (resolved decision D2)**
- [x] Keep `FirebaseCrashlytics` initialization/error handlers in `main.dart`, including `_isRecoverableImageError`, fatal/non-fatal handling and existing collection controls. Keep Android/iOS Crashlytics integrations and symbol/mapping uploads.
- [x] Keep `firebase_analytics`, existing Analytics calls and `updateAndLogTotalStreamingDuration` in `lib/functions/function.dart` using the existing Google Analytics path. Preserve existing consent/collection behavior.
- [x] Do not introduce Sentry as a replacement, a Laravel `TelemetryRepository`, `/telemetry/errors` client submissions, analytics ingestion endpoints, or forwarding/duplication of these events to Laravel. Existing Mixpanel usage continues unchanged; this phase does not migrate Google events to Mixpanel.
- [x] Automated checks: Google reporting hooks remain wired, the existing image filter remains unchanged, SDK failure/recursion guards and existing analytics payloads are tested. Client reporting paths call the Google SDKs without Laravel ingestion or mirroring.
- [ ] User-run smoke: verify retained Google reporting SDKs and collection/consent behavior on phone and TV, including real FCM delivery.

### Exit criteria
Device tokens registered; announcements render from both sources; Crashlytics and Firebase Analytics remain operational with existing behavior; no Laravel crash/analytics tracking is added; suite preserves the documented baseline.


### F6 implementation handover — 2026-10-04

Implemented on `feat/laravel-f6-notifications`, continuing committed F3.5
(`ec702a1`). Enable this phase with
`--dart-define=FLIXQUEST_MIGRATION=auth,config,ads,sync,notifications` and a
reachable `--dart-define=LARAVEL_API_URL=<Laravel base URL>`. Device registration
uses the Laravel session; public announcements also work for guests. F7 has not
started. No commits, pushes or PRs were created.

- `DeviceRepository` sends authenticated, uncached snake-case fields. The
  controller registers on authenticated cold boot, login/account changes and
  token refresh, then suppresses unchanged resumes and duplicate refreshes.
  The durable receipt contains owner, FCM token, platform and app version.
  Guests do not look up or upload a token. Missing tokens, SDK failures and
  failed HTTP calls retry on resume; late responses cannot acknowledge a
  different owner or overwrite a newer token. An owner guard in the shared
  auth interceptor rejects queued registrations for a previous account.
- The Freezed `Announcement` DTO accepts resource aliases and nullable bodies.
  `AnnouncementRepository` polls the public endpoint, coalesces concurrent
  requests and throttles successful polls (including empty catalogs) for
  fifteen minutes. Shared HTTP caching supports ETag revalidation and the
  existing seven-day offline deadline. Inactive/expired cached messages are
  filtered on each read; invalid rows do not hide valid announcements.
- `InAppMessageController` queues API and FCM messages through the unchanged
  dialog. API `id` and FCM `announcement_id` share installation-level durable
  deduplication, acknowledged when presentation opens, before dismissal.
  Pending duplicates are suppressed, dialogs are serialized, unavailable
  navigation retains messages and queued expired messages are dropped.
  Legacy FCM aliases/manual messages remain supported; ID-less messages cannot
  be durably deduplicated. The SDK adapter uses the FCM message ID as a fallback
  identity when no announcement ID is present.
- `InAppMessagingService` owns/cancels foreground and notification-tap
  subscriptions and handles cold-start notification taps. Late initial-message
  responses after disposal are ignored. Config hints still reach the F3.5
  controller; failed config refreshes do not interrupt message delivery.
  `FlixQuest` starts both controllers and refreshes on resume through the
  shared phone/TV root. Platform registration uses `android`, `ios` or `tv`.
  The existing background FCM handler and permission flow remain in place;
  registration retries after that permission flow completes.
- Firebase initialization, `_isRecoverableImageError`, Google collection
  controls and native integrations are retained. `GoogleErrorReporting` routes
  the same fatal Flutter/platform reports to Crashlytics and contains SDK
  failures and synchronous recursion. Streaming-duration events retain
  `total_streaming_duration` and cumulative `duration_seconds`; the helper's
  optional SDK argument only permits testing the existing Google path. Other
  Analytics/Crashlytics calls and Mixpanel are unchanged. No Sentry dependency,
  Laravel telemetry repository, reporting submission or Google event mirror
  was introduced.

Files added: announcement DTO and its two generated outputs; device and
announcement repositories; the push SDK adapter; three notification controllers;
Google reporting guard; seven test files and fake push SDK support. Existing
files changed: injector, auth interceptor, main/shared app root, in-app message
payload/service and streaming-duration helper, plus this document. No UI dialog,
`lib/tv/**`, native setup, package/dependency file or backend source was changed.

| Check | Result |
|---|---|
| Flutter analyze | **0 issues** (`/tmp/f6-analyze-final.log`). Two style notices in new files were resolved; no existing file was formatted. |
| Added F6 coverage | **31 new tests across 7 files, all passed** (`/tmp/f6-targeted-final.log`), including token/account races, guest mode, public polling/cache expiry, API/FCM deduplication, late disposal, all three display types, cold taps, Google payload preservation and SDK failure/recursion guards. |
| Full Flutter suite | **148 files, 1,027 executed: 1,026 passed / 1 existing failure** (`/tmp/f6-full-suite-final.jsonl`, hidden loader tests excluded). `subtitle_options_test.dart` retains its incoming-preference-order failure; the known `player_menu_route_test.dart` passed. Neither baseline test was edited, skipped or weakened. Final style-only braces were followed by the analyzer and all 31 F6 tests. |
| Laravel tests | Targeted compatibility/push checks: **29 passed, 151 assertions**. Full suite: **229 passed, 1,115 assertions** (`/tmp/f6-backend-targeted.log`, `/tmp/f6-backend-full.log`), using the existing isolated memory database and mocked FCM transport. |
| Code generation | Successful rebuild (`/tmp/f6-codegen-final.log`); repeat build wrote **0 outputs** (`/tmp/f6-codegen-repeat.log`). All **19 pre-F6 tracked generated files** retain their hashes; the **2 new announcement outputs** are stable. |
| Google/native preservation | All **7 checked native setup files** retain their pre-F6 hashes; dependency files, Firebase background handler, image-filter body and collection controls remain unchanged. Reporting uses the existing Google SDKs; no client telemetry ingestion/mirroring was added. Real Google console/device verification remains pending. |
| Live Herd smoke | Public `GET /api/v1/messages/active` returned **200**, `success: true`, an empty catalog and an ETag; conditional revalidation returned **304**. No live campaign, account or device token was created. |
| Diff checks | Flutter and Laravel `git diff --check` clean. Existing backend changes were preserved; no backend source edits, commits, pushes or PRs were made in F6. |

The first registration and queue tests failed against their stubs before
implementation. Additional failing checks exposed the in-flight identical-token
upload and SDK reporting failure/recursion cases; they now pass. The full suite
preserves the documented baseline and adds all 31 F6 cases.

User-run exit checks remain open:

- On phone and TV, sign in with the migration defines and a device-reachable
  Laravel URL. Verify device registration (`tv` on TV), a cold-launch
  re-registration, no guest upload and an updated token after FCM rotation.
- Create an active announcement in Filament for each display type; poll it,
  deliver/tap its FCM message and cold-launch from the notification. Confirm
  one presentation across sources and restarts, and check offline/resume
  behavior. Herd returned an empty public catalog during this phase, so real
  campaign rendering/delivery remains a device smoke.
- Configure backend Firebase credentials and run the queue worker in the target
  environment for real push delivery. Automated backend tests mock outbound
  FCM; this phase sent no real push and created no live accounts/campaigns.
- Verify Google Analytics DebugView receives the existing duration event and
  Crashlytics receives an intentional test report under the existing collection
  settings. Confirm reports/events go to Google, with no Laravel submissions.
  The repository currently contains Android native setup; iOS device/build
  verification requires the target's iOS project and remains pending.

A hot restart does not change compile-time defines; restart the user's existing
run with these arguments for the smoke. No device was installed, run or operated
by the agent. F6's automated implementation can be reviewed now; device/staging
exit criteria remain pending before production cutover.

---

## Phase F7 — Firebase cleanup & native build slimming

### Goal
Remove replaced Firebase Auth, Firestore and in-app-messaging packages/hooks. Keep Firebase Core, Messaging, Remote Config, Crashlytics and Analytics working on phone and TV (G2).

### Milestones

**F7.1 `pubspec.yaml`**
- [ ] Remove only: `cloud_firestore`, `firebase_auth`, `firebase_in_app_messaging` after their callers have migrated.
- [ ] **Keep:** `firebase_core`, `firebase_messaging`, `firebase_remote_config`, `firebase_crashlytics`, `firebase_analytics`, and required supporting dependencies.
- [ ] Remove `http` if all importers migrated (grep; migrate stragglers first) and `google_sign_in` stays.
- [ ] `flutter pub get`; resolve conflicts; full suite + `test/tv_*.dart` green.

**F7.2 Native**
- [ ] Android: remove only obsolete Auth/Firestore/in-app-messaging setup/rules. **Keep** Google Services configuration/plugin, Crashlytics Gradle plugin and tasks, reporting/symbol-upload setup and rules required by all retained SDKs.
- [ ] iOS: remove only obsolete Auth/Firestore/in-app-messaging pods/hooks; keep Core, Messaging, Remote Config, Crashlytics and Analytics pods and Crashlytics symbol-upload scripts; `pod install`.
- [ ] Delete dead Auth/Firestore code, legacy sync/checkpoint code and orphaned imports after grep. **Keep** `app_remote_config.dart` and the Firebase config controller (promote from `legacy` if appropriate), as well as Crashlytics/Analytics adapters and calls.

**F7.3 Build verification**
- [ ] `flutter build apk --release`; record size delta vs the pre-migration build. Do not assume the PRD's ~3.5 MB reduction: five Firebase packages/native integrations remain.
- [ ] Measure cold-start timing with the production Firebase initialization and all retained SDKs enabled; record the real result, without promising a fixed reduction.
- [ ] `rg 'cloud_firestore|firebase_auth|firebase_in_app_messaging' lib` → no remaining imports/callers. Separately verify Core/Messaging/Remote Config/Crashlytics/Analytics initialization, imports and native hooks remain.
- [ ] Smoke both config sources, FCM delivery, a Crashlytics test report and an existing Google Analytics event in the release/test builds on phone and TV; confirm these reports are not sent to Laravel.

### Exit criteria
App builds with Auth/Firestore/in-app-messaging removed and all five retained Firebase SDKs operational; Laravel still chooses the config source at runtime and receives no Google crash/analytics mirror; measured APK/startup numbers reported.

---

## Phase F8 — QA, staging & cutover

### Goal
Prove parity end-to-end on staging, then ship the cutover release with the backend running production data.

### Milestones

**F8.1 Automated integration matrix** (run against staging; see backend `docs/migration_phases.md` Phase 6.1)
- [ ] Migrated Scrypt account: first login 200 + token + password becomes Bcrypt; second login Bcrypt.
- [ ] Google sign-in for an existing Google-linked account; 409 collision shows the right message.
- [ ] Bookmarks union merge and recents/wellness LWW across two devices.
- [ ] Clock skew 25 h fast → 422 → client recovers after offset correction.
- [ ] 90-day tombstone purge uses server time.
- [ ] Offline cold boot uses cached bootstrap and cached TMDB rows; no blank screens.
- [ ] ETag 304 on bootstrap and ads.
- [ ] Switch Laravel `config_source` between Firebase and Laravel in the same phone/TV build; revalidate on every resume/config refresh and verify matching cached-source offline boot.
- [ ] Crashlytics/Google Analytics reporting and consent behavior remain intact; confirm no client crash/analytics payloads reach Laravel telemetry endpoints.
- [ ] Wellness pagination > 450 sessions across two pages; upload rejected mid-pagination is avoided by ordering.
- [ ] Guest → register → local data appears on the second device.
- [ ] Ad impression/click counters increment in Filament.
- [ ] Account deletion cascades server-side and wipes local data.

**F8.2 Data rehearsal**
- [ ] Export → import → `flixquest:verify-migration` on staging (backend owner).
- [ ] Spot-check counts per user against the export manifest.

**F8.3 Cutover playbook** (mirrors backend Phase 6.3)
- [ ] Freeze migrated Firestore data writes (rules read-only) at the start of the window. Keep Firebase Remote Config publishing and Crashlytics/Analytics collection operational.
- [ ] Final delta export/import + verification.
- [ ] Deploy backend (MySQL 8 + Redis), health checks, Filament access.
- [ ] Ship Flutter release (`version: 4.3.0+7` or agreed number) to phone + TV tracks.
- [ ] Monitor 24–48 h: Laravel API health/login/sync and ad counters; review app crashes and Google analytics in their existing Firebase/Google consoles, without a Laravel telemetry mirror.

**F8.4 Post-cutover**
- [ ] Firebase project continues Messaging, Remote Config, Crashlytics and Analytics usage; archive the Auth export/hash config and retire migrated Auth/Firestore data paths.
- [ ] Remove development rollout flags (`migration_flags.dart` simplifies to defaults on), preserving Laravel's production runtime `config_source` selector and both providers.
- [ ] Update `docs/migration_prd_firebase_to_laravel.md` status and this plan's checkboxes.

---

## 5. Part B — `flixquest-scraper` modernization (S0–S4)

**Repo:** `~/Documents/web/flixquest-scraper` — TypeScript 5 / Express 5 / ioredis, Node ≥ 22, pnpm; deployed via Render/Vercel/Netlify.

**Hard constraints**
- The shipped Flutter client consumes `/api/v2/*` today. Every path, method, and response field it relies on must keep working until the matching Flutter phase ships.
- No endpoint is deleted before the client stops using it. The only deletion is `/ads` (S4), gated on Flutter F4.
- This is a behavior-preserving refactor plus additive contracts. Provider scraping logic (`src/providers/**`, `src/sources/**`) is not rewritten — it is re-homed behind services.
- Because the repo is currently mid-merge with uncommitted Viv/VidUp work (G16), **do not start S1 until the tree is clean and the user has committed or stashed it.**

### Current state (audited)

| Area | State |
|---|---|
| Composition | `src/index.ts` is **1,247 lines**: app setup, all core routes, orchestration, caching, validation, shaping, health cron, shutdown |
| Layers | None — `src/routes/*` call `src/sources/*` directly; no controllers/services/repositories |
| Validation | No library; ~10 hand-rolled parse helpers duplicated across routes |
| Errors | No global error middleware; inconsistent `{success:false, error, details?}`; unknown-provider toggle can throw an HTML 500 |
| Caching | Redis response cache (`flixquest:provider:*`, TTL 7200s, 27-provider denylist), negative cache 60s, subtitles 1800s/86400s, single-flight, `X-Cache` |
| HTTP validators | **No ETag/`If-None-Match` anywhere**; `Cache-Control` missing on `stream-movie`/`stream-tv`; `providers` has no explicit policy |
| Config | 119 env vars read directly; `src/utils/config.ts` is 6 lines |
| `/ads` | Still present: `src/routes/ads.ts` + test + `api.use('/ads', …)` + root catalog + boot log |
| Dead surface | `src/utils/stream-proxy.ts` (`handleStreamProxy`, 618 lines) unmounted; stale `openapi.json` `/proxy`; README `proxy`/`noProxy`; `EXAMPLES.md` old `/v2` prefix |
| Tests/CI | 47 `node:test` files, no aggregate `test` script, CI runs format/lint/typecheck/build on Node 18/20 and **never tests** |

### Target layout

```
src/
  index.ts            # bootstrap only: listen, graceful shutdown, health cron
  app.ts              # express composition: middleware, routers, error handler
  config/env.ts       # zod-validated typed config, fail-fast
  http/
    middleware/       # forward-proxy ALS context, cache headers, request id, error handler
    responses.ts      # sendSuccess / sendError envelope helpers
    errors.ts         # HttpError hierarchy
  routes/             # thin router definitions (paths + controller binding)
  controllers/        # parse (zod) → call service → shape response
  services/           # stream, provider, subtitle, live-tv, cache, intro, health
  domain/             # zod schemas + inferred DTOs (requests/responses)
  cache/              # redis client, cache-policy registry, etag/http-cache
  providers/ sources/ utils/   # unchanged internals, imported by services
```

### Phase table

| Phase | Name | Size | Depends on | Client mapping |
|---|---|---|---|---|
| **S0** | Safety net & CI | S | clean tree (G16) | parallel to F0 |
| **S1** | Layered extraction (no behavior change) | L | S0 | parallel to F0/F1 |
| **S2** | Typed config, validation, errors, OpenAPI | M | S1 | F0/F1 (client parser reads `success` first) |
| **S3** | Cache contract (Cache-Control + ETag) | M | S2 | lands with F1 |
| **S4** | `/ads` removal & dead-surface cleanup | S | S2, **F4 shipped** | follows F4 |

---

## Phase S0 — Safety net & CI

### Goal
A green, tested starting point before any refactor.

- [ ] Land the in-flight `optimize` merge and the staged/unstaged Viv/VidUp work (user commits; agent does not touch the dirty tree).
- [ ] Add an aggregate `test` script: `tsx --test "src/**/*.test.ts" "scripts/**/*.test.mjs"` (or a `test/` runner file); record the baseline pass/fail/skip counts in the Part B report.
- [ ] CI (`ci.yml`): set Node 22 (matches `engines`), add `pnpm test` after `typecheck`, keep `format:check`, `lint`, `build`.
- [ ] Optional but recommended: `docker-compose.yml` with Redis so cache tests and local dev run the same way.
- [ ] Add a short `docs/architecture.md` stub describing the S1 target layout so contributors do not re-inline logic.

**Exit:** `pnpm format:check && pnpm lint && pnpm typecheck && pnpm test && pnpm build` green in CI; zero behavior change.

---

## Phase S1 — Layered extraction (no behavior change)

### Goal
Break `src/index.ts` into composition + routes + controllers + services, with every response byte-identical (except ordering that tests pin).

- [ ] Characterization tests first: pin `stream-movie`/`stream-tv` success shape, `X-Cache: HIT/MISS/BYPASS`, `full=true` rejection, unknown provider 404, subtitle search shape, providers/status shape. These are tripwires for the move.
- [ ] `src/app.ts` — express app, `express.json`, `rejectFullStreamCollection`, forward-proxy middleware (AsyncLocalStorage), routers; `src/index.ts` reduced to bootstrap (`listen`, signal handling, health-monitor spawn).
- [ ] Extract services:
  - `stream-service` — `resolveStreamResponse`, single-flight, Redis read/write, TMDB lookup, subtitle fallback, `publicResponse` shaping.
  - `provider-service` — registry access, enable/disable/toggle, health run/publish, status snapshot.
  - `subtitle-service` — search + file delivery.
  - `live-tv-service` — DLHD + EthioSports catalog/EPG/streams.
  - `cache-service` — stats/flush; switch Redis `KEYS` to cursor `SCAN` (operational fix, same responses).
  - `intro-service` — `/intro`.
- [ ] Extract controllers; routes become thin definitions. Keep `API_PREFIX`/paths unchanged.
- [ ] Fix the latent toggle bug: unknown/source-disabled provider id → 404 envelope (regression test).
- [ ] Move helper modules (`single-flight`, `negative-cache`, response shaping) under the layers; keep import paths stable or update callers.
- [ ] Do not touch `src/providers/**` / `src/sources/**` internals.

**Exit:** `src/index.ts` < 150 lines; characterization tests unchanged; full suite green; no public contract diff.

---

## Phase S2 — Typed config, validation, errors, OpenAPI

### Goal
One typed config, one validator, one error envelope, one API description.

- [ ] Add `zod`.
- [ ] `src/config/env.ts` — schema for every env var the app reads (TMDB, provider overrides, proxy pool, Redis, subtitles, live TV, health, server), with coercion + defaults + fail-fast in production and a readable report in dev. Migrate module-by-module; a temporary audit script lists remaining raw `process.env` reads so none are missed.
- [ ] `src/domain/` schemas: `streamQuery`, `streamSizeBody`, `streamSizeBatchBody`, `subtitleSearchQuery`, `providerToggleBody`, `providerPatchBody`, `healthPublishBody`, `dlhdQuery`, `ethioQuery`; controllers consume parsed types.
- [ ] `http/errors.ts` — `HttpError` hierarchy (`BadRequest`, `Unauthorized`, `NotFound`, `UpstreamError`, `Unavailable`) and a global 4-arg error middleware. Envelope: `{success:false, message, errors?}` with `error` kept as an alias of `message` for existing clients during the transition. 500s stop leaking HTML/stack traces.
- [ ] `http/responses.ts` — `sendSuccess(data, {cache})`, `sendError(...)`; replace duplicated `res.json` calls. `ProviderResponse`, `StreamResponse`, `ProviderLink` field names are frozen.
- [ ] Add `GET /api/v2/health` → `{success:true, status:'ok'}` (the PRD expects `/health`; keep `/` as the info page).
- [ ] Regenerate `openapi.json` from the zod schemas (e.g. `zod-to-openapi`) and add a test asserting route/schema parity; drop the stale `/proxy` path and add the missing `/cache/*`, `/stream-sizes`, `/providers/health/*`, `/constructed.m3u8`, `/ethiosports`, `/api/v2/health` paths.

**Exit:** every route validates via schema; no unhandled error escapes to HTML; OpenAPI matches the router; tests green.

---

## Phase S3 — Cache contract for the new Flutter client

### Goal
The Flutter cache interceptor (F1.6) can revalidate scraper GETs cheaply; stream endpoints are explicitly uncacheable.

- [ ] `src/cache/cache-policy.ts` — single registry consumed by both the Redis layer and the HTTP header layer:

| Endpoint | `Cache-Control` | ETag | Redis TTL |
|---|---|---|---|
| `GET /providers` | `public, max-age=300, stale-while-revalidate=86400` | yes | 10 min |
| `GET /providers/status` | `public, max-age=60, stale-while-revalidate=600` | yes | 60 s |
| `GET /subtitles/search` | `public, max-age=86400` | yes | 24 h (existing) |
| `GET /dlhd/channels`, `/dlhd/epg`, `/ethiosports/channels`, `/ethiosports/epg` | `public, max-age=…` matching the existing in-memory TTLs | optional | existing |
| `GET /stream-movie`, `/stream-tv` | `no-store` (explicit) | no | existing provider response cache unchanged (7200 s, 27-provider denylist) |
| `POST /stream-size`, `/stream-sizes` | `private, max-age=60` (existing) | no | none |
| `GET /api/v2/health`, `/` | `no-store` | no | none |

- [ ] ETag middleware: strong ETag over the final JSON body, honor `If-None-Match` → `304` with the same `Cache-Control`; keep `X-Cache: HIT/MISS/BYPASS` as-is.
- [ ] `GET /cache/stats` gains policy metadata; flush uses `SCAN` (from S1).
- [ ] Tests: 304 round-trip, exact header values per route, `X-Cache` unchanged, flush still works, stream routes emit `no-store`.
- [ ] Note the 27-provider denylist is unchanged — this phase adds HTTP validators, it does not alter stream caching.

**Exit:** `curl -I` on each safe GET shows the policy; conditional GET returns 304; Flutter F1.4 tests consume the headers; full suite green.

---

## Phase S4 — `/ads` removal & dead-surface cleanup

### Goal
The scraper is a pure extraction service, matching the PRD Phase 2 objective.

- [ ] **Timing gate: only after Flutter F4 is released** (the client stops calling `GET /api/v2/ads` in F4). Until then, leave `/ads` in place — the client treats non-2xx as "no ads", so removing early is survivable but must not be done casually.
- [ ] Delete `src/routes/ads.ts`, `src/routes/ads.test.ts`, the import and `api.use('/ads', adsRouter)` mount, the root `/` catalog entry, and the startup log line.
- [ ] `grep -rn "ads" src README.md openapi.json` — remove/repair remaining references (the OpenAPI has none; README/docs may).
- [ ] Dead-surface cleanup:
  - delete or quarantine `src/utils/stream-proxy.ts` + `handleStreamProxy` (unmounted since `2725fec`);
  - remove the stale `/proxy` path from `openapi.json`;
  - fix `EXAMPLES.md` to the `/api/v2` prefix;
  - reconcile README `proxy`/`noProxy` params and the `requiresProxy` provider flags that `unproxyStreamLink` overrides (document the decision; do not change provider behavior in this phase).
- [ ] Scraper repo's own PRD Phase 2 checklist (2.1.x, 2.2.x) can be closed once stream/subtitle/health smoke tests pass.

**Exit:** no ads surface remains; stream/subtitle/live endpoints behavior-identical; full suite green; the repo README/OpenAPI describe only what exists.

---

### Part B verification & KPIs

| Check | Command / method | Target |
|---|---|---|
| Format/lint/types | `pnpm format:check && pnpm lint && pnpm typecheck` | green |
| Tests | `pnpm test` | green; CI runs it on Node 22 |
| Build | `pnpm build` | green on Render/Vercel/Netlify paths |
| Contract parity | OpenAPI vs router test | 100% paths match |
| Cache validators | `curl -I` + `If-None-Match` on `/providers`, `/providers/status`, `/subtitles/search` | correct headers + 304 |
| Stream safety | `curl -I /api/v2/stream-movie` | `Cache-Control: no-store`, `X-Cache` intact |
| Architecture | `wc -l src/index.ts`; grep for `res.json(` outside `http/responses.ts` | `index.ts` < 150; helpers centralized |
| Config | grep `process.env` outside `config/env.ts` (allowlist documented) | near zero |
| Ads | route + docs grep | gone after F4 |
| Client compatibility | Flutter F1.4/F4 tests against the deployed scraper | green |

---

## 6. Cross-cutting test matrix — Part A (Flutter)

| Concern | Unit | Widget/integration | Phase |
|---|---|---|---|
| Cache freshness/ETag/offline fallback | ✅ fake adapter + sqflite in-memory (`sqflite_common_ffi` may be needed in tests) | — | F1 |
| TMDB cache key normalization / proxy / key rotation | ✅ | — | F1 |
| Scraper no-store on streams | ✅ | — | F1 |
| Auth repository status mapping (401/409/422/429/403) | ✅ fixtures | login/signup widget flows | F2 |
| Session restore/expiry | ✅ | routing to landing | F2 |
| Google token exchange + collision message | ✅ fake Google client | TV + phone smoke | F2 |
| Bootstrap parsing/theme v2 parity | ✅ original fixtures + ported theme tests | offline boot | F3 |
| Laravel config-source choice / switching / ETag / offline / races | shared fixtures + controller/SDK boundary tests | same phone/TV build switches both ways on resume | F3.5 |
| Ads shared fetch / queue / impressions | ✅ | placement manifest parity test | F4 |
| Bookmarks union merge | ✅ | manual two-device | F5 |
| Recents LWW + revision cursor + skew retry | ✅ ported tests | manual two-device | F5 |
| Wellness pagination drain + ledger | ✅ ported tests | manual stale-history account | F5 |
| Guest → account merge | ✅ | staging manual | F5 |
| Device register / announcements dedupe | ✅ | resume smoke | F6 |
| Retained Crashlytics/Google Analytics; no Laravel mirror | preserve hooks/payloads; assert no telemetry submissions | Google reporting smoke + consent controls | F6 |
| Replaced Firebase SDK cleanup; retained SDK verification | import/native hook checks | release build + both config sources + Google reporting | F7 |
| Full integration matrix | — | staging | F8 |

## 7. Definition of done / KPIs (adjusted)

| KPI | Target | Notes |
|---|---|---|
| Existing test suite | stays green; migrated tests replaced 1:1 | baseline recorded at F0 |
| `flutter analyze` | 0 issues | current state |
| Password resets for migrated users | 0 (backend already proven by Pest) | F2/F8 |
| Data parity | 100% counts vs export manifest | F8 |
| APK size | measured vs baseline; no fixed reduction promised with five Firebase packages retained (G2) | F7 |
| Cold-start | measured with all retained SDKs; no fixed 250 ms improvement promised (G2) | F7 |
| TMDB metadata requests | served from cache on repeat/offline | F1 |
| Scraper safe GETs | cached; streams never cached | F1 |
| Ad placements | every slot fillable from Filament | F4 |
| Admin toggles | Laravel chooses config provider at each refresh; themes/flags/ads manageable without app deploys | F3.5/F4 |
| Google reporting | Crashlytics/Analytics retained; no Laravel ingestion or duplication | F6/F7/F8 |

## 8. Decisions and recommendations

| # | Decision | Resolution / recommendation | Needed by |
|---|---|---|---|
| D1 | Freezed scope | Incremental: new DTOs + VM states + converted-on-touch models (§1.4) | F0 |
| D2 | Crash/analytics reporting — **resolved by user, 2026-10-04** | Keep Firebase Crashlytics and Google Analytics for Firebase, including native setup and existing events; no replacement or Laravel mirror. Existing Mixpanel usage unchanged. | F6/F7 |
| D3 | Cache implementation | Selected `dio_cache_interceptor` for HTTP validation/serialization, with app policies and a bounded sqflite store | F1 |
| D4 | Ads fetch strategy | One shared `GET /ads` + local placement filtering (matches today's `HostedAdsRepository`); `?placement=` remains available for server-side filtering if desired | F4 |
| D5 | Sanctum token expiry | Keep never-expiring tokens + revocation on password/email change (current backend), or add `expiration` + refresh later | F2 |
| D6 | Rollout/config source — **resolved by user, 2026-10-04** | Compile-time flags are development aids. Laravel chooses Firebase/Laravel config at every refresh in production too; retain both providers after F7. | F3.5/F8 |
| D7 | Legacy placement aliasing | Keep legacy `home_movies`/`home_tv` targeting working alongside new `home_*_*` names | F4 |
| D8 | TV ads placement names | Add `title_detail_tv`/`live_tv_strip_tv` to the backend enum so TV slots are targetable | F4 |
| D9 | Scraper validation library | `zod` (runtime validation + inferred DTOs + OpenAPI generation) | S2 |
| D10 | Scraper error envelope | `{success:false, message, errors?}` with `error` kept as a legacy alias; Flutter reads `success` first either way | S2 |
| D11 | Scraper lifetime after cutover | Keep as the pure extraction service (recommended) vs. fold extraction into Laravel; either way S0–S3 are prerequisites | S0 |
| D12 | Config selector contract | Implemented `data.config_source: firebase \| laravel` in public Laravel bootstrap, Filament-controlled and ETag-covered; last valid choice plus matching source cache offline. | F3.5 |

---

*Generated from a full audit of `feat/laravel` (client), the Laravel backend, the `flixquest-scraper` repo, and all PRD/migration documents. Checkboxes are intended to be ticked as work lands; the plan is not committed until the user asks.*
