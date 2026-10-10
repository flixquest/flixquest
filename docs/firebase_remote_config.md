# Firebase Remote Config: feature toggles, logos and occasional themes

This file documents the Remote Config values used by the feature toggles and by
the occasional-theme system. The theme catalog is intentionally one JSON string
so a single publish activates a consistent catalog on every client.

At startup, the app loads and applies Firebase's last activated values before
refreshing them over the network. A slow refresh therefore keeps the cached ad
selection usable for the first playback attempt. A fresh install still uses
the disabled ad defaults until its first successful fetch.

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

## Ad networks at a glance

FlixQuest serves three ad formats, and each one picks its network with its own
selector. Every network keeps its codes in its own catalog and has its own
switch, so both catalogs can stay published and swapping providers is a change
of the selector alone. A selector value of `none`, or any unknown value, turns
the format off. Selectors are case-insensitive and apply while the app runs.

| Format | Selector (default) | Adsterra | Clickadu |
| --- | --- | --- | --- |
| Banners | `banner_ad_network` (`adsterra`) | `adsterra_banner_enabled`, `adsterra_tv_enabled`, `adsterra_banners` | `clickadu_banner_enabled`, `clickadu_tv_enabled`, `clickadu_banners` |
| Stream-found popup (Popunder / Smartlink / Direct Link) | `playback_popunder_network` (`adsterra`) | `adsterra_playback_enabled`, `adsterra_playback_ads` | `clickadu_playback_enabled`, `clickadu_playback_ads` |
| Video pre-roll (VAST) | `vast_preroll_network` (`clickadu`) | `vast_preroll_enabled`, `vast_preroll.adsterra` | `vast_preroll_enabled`, `vast_preroll.clickadu` |

