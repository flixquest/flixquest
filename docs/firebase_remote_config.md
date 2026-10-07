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
| `banner_ad_network` | String | `adsterra` | `adsterra` selects WebView banners; `none` hides all banners including hosted announcements. Published legacy values `native`, `unity`, and `startio` also select the Adsterra surface, but cannot enable requests without the new switch and valid codes. |
| `adsterra_banner_enabled` | Boolean | `false` | Adsterra banner switch. Must be explicitly enabled remotely; no demo ads or hardcoded publisher codes ship in the app. |
| `adsterra_tv_enabled` | Boolean | `false` | Additional gate for Android TV; the global switch must also be on. TV placements use `_tv` names and TV-specific defaults. |
| `adsterra_banners` | String (JSON) | `{"units":{},"defaults":{},"placements":{}}` | Central catalog of banner codes, sizes, default variants and placement overrides. See below. |
| `hosted_banner_mode` | String | `stack` | How `/ads` announcements share a slot with Adsterra. `stack`: hosted above Adsterra. `priority`: an eligible hosted banner takes the slot and Adsterra loads only where no hosted ad exists. `off`: show only Adsterra. Unknown values use `stack`. |
| `banners` | String (JSON) | `{"banners":[]}` | Existing per-announcement overrides for `/ads`, keyed by `key` (`enabled`, `placements`, `shape`, `width`, `height`, `aspectRatio`). Separate from Adsterra's catalog. |

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

### Loading and clicks

The banner WebView loads a minimal local HTML document with the generated script, JavaScript enabled, an `AD` label, and the exact unit dimensions. The local document uses `https://appassets.androidplatform.net/adsterra/` as its HTTPS base URL, giving it an isolated app-content origin where `document.cookie` and storage work. Loading without a base URL creates an opaque origin and makes cookie-dependent scripts fail. This URL is not fetched and does not adopt the ad server or publisher website's origin. Ads use the actual system WebView user agent. Script load/runtime errors, main-document failures, or a script that fails to load within 20 seconds collapse the slot without blocking browsing or playback.

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


## Mobile playback ads

Playback ads are controlled separately from banners. Android/iOS phones and
tablets support them; television presentation, downloads, desktop and web skip
both stages. No publisher code is compiled into the defaults.

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
  and player recommendation/episode transitions.
- `stream_found_experiment`: alternates Popunder then Smartlink after a playable
  stream is selected, before navigating to `player.dart`. The counter is saved
  per experiment `id` on the device, so restarting continues the sequence. Each
  eligible attempt consumes one variant, including failed loads. TV/download/
  background skips and overlapping requests do not consume variants. No second
  variant is loaded on the same attempt when the first fails.
- `popunder`: the single-placement key for this stage, whatever the format.
  The supplied catalog uses it for the Smartlink. It applies only
  when the experiment is absent or disabled. A malformed enabled experiment
  disables this stage instead of silently loading a different placement.

Ads never open an external browser. Script tags (Social Bar, or a Popunder
tag) run in one WebView whose main frame never navigates. Script-initiated
navigations to `about:blank` or the app's base URL are dropped, and any other
web URL is treated as the popup. Advertiser pages (Smartlinks, and the popup
URLs that scripts emit) open in FlixQuest's **ad page**, a second full-screen
WebView that follows the network's redirect chain:

- The **Close ad** control and system Back stay hidden until the final redirect
  is served. That means the page has finished loading, shows visible content,
  and has started no new navigation for 800 ms. They appear after 5 seconds at
  most, whatever the ad does, as Google Play's ad policy requires. A loading bar
  and "Loading advertisement…" show until the page has visible content.
- App-install offers often end in a `market://` or `intent://` link that a
  WebView cannot load. The ad page loads the link's web page in place: the
  intent's `browser_fallback_url`, its https target, or the Play Store listing.
  Only a tap inside the ad in the previous two seconds, such as Install, hands
  the link to the Play Store app, using a launch mode that never opens a
  browser.
- A main-frame load error, an HTTP error on the main page, or a page that shows
  no content within `load_timeout_ms` continues playback.

