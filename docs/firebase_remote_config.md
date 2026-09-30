# Firebase Remote Config: feature toggles, logos and occasional themes

This file documents the Remote Config values used by the feature toggles and by
the occasional-theme system. The theme catalog is intentionally one JSON string
so a single publish activates a consistent catalog on every client.

## Feature toggles

| Parameter | Firebase type | Default | Purpose |
| --- | --- | --- | --- |
| `enable_stream` | Boolean | `true` | Shows every **Watch now** / **Play** affordance. |
| `enable_download` | Boolean | `true` | Shows every **Download** button for movies and episodes. |
| `enable_live_tv` | Boolean | `true` | Shows the Live TV shortcuts and the Android TV **Live TV** destination. |
| `enable_ott` | Boolean | `true` | Legacy Live TV key. Only consulted when `enable_live_tv` has not been published. |

All three toggles are registered as in-app defaults set to `true`, so a failed,
throttled, or offline fetch never hides playback, downloads, or Live TV. Publish
`false` to hide a feature.

Turning a toggle off only removes the entry points; it does not delete state.
With `enable_download` off, the Downloads library and any already-downloaded
files stay reachable so users can still watch what they have. With
`enable_stream` off, the Continue watching rows still resume playback.

`enable_live_tv` supersedes `enable_ott`. A remotely published `enable_live_tv`
always wins; if only `enable_ott` is published, its value is still honoured so
existing consoles keep working. Publish `enable_live_tv` and retire `enable_ott`
once every client is on a build that reads the new key.

### What each toggle hides

| Toggle | Surfaces |
| --- | --- |
| `enable_stream` | Movie/episode detail **Watch now**, the home hero **Watch now** on both the Movies and TV tabs, the poster-page watch button, the Android TV movie **Play** action and the Android TV episode dialog's **Play episode** action. |
| `enable_download` | Movie detail **Download** and episode detail **Download**. |
| `enable_live_tv` | The Live TV shortcut on the handheld Movies and TV tabs and the Android TV shell's **Live TV** rail destination and screen. |

## Logos and themes

| Parameter | Firebase type | Default | Purpose |
| --- | --- | --- | --- |
| `occasional_theme` | String | `{"enabled":false}` | Versioned theme catalog described below. |
| `app_logo_url` | String | Empty | General in-app logo URL when no active theme supplies one. |
| `cinemax_logo` | String | `default` | Legacy logo fallback. Keep only while older clients need it. |

An active theme's `logo_url` wins over `app_logo_url`, which wins over
`cinemax_logo`, which wins over the bundled logo. The native Android/iOS launch
splash remains bundled because it appears before Firebase initializes.

## API and service configuration

| Parameter | Firebase type | Default | Purpose |
| --- | --- | --- | --- |
| `tmdb_api_key` | String | Empty | TMDB API key override. When non-empty, overrides the local `.env` key at runtime. Falls back to `.env` when empty, unpublished, or offline. |
| `tmdb_proxy` | String | Empty | Optional reverse proxy URL prefix for TMDB image and metadata requests. |
| `flixquest_api_instances` | String | Empty | JSON array or `{"instances": [...]}` defining load-balanced FlixQuest scraper endpoints. |
| `flixquest_api_url_v2` | String | Empty | Legacy single fallback URL for the scraper API. |

## Ad network and banner configuration