Monetag serves only the stream-found popup: `playback_popunder_network=monetag` with `monetag_playback_enabled` and `monetag_playback_ads`. See [Monetag popup](#monetag-popup).

ExoClick serves the stream-found popup through `exoclick_playback_enabled` and
`exoclick_playback_ads`, selected by `playback_popunder_network=exoclick`. See
[ExoClick popup](#exoclick-popup). Its video pre-roll uses
`vast_preroll.exoclick`. The pre-roll selector also takes a priority list such
as `exoclick,clickadu`: the next network is asked when the one before it has
no ad. See
[Video pre-roll (VAST)](#video-pre-roll-vast).

The Social Bar before the media loader is Adsterra-only (`adsterra_playback_ads`
`interstitial`). Switching a selector closes an active popup and replaces live
banners on the next frame; a pre-roll already playing finishes.

To add another network in code: add it to `AdNetwork`
(`lib/models/ad_network.dart`). The compiler then points at each place that
needs its formats: a `BannerAdUnit` subclass and its catalog parse in
`lib/models/banner_ads_config.dart`, its keys in `AppRemoteConfig`, and the
popup placement in `AdsterraPlaybackAdsService`. A VAST-only network needs
nothing beyond the enum value: its tag goes in its own `vast_preroll` section,
named after the enum value.

## Ad network and banner configuration

| Parameter | Firebase type | Default | Purpose |
| --- | --- | --- | --- |
| `banner_ad_network` | String | `adsterra` | Which network's WebView banners fill the slots: `adsterra` or `clickadu`. `none` hides all banners including hosted announcements. Published legacy values `native`, `unity`, and `startio` select Adsterra, but cannot enable requests without its switch and valid codes. Unknown values show no network banner but keep hosted announcements. |
| `adsterra_banner_enabled` | Boolean | `false` | Adsterra banner switch. Must be explicitly enabled remotely; no demo ads or hardcoded publisher codes ship in the app. |
| `adsterra_tv_enabled` | Boolean | `false` | Additional gate for Android TV; the global switch must also be on. TV placements use `_tv` names and TV-specific defaults. |
| `adsterra_banners` | String (JSON) | `{"units":{},"defaults":{},"placements":{}}` | Central catalog of banner codes, sizes, default variants and placement overrides. See below. |
| `clickadu_banner_enabled` | Boolean | `false` | Clickadu banner switch. Must be published remotely. |
| `clickadu_tv_enabled` | Boolean | `false` | Android TV gate for Clickadu banners, like `adsterra_tv_enabled`. |
| `clickadu_banners` | String (JSON) | `{"units":{},"defaults":{},"placements":{}}` | Clickadu's catalog: the same `units` / `defaults` / `placements` schema as Adsterra's, with Clickadu unit fields. See [Clickadu banners](#clickadu-banners). |
| `hosted_banner_mode` | String | `stack` | How `/ads` announcements share a slot with the network banner. `stack`: hosted above the network banner. `priority`: an eligible hosted banner takes the slot and the network banner loads only where no hosted ad exists. `off`: show only the network banner. Unknown values use `stack`. |
| `banners` | String (JSON) | `{"banners":[]}` | Existing per-announcement overrides for `/ads`, keyed by `key` (`enabled`, `placements`, `shape`, `width`, `height`, `aspectRatio`). Separate from the network catalogs. |

### Activate Adsterra banners

**Ready-to-publish catalog:** [adsterra_banners.json](adsterra_banners.json) contains the six active banner codes read from the FlixQuest publisher dashboard. Publish its contents as `adsterra_banners`; TV reuses the corresponding size codes until separate TV units are generated. The blank example remains available for other publisher accounts.

1. Generate banner codes in the Adsterra publisher dashboard, using the sizes you want. Each size needs its matching code; changing dimensions does not turn one ad unit into a different size.
2. Copy [adsterra_banners.example.json](adsterra_banners.example.json). For each unit you intend to use, fill `key` from the generated `atOptions.key`, and `script_url` with the exact HTTPS script URL from the generated code (the URL does not have to end in `invoke.js`). Empty units remain inactive. Protocol-relative URLs (`//...`) must be written as `https://...`.
3. Publish the completed JSON as the **String** parameter `adsterra_banners` in Firebase Remote Config.
4. Set `banner_ad_network=adsterra` and `adsterra_banner_enabled=true`. To activate television slots too, publish `adsterra_tv_enabled=true` and fill the TV units.
5. Select `hosted_banner_mode=off`, `stack`, or `priority` depending on whether your own announcements should appear.

Remote Config's existing realtime listener applies switches and new codes while the app is running. A changed unit replaces its WebView; turning a switch off removes the view and stops its document. Unrelated rebuilds keep the same WebView. No automatic ad refresh is scheduled.

The Start.io SDK, Android initialization/metadata, and playback interstitial paths have been removed from this build. Existing `startio_*` and `unity_*` parameters may remain in Firebase for older app versions; this build ignores them. There is no rewarded or fullscreen ad replacement.

### Catalog schema and sizes

```json
{
  "units": {
    "mobile_banner": {
      "key": "YOUR_320X50_KEY",
      "script_url": "https://YOUR_ADSTERRA_HOST/YOUR_320X50_KEY/invoke.js",
      "size": "320x50"
    },
    "rectangle": {
      "key": "YOUR_300X250_KEY",
      "script_url": "https://YOUR_ADSTERRA_HOST/YOUR_300X250_KEY/invoke.js",
      "size": "300x250"
    }
  },
  "defaults": {
    "standard": ["mobile_banner"],
    "tall": ["rectangle"],
    "tv_standard": ["mobile_banner"]
  },
  "placements": {
    "movie_detail": {"units": ["rectangle"]},
    "bookmarks": {"enabled": false},
    "title_detail_tv": {"units": ["mobile_banner"]}
  }
}
```

Supported `size` values are `320x50`, `300x250`, `468x60`, `728x90`, `160x300`, and `160x600`, matching [Adsterra's banner formats](https://adsterra.com/banner-ads/). Dimensions are CSS pixels / Flutter logical pixels, without enlarging or shrinking the creative.

`units` defines reusable named codes. A unit can also set `enabled=false`. `defaults` maps the existing thin (`standard`) and rectangle (`tall`) variants to unit IDs, with separate `tv_standard` and `tv_tall` variants. `placements` overrides those defaults for a particular slot. Both defaults and overrides accept an ordered `units` list (or a shorthand list/string). The first valid unit that fits the available width and height wins. For example, `["leaderboard", "mobile_banner"]` chooses 728x90 on a wide surface and 320x50 on a phone. A unit too large for the slot is skipped, so a 728x90 creative never gets cropped into the 360-wide TV details slot.

A placement override replaces the default; missing/invalid unit IDs in an override hide that placement rather than silently displaying another code. Malformed JSON, missing codes, invalid sizes, and non-HTTPS script URLs are inactive. TV never borrows a phone placement override or phone variant default.

Existing phone/tablet slot names:

- `home_{all|movies|series}_{hero|trending|genres}`
- `new_and_hot`, `movie_detail`, `tv_detail`, `season_detail`, `episode_detail`
- `collection_detail`, `person_detail`, `bookmarks`, `downloads`
- `stream_loading`, `live_tv_top`, `live_tv_list_a`, `live_tv_list_b`, `live_tv_list_c`

TV slots: `title_detail_tv` (top-right details slot, maximum width 360) and `live_tv_strip_tv` (below the Live TV list). TV Home has no banner slot. TV banners remain display-only and cannot take D-pad focus or open an offer. Hidden details banners are removed while browsing the lower rows.

### Clickadu banners

**Ready-to-publish catalog:** [clickadu_banners.json](clickadu_banners.json)
holds spot `2150724`. Publish it as `clickadu_banners`, publish
`clickadu_banner_enabled=true`, then set `banner_ad_network=clickadu`.
Switching back is `banner_ad_network=adsterra`.

Clickadu's code is a Main Tag (`bn.js`) plus one Ad Spot per banner
(`<div data-cl-spot="…">`). Every banner is its own WebView document, so the
app writes the Main Tag and the unit's spot into each one, which is the
one-spot-per-page case of Clickadu's guide.

```json
{
  "script_url": "https://guidepaparazzisurface.com/bn.js",
  "units": {
    "rectangle": {"spot_id": "2150724", "size": "300x250"}
  },
  "defaults": {"tall": ["rectangle"], "tv_tall": ["rectangle"]},
  "placements": {}
}
```

| Field | Where | Rules |
| --- | --- | --- |
| `script_url` | Catalog | The Main Tag's `src` with `https://` spelled out (the dashboard gives `//guidepaparazzisurface.com/bn.js`). |
| `spot_id` | Unit | The `data-cl-spot` value, digits only (string or number). |
| `size` | Unit | `WxH`, exactly the size the spot was created with in the Clickadu dashboard (the WebView is sized to it). Each side 20–1000. |
| `script_url` | Unit, optional | Overrides the catalog's Main Tag for that unit. |
| `enabled` | Unit, optional | `false` turns the unit off. |

`defaults` and `placements` work exactly as in Adsterra's catalog below. The
supplied catalog only fills the rectangle (`tall`) slots; thin (`standard`)
slots stay empty on Clickadu until you add a 320x50 or 728x90 spot and list
it under `standard` / `tv_standard`.

Clickadu's script fills the spot a moment after it loads, or not at all when
it has no ad. The slot counts as loaded only once a creative of visible size
appears; a spot still empty after 20 seconds collapses. The spot runs on the
app's placeholder origin (`appassets.androidplatform.net`), not the site it was
approved for. A desktop test page on `localhost` loaded `bn.js` but got no
creative, so confirm with Clickadu that the spot accepts in-app WebView
traffic.

### Loading and clicks

The banner WebView loads a minimal local HTML document with the network's generated code, JavaScript enabled, an `AD` label, and the exact unit dimensions. Adsterra and Clickadu banners share this view. The local document uses `https://appassets.androidplatform.net/adsterra/` as its HTTPS base URL, giving it an isolated app-content origin where `document.cookie` and storage work. Loading without a base URL creates an opaque origin and makes cookie-dependent scripts fail. This URL is not fetched and does not adopt the ad server or publisher website's origin. Ads use the actual system WebView user agent. Script load/runtime errors, main-document failures, or a script that fails to load within 20 seconds collapse the slot without blocking browsing or playback.

HTTP(S) offer navigation opens the external browser only following a recent pointer interaction on a phone/tablet. Programmatic main-frame redirects and non-web schemes are blocked; iframe resource navigation stays in the WebView. There are no forced clicks or Smartlink countdowns. Confirm the WebView inventory with Adsterra before publishing real codes, and use Adsterra's reporting to verify monetization; a script-load signal is not a billable-impression callback.

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


## Playback ads

Playback ads are controlled separately from banners. Android/iOS phones and
tablets show both stages. Android TV shows only the stream-found popup, from a
`tv_popunder` placement (see [Playback ads on Android TV](#playback-ads-on-android-tv)).
Downloads, desktop and web skip both stages. No publisher code is compiled into
the defaults.

The stream-found popup runs before movies and episodes, and before a Live TV
channel opens from the phone or TV Live screen (not on channel switches inside
the player).

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `adsterra_playback_enabled` | Boolean | `false` | Explicitly published switch for both mobile playback stages. Turning it off closes an active playback ad and continues the flow. |
| `adsterra_playback_ads` | String (JSON) | `{}` | Per-stage scripts or Smartlinks, enable flags and timeouts. |

Copy [adsterra_playback_ads.json](adsterra_playback_ads.json) into the String
parameter `adsterra_playback_ads`. It contains the Social Bar script and the
Smartlink supplied for FlixQuest. Publish `adsterra_playback_enabled=true` to
enable configured stages. Each stage also requires its own `enabled=true`. The
supplied catalog enables both stages. It opens the Smartlink in FlixQuest's
ad page on every stream-found attempt, with `psid=fqsmartpagev1`. It has no
experiment. There is no app cooldown: old `cooldown_seconds`
fields are ignored by the updated app. Only overlapping active ads are blocked.

- `interstitial`: shows Social Bar immediately before entering the movie/episode
  media loader. The loader is not constructed or started until the ad closes or
  fails. This includes Play Now, phone browse/detail/resume/episode entry points,
  and player recommendation/episode transitions. When this placement is disabled,
  playback builds the loader immediately, including its first frame; an enabled
  stream-found popunder does not insert a before-loader screen. Set
  `interstitial.enabled=false`, or remove the `interstitial` entry, to skip its
  ad page and gate entirely.
- `stream_found_experiment`: alternates Popunder then Smartlink after a playable
  stream is selected, before navigating to `player.dart`. The counter is saved
  per experiment `id` on the device, so restarting continues the sequence. Each
  eligible attempt consumes one variant, including failed loads. TV never uses
  the experiment. Download/background skips and overlapping requests do not
  consume variants. No second
  variant is loaded on the same attempt when the first fails.
- `popunder`: the single-placement key for this stage, whatever the format.
  The supplied catalog uses it for the Smartlink. It applies only
  when the experiment is absent or disabled. A malformed enabled experiment
  disables this stage instead of silently loading a different placement.

Popunder content starts loading only after a playable stream is selected and
its ad screen opens. Movie and episode scraping does not create an ad WebView
or start advertiser requests. Experiment variants are also selected at
stream-found, so an abandoned scrape consumes no variant.

Ads never open an external browser. Script tags (Social Bar, or a Popunder
tag) run in one WebView whose main frame never navigates. Script-initiated
navigations to `about:blank` or the app's base URL are dropped, and any other
web URL is treated as the popup. Advertiser pages (Smartlinks, and the popup
URLs that scripts emit) open in FlixQuest's **ad page**, a second full-screen
WebView that follows the network's redirect chain:

- A top bar shows an amber **Ad** badge and "Sponsored · keeps FlixQuest
  free". Once the page shows content, it names the advertiser's site instead
  ("Sponsored · example.com").
- Until the page has visible content, a placeholder covers the blank redirect
  pages: "Your video is ready. A short sponsored page comes first." (or "Opening
  the sponsor's page" / "Opening the advertiser's page"). It takes touches, so
  a tap on it never counts as a tap on the ad. Once revealed, the page stays on
  screen through later redirects, with a thin loading line under the bar.
- The way on (**Play now**, **Continue** before the loader, or **Back to
  video** for a video ad's click-through) and system Back appear only once the
  final ad has been seen. Seen means the last page of the redirect chain shows
  visible content, starts no new navigation for 800 ms, and has been on screen
  for 3 seconds since its content appeared. An earlier page that redirects
  restarts the count with the next one. Until the final page has content the
  pill where the button will be says "Ad loading"; then it counts "Continue in
  3…1". Pressing Back (or OK on a remote) early briefly highlights it.
- If the ad never gets there (a chain that keeps redirecting, say), the button
  appears at the placement's `close_fallback_seconds`, 15 by default, and the
  placeholder gives way to whatever the page shows. Google Play's
  [Better Ads Experiences policy](https://support.google.com/googleplay/android-developer/answer/12271244)
  allows a full-screen ad to stay unclosable for at most 15 seconds, so that is
  also the upper limit. A page that shows no content at all ends sooner, at
  `load_timeout_ms`.
- A redirect chain that lands on a search engine's home page (`google.<tld>`,
  `bing.com`) is a tracker rejecting the visit: there is no ad, so playback
  continues at once (`closing reason=no_ad_fallback`). App store listings and
  other Google pages are not affected.
- Each content check gives up after 2 seconds and the next one asks again: a
  check sent while the document is being replaced may never answer.
- App-install offers often end in a `market://` or `intent://` link that a
  WebView cannot load. The ad page loads the link's web page in place: the
  intent's `browser_fallback_url`, its https target, or the Play Store listing.
  Only a tap inside the ad in the previous two seconds, such as Install, hands
  the link to the Play Store app, using a launch mode that never opens a
  browser.
- A main-frame load error, an HTTP error on the main page, or a page that shows
  no content within `load_timeout_ms` continues playback.

The Social Bar page keeps its **Continue** control from the start. On a
stream-found tag page, its own **Play now** button leads on; **Skip** in the
top bar and system Back appear at the same `close_fallback_seconds`. Backgrounding
FlixQuest closes any ad, including the hand-off to the Play Store. Playback is
never handed to the player while FlixQuest is in the background; it continues
when the app resumes. An Android/iOS app cannot place a page behind its own
activity, so a Popunder's page opens in front, not as a literal pop-under.
Scripts open only the popup URL they emit, never their JavaScript source URL.
The tag's `window.open` is not replaced.

Per-stage fields:

| Field | Default | Limits |
| --- | --- | --- |
| `enabled` | `false` | Must be the JSON Boolean `true`. |
| `mode` | `script` | `script` or `smartlink`. |
| `script_url` | Empty | In script mode, exact generated HTTPS `src`; numeric dashboard IDs are not script URLs. |
| `url` | Empty | In Smartlink mode, exact HTTPS direct link. |
| `sub_id` | Empty | Smartlink tracking label: 1–64 letters, digits, underscores or hyphens. Appends `psid` to the URL while preserving other query parameters. Prefer alphanumeric labels per Adsterra's guide. |
| `load_timeout_ms` | `5000` | 500–10,000 milliseconds (up to 30,000 for Monetag). Bounds script loading and each ad-page document until it shows content. Failure continues playback. |
| `max_duration_seconds` | `30` | 5–120 seconds; upper bound for the whole ad, including the ad page. The viewer can leave sooner once **Play now** appears. |
| `close_fallback_seconds` | `15` | 5–15 seconds. When **Play now** appears if the final ad never finishes loading. |

### Playback ads on Android TV

A remote cannot give the touch that Adsterra's Popunder opens its popup from.
TV therefore uses its own placement in each popup
catalog, `tv_popunder`, with the same fields as `popunder`. Only formats that
open without a touch are accepted: `mode: "smartlink"` (Adsterra Smartlink, a
Clickadu or Monetag Direct Link), or Clickadu's and Monetag's tags (`page` or
`script`), which FlixQuest starts itself on Android. Any other `tv_popunder` is ignored. Without one, TV
shows no popup; the selected `playback_popunder_network` still decides which
catalog is read. The Social Bar and the experiment never run on TV.

```json
{
  "popunder": {"enabled": true, "mode": "script", "script_url": "…", "zone_id": "2150355"},
  "tv_popunder": {"enabled": true, "mode": "smartlink", "url": "https://…your Direct Link…"}
}
```

The supplied Adsterra catalog has a `tv_popunder` with its Smartlink and
`sub_id` `fqsmarttvv1`, so TV traffic reports separately. The Monetag catalog
reuses its hosted page. The Clickadu catalog has none: add a `tv_popunder` with
its zoned tag or a Direct Link from your Clickadu manager to enable it on TV.

On TV the ad page uses larger type and overscan margins. The remote stays on
FlixQuest's controls: the arrows never move into the page, OK before the way
on appears highlights the wait, and **Play now** takes focus the moment it
appears, so one press of OK continues. Back behaves as on phones. Store
hand-offs never happen on TV, since they need a tap inside the ad.

For the original Popunder placement, use `mode: "script"` and its generated
`script_url` instead of the Smartlink. The page shows "Your video is ready", a
**Play now** button (labelled "One moment…" while disabled) and a note:
"Sponsored: an ad may open first. Ads like this keep FlixQuest free." The
button stays disabled until the tag has
loaded, then waits for the viewer's tap. The `max_duration_seconds` limit still
applies. The tag opens its popup from that tap, and the app sends the popup URL
to the ad page. The head script uses `defer` so the body and control
exist before the tag runs. A tap that opens nothing continues to the player after
750 ms. This happens when the tag's own frequency cap is reached; the cap is kept
in the WebView's cookies. The old `auto_activate` key is ignored. The tag listens
for real touch events and never opened a popup from a programmatic click.
Loading the script does not guarantee a popup or a paid impression.
Adsterra reports statistics per placement; see its
[publisher API guide](https://adsterra.com/blog/how-to-use-adsterra-publishers-api/).

The experiment requires an `id` and 2–8 `variants`. Each variant includes a unique
`id` (1–64 letters, digits, underscores or hyphens), `enabled: true`, and the
placement fields above. Use a new experiment `id` when changing the order or
meaning of its variants. Logs identify each attempt as
`variant=<experiment id>/<variant id>`. `variant=legacy` means no experiment is
active on that client, which is expected with the supplied catalog.

Retrieve statistics grouped by `placement_sub_id` through Adsterra's Publisher
API; Popunder has its own placement statistics. Keep API credentials on your
server, outside the app and Remote Config. Compare CPM, revenue per 1,000
eligible playback attempts, and playback completion. App logs and DOM readiness
are diagnostics, not billable-impression counters. The old `browser` field is
ignored, so catalogs that still set it keep working.

Both WebViews use Hybrid Composition on Android to avoid the SurfaceTexture
path when coming from video playback. Script loading, popup URLs, page
starts/finishes, visible content, `close enabled reason=ad_served` or
`cap_reached`, store hand-offs and the closing reason are logged under
`[AdsterraPage]`.

Android playback ad WebViews remove the `; wv` and `Version/4.0` user-agent
markers before loading a script, hosted page or advertiser. The device details
and installed Chromium version are retained, including for subsequent redirects;
iOS uses its system user agent. This is scoped to playback ad WebViews.
The app adds no `X-Requested-With` header. Android has discontinued WebView's
automatic package-name header; its former allow-list API is now a no-op.
See [Android's WebSettingsCompat reference](https://developer.android.com/reference/androidx/webkit/WebSettingsCompat#setRequestedWithHeaderOriginAllowList(android.webkit.WebSettings,%20java.util.Set%3Cjava.lang.String%3E)).
Changing the user agent does not guarantee advertiser fill or make WebView
identical to Chrome; JavaScript capabilities, cookies and other device signals
can still differ. Logs report the applied user agent.

A script download is not an interstitial-ready callback: the Social Bar view
waits for a visible creative element, otherwise the load timeout continues
playback. Adsterra chooses the Social Bar subformat and has its own frequency
limits; ask your Adsterra manager for interstitial-only delivery and approved
in-app placement. Removing the app cooldown does not override network limits or guarantee
fill/CPM. See [Adsterra's Social Bar publisher guide](https://adsterra.com/blog/publishers-guide-to-social-bar/)
and [Popunder guide](https://adsterra.com/blog/popunder-traffic-monetization/).

Script HTML uses the same isolated HTTPS app-content base origin as banners;
Smartlinks load their actual URL directly. Neither claims requests originate from
`flix.quest`. Closing, timing out, remote
disabling, replacing the ad, or backgrounding the app prevents late callbacks from opening another ad
over the player. There is no hidden preload, automatic refresh, fabricated
advertiser click or app-reported paid impression. Provider script downloads from this
workstation returned HTTP 403; native live fill and actual earnings still require
validation on a mobile device with the remote switches enabled.

### Choosing the popup network (Adsterra, Clickadu, Monetag or ExoClick)

`playback_popunder_network` picks which network serves the stream-found popup.
The Social Bar before the loader is Adsterra-only and stays controlled by
`adsterra_playback_ads`.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `playback_popunder_network` | String | `adsterra` | `adsterra` uses `adsterra_playback_ads` (its `popunder` or experiment). `clickadu` uses `clickadu_playback_ads`. `monetag` uses `monetag_playback_ads`. `exoclick` uses `exoclick_playback_ads`. `none`, or any other value, shows no stream-found popup. Case-insensitive. |
| `clickadu_playback_enabled` | Boolean | `false` | Clickadu's own switch. Must be published remotely. |
| `clickadu_playback_ads` | String (JSON) | `{}` | Clickadu's `popunder` placement. |
| `monetag_playback_enabled` | Boolean | `false` | Monetag's own switch. Must be published remotely. |
| `monetag_playback_ads` | String (JSON) | `{}` | Monetag's `popunder` placement. |
| `exoclick_playback_enabled` | Boolean | `false` | ExoClick's own popup switch. Must be published remotely; independent of VAST pre-roll. |
| `exoclick_playback_ads` | String (JSON) | `{}` | ExoClick's `popunder` and optional `tv_popunder` placements. |

Changing any of these while a popup is open closes it and continues playback.

To switch to Clickadu, copy [clickadu_playback_ads.json](clickadu_playback_ads.json)
into `clickadu_playback_ads`, publish `clickadu_playback_enabled=true`, then set
`playback_popunder_network=clickadu`. Switching back is just
`playback_popunder_network=adsterra`.

The supplied catalog runs Clickadu's onclick tag (zone 2150355). On Android,
the app activates Continue automatically once the tag's `/adx/get/` request
finishes and its initialization grace period ends. Loading `on.js` alone does
not trigger it. The existing native input bridge sends one touch to the enabled
`fq-continue` button in the original tag document; it never taps an advertiser
link. A returned popup loads in the app's ad page, with the same held **Play
now** and redirect handling as the Smartlink.

Android can report `about:blank` as the native URL for this inline document,
even though JavaScript sees its HTTPS base URL. The input bridge verifies that
base URL and the original inline document before sending the touch. Rebuild
and reinstall the app for this Kotlin change; hot restart cannot update an
installed native bridge. Logs include `PlaybackAdInput` rejection reasons or
`Continue touch sent: accepted=true inline=true` when the touch is dispatched.

The tag starts when this screen is shown. Only Clickadu Direct Links can be
preloaded. If the tag never becomes ready, or the automatic touch opens no
ad within `load_timeout_ms`, playback continues without one. Duplicate
readiness signals cannot trigger a second touch or extend that waiting period.
Closing the screen disables the tag and prevents late activation. When native
input is unavailable, including on iOS, the enabled **Play now** button remains
available for a manual tap; it continues after 750 ms if no popup opens.
Use a provider-issued Direct Link in `smartlink` mode for automatic opening on
both Android and iOS.

The tag's loading window starts when the document is requested, after native
WebView setup. Cold WebView initialization no longer consumes
`load_timeout_ms`; `max_duration_seconds` still bounds the entire screen,
including setup. Direct-link pages use the same timing rule. Timeout logs
include `scriptLoaded` and `waitingForAdRequest`, distinguishing an unloaded
`on.js` from a loaded tag whose ad request has not completed.

`popunder` takes the per-stage fields above, with two differences:

- `zone_id` is required in script mode: the zone from Clickadu's tag
  (`data-clocid`), as digits. The app adds it to the script element, where the
  tag looks for it.
- `sub_id` is rejected, because `psid` is Adsterra's parameter. A Clickadu
  Direct Link from your manager works with `mode: "smartlink"` and `url`, with
  any tracking parameters already in the URL.

Clickadu's tag snippet uses a protocol-relative `src` (`//driverhugoverblown.com/on.js`);
`script_url` must spell out `https://`. The tag runs on the app's placeholder
origin (`appassets.androidplatform.net`), not the site the zone was approved
for; confirm with Clickadu that the zone accepts in-app WebView traffic. Logs
show the network, for example `[AdsterraPage] clickadu/streamFound: popup URL received`.

### ExoClick popup

[exoclick_playback_ads.json](exoclick_playback_ads.json) contains the **Popunder
Redirect URL** generated by ExoClick for FlixQuest's Mobile Popunder zone
6050984: `https://s.pemsrv.com/v1/link.php?cat=&idzone=6050984&type=8`.

Production was switched on 2026-10-10 to
[exoclick_rotating_playback_ads.json](exoclick_rotating_playback_ads.json), using
`https://flix.quest/api/exoclick-popup`. The server route was deployed through
the landing repo's Git workflow (commit `3eae738`), and its HTTP 302 redirect
and Vercel cache HIT were verified. The original catalog remains a reference
for the publisher-generated URL.
This is the publisher's zone URL, not a captured advertiser URL. To get a new
one, open the zone's **HTML Tag** page and select **Popunder Redirect URL**.

To activate it:

1. Publish the rotating catalog as `exoclick_playback_ads` after deploying the
   server endpoint described below.
2. Publish `exoclick_playback_enabled=true`.
3. Set `playback_popunder_network=exoclick`.

For networks where the generated `s.pemsrv.com` endpoint cannot connect, deploy
`api/exoclick-popup.js` in the existing flixquest-landing Vercel project, verify
`https://flix.quest/api/exoclick-popup` returns HTTP 302, then publish
[exoclick_rotating_playback_ads.json](exoclick_rotating_playback_ads.json) instead.
The function fetches the current delivery domain on the server and caches its
redirect at Vercel for 24 hours. The device follows the redirect and makes the
ad request with its own IP, user agent and cookies. It retains zone 6050984 and
the generated query parameters. No app update is needed for this catalog.

This uses ExoClick's [Dynamic Domains API](https://docs.exoclick.com/publishers/adblock/adblock-dynamic-domains-api),
which also documents support for replacing the VAST delivery domain. The popup
endpoint changes only popup delivery; VAST remains separately configured.
Rotating domains expire in six days, so do not paste today's domain permanently
into Firebase. On 2026-10-10 the emulator's native TLS probe timed out on
`s.pemsrv.com` but connected successfully to the API-issued delivery domain.
The zone request with the emulator's user agent then answered HTTP 302 to the
Yahoo home page rather than an advertiser. The app treats that as no fill and
continues playback. A reachable delivery domain fixes the connection failure;
it does not guarantee an offer for the device or network. Verify delivery on a
physical phone using mobile data after deploying and publishing this catalog.
A subsequent native probe on the connected physical phone also timed out
connecting to `s.pemsrv.com`; that phone could not establish TCP to the current
rotating domain either. The route is a delivery workaround to validate after
deployment, not proof of an advertiser impression on every network.

The catalog uses `mode: "smartlink"`, the same direct-navigation mode as
Adsterra's Smartlink. ExoClick popup preloading is disabled: movie, episode
and Live TV flows request the link when the ad screen opens after a stream
is ready. The presentation log reports `preloaded=false`. Advertiser
redirects stay in the app, with the same content detection, minimum visible
view, close fallback, timeouts and cancellation as Adsterra. Missing or invalid
configuration issues no ad requests. Switching networks or disabling the
popup closes an active ad and continues playback.

The supplied `tv_popunder` uses the same link for Android TV and the existing
D-pad controls. Remove it or set its `enabled` to `false` to disable TV popups;
the zone's targeting still determines whether ExoClick returns an ad. Put
ExoClick tracking parameters directly in `url`; `sub_id` is reserved for
Adsterra's `psid` and is rejected for other networks.

The Social Bar before the loader remains controlled by Adsterra. ExoClick's
VAST pre-roll is independently controlled by `vast_preroll_enabled`,
`vast_preroll_network` and `vast_preroll.exoclick`; enabling only the VAST
switch never enables a popup. If both formats are enabled, a stream-found
popup runs before the video pre-roll.

### Monetag popup

Monetag's stream-found popup starts automatically inside FlixQuest, without a
**Play now** tap. Preloading is disabled for every Monetag mode, including
Direct Links. Its first request starts when the ad screen opens after a
stream is ready; the presentation log reports `preloaded=false`.
With `mode: "page"` or `mode: "script"`, the app
shows the "Your video is ready" placeholder, waits for the Onclick tag's `/5/<zone>/`
options request to finish and the Continue button to become enabled. After
a short initialization delay, Dart asks the Android bridge to send one native
touch to that button. The emitted popup URL opens in the same ad
page used by Adsterra, with the held **Play now**. HTTP redirects and
`intent://` web targets stay in that ad page.

The native touch is restricted to the original tag document's `fq-continue`
button, and is attempted once per ad screen. The bridge cancels the release
if the document changes or the screen disables JavaScript while closing.
The tag page's 750 ms Continue callback does not close the screen during this
attempt: its advertiser URL may arrive later. If native input is unavailable
(including iOS), the app invokes `onClickTrigger` once as a fallback. Missing
controls, a stalled tag or an activation that emits no URL is bounded by
`load_timeout_ms`. An options response with HTTP 204 still continues playback
immediately.

Rebuild and reinstall the Android app for this native bridge; hot reload or
hot restart alone cannot add it to an already installed build. Debug logs
report `monetag Continue tapped automatically via Android WebView`, and the
page reports `Monetag Continue input trusted=true userActivation=true` when
its click listener receives the input. Live delivery requires a device test.

The hosted Monetag catalog allows 30 seconds for loading and 60 seconds for
the entire ad screen. Once the tag reports loaded, its automatic popup gets
a fresh 30-second loading window, still bounded by the overall 60-second
limit. A completed HTTP 204 response continues playback immediately;
increasing the timeout does not turn that empty response into an offer.

Monetag registers zones to a website. On the app's placeholder origin
(`appassets.androidplatform.net`) zone 11983408 answered its ad request with
`204 No Content`, so the published catalog loads a page on flix.quest instead:

- `mode: "page"` with `url`: the app loads that page in the ad WebView. The
  page carries the tags and `PlaybackAd` signals. Its web Continue control
  is covered by the app's loading surface during automatic activation.
  [monetag_playback_ads.json](monetag_playback_ads.json) uses
  `https://flix.quest/a/3ad05c8e4d`, served from
  `public/a/3ad05c8e4d/index.html` in the flixquest-landing repo. It runs
  Onclick zone 11983408 and the push tag for zone 11917894 (push does nothing
  in a WebView, which has no Notification API).
- `mode: "script"` runs the tag on the placeholder origin. From Monetag's inline
  snippet, use `s.src` as `script_url` and `s.dataset.zone` as `zone_id` (sent
  as `data-zone`). For a `/401/<zone>` snippet, use
  `https://<domain>/401/<zone>` as `script_url` and leave out `zone_id`.
- `mode: "smartlink"` with `url` opens a Monetag Direct Link, which is not tied
  to a site. It loads automatically as soon as the ad screen opens, without
  showing or waiting for **Play now**. `sub_id` is rejected; put any
  tracking parameters in the URL.

The existing hosted `mode: "page"` catalog needs no configuration change for
automatic activation. A Direct Link remains an alternative that skips tag
initialization: create a **Direct Link (SmartLink)** zone in Monetag and copy
its exact HTTPS link from **Get tag**. To use it, set `monetag_playback_ads` to
the following, replacing the placeholder with that link:

```json
{
  "popunder": {
    "enabled": true,
    "mode": "smartlink",
    "url": "<paste your Monetag HTTPS Direct Link here>",
    "load_timeout_ms": 10000,
    "max_duration_seconds": 30
  }
}
```

The app follows the Direct Link's redirects inside its ad page and enables
**Play now** once the final page's content has settled and been up for
3 seconds, or at `close_fallback_seconds`.
The hosted page in `monetag_playback_ads.json` uses Onclick zone 11983408.
Onclick and push zone IDs cannot be substituted for a Direct Link; use the
link issued for its own zone.

Publish the catalog as `monetag_playback_ads`, publish
`monetag_playback_enabled=true`, then set `playback_popunder_network=monetag`.

In a WebView, Monetag's tag hands its ad to Chrome with an `intent://` link
instead of opening a window. The app loads that link's web page in its ad page.

To debug an empty popup, check `[PlaybackAdConfig]` for the active mode, target
and Remote Config value source. Editing `docs/monetag_playback_ads.json` does
not publish it to Firebase. For the hosted setup, the playback log must say
`presenting monetag page` and load `https://flix.quest/a/3ad05c8e4d`; a log
saying `presenting monetag script` is using another active catalog value.
Publish the JSON under `monetag_playback_ads` and check any conditional values
that may override the default. The app activates real-time config updates.
Debug builds fetch and activate config on hot reload as well as startup,
with no minimum fetch interval; release builds retain the one-minute minimum.
Fetch/activation failures are logged under `[PlaybackAdConfig]` in debug builds.
An options request with HTTP 204 returned no offer, so the automatic trigger
is not called. HTTP 204 was also observed on the hosted page during emulator
testing; correcting the catalog selects the intended origin but does not
guarantee that Monetag will return an offer.

On 2026-10-08, a comparison in regular desktop Chrome returned HTTP 200
from the same `/5/11983408/` endpoint. A real Continue click opened an
advertiser page. The Monetag dashboard also confirmed that flix.quest is
verified and issued the same `data-zone=11983408` and
`https://al5sm.com/tag.min.js` used by the live hosted page. The emulator's
FlixQuest WebView session instead returned HTTP 204 before activation.
This rules out a completely unavailable zone or an incorrect hosted tag;
it does not establish whether the differing response is due to the
WebView, emulator, browser session, frequency limits or another delivery
decision. Compare the same build on a real Android phone before changing
the integration based on a presumed cause.

The user also tested the hosted page with a real Continue tap in Chrome
134 on the same Android emulator and reported that no advertiser opened.
That failure occurs outside FlixQuest as well. The Android Chrome debug
target disconnected before its request response could be inspected, so
its HTTP status is unverified. The comparison points toward Android/emulator
delivery or client compatibility; it does not prove emulator filtering or
that real Android phones would fail.

Hosting the tag on flix.quest supplies the publisher origin, but does not
proxy the ad request through the website's server. The WebView still sends
the request directly to Monetag with its own browser/device information.
The account had no Direct Links during this check; an advertiser URL
captured from a browser test must not be reused as a placement URL.

## Video pre-roll (VAST)

A VAST video ad can play inside the player before a movie or episode. It is
independent of the playback popups above. If both are enabled, the
stream-found popup still runs before the player opens, so a viewer would see
two ads. Disable one of them unless that is intended.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `vast_preroll_enabled` | Boolean | `false` | Explicitly published switch. Turning it off stops new pre-rolls; an ad already playing finishes. |
| `vast_preroll_network` | String | `clickadu` | Which networks' sections of `vast_preroll` are asked, in priority order: one name (`exoclick`) or a comma-separated list (`exoclick,clickadu`). Names are `clickadu`, `exoclick` or `adsterra`. Unknown names and repeats are dropped; `none` or an empty value plays no pre-roll. |
| `vast_preroll` | String (JSON) | `{}` | Each network's tag and limits, under the network's name. |

Copy [vast_preroll.json](vast_preroll.json) into `vast_preroll` and publish
`vast_preroll_enabled=true`. It holds the Clickadu video zone's tag (zone
2150357) under `clickadu` and the ExoClick in-stream zone's tag ("FQ video
roll", zone 6050988) under `exoclick`. Both sections set `tv_enabled: true`,
so Android TV and its Live TV play them too:

```json
{
  "clickadu": {"tag_url": "https://detoxifylagoonsnugness.com/ceef/gdt3g0/tbt/2150357/tlk.xml"},
  "exoclick": {"tag_url": "https://s.magsrv.com/v1/vast.php?idz=6050988"}
}
```

Every network goes through the same VAST client, ad session and overlay; only
its section differs. To swap networks, publish `vast_preroll_network` with the
other name. To use both, publish a list such as `exoclick,clickadu`. The first
network is asked first. Only when it returns no playable ad (no fill, an HTTP
error, invalid XML, the wrapper limit, or its `request_timeout_ms` running out)
is the next one asked, and so on. The first ad returned plays, with the
`start_timeout_ms` of the network that served it. Each network asked adds up to
its own `request_timeout_ms` to the wait before the content, so give fallbacks
a short budget. A no-fill answer is usually fast. A listed network without a
section, or without `tv_enabled` on TV, is passed over. A flat object with
`tag_url` at the top level (the format before `vast_preroll_network`) still
works and serves the first listed network. Debug builds log the order in effect
as `[VAST] config enabled=… order=exoclick,clickadu` and the network that
filled as `[VAST] pre-roll from exoclick`.

Each section takes these fields:

| Field | Default | Limits |
| --- | --- | --- |
| `tag_url` | Empty | Required. The HTTPS VAST tag from the ad network. |
| `request_timeout_ms` | `5000` | 1,000–15,000. Budget for the tag and all wrapper redirects. The content starts without an ad when it runs out. |
| `start_timeout_ms` | `8000` | 2,000–20,000. How long the ad's video may take to start before the content plays (VAST error 402). |
| `max_wrappers` | `5` | 0–10 wrapper redirects (VAST error 302 beyond). |
| `tv_enabled` | `false` | Also play on Android TV. Confirm with the network that TV traffic is accepted first. |

How it plays:

- The tag is requested while the player opens, alongside the branded intro
  lookup. When an ad is returned it replaces the branded intro for that session.
  Live TV does the same when a channel opens from the Live screen, on phones and
  on TV (with `tv_enabled`). Channel switches and reconnects inside the Live
  player play no ad.
- The ad and the content play as one native ExoPlayer/AVPlayer sequence on the
  same video surface, without a new player or route. The content starts at its
  resume position, as it would without an ad. Resuming mid-title may still
  buffer briefly at that position.
- While the ad plays, the player's controls are replaced by the ad overlay:
  an "Ad · 0:25" countdown, "Skip in N" then **Skip ad** at the tag's
  `skipoffset`, an amber ad progress line, and on phones **Visit advertiser**
  and a back button. On TV the overlay keeps the remote: the arrows stay on
  it, OK before Skip highlights the countdown, Skip takes focus as soon as it
  appears so OK skips, and Back leaves the player. When the ad ends, the TV
  player's controls take focus again. Seeking, gestures and the content menus
  are unavailable, because the timeline belongs to the ad.
- Subtitles are hidden until the content starts; their cues are timed to the
  content. Watch progress, resume points, IntroDB lookup, completion detection
  and wellness time all ignore the ad. A "recently watched" save requested
  during the ad runs once the content starts, so leaving mid-ad keeps the old
  resume point.
- **Visit advertiser** pauses the ad and opens the click-through URL in
  FlixQuest's ad page with its close control visible. The ad resumes on return.
- Only linear MP4/WebM/HLS media is played. VPAID and other interactive
  creatives are skipped. On phones the largest rendition up to 720p and
  2.5 Mbps is used; on TV up to 1080p and 8 Mbps.

Tracking follows VAST 3: impression and `creativeView`/`start` on the first
frame; `firstQuartile`, `midpoint`, `thirdQuartile`, `progress` offsets;
`complete`, `skip`, `pause`/`resume`, `closeLinear` when the viewer leaves
mid-ad, and `ClickTracking`. Errors are reported through `[ERRORCODE]`: 100 bad
XML, 301/302 wrapper timeout/limit, 303 no ad, 402 media timeout or stall, 403
no playable media, 405 playback error. Tag requests and tracking use the
system WebView's user agent. The click-through opens in that WebView; on Android
its ad page removes the WebView-specific markers as described above. Without a WebView,
tag requests and tracking
fall back to `Mozilla/5.0 (Linux; Android <version>; <model>) FlixQuest/<version>`.
Logs use the `[VAST]` prefix. An advertiser link that answers with XML, JSON or
text instead of a page closes the ad page immediately and the video ad resumes.

Clickadu's video zone 2150357 was checked on 2026-10-07: it answers with a
VAST 3.0 InLine ad (no wrapper), a 30-second linear creative skippable after
5 seconds, and four progressive MP4 renditions from 180p to 720p, with no VPAID.
The video.js / VPAID plugin in Clickadu's integration guide is for websites;
the app plays the tag natively and does not need it. Clickadu states
`bitrate` in bits per second (`2000000`) instead of VAST's Kbps; the app reads
values of 100000 or more as bps, so phones get the 720p rendition rather than
falling back to 180p.

Ask Clickadu which macros they expect from an app (there is no page URL) and
for confirmation that in-app requests are accepted and counted.

ExoClick's in-stream zone 6050988 was checked on 2026-10-08: it answers with a
VAST 3.0 InLine ad (no wrapper), a 12-second linear creative skippable after
5 seconds, and one progressive MP4 without `width`, `height` or `bitrate`. That
file is used whatever the device's rendition cap. Its only tracking is timed
`progress` events,
sent as each offset passes, and the impression fires on the first frame. The
`Icons` element and ExoClick's `TitleCTA` extension (a "View More" bar) are not
drawn; **Visit advertiser** uses the `ClickThrough`. The response sets a
5-minute `zone-cap-6050988` cookie. Tag requests keep no cookies, so ExoClick's
server-side rules decide frequency.

ExoClick's dashboard also offers a Client Hints meta tag (`Delegate-CH` for
`s.magsrv.com`). It is for web pages that load the tag in a browser. The app
requests the tag natively, so there is no page to put it in. The request's
user agent, the system WebView's own, already carries the Android version and
device model.

Ask ExoClick for confirmation that in-app requests to this zone are accepted and
counted, and check the zone's advertiser category filters. The 2026-10-08 test
fill advertised an AI companion app, and ads must suit the app's content rating
under Google Play's ads policy.
