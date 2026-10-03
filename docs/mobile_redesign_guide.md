# FlixQuest phone and tablet redesign: implementation guide

This guide redesigns FlixQuest's phone and tablet UI ("handheld") in the spirit of the new Android TV app and the current Netflix Android app. It is written for an engineer or agent working in this repository. Follow the phases in order: each one ends with checks that must pass before the next begins.

The TV app under `lib/tv/` is the reference for tone and structure: artwork first, a quiet interface, one accent colour, white focus and selection, and the next action always obvious. Read `lib/tv/app/tv_design.dart`, `lib/tv/widgets/tv_browse_view.dart`, `lib/tv/screens/tv_media_details_screen.dart` and `lib/tv/screens/tv_search_screen.dart` before starting. Most of what this guide asks for has already been solved there once.

---

## 0. Ground rules

### Tooling
- Flutter and Dart are not on `PATH`. Use the repo's SDK: `.fvm/flutter_sdk/bin/flutter` and `.fvm/flutter_sdk/bin/dart` (Flutter 3.35.7).
- Analyze what you touch: `.fvm/flutter_sdk/bin/flutter analyze lib test`.
- Test: `.fvm/flutter_sdk/bin/flutter test`. `test/player_menu_route_test.dart` and `test/subtitle_options_test.dart` already fail on this branch. Do not count them against a phase, and do not "fix" them by deleting assertions.
- Format only the files you changed: `.fvm/flutter_sdk/bin/dart format <files>`. Never format a whole directory; unrelated files will be rewritten.
- The phone emulator is the AVD with product `sdk_gphone16k_arm64`. Check `adb devices -l`; the serial changes. The TV emulator is `sdk_google_atv64_arm64`; do not install onto it for this work. Before running anything, check `ps aux | grep 'flutter run'`. If the user has a session attached to a device, do not reinstall over it or send input to it.
- Capture screens with `adb -s <serial> exec-out screencap -p > shot.png`.

### Things that must keep working
- **The TV app.** `lib/tv/**` must behave exactly as it does now. After every phase, run `.fvm/flutter_sdk/bin/flutter test test/tv_*.dart`; all of those tests must pass. `lib/constants/theme_data.dart` is shared with TV, so theme changes reach TV too.
- **Deep links.** Android home-screen widgets and media links open titles through `lib/services/home_widget_navigation_service.dart`, `home_widget_deep_link.dart` and `media_link_navigation_service.dart`. `test/home_widget_*` must stay green.
- **State restoration.** `AppSessionStateStore` (`lib/services/app_session_state_store.dart`) remembers the selected tab (`handheldDestinations`) and `FlixQuestHomePage` restores it. Update both together (see phase 1).
- **Offline use.** Downloads (`lib/screens/common/downloads_screen.dart`, `offline_player_screen.dart`) must be reachable and playable with no network.
- **Ads.** `RemoteHostedAdsBanner` placements are a revenue contract. Move them; do not delete them. The rules for where they may go are in section 4.6.
- **All three theme modes, plus the extras.** Dark, AMOLED and Light (Settings → Theme mode), and on top of those dynamic colour, the Material 3 toggle, custom and occasional (seasonal) colours, and ambient mode. Every new screen must look correct in each. See section 3.
- **Four languages, including Arabic (RTL).** Every new string goes into all four files: `assets/translations/{en,es,ar,hi}.json`. Use `EdgeInsetsDirectional`, `AlignmentDirectional` and `start`/`end`, never `left`/`right`, for anything directional. Today only two handheld files handle RTL explicitly; the new UI must be correct in Arabic.
- **The player.** `lib/screens/common/player.dart` is shared by phone and TV. Its phone controls live in the sibling repo `../flixquest-betterplayer` (`lib/src/controls/better_player_material_controls.dart` and friends), which has its own git history and tests. Player changes are phase 8 only.

### Working method
- One phase per commit, or a small series of commits, each leaving the app building and tested.
- Build new UI next to the old, then switch over, then delete the old. Never leave two live versions of a screen.
- Prefer new, small files under `lib/mobile/` (section 2) over growing `lib/widgets/movie_widgets.dart` (4,670 lines) or `lib/widgets/tv_widgets.dart` (6,640 lines). As a screen moves to the new UI, delete the widgets in those files that only it used.
- Write widget tests for behaviour, not pixels: what shows, in what order, what a tap does, and that the accent is absent where this guide says so.
- After each phase, take screenshots in Dark, AMOLED and Light (and one in Arabic), and look at them. Several bugs in the TV work were only visible that way.

---

## 1. Review of the earlier plan: what to keep, change, add and avoid

The earlier plan (a Codex conversation) is sound on the big moves. This guide keeps its direction and fixes the gaps.