| Parameter | Firebase type | Default | Purpose |
| --- | --- | --- | --- |
| `banner_ad_network` | String | `native` | Legacy banner selector. `native`, `unity`, and `startio` all render Start.io banners so existing published values remain compatible; `none` hides every banner, hosted ones included. |
| `hosted_banner_mode` | String | `stack` | How the hosted `/ads` banner (announcements and calls to action) shares a slot with the Start.io banner. `stack`: both show, hosted above Start.io. `priority`: a slot with a live hosted ad shows only that ad; other slots keep Start.io. `off`: hosted banners never show. Unknown values behave as `stack`. |
| `unity_game_id_android` | String | `5445375` | Legacy compatibility key retained for older app versions. New builds do not initialize Unity from it. |
| `unity_banner_placement_id` | String | `Banner_Android` | Legacy compatibility key retained for older app versions. |
| `unity_test_mode` | Boolean | `false` | Legacy-named test-mode switch now also controls Start.io test ads. |
| `startio_banner_enabled` | Boolean | `false` | Enables Start.io banners on all existing banner surfaces only when remotely set to `true`. `banner_ad_network=none` remains the global banner kill switch. |
| `startio_interstitial_enabled` | Boolean | `false` | Enables the preloaded Start.io interstitial on phones/tablets only when remotely set to `true`. It runs while the stream resolves and the player opens once it closes. Android TV never loads or shows interstitials. |
| `startio_rewarded_enabled` | Boolean | `true` | Legacy. Only the first Start.io build reads it (a rewarded video before every stream). Current builds show no rewarded ads; set `false` to switch it off in that old build. |
| `startio_interstitial_interval_seconds` | Number | `600` | Minimum gap between two playback interstitials, so replays, retries and channel surfing see one ad. Values below `60` are raised to `60`. |
| `startio_tv_interstitial_mode` | String | `video` | Legacy compatibility setting for older builds with TV interstitials. Current builds never load or show interstitials on Android TV. |
| `banners` | String | `{"banners":[]}` | Per-ad display overrides for hosted `/ads` banners, keyed by the ad's `key` (`enabled`, `placements`, `shape`, `width`, `height`, `aspectRatio`). |

### Hosted `/ads` banners beside Start.io

The two sources are independent: `startio_banner_enabled` controls Start.io,
`hosted_banner_mode` controls hosted banners, and either can run without the
other. One `/ads` response is fetched and shared by every slot on screen
(cached for 5 minutes, or 1 minute when empty).

Each ad's `placements` list picks where it shows. On phones and tablets an
empty list means every slot; otherwise the placement name must be listed.
Slot names: `home_{all|movies|series}_{hero|trending|genres}`, `new_and_hot`,
`movie_detail`, `tv_detail`, `season_detail`, `episode_detail`,
`collection_detail`, `person_detail`, `bookmarks`, `downloads`,
`stream_loading`, `live_tv_top` and `live_tv_list_{a|b|c}`.

Android TV only shows an ad that lists the `_tv` name (`title_detail_tv`,
`live_tv_strip_tv`), so a phone announcement never reaches a television. TV
banners are display-only (no focus, no tap), because Android TV's quality
rules forbid an in-page ad that opens a web page; put the message in the
image itself. Start.io banners use the existing top-right title-details slot
(`title_detail_tv`) and the strip below the Live TV list (`live_tv_strip_tv`)
when `startio_banner_enabled=true`. TV interstitials remain disabled regardless
of `startio_interstitial_enabled`. TV Home has no banner slot.

For Start.io banners without interstitials on any device, publish
`startio_banner_enabled=true` and `startio_interstitial_enabled=false`.

The Start.io application ID is build-time Android metadata, not a Remote Config
value. Set `startapp.appId` in `android/local.properties` or provide the
`STARTAPP_APP_ID` build environment variable. Return and splash ads are disabled;
only banners and the playback interstitial are used. Local builds fall
back to Start.io's demo application ID (`205489527`); production builds should
always supply the FlixQuest Start.io application ID.

## Ready-to-paste complete catalog

Create `occasional_theme` as a **String**, paste this JSON as its value, replace
the logo URLs and dates, then publish. Overlapping dates are supported.