The script page keeps its **Close ad** control from the start. Backgrounding
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
| `load_timeout_ms` | `5000` | 500–10,000 milliseconds. Bounds script loading and each ad-page document until it shows content. Failure continues playback. |
| `max_duration_seconds` | `30` | 5–120 seconds; upper bound for the whole ad, including the ad page. The viewer can close sooner once **Close ad** appears. |

For the original Popunder placement, use `mode: "script"` and its generated
`script_url` instead of the Smartlink. The page shows a **Continue to player**
button with a "Sponsored" note. The button stays disabled until the tag has
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

### Choosing the popup network (Adsterra or Clickadu)

`playback_popunder_network` picks which network serves the stream-found popup.
The Social Bar before the loader is Adsterra-only and stays controlled by
`adsterra_playback_ads`.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `playback_popunder_network` | String | `adsterra` | `adsterra` uses `adsterra_playback_ads` (its `popunder` or experiment). `clickadu` uses `clickadu_playback_ads`. `none`, or any other value, shows no stream-found popup. Case-insensitive. |
| `clickadu_playback_enabled` | Boolean | `false` | Clickadu's own switch. Must be published remotely. |
| `clickadu_playback_ads` | String (JSON) | `{}` | Clickadu's `popunder` placement. |

Changing any of these while a popup is open closes it and continues playback.

To switch to Clickadu, copy [clickadu_playback_ads.json](clickadu_playback_ads.json)
into `clickadu_playback_ads`, publish `clickadu_playback_enabled=true`, then set
`playback_popunder_network=clickadu`. Switching back is just
`playback_popunder_network=adsterra`.

The supplied catalog runs Clickadu's onclick tag (zone 2150355) like the
Adsterra Popunder script above. The page shows **Continue to player**. Unlike
Adsterra's, it stays disabled until the tag has fetched its ad (its `/adx/get/`
request), usually 1–3 seconds after the script loads: a tap before that opens
nothing. If the tag hasn't fetched an ad within `load_timeout_ms`, playback
continues without one. The viewer's tap lets the tag open its window, and the app
loads that URL in the ad page, with the same held **Close ad** and redirect
handling as the Smartlink. It never opens an external browser. A tap that
opens nothing continues to the player after 750 ms.

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

## Video pre-roll (VAST)

A VAST video ad can play inside the player before a movie or episode. It is
independent of the Adsterra playback ads above. If both are enabled, the
stream-found Smartlink still runs before the player opens, so a viewer would see
two ads. Disable one of them unless that is intended.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `vast_preroll_enabled` | Boolean | `false` | Explicitly published switch. Turning it off stops new pre-rolls; an ad already playing finishes. |
| `vast_preroll` | String (JSON) | `{}` | The tag and its limits. |

Copy [vast_preroll.json](vast_preroll.json) into `vast_preroll` and publish
`vast_preroll_enabled=true`. It holds the Clickadu video zone's tag.

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
- The ad and the content play as one native ExoPlayer/AVPlayer sequence on the
  same video surface, without a new player or route. The content starts at its
  resume position, as it would without an ad. Resuming mid-title may still
  buffer briefly at that position.
- While the ad plays, the player's controls are replaced by the ad overlay:
  an "Ad · 0:25" countdown, "Skip in N" then **Skip ad** at the tag's
  `skipoffset`, an amber ad progress line, and on phones **Visit advertiser**
  and a back button. On TV, Skip takes focus as soon as it appears and Back
  leaves the player. Seeking, gestures and the content menus are unavailable,
  because the timeline belongs to the ad.
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
system WebView's user agent, the same browser the click-through opens in, so
the request, impression and click share one identity. Without a WebView they
fall back to `Mozilla/5.0 (Linux; Android <version>; <model>) FlixQuest/<version>`.
Logs use the `[VAST]` prefix. An advertiser link that answers with XML, JSON or
text instead of a page closes the ad page immediately and the video ad resumes.

Ask Clickadu for a tag that returns linear MP4 only (no VPAID), which macros
they expect from an app (there is no page URL), and confirmation that in-app
requests are accepted and counted.