**Keep:**
- One Home for movies and series, with filters across the top.
- Continue Watching directly under the hero, with movies and episodes merged into one row.
- A stable hero instead of the random, auto-advancing carousel. `DiscoverMovies.getData()` in `lib/widgets/movie_widgets.dart` mixes trending titles with a random year, genre and page.
- Search as a real destination, not a `SearchDelegate`.
- On detail pages, Play or Resume before the metadata; for series, "Resume S2:E4" or "Play S1:E1".
- A "My FlixQuest" hub for Continue Watching, My List, Downloads and the profile.
- Larger posters (today 72–100 logical pixels wide, see `app_ui_components.dart`), fewer duplicate rows, and "Top 10" only where the data really is a ranking.
- A sparing orange accent.

**Change:**
- **Bottom bar: Home · New & Hot · Search · My FlixQuest**, not Home · Discover · Search · My FlixQuest.
  - FlixQuest's Discover is a filter tool (genre, year, sort). That is a power-user search mode, so it moves into Search as "Browse with filters".
  - New & Hot (Coming Soon, Everyone's Watching, Top 10) is what Netflix uses the slot for, and the data already exists: `Endpoints.upcomingMoviesUrl`, `onTheAirUrl`, `trendingMoviesTodayUrl`, `trendingTVTodayUrl`.
- **Keep the hero stable, but keep it alive.** Show the day's top trending title; if the user has something in progress with a good backdrop, it may take the hero instead. Do not auto-advance. The ambient colour the app already extracts from posters (`AppDependencyProvider.activeAmbientColor`, `_applyAmbientColor` in `theme_data.dart`) should tint the hero's backdrop fade. That is Netflix's colour-washed hero, and it reuses a FlixQuest feature.
- **Remove from Continue Watching** through a long press and an overflow menu that opens a bottom sheet, not a visible "×" on every card.

**Add:**
1. **Shared data layer (phase 0).** The TV work already contains well-tested, UI-agnostic logic:
   - `TvMediaItem`, `TvCatalogController`, `TvHomeController`, `TvMediaDetailsController`;
   - `TvResumePoint`, `initialSeasonNumber`, `episodeAfter`, `hasAired`;
   - `TvTitleLogos` and `pickTitleLogo`;
   - `TvContinueWatchingRemoval`, `TvSearchSuggestions`, `TvCollection`.

   Extract it so both UIs use one copy. Today the phone fetches rows inside widgets (`ScrollingMovies` fetches in its own `initState`), which is why it is hard to reorder and dedupe.
2. **A palette the phone UI draws from (phase 0).** The TV's `TvPalette` (theme-derived roles such as page, surface, foreground, focus fill and scrim) is the reason TV works in all three modes. Promote it to a shared `AppPalette`.
3. **Retune the theme's component defaults (phase 0).** 149 of about 430 handheld accent references are in `theme_data.dart`. Every `FilledButton`, `ElevatedButton`, icon, chip, tab indicator and navigation indicator defaults to `colorScheme.primary`. Changing those defaults removes most of the orange at once (section 3.3).
4. **Title logos** in the hero and on detail pages, reusing `TvTitleLogos`.
5. **A Top 10 row with rank numbers**, reusing the painter in `lib/tv/widgets/tv_top_ten_rank.dart`.
6. **Badges** ("NEW", "NEW EPISODES", "TOP 10"), reusing `TvMediaBadge.recencyOf`.
7. **Skeleton loading that matches each layout** (the shimmer helpers exist, e.g. `mainPageVerticalScrollShimmer`), fading into content.
8. **Search behaviour.** Today it waits 3 seconds after typing (`Timer(const Duration(seconds: 3)` in `search_view.dart`) and then adds `Future.delayed(700ms)` per tab. Target: 350 ms, stale responses dropped, mixed results.
9. **Back behaviour.** Android Back from any tab except Home returns to Home; from Home it exits. Tapping the active tab scrolls to top, then (on a second tap) resets its filters.
10. **RTL, text scaling and tablet layouts** as explicit acceptance criteria, not polish.
11. **Performance rules** (section 4.9): decode images near display size, keep one controller per page, and no `Opacity` over large areas.

**Avoid:**
- **A Clips tab or autoplaying hero trailers.** Trailers are YouTube links; inline autoplay would need a web player, costs data and battery, and fails often. A "Trailer" button on the details page is enough.
- **Rewriting the player's logic.** Restyle only (phase 8). Playback, IntroDB, sources, subtitles and progress saving stay as they are.
- **Removing features to look like Netflix.** Keep Live TV, the Discover filters, provider choice, Viewing Insights, sync, downloads with quality choice, and the extra details tabs (cast, crew, images, videos, reviews, watch providers). Reorder and restyle; don't delete.
- **Pure white `#FFFFFF` backgrounds in Light.** Use the theme's page colour (`#FCFCFD`), as TV does.
- **Orange full-width buttons.** The Play button is white in dark themes and near-black in Light (section 3.3).
- **Hard-coded colours in new UI.** Every colour comes from `AppPalette`, `colorScheme` or a documented artwork overlay.
- **Global find-and-replace across widget code.** When TV was moved to palette roles, a bulk `const` edit broke unrelated code silently. Change files deliberately and review each diff.
- **Keeping all tabs alive forever.** `IndexedStack` currently mounts all five heavy tabs at startup. Build tabs lazily on first visit, then keep them alive to preserve scroll position.

---

## 2. Target structure

### 2.1 Navigation

| Place | Contents |
|---|---|
| Bottom bar | **Home** · **New & Hot** · **Search** · **My FlixQuest** |
| Home, top filter chips | **All** (default) · **Movies** · **Series** · **Live TV** (only when `displayLiveTV`) · **Categories ▾** (bottom sheet of genres) |
| My FlixQuest | Profile header · Continue Watching · My List · Downloads · Viewing Insights entry · Settings and account rows |
| Search | Query field · recent searches · Top searches · genres · "Browse with filters" (today's `DiscoverPage`) |
| New & Hot, segmented | **Coming Soon** · **Everyone's Watching** · **Top 10 Movies** · **Top 10 Series** |

- **Tab ids:** `home`, `new`, `search`, `mine`.
  - Update `AppSessionStateStore.handheldDestinations`. Map old stored ids so nobody lands on a dead tab: `movies`/`series`/`discover` → `home`, `downloads`/`profile` → `mine`.
  - The Settings "default home screen" option (`SettingsProvider.defaultValue`; options defined in `settings.dart` around line 347 as 0 Movies, 1 TV shows, 2 Discover, 3 Profile) becomes a choice of Home, Home: Movies, Home: Series, Search, or My FlixQuest.
  - Migrate the stored integers:
    - 0 → Home (All filter). 0 is also everyone's default, and Movies was only the de facto home, so it can't be read as a deliberate choice.
    - 1 → Home: Series.
    - 2 → Search, where the Discover filters now live.
    - 3 → My FlixQuest.
  - The shell today also accepts 4 (downloads) through its index lookup; map it to My FlixQuest. Store the new value under a new key so the migration runs once. Add a test for each mapping.
- **Movies and Series** are no longer tabs. They are Home filters, and the choice is remembered per session.
- **Bookmarks** become My List, reached from My FlixQuest and from the Home app bar's avatar. `BookmarkScreen` survives as the "See all" page.

### 2.2 Code layout
- `lib/catalog/`: the shared, UI-agnostic layer (phase 0).
  - `media_item.dart` (from `TvMediaItem`)
  - `catalog_controller.dart`, `home_controller.dart`, `details_controller.dart`
  - `resume.dart` (`ResumePoint` and friends)
  - `title_logos.dart`, `search_suggestions.dart`, `continue_watching.dart`
- `lib/design/`: `app_palette.dart` (from `TvPalette`) and `app_tokens.dart` (spacing, radii, type).
- `lib/mobile/`: the new handheld UI.
  - `app/`: `mobile_shell.dart`, `mobile_nav_bar.dart`
  - `screens/`: `home_screen.dart`, `new_and_hot_screen.dart`, `search_screen.dart`, `my_flixquest_screen.dart`, `movie_details_screen.dart`, `series_details_screen.dart`, `collection_screen.dart`
  - `widgets/`: `hero_card.dart`, `media_row.dart`, `poster_card.dart`, `continue_card.dart`, `top_ten_row.dart`, `filter_chips.dart`, `pill_button.dart`, `section_header.dart`, `skeletons.dart`, `badges.dart`
- The TV code keeps its names by importing from `lib/catalog/`. Either rename in place with every import updated, or leave `typedef TvMediaItem = MediaItem;` style aliases in the old files for one release. The TV tests must pass unchanged, apart from import lines.

---

## 3. Design system

### 3.1 Palette (`lib/design/app_palette.dart`)
Move `TvPalette` from `lib/tv/app/tv_design.dart` into `AppPalette`, unchanged in behaviour, and make `TvPalette` a typedef or thin wrapper so TV code is untouched. Roles:

| Role | Dark / AMOLED | Light | Use |
|---|---|---|---|
| `page` | theme `scaffoldBackgroundColor` (`#111315` / `#000000`) | `#FCFCFD` | Screens; what artwork fades into |
| `surface` / `raisedSurface` | page + 4.5% / 8.5% ink | page + 3.5% / 7% ink | Sheets, cards, placeholders |
| `foreground` | `#F7F7F7` | `#141516` | Titles, icons |
| `secondaryText` | `#D6D7D7` | `#2F3134` | Synopses over artwork |
| `mutedText` | `#A7A8A8` | `#5C5F63` | Metadata, labels |
| `focusFill` / `onFocus` | white 95% / black | ink 95% / white | Primary buttons, selected chips, the active tab pill |
| `idleFill` / `idleFillStrong` | ink 14% / 25% | same | Secondary buttons, unselected chips |
| `hairline` | ink 12% | same | Dividers |
| `scrim(a)` | page at alpha a | same | Hero and backdrop fades |

`test/tv_palette_test.dart` shows how to test contrast. Add the same checks for `AppPalette`, including the ambient-tinted and seasonal themes.

**Artwork overlays keep fixed colours in every mode.** These sit on posters, logos or video, not on the page:
- badges: white text on `#D9050606`;
- service-logo plates: `#1E1F22`;
- genre tile washes;
- progress-bar tracks on artwork: `white24`.

### 3.2 The accent budget
`colorScheme.primary` (FlixQuest orange, or the user's chosen colour) may appear **only** in:
1. the FlixQuest logo and wordmark;
2. progress: watch-progress bars, the player timeline's played part, download progress;
3. (removed: the bottom bar has no accent marker; the selected item is a filled ink icon);
4. small uppercase kickers ("NEW", "TOP 10", "SERIES" on a hero), at most one per screen region;
5. text-selection handles and the cursor;
6. the "on" state of switches (a small control).

Everything else is neutral: buttons, chips, tabs, icons, the navigation indicator, links in body text, section headers, and loading spinners (use `mutedText`). Write a test that pumps Home, Search, details and My FlixQuest in Dark and asserts that no `FilledButton`, `Icon` or `Text` outside the allowed widgets resolves to `colorScheme.primary`.

### 3.3 Theme component retune (`lib/constants/theme_data.dart`, `_applyFlixQuestUI`)
Change these defaults. They apply to phone and TV, so run the TV tests afterwards.

| Theme | Now | Target |
|---|---|---|
| `filledButtonTheme`, `elevatedButtonTheme` | bg `primary` | bg `onSurface`, fg `surface` (white-on-dark / dark-on-light, as Netflix's Play) |
| `outlinedButtonTheme` | fg and side `primary` | fg `onSurface`, side `onSurface @ 24%` |
| `textButtonTheme` | fg `primary` | fg `onSurface` |
| `iconTheme` | `actionButtonForeground` (primary) | `onSurface` |
| `iconButtonTheme` | primary | `onSurface` |
| `chipTheme` | selected `primary`, side `primary` | selected bg `onSurface`, selected label `surface`; unselected bg `onSurface @ 8%`, no side |
| `tabBarTheme` | indicator and label `primary` | indicator `onSurface` (2 px), label `onSurface`, unselected `onSurface @ 60%` |
| `navigationBarTheme` | indicator `primary @ 14%` | no indicator; handled by the custom bar (section 3.6) |
| `floatingActionButtonTheme` | primary | `raisedSurface` bg, `onSurface` fg |
| `inputDecorationTheme` | focused border and suffix `primary` | focused border `onSurface @ 60%`, suffix `onSurfaceVariant` |
| `toggleButtonsTheme` | primary fill | `onSurface` fill, `surface` text |
| `progressIndicatorTheme` | primary | keep primary for determinate progress; spinners pass `color: mutedText` |
| `sliderTheme` | primary | keep (the player timeline and settings sliders are "progress") |
| `switchTheme`, `checkboxTheme`, `radioTheme` | primary | keep (small selection marks) |

Leave `colorScheme.onPrimary` as it is; widgets that genuinely sit on `primary` still need it. Then search the handheld code for direct `colorScheme.primary` or `colors.primary` uses (about 280 outside the theme file) and re-point each to its role, one file at a time. Do not bulk-replace.

### 3.4 Type and spacing (`lib/design/app_tokens.dart`)
- **Families:** `FigtreeBold` for display and titles, `FigtreeSB` for labels and buttons, `Figtree` for body text. The app theme already applies Figtree.
- **Scale (phone):**

  | Style | Size / line height | Family |
  |---|---|---|
  | Hero title fallback | 30/34 | Bold |
  | Page title | 28/32 | Bold |
  | Section header | 18/24 | SB |
  | Card title | 14/18 | SB |
  | Metadata | 12/16 | regular, `mutedText` |
  | Kicker | 11, letter spacing 1.4 | SB, uppercase |
  | Body | 14/20 | regular |
  | Button | 15 | SB |

  On tablets (width ≥ 700), multiply by 1.1. Respect text scaling: layouts must not clip at 1.3×.
- **Spacing:** 4, 8, 12, 16, 20, 24, 32. Page gutter is 16 on phone and 24 on tablet. Rows are separated by 24. A section header sits 8 above its row.
- **Radii:** cards 6, buttons 6, chips 18 (pill), sheets 16 (top corners only), the bottom bar has none.

### 3.5 Cards and rows (`lib/mobile/widgets/`)
- **Poster card:**
  - width `clamp((screenWidth − gutter×2 − 2×10) / 3.15, 104, 140)` on phones, so three full posters and a sliver of a fourth show; on tablets 132–160;
  - 2:3 artwork, radius 6, no text under it on Home rows;
  - a `TvMediaBadge`-style badge at top start;
  - decode with `memCacheWidth = width × devicePixelRatio`;
  - placeholder: `raisedSurface` plus a centred film icon;
  - press: scale 0.97 for 90 ms and a light haptic;
  - long press opens a quick sheet: Play, My List, Details.
- **Continue card:** 16:9 backdrop or episode still, about 62% of the width of two poster cards. It shows a progress bar along the bottom edge (accent), an overflow "⋮" at bottom end, and below it the title, then "S2:E4 · 23m left" or "1h 04m left". Tap resumes. The sheet offers Resume, Details, Remove from row.
- **Top 10 row:** the rank-number painter from `tv_top_ten_rank.dart`, sized to the poster card; ten items only.
- **Wide feature card (optional per page):** a 16:9 card with a title logo, used for a collection or a live event.
- **Service row:** logo plates on `#1E1F22` using `appStreamingServices` in `lib/widgets/common_widgets.dart`; opens that service's catalog.
- **Section header:** the title at start, with a "See all ›" link at end in `mutedText` (not orange) when a full list exists.

### 3.6 Bottom bar (`lib/mobile/app/mobile_nav_bar.dart`)
- Flush with the bottom edge, full width, no border, radius, shadow or floating margin (drop the current `Container` with margin, radius, border and shadow in `flixquest_main.dart`).
- Background: `page` at 94% with a 12 px `BackdropFilter` blur. On low-end devices (check `MediaQuery.of(context).disableAnimations` or an existing low-performance flag), use `page` at 100% with no blur.
- Height 60 plus the bottom inset. Four items, each an icon (Phosphor regular, or fill when selected) over a label in 11 px FigtreeSB.
- Selected: `foreground` icon (fill style) and label. Unselected: `mutedText` (regular style). No accent marker and no Material indicator pill: the filled ink icon is the whole cue.
- Reselect: scroll the tab's primary scrollable to the top. A second reselect resets that tab (Home chips to All, Search clears).

### 3.7 Motion
- **Tab switch:** 180 ms fade between tab bodies. They are kept alive, so this fades the incoming one only (see TV `TvShellLayout` for the single-layer fade).
- **Filter change on Home:** crossfade the rows region (220 ms); the hero stays.
- **Opening details from a card:** a `Hero` on the poster into the details backdrop is optional. If it stutters on a mid-range phone, drop it and use the default page transition.
- **Skeletons:** a slow 1.1 s pulse between `surface` and `raisedSurface` (see `TvBrowseSkeleton`), then a 280 ms fade to content.
- **Never** animate `Opacity` over full-screen areas while scrolling. Use `AnimatedContainer` colours or `FadeTransition` on small widgets.

---

## 4. Phases

Every phase lists files, specific requirements, and checks. "Screenshots" always means Dark, AMOLED and Light on a phone, plus one Arabic run.

### Phase 0: foundations (no visible change except colours)
**0.1 Extract `lib/catalog/`.**
- Move the pure logic out of `lib/tv/controllers/` and `lib/tv/models/`:
  - `TvMediaItem` → `MediaItem`;
  - `TvResumePoint`, `formatRuntime`, `initialSeasonNumber`, `episodeAfter`, `hasAired`;
  - `TvTitleLogos` and `pickTitleLogo`;
  - `TvCatalogController`, `TvCollection`, `TvSearchSuggestions`, `TvServiceShelf`, `TvCatalogData`;
  - `TvHomeController` / `TvHomeData`;
  - `TvMediaDetailsController` / `TvMediaDetailsData`;
  - `TvContinueWatchingRemoval` (logic only; the dialog stays in TV).
- Keep the old names working through typedefs or re-export files, so `lib/tv/**` changes are import-only.
- Check: TV tests pass. `.fvm/flutter_sdk/bin/flutter analyze` is clean.

**0.2 `AppPalette` and tokens.** Create `lib/design/app_palette.dart` from `TvPalette`, plus `app_tokens.dart` from section 3.4. Make `TvPalette` delegate to it. Port `test/tv_palette_test.dart` as `test/app_palette_test.dart`.

**0.3 Theme retune** (section 3.3).
- Checks:
  - Screenshots of the current screens (old UI) show no orange buttons, icons or tab indicators.
  - TV tests pass.
  - Settings, dialogs and sheets are still legible in Light: check the colour-theme picker and the subtitle settings, which show real colours on purpose.

**0.4 Handheld page data.**
- Add `HomeFeedController` in `lib/catalog/` returning `HomeFeed`: `{hero, continueWatching, topMovies, topSeries, trending, popularMovies, popularSeries, newReleases, genres, services}`.
- Filters narrow it: `all`, `movies`, `series`.
- Every row fails on its own (as `TvCatalogController._orEmpty` does).
- Dedupe across rows: a title may appear in at most two of the first five rows.
- Unit-test the dedupe and the filter mapping with fake fetchers.

### Phase 1: shell and navigation
**Files:**
- new `lib/mobile/app/mobile_shell.dart` and `mobile_nav_bar.dart`;
- `lib/flixquest_main.dart` (`FlixQuestHomePage` builds `MobileShell`);
- `lib/services/app_session_state_store.dart`;
- `lib/provider/settings_provider.dart` and `lib/preferences/setting_preferences.dart` (default-home migration);
- `lib/screens/common/settings.dart` (default-home options).

**Requirements:**
- Four tabs as in section 2.1. Build each lazily on first visit and keep it alive afterwards (for example, a list of nullable widgets filled on first selection, rendered in a `Stack` with `Offstage` and `TickerMode(enabled: false)` for hidden tabs).
- Back: a `PopScope` on the shell. If the current tab is not Home, select Home; otherwise allow the pop (the app exits). Nested navigators are not used; detail pages remain pushed routes on the root navigator.
- Reselect behaviour per section 3.6. Expose a `ScrollController` per tab through a `MobileTabController` inherited widget.
- Analytics: keep `trackNavigation(destination:, surface: 'standard')` with the new ids.
- Deep links and home-widget taps must still open details over whatever tab is showing.

**Checks:**
- Tests for: restoration of each id, the old-id mapping, default-home migration, Back from each tab, and reselect scrolling to top.
- `test/home_widget_*` pass.
- Screenshots of the bar in the three modes.

### Phase 2: Home
**Files:** `lib/mobile/screens/home_screen.dart` and widgets. Retire `MainMoviesDisplay` and `MainTVDisplay`, and delete their now-unused widgets from `movie_widgets.dart` and `tv_widgets.dart` once nothing references them.

**Layout, top to bottom:**
1. **Transparent app bar**, over the hero, pinned.
   - Start: the FlixQuest logo (small, accent). End: a Search icon (switches to the Search tab) and the avatar (opens My FlixQuest).
   - After 80 px of scroll it fades to `page @ 94%` with a blur (reuse the idea of `AppFeedOverlayHeader`, restyled).
2. **Filter chips**, pinned under the app bar: All · Movies · Series · Live TV · Categories ▾.
   - Selected: `focusFill` background, `onFocus` label. Others: `idleFill` background, `foreground` label.
   - Live TV pushes `ChannelList` (`lib/screens/common/live_tv_screen.dart`); it is not a filter.
   - Categories opens a bottom sheet of genres for the current filter (movie genres for Movies, TV genres for Series, both for All). Choosing one opens a `CollectionScreen`, a paged grid like TV's `TvCollectionScreen`.
3. **Hero card**, a Netflix-mobile style card rather than full-bleed:
   - inset 16, radius 10, height about 62% of screen width × 1.45, capped at 520;
   - backdrop, or portrait poster on phones, with a bottom-to-top fade to `scrim(0.9)`, tinted by the ambient colour when available;
   - title logo (`TitleLogos`, max height 72) or a text fallback;
   - one metadata line: "Series · Crime · Thriller" in `secondaryText`, with genre names from the genre lists;
   - two buttons side by side: **Play** (or **Resume S2:E4**) as a `focusFill` pill with a play icon, and **My List** as an `idleFill` pill with a plus or check icon;
   - tapping the card elsewhere opens details.
   - Hero choice:
     - All filter: the day's #1 trending title (movie or series), unless the most recent in-progress title has a backdrop and was watched in the last 3 days. Then use that title, with the kicker "CONTINUE WATCHING".
     - Movies / Series filters: the #1 trending of that kind.
     - The choice is fixed for the session; it doesn't change on rebuild.
4. **Continue Watching**: continue cards (section 3.5), movies and episodes merged newest first from `RecentProvider.movies` and `.episodes`, at most 16. Hidden when empty. Under the Movies filter show only movies; under Series only episodes.
5. **Top 10 today**: the Top 10 row, which is the combined movies-and-series list under All (as TV Search's "Top searches today"). With the Movies or Series filter, use that kind's list.
6. **Trending this week**: poster row.
7. **My List**: poster row of saved titles, if any, with "See all ›".
8. **New releases**: `nowPlaying` for movies, `onTheAir` for series, and both under All. Poster row with "NEW" badges.
9. **Popular on Netflix / Max / Prime Video / Disney+**: one poster row per service shelf (`TvCatalogController` shelves). The first two show by default; the rest load as the user nears them (lazy slivers).
10. **Streaming services**: service logo row.
11. **Top rated**: poster row.
12. **Upcoming**: poster row with release dates as the badge ("MAY 3").
13. **Random categorised feed**: keep `RandomCategorizedFeed` if it adds variety, restyled into standard rows.

- **Ads:** at most two `RemoteHostedAdsBanner` on Home, placed after row 6 and after row 10, never above Continue Watching or within the first screen height. Keep the `placement` names.
- **`UpdateBottom`:** show it as a dismissible banner at the top of My FlixQuest and as a one-time bottom sheet, not in the Home feed.
- **Pull-to-refresh** reloads the feed (not the hero choice). While refreshing, rows keep their old content.
- **Loading:** a skeleton of hero, chips and two rows. Errors: a quiet `mutedText` message with a Retry pill, per row.

**Checks:**
- Widget tests for order under each filter, dedupe (no title twice in the first five rows), hero choice rules, Continue Watching merge and order, and that no ad sits above Continue Watching.
- Screenshots.
- Manual check: fling-scroll the whole feed on a mid-range phone without dropped frames (watch `flutter run --profile` output).

### Phase 3: Continue Watching behaviours
- The long-press or "⋮" sheet offers: Resume, Episodes (series; opens details scrolled to Episodes), Details, **Remove from row**.
- Removal reuses `TvContinueWatchingRemoval` logic and `RecentProvider` (tombstones sync across devices). Show a snackbar with **Undo**. Undo re-inserts the entry with its old timestamp.
- Resume uses the same resume rules as TV details (`ResumePoint`):
  - finished movies restart;
  - a finished episode plays the next one;
  - that includes the first episode of the next season.
- Tests: removal, undo, next-episode choice.

### Phase 4: Search as a destination
**Files:** `lib/mobile/screens/search_screen.dart`. Retire the `Search` `SearchDelegate` in `lib/screens/common/search_view.dart` once nothing opens it (the Movies and Series headers used it).

**Requirements:**
- A search field at the top of the page. It autofocuses when the user switches to the tab, and never on app start.
- Typing:
  - search after 350 ms of no typing, and only when the query has at least 2 characters;
  - drop any response whose query is no longer current (a generation counter, as in `TvSearchScreen._generation`);
  - show a small spinner in the field, not a full-page one;
  - keep the last results on screen while the next query loads.
- **Results, all in one list:**
  - a "Top result" wide card when one title matches strongly (an exact title match, or the highest popularity with a title prefix match);
  - then "Movies" and "Series" as poster grids (three columns on phones, five on tablets);
  - then "People" as circular avatars.
  - Filter chips above (All · Movies · Series · People) narrow the list. There are no tabs and no `Future.delayed`.
- **Empty query:**
  - Recent searches as `idleFill` chips, with long press to remove and "Clear" at end. Use the existing `SettingPreferences.getRecentSearches` / `addRecentSearch` (keep the storage key `recent_searches`; add remove and clear methods);
  - "Top searches" (a Top 10 row);
  - genre tiles;
  - "Browse with filters", which opens `DiscoverPage` restyled (phase 7).
- Save a recent search only when the user submits (keyboard search key) or opens a result.
- Keep the query and scroll position when coming back from a details page.
- **No results:** "No matches for ‘x’", then "Try: …" suggestions built from genre names that contain the query, then the Top searches row.
- The adult-content setting (`SettingsProvider.isAdult`) and language still apply.
- Tests: debounce (one request for a fast burst), stale-drop, save-on-open only, restore on return, filter chips. The storage key stays `recent_searches` so `test/mobile_search_history_test.dart` continues to pass.

### Phase 5: New & Hot
**Files:** `lib/mobile/screens/new_and_hot_screen.dart`.
- A segmented pill bar at the top: Coming Soon · Everyone's Watching · Top 10 Movies · Top 10 Series.
- **Coming Soon:** a vertical list of upcoming movies (`upcomingMoviesUrl`) and new seasons (`onTheAirUrl`), grouped by date.
  - Each item: a date column at start ("MAY" / "3"), a 16:9 backdrop, a title logo or title, a two-line synopsis, a genre line, and a **My List** pill ("Remind me" is out of scope; there is no notification support).
  - Future dates only, soonest first.
- **Everyone's Watching:** trending today, as large backdrop cards with Play and My List.
- **Top 10 Movies / Series:** a vertical ranked list with big rank numbers (reuse the painter), poster, title and one metadata line.
- Tests: date grouping and ordering, future-only filter, and that Top 10 lists never exceed ten.

### Phase 6: details pages
**Files:** `lib/mobile/screens/movie_details_screen.dart` and `series_details_screen.dart`. They replace `MovieDetailPage` (`lib/screens/movie/movie_detail.dart`, 2,803 lines) and `TVDetailPage` (`lib/screens/tv/tv_detail.dart`) at the routes that push them, including deep links. Keep the classes' public names as thin wrappers if other code or deep links construct them.

**Order, top to bottom:**
1. **Backdrop**, 16:9, full width, with a top scrim for the status bar and a bottom fade to `page`. Back and Cast buttons float over it in `idleFill` circles. Share is in the overflow.
2. **Title logo** (or title), then one metadata line: year · rating · runtime or "3 Seasons" · certification if known, plus a badge ("NEW", "TOP 10") when it applies.
3. **Primary button**, full width: **Play** / **Resume** / **Resume S2:E4** / **Play S1:E1** / **Next episode**, using the TV rules (`ResumePoint`). It shows the progress bar underneath when resuming, with "23m left".
   - Only when `AppDependencyProvider.displayWatchNowButton`.
   - The movie availability check stays whatever the current code uses; do not show Play for unreleased titles.
4. **Secondary full-width button:** **Download** (existing download flow and quality sheet). Hidden when downloads are unavailable.
5. **Synopsis** (three lines, tap to expand), then "Starring: …" and "Director: …" / "Creators: …" as one muted line each.
6. **Action row:** My List · Rate or Watch providers · Trailer · Share, as icon-over-label buttons in `foreground`, evenly spaced.
7. **Series only:** an Episodes section.
   - A season dropdown button ("Season 2 ▾") opens a bottom sheet of seasons; specials go last (`TvMediaDetailsData.seasons` does this).
   - Episode list: a 16:9 still on the start side, "3. Title", runtime and air date, a two-line synopsis, and a download icon at end.
   - The in-progress episode shows its progress bar. Unaired episodes are dimmed with "Coming May 3".
   - The page opens on the season being watched.
8. **Tabs**, a sticky tab bar using the retuned theme: **More Like This** (poster grid) · **Trailers & More** (videos) · **Details** (the rest of today's `_DetailsTab`: cast and crew grid, images, info table, watch providers, reviews, collection, social links).
   - Ads (`movie_detail`, `tv_detail`) go inside the Details tab, never above the Play button.

**Checks:**
- Tests for button labels in each resume state, season default, specials ordering, and that Play is absent when `displayWatchNowButton` is off.
- Deep-link tests still pass.
- Screenshots of a movie and a series in the three modes and in Arabic.

### Phase 7: My FlixQuest, Downloads, Discover and Settings
- **My FlixQuest** (`lib/mobile/screens/my_flixquest_screen.dart`):
  - Header: avatar, name, "Signed in" or "Guest" (from `UserInfo` logic), with a Profile pill that opens the existing edit-profile flow.
  - Then **Continue Watching** (continue cards), **My List** (poster row, "See all" opens `BookmarkScreen`), **Downloads** (the first three items as list tiles with status and progress, and "See all" opens `DownloadsScreen`), and **Viewing Insights** (one card that opens `WellnessScreen`).
  - Then list rows: Settings · Sync · Server status · About · Sign out. Use a `TvListRow`-like row: an icon in `mutedText`, a label in `foreground`, and a chevron.
  - Must work fully offline: downloads first; every network section fails quietly.
- **Downloads, My List, Discover, Settings and Profile screens:** restyle to the tokens. The app bar has a transparent background and a page title; lists use the list row; buttons are pills; there is no orange except progress.
  - `DownloadsScreen`'s `_StatusChip`: neutral chips; "Failed" uses `colorScheme.error`.
- **Discover** moves under Search ("Browse with filters"). Keep its filters. Results use the poster grid.

### Phase 8: phone player restyle (two repos)
- In `../flixquest-betterplayer` (`better_player_material_controls.dart`, `better_player_material_progress_bar.dart`):
  - icons white;
  - the timeline's played part is the accent;
  - no other accent;
  - buttons are 44-px circles on `black45` that turn `white` with black icon on press/focus;
  - the overlay fades in 160 ms and hides after 3 s.
- Match the TV controls' structure (`better_player_tv_controls.dart`) where it makes sense on touch: title at top start, the timeline at bottom with remaining time, and a row with play, back 10, forward 10 at start and episodes, subtitles, speed and quality at end.
- In `lib/screens/common/player.dart`, phone branch (`!widget.useTvControls`):
  - IntroDB skip uses a white-outlined pill (like `_TvSkipButton`);
  - the next-episode card matches the TV card: bottom end, countdown fill in the button, "Watch credits".
  - Keep IntroDB logic, completion detection and `shouldShowNextEpisodeTeaser` exactly as they are.
- Run both repos' tests. Commit each repo separately.

### Phase 9: tablets, accessibility, polish
- **Tablets (width ≥ 700):**
  - bottom bar becomes a `NavigationRail`-style side bar with the same four items and no Material indicator;
  - rows show 5–7 posters;
  - details use two columns (backdrop and actions at start, episodes and tabs at end) above 1,000 px.
- **Accessibility:**
  - every card has a semantic label ("Title, 2024, movie, 7.6 rating");
  - buttons are at least 48 × 48 tap targets;
  - contrast is checked by the palette tests;
  - screens survive text scale 1.3 without clipping.
- **Haptics:** light impact on long press and on adding to My List.
- **Empty and error states** use one component: an icon in `mutedText`, a title, one line, and an optional pill.
- **Clean-up:** delete dead widgets from `movie_widgets.dart`, `tv_widgets.dart` and `app_ui_components.dart`. `flutter analyze` must report no unused elements you introduced.

---

## 5. Definition of done
- A returning user can resume in one tap from Home's first screen.
- A new user can find a title in Search and start it without visiting any other tab.
- No screen shows orange outside the accent budget (section 3.2), verified by the accent test and by eye in all three modes.
- Dark, AMOLED, Light, a custom colour, a seasonal theme and ambient mode all look deliberate.
- Arabic is correct (RTL, no clipped text). Spanish and Hindi strings exist for every new key.
- Offline: My FlixQuest and Downloads work in airplane mode.
- The TV app is unchanged: `test/tv_*.dart` pass.
- Deep links and restoration work: `test/home_widget_*` pass.
- `flutter analyze` is clean for touched files. All tests pass except the two known failures.

---

## 6. Screenshot checklist (per phase)

| Screen | Dark | AMOLED | Light | Arabic | Tablet |
|---|---|---|---|---|---|
| Home (All, Movies, Series) | ☐ | ☐ | ☐ | ☐ | ☐ |
| Home loading skeleton | ☐ | | ☐ | | |
| Continue Watching sheet | ☐ | | ☐ | ☐ | |
| Search: empty, typing, results, no results | ☐ | ☐ | ☐ | ☐ | ☐ |
| New & Hot (each segment) | ☐ | | ☐ | ☐ | |
| Movie details / Series details | ☐ | ☐ | ☐ | ☐ | ☐ |
| My FlixQuest, offline | ☐ | | ☐ | | |
| Player (phone) | ☐ | | | | |