```json
{
  "schema_version": 2,
  "enabled": true,
  "allow_user_selection": true,
  "effects_enabled": true,
  "allow_user_effects_toggle": true,
  "default_theme_id": "",
  "themes": [
    {
      "id": "christmas",
      "display_name": "Christmas",
      "description": "A warm Christmas celebration",
      "enabled": true,
      "user_selectable": true,
      "priority": 80,
      "logo_url": "https://example.com/logos/christmas.png",
      "starts_at": "2026-12-01T00:00:00Z",
      "ends_at": "2027-01-07T23:59:59Z",
      "effect": {
        "enabled": true,
        "type": "snow",
        "density": 34,
        "speed": 0.75,
        "opacity": 0.62,
        "colors": ["#FFFFFF", "#DCEEFF", "#EAF7FF"]
      }
    },
    {
      "id": "ethiopian_new_year",
      "display_name": "Ethiopian New Year",
      "description": "Enkutatash and the season of Adey Abeba",
      "enabled": true,
      "user_selectable": true,
      "priority": 90,
      "logo_url": "https://example.com/logos/enkutatash.svg",
      "starts_at": "2026-09-01T00:00:00+03:00",
      "ends_at": "2026-09-20T23:59:59+03:00",
      "effect": {
        "enabled": true,
        "type": "adey_flowers",
        "density": 26,
        "speed": 0.7,
        "opacity": 0.55,
        "colors": ["#F9A825", "#FFD740", "#2E7D32"]
      }
    },
    {
      "id": "new_year",
      "display_name": "New Year",
      "enabled": true,
      "user_selectable": true,
      "priority": 100,
      "logo_url": "https://example.com/logos/new-year.png",
      "starts_at": "2026-12-28T00:00:00Z",
      "ends_at": "2027-01-03T23:59:59Z",
      "effect": {
        "enabled": true,
        "type": "fireworks",
        "density": 12,
        "speed": 0.9,
        "opacity": 0.7
      }
    },
    {
      "id": "halloween",
      "display_name": "Halloween",
      "enabled": true,
      "user_selectable": true,
      "priority": 70,
      "logo_url": "https://example.com/logos/halloween.png",
      "starts_at": "2026-10-20T00:00:00Z",
      "ends_at": "2026-11-02T23:59:59Z",
      "effect": {
        "enabled": true,
        "type": "bats",
        "density": 14,
        "speed": 0.65,
        "opacity": 0.48
      }
    },
    {
      "id": "valentines",
      "display_name": "Valentine's Day",
      "enabled": true,
      "user_selectable": true,
      "priority": 60,
      "logo_url": "https://example.com/logos/valentines.png",
      "starts_at": "2027-02-07T00:00:00Z",
      "ends_at": "2027-02-15T23:59:59Z",
      "effect": {
        "enabled": true,
        "type": "hearts",
        "density": 20,
        "speed": 0.6,
        "opacity": 0.48
      }
    },
    {
      "id": "easter",
      "display_name": "Easter",
      "enabled": true,
      "user_selectable": true,
      "priority": 55,
      "logo_url": "https://example.com/logos/easter.png",
      "starts_at": "2027-03-22T00:00:00Z",
      "ends_at": "2027-03-30T23:59:59Z",
      "effect": {
        "enabled": true,
        "type": "candy_eggs",
        "density": 20,
        "speed": 0.6,
        "opacity": 0.5
      }
    },
    {
      "id": "eid",
      "display_name": "Eid",
      "enabled": true,
      "user_selectable": true,
      "priority": 75,
      "logo_url": "https://example.com/logos/eid.svg",
      "starts_at": "2027-03-08T00:00:00Z",
      "ends_at": "2027-03-13T23:59:59Z",
      "effect": {
        "enabled": true,
        "type": "stars",
        "density": 24,
        "speed": 0.55,
        "opacity": 0.58,
        "colors": ["#D4AF37", "#FFF8E1", "#00897B"]
      }
    },
    {
      "id": "diwali",
      "display_name": "Diwali",
      "enabled": true,
      "user_selectable": true,
      "priority": 65,
      "logo_url": "https://example.com/logos/diwali.png",
      "starts_at": "2026-11-01T00:00:00+05:30",
      "ends_at": "2026-11-10T23:59:59+05:30",
      "effect": {
        "enabled": true,
        "type": "sparkles",
        "density": 30,
        "speed": 0.7,
        "opacity": 0.64
      }
    }
  ]
}
```

The dates above are configuration examples, not a permanent holiday calendar.
Update movable observances such as Easter, Eid, and Diwali each year before
publishing.

