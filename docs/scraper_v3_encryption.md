# Scraper v3 encryption handoff

Last updated: 2026-11-06. Start at [Current status](#current-status) and
[Next steps](#next-steps).

This covers encrypted `/api/v3` routes between the Flutter app and the scraper.
This file contains no secrets. Never add the values from `.env.scraper` or
`SCRAPER_V3_KEYS` to it. Don't paste those values into an AI chat either.

## Repos

| Repo | Path | Branch |
|---|---|---|
| Flutter app | `~/Documents/flutter_projects/personal/fq/flixquest` | `main` (also on `v4.3.2`) |
| Scraper | `~/Documents/web/flixquest-scraper` | `main` |

## Current status

**v3 is live in production at `https://scraper.flix.quest`, and the code is merged
to `main` in both repos. No released app uses it yet.**

| Item | State |
|---|---|
| Active scraper release | `20261106T191638Z-26b8daa98c47` (commit `26b8daa`, on `main`) |
| Previous release, for rollback | `20261106T183055Z-ac47af28ea5e` |
| `SCRAPER_V3_MODE` in production | Not set, which means `sealed` |
| Server keys | `2026-11` (release) and `dev-2026-11` (debug) in `/etc/flixquest/scraper.env` |
| Env backup on the VPS | `/etc/flixquest/scraper.env.before-v3-20261106T183038Z` |
| `.env.scraper` | Only on the owner's Mac. It is gitignored and needs a private backup |

Rollback, if needed: `ssh flixquest-vps`, then `sudo fq rollback scraper`.

**Building Flutter's `main` needs setup.** `.env.scraper` and the generated
`lib/core/config/scraper_secrets.g.dart` are gitignored, so a fresh checkout won't
compile until you follow [Setting up a new machine](#setting-up-a-new-machine).

### Other work in the Flutter tree

Other sessions were changing files in the working tree during this work. Only the
v3 files were committed, so these are still uncommitted and aren't on `main`:

- `docs/firebase_remote_config.md`
- `lib/widgets/adsterra_playback_ad_screen.dart`
- The wellness recap work: `assets/translations/*`, `lib/translations/*`,
  `lib/screens/wellness/*`, `lib/models/wellness_recap_story.dart` and its tests

`build/app/outputs/flutter-apk/app-prod-release.apk` was built from that mixed tree.
**Don't publish it.**

## Next steps

Do these in order before releasing the app.

1. **Fix the bundled default URL.** `.env` sets `FLIXQUEST_API_URL` to the Render
   deployment, and `.env.example` names `scraper-1.flixquest.app`, which doesn't
   resolve. Render had no v3 when checked: the request timed out. A device that
   hasn't loaded remote config yet falls back to the bundled URL, and stream lookups
   would fail. Point it at `https://scraper.flix.quest`. Also confirm
   `flixquest_api_url_v2` and the API instances in remote config only list scrapers
   with v3, because the app doesn't fall back to v2.

2. **Compare the certificate with a published APK (recommended).** The release
   hash below came from the release keystore. It is public, not a secret:

   ```text
   160a12026d628039d3202d91706a8a29deda4c3913503ff568000ebbe926b87f
   ```

   ```bash
   ~/Library/Android/sdk/build-tools/36.0.0/apksigner verify --print-certs <published.apk> | grep SHA-256
   ```

   If it differs, stop. Android refuses updates signed with a different
   certificate, and this key would not match builds signed with the other one.

3. **Build from a clean checkout of `main` and release:**

   ```bash
   fvm flutter build apk --release --flavor prod --obfuscate --split-debug-info=build/symbols
   ```

   Keep `build/symbols` for Crashlytics.

To test any signed build against production:

```bash
fvm flutter run --flavor dev -d <device> -t tool/scraper_v3_smoke.dart \
  --dart-define=SCRAPER_URL=https://scraper.flix.quest
```

Add `--release` to test a release build. `flutter run` doesn't accept
`--obfuscate`, so build the obfuscated APK with `-t tool/scraper_v3_smoke.dart`,
install it and read logcat. Look for `SCRAPER_V3_SMOKE PASS`. Debug and release
builds have different signatures, so switching between them means uninstalling
the app first.

## If keys fail: the emergency switch

Symptom: stream lookups fail with 401 for many users. Crashlytics may show
non-fatal `Scraper v3 fell back to plain` errors.

**Turn it on:**

```bash
ssh flixquest-vps
sudo sh -c 'echo SCRAPER_V3_MODE=open >> /etc/flixquest/scraper.env'
sudo systemctl restart flixquest-scraper
```

Streaming recovers with no app update, for builds that include this fail-safe.

**Turn it off once the key is fixed.** While it's on, anyone can call v3 without a
key, as on v2:

```bash
sudo sed -i '/^SCRAPER_V3_MODE=/d' /etc/flixquest/scraper.env
sudo systemctl restart flixquest-scraper
```

The startup log warns whenever open mode is on. Check for it with
`sudo journalctl -u flixquest-scraper | grep SCRAPER_V3_MODE`.

| Situation | `sealed` (default) | `open` |
|---|---|---|
| Sealed request, known key | Sealed reply | Plain reply |
| Sealed request, unknown or broken key | Plain 401 | 401 with `fallback: plain`, and the app resends plain |
| Plain request | 401 | Plain reply |
| `SCRAPER_V3_KEYS` missing or invalid | 503 | Plain requests still work |
| Stale timestamp | Sealed `clock_skew` | Ignored |

Plain request body: `{ "plain": true, "params": { ... } }`. The parameter allowlist
applies in both modes, so `fProxy` and `full` stay blocked.

**The app has no setting for this.** On each call it tries encrypted first. It only
sends plain if it can't build its key, or the server replies with `fallback: plain`.
It resends at most once, and it remembers nothing between calls.

**Why the switch is manual:** the server can't tell a broken app from someone who
never had the key. Opening automatically would let attackers trigger it with bad
requests. Only the exact value `open` turns it on, so a typo stays `sealed`.

**Trade-off:** the app accepts a plain JSON 2xx, because open mode needs it. Someone
inspecting their own device could feed their own copy fake links. HTTPS still
protects everyone else.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Encrypt requests too? | Yes | A sealed request authenticates the caller, so bad requests are rejected before scraping uses the proxy pool |
| Where the key lives | Compiled into the app (option A) | Owner's choice. Remote Config, login-issued session keys and device attestation were considered and not chosen |
| IP rate limiting | None | Owner's explicit decision. Don't add it without asking |
| Derive the key from the `.jks`? | No | Only the public certificate hash is used. The private key stays out of it |

A key shipped in an app is obfuscation, not real security. It stops URL copying,
casual mitmproxy use and other apps reusing the API. A skilled reverse engineer
can still hook the running app. Replacing a leaked key requires a new release.

## How it works

### Routes

All are `POST /api/v3/...`. The decrypted reply has the same status and JSON as
the v2 route, because both share one handler.

| Route | Params allowed inside the envelope |
|---|---|
| `/stream-movie` | `provider`, `tmdbId`, `skipCache`, `nocache`, `refresh` |
| `/stream-tv` | `provider`, `tmdbId`, `season`, `episode`, `skipCache`, `nocache`, `refresh` |
| `/stream-size` | `token` |
| `/stream-sizes` | `tokens` |
| `/dlhd/stream`, `/dlhd/embeds`, `/ntv/stream` | `id` |
| `/ethiosports/stream` | `id`, `variant`, `server` |

Everything else is dropped, including `fProxy` and `full`. The app has no
Ethio Sports client yet.

These stay public on v2 because they don't return playable sources or the player
fetches them directly: `/proxy`, `/constructed.m3u8`, subtitle search and files,
provider lists, channel lists and EPG. **Retiring v2's JSON routes must not
remove the player-facing ones.**

### Wire format

```text
Request:   { "kid": "...", "iv": "<base64>", "ct": "<base64>" }
Decrypted: { "ts": <unix seconds>, "nonce": "...", "params": { ... } }
Response:  { "iv": "<base64>", "ct": "<base64>" }  decrypts to gzipped JSON
```

- **Cipher:** AES-256-GCM with a 12-byte IV. `ct` is the ciphertext followed by
  the 16-byte tag.
- **Purpose keys:** HKDF-SHA256 over the root key with an empty salt, using the
  info `fq-v3-request` or `fq-v3-response`.
- **Additional data:** `POST <path> <kid>` for requests and `<path> <nonce>` for
  responses. `<path>` is always `/api/v3/<route>`.

### Server replies

| Case | Reply |
|---|---|
| Envelope can't be authenticated | Plain `401 Unauthorized`, before any scraping |
| `SCRAPER_V3_KEYS` missing or invalid | Plain `503` |
| Timestamp more than 300 seconds off | Sealed `401` with `error: clock_skew` and `serverTime` |
| Anything else, including handler errors | Sealed, with the handler's real status |

On `clock_skew` the client corrects its clock offset and retries once. A 2xx that
isn't sealed or a JSON object is rejected. See
[the emergency switch](#if-keys-fail-the-emergency-switch) for open mode.

### Root key derivation

```text
mix  = HMAC-SHA256(native secret, "fq-v3-mix|<package>|<cert hash>")
root = HKDF-SHA256(ikm  = base64-decoded Dart fragment + mix,
                   salt = certificate SHA-256 bytes,
                   info = "fq-v3-root|<package>|<kid>")
```

- The package is `dev.beamlak.flixquest_v2`.
- Each signing certificate derives a different key, so a re-signed APK fails.
- Release builds use `SCRAPER_PROD_*`. Debug and profile builds use
  `SCRAPER_DEV_*`.
- The server only stores the final root key. It never needs `.env.scraper` or
  the `.jks`.

## Files

### Flutter

| File | Purpose |
|---|---|
| `lib/core/network/scraper_v3/scraper_v3_client.dart` | Sends sealed calls, handles clock correction, rejects unsealed successes |
| `lib/core/network/scraper_v3/scraper_cipher.dart` | Seals requests and opens responses |
| `lib/core/network/scraper_v3/scraper_key_derivation.dart` | Key derivation shared by the app and the tool |
| `lib/core/network/scraper_v3/scraper_key_loader.dart` | Reads the fragment, native mix and certificate on the device |
| `lib/core/network/scraper_v3/scraper_key_loader_stub.dart` | Used by plain `dart run` tools through a conditional import |
| `lib/core/config/scraper_secrets.dart` | `envied` fields. The generated `.g.dart` is gitignored |
| `android/app/src/main/cpp/fq_core.cpp` | Native HMAC holding the masked secret |
| `android/app/src/main/cpp/CMakeLists.txt` | Native build. Fails without the secret |
| `android/app/build.gradle` | Passes `SCRAPER_NATIVE_SECRET` to CMake |
| `tool/scraper_key.dart` | `init` and `server-key` commands |
| `tool/scraper_v3_smoke.dart` | Device test against a real scraper |
| `test/support/sealed_scraper.dart` | Plays the server side of the envelope in tests |
| `test/flutter_test_config.dart` | Installs a test key for all tests |

`scraper_api.dart`, `daddylive_service.dart` and `ntv_service.dart` were changed
to use the client. `retry_interceptor.dart` gained a `retrySafe` flag.

### Scraper

| File | Purpose |
|---|---|
| `src/routes/v3.ts` | Route table, allowed params, sealing `res.json` |
| `src/utils/sealed-envelope.ts` | Keyring parsing, opening requests, sealing responses |
| `src/routes/v3.test.ts` | Run with `pnpm test:v3` |
| `src/index.ts` | Mounts v3 and turns the stream handlers into named functions |
| `src/routes/dlhd.ts`, `ntv.ts`, `ethio-sports.ts` | Export their stream handlers |

`openapi.json`, `README.md` and `.env.example` in the scraper repo are updated.
The Flutter repo's `openapi.json` is not. It already differed from the
scraper's copy.

## Setting up a new machine

1. Restore `.env.scraper` from the private backup into the Flutter repo root.
2. Run `fvm dart run build_runner build --delete-conflicting-outputs`.

Android builds fail without `.env.scraper`. Only run `tool/scraper_key.dart init`
if no key exists anywhere, because new inputs mean a new key and a new release.

Debug certificate hash, for dev keys:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -storepass android | grep SHA256:
```

## Replacing a key

1. Change `KID` and `FRAGMENT` for that mode in `.env.scraper`, then run
   `build_runner`.
2. Generate the new value with `server-key`.
3. Add it to `SCRAPER_V3_KEYS` next to the old one, separated by a comma.
4. Release the app.
5. Remove the old value once old builds have updated.

Changing `SCRAPER_NATIVE_SECRET` affects both the prod and dev keys.

## Things that will break if changed carelessly

- **Don't add `cryptography_flutter`.** It sends the key through Android's Java
  crypto, where one Frida hook can capture it.
- **Keep the `asm` barrier in `fq_core.cpp`.** Without it the compiler folds the
  mask away and stores the plain secret in the binary. This really happened.
  After native changes, confirm the secret bytes aren't in `libfqcore.so`.
- **Never list `.env.scraper` in `pubspec.yaml` assets.** The regular `.env` ships
  in the APK as plain text.
- **Express 5's `req.query` is getter-only.** `v3.ts` uses
  `Object.defineProperty` because plain assignment throws.
- **v3 mounts ahead of v2's global middleware,** which reads the plain query
  string. v3 applies proxy and cache context itself after decrypting. Providers
  that need the proxy break without it.
- **`_post` in `scraper_api.dart` treats 5xx as errors on purpose,** so lookups
  keep the retries they had as GETs. The sealed reason is recovered afterwards.
- **`daddylive_service.dart` must stay free of Flutter imports,** because
  `tool/dlhd_live_smoke.dart` runs it with plain `dart run`. That tool can't reach
  v3 routes, so those steps fail and fall through.

## What was tested

Run on 2026-11-06 against production unless noted.

| Check | Result |
|---|---|
| Real debug app: open Fight Club, tap Play | `POST /api/v3/stream-movie` returned 200, and the movie played |
| Real obfuscated release app, same steps | Same, with 5 links and 120 subtitles decrypted |
| Smoke tool on debug and obfuscated release builds | Passed, so both derive the key the server holds |
| v2 vs v3 with the production key on 3 providers, plus TV, NTV and DLHD embeds | Same results |
| Live traffic from released apps on v2 after the deploy | Still returning 200s |
| Plain POST to v3, and GET to v3 | 401 and 404 |
| Stale timestamp | Sealed `clock_skew` reply |
| VPS release tool's tests and health check | Passed, and the release activated with 0 restarts |
| Plain request and unknown key against production | Both plain 401s with no `fallback`, so production stays sealed |
| Device, local scraper, `open`, no keys | Smoke passed: sealed, rejected, resent plain |
| Device, local scraper, `open`, right key | Smoke passed |
| Device, local scraper, `sealed`, wrong key | All 401, so it failed closed as intended |
| Device, local scraper, `sealed`, right key | Smoke passed |
| `scripts/scraper-smoke.mjs` on the VPS | 17 of 17 |
| Fake relay passed through `fProxy` (local server) | 2 hits on v2, 0 on v3 |
| All 14 scraper test suites locally | 234 pass, plus typecheck and build |
| Flutter suite | 2139 pass, 3 fail |
| Secret scan of the release APK's `.so`, `.dex` and asset files | Nothing found in plain form |

The 3 Flutter failures also fail on a clean checkout of `34ae2e4`:

- `test/presentation/config_source_controller_test.dart`
- `test/presentation/bootstrap_view_model_test.dart`
- `test/tv_media_details_test.dart`

### Not tested

- Live TV through the real app. The routes were called directly, but nobody
  tapped through a DLHD or NTV channel.
- TV episodes through the real app, and the Android TV interface.
- A clock-skew retry on a real device.
- A physical phone or a cheap TV box. All runs used an arm64 emulator.
- Open mode in production. It has only run against a local scraper.
- The app failing to build its key on a device (`key_unavailable`). Only unit tests
  cover this.
- The Crashlytics report actually arriving in the Firebase console.

When testing locally, set `PROVIDER_HEALTH_MONITOR_ENABLED=false` and
`REDIS_CACHE_ENABLED=false`. Use enabled providers from `/api/v2/providers`,
because `vixsrc`, `vidrock` and `videasy` are disabled. The emulator's AVD is
`Pixel_7_Pro_2`, and it needs `-dns-server 8.8.8.8,1.1.1.1`.

## Open issues

Most serious first. None are fixed.

1. **v2 is still open.** Anyone can call it for the same data, so v3 protects
   little until v2's JSON routes are retired. Use the in-app update screen to move
   users first.
2. **v2's `fProxy` accepts any relay URL,** with no validation found in the code
   reviewed. A caller can route scraper requests through their own server or at
   internal addresses. This was confirmed on a local server, and Caddy doesn't
   filter it. The current app doesn't send it. Check older releases, then remove
   the URL form.
3. **Requests can be replayed for about 5 minutes.** The sender can't read the
   reply, but it does trigger a scrape. A Redis nonce check would close this.
4. **Playback URLs stay visible on the user's device.** `/proxy` redirects to the
   provider URL and proxy tokens are readable. `/constructed.m3u8` data is unsigned
   (low risk). This is a known limit of encrypting only the API call.
5. **Admin routes have no auth in the app itself:** `POST /cache/flush` and
   `POST /providers/:id/toggle`. Caddy returns 403 for them on
   `scraper.flix.quest` (checked), so this only matters for deployments without
   Caddy, such as Render.

Checked and fine: `STREAM_PROXY_SECRET` is set in production, so signing doesn't
fall back to the TMDB key.

## Production deployment

- **Host:** `ssh flixquest-vps` (`213.199.52.19`), behind Cloudflare and Caddy.
- **Service:** `flixquest-scraper` on `127.0.0.1:3200`. Env is in
  `/etc/flixquest/scraper.env`.
- **Deploy:** `sudo fq deploy scraper <commit-or-branch>`. It fetches from GitHub,
  runs the build and tests, and restores the old release if the health check fails.
  The ref must be pushed first.
- **Other commands:** `sudo fq releases scraper`, `sudo fq rollback scraper`,
  `sudo fq status scraper`.
- **Logs:** `/var/log/caddy/scraper-requests.log` shows v3 traffic.
- **Docs:** `/opt/flixquest-platform/README.md`.

To add or replace a key, edit `SCRAPER_V3_KEYS` in the env file, then run
`sudo systemctl restart flixquest-scraper`.