## Catalog configuration

| Field | Type | Default | Behavior |
| --- | --- | --- | --- |
| `schema_version` | Integer | `2` | Current schema version. |
| `enabled` | Boolean | `false` | Master switch. When false, no occasional theme or effect is used. |
| `allow_user_selection` | Boolean | `false` | Shows Seasonal theme in handheld and TV settings. |
| `effects_enabled` | Boolean | `true` | Master switch for every vector effect. Colors and logos still work when false. |
| `allow_user_effects_toggle` | Boolean | `false` | Lets users disable decorative effects in settings. |
| `default_theme_id` | String | Empty | Automatic mode prefers this active ID. Empty uses priority. |
| `themes` | Array | Empty | Up to 24 definitions; duplicate IDs use the last definition. |

### Overlap and selection rules

1. Only themes with `enabled: true` inside their start/end window are active.
2. A user's explicit active selection wins when selection is allowed.
3. Otherwise Automatic uses an active `default_theme_id`, if supplied.
4. Otherwise the highest `priority` wins.
5. Equal priorities are resolved by ID alphabetically for deterministic results.
6. Removed, disabled, or expired user choices return to Automatic.

### User controls

When the catalog is enabled, **Settings → Appearance → Seasonal themes** is a
local master switch. It defaults to on. Turning it off removes the occasional
palette, occasional logo, and decorative effect while preserving the selected
theme for later. On TV, the same switch is available under **Settings →
Seasonal themes**.

When `allow_user_effects_toggle` is true, **Seasonal effects** is a separate
switch that disables only snow, flowers, treats, fireworks, and other decorations while
keeping the seasonal colors and logo.

## Theme configuration

| Field | Type | Default | Behavior |
| --- | --- | --- | --- |
| `id` | String | Required | Stable lowercase identifier. Built-in IDs are listed below. |
| `display_name` | String | Preset/name derived from ID | User-facing label in settings. |
| `description` | String | Empty | Optional catalog description reserved for richer selectors. |
| `enabled` | Boolean | `false` | Switch for this definition. |
| `user_selectable` | Boolean | `true` | Whether this active theme appears as a manual choice. |
| `priority` | Integer | `0` | Automatic overlap priority, clamped from `-1000` to `1000`. |
| `logo_url` | String | Empty | Theme logo; HTTPS PNG/WebP/JPEG/GIF/SVG recommended. |
| `colors` | Array of two hex colors | Required for custom IDs | Primary and complementary secondary colors. `#RRGGBB` or `#AARRGGBB`. |
| `primary_color` | Hex color | Preset | `#RRGGBB` or `#AARRGGBB`. |
| `secondary_color` | Hex color | Preset | Secondary palette color. |
| `tertiary_color` | Hex color | Preset/derived | Optional third accent; custom themes derive it from `colors`. |
| `light_background_color` | Hex color | Preset/derived | Optional page surface in Light mode. |
| `dark_background_color` | Hex color | Preset/derived | Optional page surface in Dark/AMOLED mode. |
| `starts_at` | ISO-8601 string | No lower bound | UTC or an explicit offset such as `+03:00`. |
| `ends_at` | ISO-8601 string | No upper bound | Inclusive activation endpoint. |
| `effect` | Object | Disabled preset effect | Optional vector effect configuration. |

Malformed or structurally invalid JSON is not persisted and leaves the last
known-good catalog active. An invalid date or reversed date range removes that
theme from the catalog. Invalid colors on a built-in ID fall back to its
hardcoded preset. An enabled custom ID requires two distinct valid colors; an
invalid custom entry is ignored, allowing another valid built-in entry in the
same catalog to act as the fallback. Unknown effect names use the preset type.
An unreachable/invalid logo URL falls back to the next logo source without
breaking the page.

## Built-in theme IDs and defaults

| ID | Aliases | Default effect | Palette character |
| --- | --- | --- | --- |
| `christmas` | `xmas` | `snow` | Red, evergreen, gold |
| `ethiopian_new_year` | `ethiopian-new-year`, `enkutatash` | `adey_flowers` | Falling leaves with miniature Adey flowers |
| `new_year` | `new-year` | `fireworks` | Gold, indigo, magenta |
| `halloween` | — | `bats` | Orange, purple, near-black |
| `valentines` | `valentines_day`, `valentine` | `hearts` | Rose and pink |
| `easter` | — | `candy_eggs` | Falling leaves, wrapped candies, and decorated eggs |
| `eid` | `eid_al_fitr`, `eid_al_adha` | `stars` | Emerald, gold, violet |
| `diwali` | — | `sparkles` | Saffron, pink, purple |

Any other ID is a custom theme. Supply two distinct complementary colors using
`colors`, or the equivalent `primary_color` and `secondary_color` fields. The
app derives a tertiary accent and readable Light/Dark surfaces from that pair;
you can still override those derived values explicitly. The default custom
effect type is `confetti`.

## Effect configuration

Effects are vector shapes drawn by Flutter; no image assets or downloads are
required. They ignore pointer input, stop while the app is backgrounded, and
are automatically hidden when the operating system requests reduced motion.

| Field | Type | Default | Valid values / limits |
| --- | --- | --- | --- |
| `enabled` | Boolean | `false` | Per-theme effect switch. |
| `type` | String | Theme preset | `none`, `snow`, `confetti`, `fireworks`, `petals`, `candy_eggs`, `adey_flowers`, `hearts`, `stars`, `bats`, `sparkles` |
| `density` | Integer | `28` | Clamped to `4`–`80`; use `8`–`36` for TVs and phones. |
| `speed` | Number | `1.0` | Clamped to `0.2`–`3.0`. |
| `opacity` | Number | `0.65` | Clamped to `0.1`–`1.0`. |
| `colors` | Array of hex colors | Theme-aware colors | Optional, first eight valid colors are used. |

To keep a seasonal palette/logo without animation:

```json
"effect": { "enabled": false, "type": "snow" }
```

To disable every effect immediately while preserving all seasonal themes:

```json
"effects_enabled": false
```

## Custom campaign example

```json
{
  "id": "flixquest_anniversary",
  "display_name": "FlixQuest Anniversary",
  "enabled": true,
  "user_selectable": true,
  "priority": 500,
  "colors": ["#7B1FA2", "#00897B"],
  "logo_url": "https://example.com/logos/anniversary.svg",
  "starts_at": "2026-10-01T00:00:00Z",
  "ends_at": "2026-10-15T23:59:59Z",
  "effect": {
    "enabled": true,
    "type": "confetti",
    "density": 30,
    "speed": 0.8,
    "opacity": 0.55,
    "colors": ["#7B1FA2", "#00897B", "#F9A825"]
  }
}
```

Add that object inside the catalog's `themes` array.

For a safe custom-event rollout, keep a built-in definition (for example
`halloween`) in the same catalog with a lower priority and the same activation
window. If the custom entry is invalid, the parser drops it and automatic mode
resolves the built-in preset. If the entire new value is malformed, the app
keeps the previously persisted catalog instead.

## Safe rollout and rollback

1. Publish the catalog with `enabled: false` to validate delivery first.
2. Enable individual themes and confirm their date windows and logo URLs.
3. Set catalog `enabled: true`; use Firebase targeting/percentage conditions if
   you want a staged rollout.
4. Roll back instantly with `{"schema_version":2,"enabled":false,"themes":[]}`.

Clients persist the last successfully activated remote catalog for offline
startup and listen for real-time Remote Config activation events. Start/end
boundaries are also scheduled locally, so an open app changes theme without a
restart or another fetch.

## Legacy single-theme format

Older values still work and are migrated in memory:

```json
{
  "enabled": true,
  "id": "christmas",
  "logo_url": "https://example.com/christmas.png",
  "starts_at": "2026-12-01T00:00:00Z",
  "ends_at": "2027-01-07T23:59:59Z"
}
```

Legacy format does not expose user selection. Move to schema version 2 for
overlaps, selection, priorities, and global effect controls.
