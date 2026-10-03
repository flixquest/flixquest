# Handover: FlixQuest phone redesign, phase 5 onwards

You are continuing a phone and tablet UI redesign of FlixQuest, a Flutter app. The previous engineer finished phases 0–4. You will implement **phase 5 first, then stop and report**. Do not start the next phase until the user says so.

Read this whole file before touching code. Then read `docs/mobile_redesign_guide.md` (the full spec). **Where the two disagree, this file wins**, because it records decisions the user made after the guide was written.

---

## 1. Where things stand

- **Repo:** `/Users/beamlak/Documents/flutter_projects/personal/fq/flixquest`. Branch `feat/better-mobileui`. Main branch is `main`.
- **Done and committed:** phase 0 (shared catalog layer, palette, theme retune), phase 1 (shell and bottom bar), phase 2 (Home), phase 3 (Continue Watching), phase 4 (Search), plus a redesigned "Browse with filters" (Discover).
- **Not done:**
  - phase 5: New & Hot. The tab exists but shows a placeholder, `_NotYet` in `lib/mobile/app/mobile_shell.dart`;
  - phase 6: movie and series details pages;
  - phase 7: My FlixQuest hub and restyling Downloads, My List and Settings;
  - phase 8: phone player restyle, which touches a second repo;
  - phase 9: tablets, accessibility and polish.
- **The user commits each phase themselves.** Do not commit, push, create branches or open PRs unless the user asks. When a phase is finished, stop and report (section 9).

---

## 2. Hard rules (breaking any of these is a failed phase)

### 2.1 Tooling
- Flutter and Dart are **not on PATH**. Always use the repo's own SDK:
  - `.fvm/flutter_sdk/bin/flutter`
  - `.fvm/flutter_sdk/bin/dart`
- Analyze with `.fvm/flutter_sdk/bin/flutter analyze`.
  - The expected result is exactly **2 issues**: two `use_build_context_synchronously` infos in `lib/screens/common/live_tv_screen.dart`. They were there before; leave them.
  - Anything else is yours to fix.
- Test with `.fvm/flutter_sdk/bin/flutter test`.
  - **Expected: 541 or more passing, and exactly 2 failing.** The failing ones are `test/player_menu_route_test.dart` and `test/subtitle_options_test.dart`. They already fail on this branch.
  - Do not fix, skip, or weaken those two, and do not count them against yourself.
  - Any other failure is yours.
- Read the tally with this, since the default output is hard to read:

  ```
  .fvm/flutter_sdk/bin/flutter test 2>&1 | tr '\r' '\n' | grep -E "Some tests failed|All tests passed" | tail -1
  ```

### 2.2 Formatting
- Run `.fvm/flutter_sdk/bin/dart format <file>` **only on files you created**.
- **Never run `dart format` on an existing file, a directory, or the whole project.** Existing files are hand-formatted, and the formatter rewrites hundreds of unrelated lines.
- Edit existing files by hand in the surrounding style. Before you finish, run `git diff` on every existing file you touched. If you see reflowed lines you didn't mean to change, revert them.

### 2.3 Devices
- The user usually has `flutter run` attached to the phone emulator (`emulator-5554`) and hot-restarts it themselves.
- **Do not `flutter run`, `flutter install` or `adb install` onto any device, and do not send input with adb.** Check with `ps aux | grep "flutter run"` if unsure.
- A TV emulator may also be running. Never touch it.
- To look at your UI, use offscreen golden previews (section 7.3), not a device.
- When done, tell the user to press **R** in their `flutter run` terminal.

### 2.4 Scope
- Only change what the phase needs.
- **Do not change the TV app** (`lib/tv/**`). `test/tv_*.dart` must keep passing.
- `lib/constants/theme_data.dart` is shared with TV. Avoid editing it; if you must, run the TV tests.
- Do not "clean up" unrelated code you happen to see.

---

## 3. Design language (the user cares about this a lot)

The look copies the app's Android TV UI: **artwork first, a quiet interface, neutral ink for selection, and the orange accent used almost nowhere.** The user has pushed back hard every time orange appeared on a control. Direct quote: "i hate the primary color on the discover page on the slider and the switch".

### 3.1 Colours
- **Every colour comes from `AppPalette.of(context)`** (`lib/design/app_palette.dart`). Roles:
  - `page`, `surface`, `raisedSurface` (backgrounds);
  - `foreground`, `secondaryText`, `mutedText` (text and icons);
  - `focusFill` / `onFocus` (the selected or primary thing: white in dark themes, near-black in Light);
  - `idleFill` / `idleFillStrong` (unselected chips, secondary buttons);
  - `hairline` (dividers);
  - `scrim(alpha)` (fades into the page).
- **No hard-coded colours** except artwork overlays that sit on images and stay fixed in every theme:
  - black gradients over backdrops;
  - white text on artwork;
  - `AppPalette.logoPlate` (`#F2F2F3`), the light plate that streaming-service logos sit on;
  - `MediaArt.darkPlaceholder`.
- **`colorScheme.primary` (the accent, orange by default) may only appear in:**
  - the FlixQuest logo mark;
  - progress bars (watch progress, download progress);
  - one small uppercase kicker per screen region (for example "NEW" or "COMING MAY 3");
  - the text cursor and selection handles.
- **Never use the accent on:**
  - buttons or chips;
  - tabs or segmented controls;
  - switches, sliders or checkboxes;
  - icons, section headers, links or spinners.
  - Spinners use `palette.mutedText`.
- **Do not use Material `Switch`, `Slider`, `Checkbox`, `TabBar` or `SegmentedButton` in new UI.** Their theme colours are the accent. Use pills (`ChoicePill`, `PillButton`) or a segmented control built from `focusFill` / `idleFill`. Copy `_KindSwitch` in `lib/mobile/screens/discover_screen.dart`.
- **All three theme modes must look right:** Dark (page `#111315`), AMOLED (page `#000000`) and Light (page `#FCFCFD`, never pure white). Also dynamic colour, custom colours, seasonal themes and ambient tint; these only change the accent and the page tint if you use palette roles.

### 3.2 Type, spacing and icons
- Type comes from `lib/design/app_tokens.dart`:
  - `AppType` has `heroTitle`, `pageTitle`, `sectionHeader`, `cardTitle`, `metadata`, `kicker`, `body` and `button`;
  - the font families are `AppType.bold` (`FigtreeBold`), `AppType.semiBold` (`FigtreeSB`) and `AppType.regular` (`Figtree`), plus `FigtreeBlack` for the wordmark only;
  - style with `.copyWith(color: palette.x)`.
- Spacing and sizes, also from `app_tokens.dart`:
  - `AppSpace`: `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 20, `xxl` 24, `xxxl` 32;
  - `AppSpace.gutter(context)` is the page side padding (16 on phones, 24 on tablets);
  - `AppSpace.rowGap` is 24 between rows;
  - `AppRadii`: `card` 6, `button` 6, `hero` 10, `chip` 18, `sheet` 16;
  - `AppBreakpoints`: `tablet` 700, `wide` 1000.
- **Icons: Phosphor only** (`package:phosphor_flutter`):
  - `PhosphorIcons.play(PhosphorIconsStyle.fill)`, `PhosphorIcons.plus()`, `PhosphorIcons.check()`, etc.;
  - use the regular style normally and the fill style for "selected / on";
  - no Material `Icons.*` in new UI.

### 3.3 Language and layout direction
- **Four languages: en, es, ar (right-to-left), hi.** Every new user-visible string needs a key in **all four** files: `assets/translations/{en,es,ar,hi}.json`.
  - Write real Spanish, Arabic and Hindi translations, not English copies.
  - `test/translation_catalog_test.dart` fails if any file is missing a key.
  - Look up strings with `tr('key')` from `easy_localization`. For placeholders use `tr('key', namedArgs: {'n': '3'})`, with `{n}` in the JSON.
  - **Don't overwrite whole files when adding keys.** Insert new keys near the end of each file, keep valid JSON, and check it with `python3 -c "import json;json.load(open('assets/translations/en.json'))"`.
- **After adding keys, regenerate the two generated files** (the user expects them kept in sync):

  ```
  .fvm/flutter_sdk/bin/dart run easy_localization:generate -S assets/translations -O lib/translations -o codegen_loader.g.dart
  .fvm/flutter_sdk/bin/dart run easy_localization:generate -S assets/translations -O lib/translations -f keys -o locale_keys.g.dart
  ```
- **Layout direction:** use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, and `start`/`end`. Never use `left`/`right` for anything directional. The Arabic layout must mirror.
- `easy_localization` re-exports `intl`'s `TextDirection`. If you need Flutter's, import `package:easy_localization/easy_localization.dart hide TextDirection`.
- **Large text must not break layouts:** at text scale 1.3 on a 320-wide phone, nothing may overflow. Use `Flexible`, `Expanded`, `FittedBox(fit: BoxFit.scaleDown)` or `maxLines` with `overflow: TextOverflow.ellipsis`.

---

## 4. Decisions the user made (these override the guide)

1. **Home's hero is a carousel, not a fixed title.** The guide says "stable hero, don't auto-advance"; the user asked for the old FlixQuest behaviour instead: randomised trending and discover picks that cross-fade. Leave `HeroCarousel` alone.
2. **Movies and series stay in separate rows.** Only personal rows (Continue Watching, My List) and the labelled hero mix the two kinds. Apply the same rule in New & Hot: Top 10 Movies and Top 10 Series are separate.
3. **Streaming-service logos sit on the light `AppPalette.logoPlate`.** Several logos (Max, Apple TV+, Peacock) are dark and were invisible on the dark plate the guide specified. Ignore the guide's `#1E1F22`.
4. **The Home header is the SVG logo in the accent colour plus a "FLIXQUEST" wordmark** (`FigtreeBlack` 20 in `foreground`). Don't change it.
5. **Browse with filters (Discover) is finished.** It's reached from Search, not Home. It has no explicit-content toggle; it follows `SettingsProvider.isAdult` like every other list. Phase 7 needs no Discover work beyond checking it.
6. **The update banner (`UpdateBottom`) is on Home for now**, as the first optional row in `homeRows(...)` in `lib/mobile/screens/home_screen.dart` (`HomeOptionalRow(child: UpdateBottom())`). Phase 7 moves it to the top of My FlixQuest.
7. **Continue Watching includes "up next" episodes.** After an episode passes 85%, `UpNext` (`lib/catalog/up_next.dart`, stored on the device) records the next one. Resume and play logic lives in `MobilePlayback` (`lib/mobile/playback.dart`) and `chooseEpisode` / `upNextFor` (`lib/catalog/episode_choice.dart`). Reuse these; never write your own resume rules.

---

## 5. Known traps (each of these has already cost time)

- **Text fields:** the app theme's `inputDecorationTheme` adds `contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16)` to every `TextField`, even with `isCollapsed: true`. Any compact field must set `contentPadding: EdgeInsets.zero`, or its text sits off-centre. See `_SearchField` in `search_screen.dart`.
- **Provider:**
  - `context.watch` / `Provider.of(context)` with listening **must not** be called outside `build`, such as in callbacks, `initState` or post-frame callbacks. Use `context.read` or `listen: false` there.
  - `tmdbImageUrl(context, path, size: ..., listen: false)` has a `listen` flag for exactly this reason.
- **Bottom sheets that can be tall:** use `showModalBottomSheet(isScrollControlled: true, ...)` with a `SingleChildScrollView` inside, or they overflow on short phones with large text.
- **Never return a `Future` from a `setState` callback.** Do the async work, then `setState(() {...})` with a synchronous body.
- **The TMDB proxy:** requests go through `CatalogController` (`lib/catalog/catalog_controller.dart`), which applies the user's proxy and language settings. Don't call `http.get` on TMDB URLs yourself.
- **`RecentProvider` needs Firebase**, so it can't be built in widget tests. Put the logic in a plain class, as `UpNextBook` did, or pass data in through constructor parameters, and test that.
- **Deep links** construct `MovieDetailPage` and `TVDetailPage` in `lib/services/deep_link_routes.dart`. Keep those class names and constructors working in phase 6. `test/home_widget_*` and `test/media_link_test.dart` must pass.
- **Ads:** `RemoteHostedAdsBanner` placements are revenue. Move them, never delete them, keep the `placement:` strings, and never put one above the first screen of content or above a Play button. For an ad slot in a list, copy `HomeAdSlot` in `home_screen.dart`; it collapses with no gap when no ad loads.

---

## 6. Building blocks to reuse (read these files first)

**Data** (`lib/catalog/`, UI-free and unit-testable):
- `media_item.dart`: `MediaItem` has `kind`, `id`, `title`, `overview`, `posterPath`, `backdropPath`, `rating`, `releaseDate`, `genreIds`, `popularity`, `year`, `progress`, `upNext` and `stableId`, with factories `fromMovie`, `fromSeries` and `fromUpNext`. `MediaKind` is `{movie, series}`.
- `catalog_controller.dart`: `CatalogController`
  - `loadRow(kind:, url:, settings:, dependencies:)` fetches one list, returning empty on failure;
  - `loadServiceRow(...)` fetches a streaming service's titles;
  - `loadGenres(...)`;
  - `listCollection(...)` builds a paged `MediaCollection` to open in `CollectionScreen`;
  - `serviceFor(id)`.
- `home_feed_controller.dart`:
  - `HomeFeedSource` is the interface; `CatalogHomeFeedSource` is the real TMDB one, and `urlFor(kind, HomeList)` maps each `HomeList` to a TMDB URL;
  - `HomeList` is `{trendingToday, trendingWeek, popular, topRated, newReleases, upcoming}`;
  - tests pass a fake `HomeFeedSource`. Copy that pattern for New & Hot.
- `details_controller.dart`:
  - `MediaDetailsController.load(...)` / `loadSeason(...)` and `MediaDetailsData` (with `facts` and `seasons`, specials last);
  - `ResumePoint` has `forItem`, `finished`, `progress`, `episodeLabel` and `timeLeft`;
  - `formatRuntime`, `initialSeasonNumber`, `episodeAfter` and `hasAired`.
- `title_logos.dart`: `TitleLogos` and `TitleLogoScope`. The widget is `TitleLogo` in `lib/design/title_logo.dart`; it shows a title's logo art, or falls back to text.
- Also: `continue_watching.dart`, `episode_choice.dart`, `up_next.dart`, `media_search.dart`, `discover_query.dart`.
- Endpoints are in `lib/api/endpoints.dart`: `upcomingMoviesUrl(lang)`, `onTheAirUrl(lang)`, `airingTodayUrl(lang)`, `trendingMoviesTodayUrl(lang)`, `trendingTVTodayUrl(lang)`, `nowPlayingMoviesUrl(page, lang)`, and more.

**Design** (`lib/design/`):
- `AppPalette` and the `app_tokens.dart` tokens described in section 3;
- `MediaBadge(label:)` with `MediaBadge.recencyOf(item)`;
- `TopTenRank(rank:, cardWidth:, height:)`, which paints the big rank numbers;
- `TitleLogo`.

**Phone widgets** (`lib/mobile/widgets/`):
- `media_art.dart`:
  - `MediaArt(...)` is a network image with a themed placeholder;
  - `tmdbImageUrl(context, path, size:, listen:)`;
  - `ArtSize.backdrop` / `ArtSize.still`;
  - `posterWidth(context)`.
- `poster_card.dart`:
  - `PosterCard(item:, width:)`;
  - `Pressable` gives press-scale and haptics, with `onTap` / `onLongPress`;
  - `mediaSemanticLabel(item)`.
- `media_rows.dart`:
  - `PosterRow(title:, kicker:, items:, badgeFor:, onSeeAll:)`;
  - `TopTenRow`, `ContinueRow`, `ContinueCard`, `StillRow`, `ServiceRow`;
  - `recencyBadge`.
- `pill_button.dart`: `PillButton(label:, icon:, onPressed:, primary:, busy:, height:, onArtwork:)`. `primary: true` gives the `focusFill` pill (the Play button); the default gives `idleFill`. Use `onArtwork: true` over images.
- `filter_chips.dart`: `FilterChips(chips: [FilterChipSpec(label:, onTap:, selected:)])` is a horizontal chip row; `ChoicePill` is a single chip.
- `section_header.dart`: `SectionHeader(title:, kicker:, onSeeAll:)`.
- `hero_card.dart`: `HeroCard`, `HeroCarousel`.
- `category_section.dart`: `FeatureCard(item:, onTap:)`, a wide 16:9 card with a title.
- `title_sheet.dart`: `showTitleSheet(context, item)`, the long-press quick sheet with Play, My List and Details; also `mediaFacts(item)`.
- `continue_sheet.dart`: `showContinueSheet(...)`.
- `skeletons.dart`: `HomeSkeleton`. Copy its pulse for new skeletons.
- `genre_sheet.dart`.

**Phone helpers** (`lib/mobile/`):
- `playback.dart`: `MobilePlayback.canPlay(context)` respects the `displayWatchNowButton` flag. Also `resumeFor`, `openDetails(context, item)` and `play(context, item)`.
- `my_list.dart`: `MyList.contains(context, item)`, `MyList.items(context, ...)` and `MyList.toggle(context, item)` (shows its own snackbar).
- `collections.dart`: `openGenreCollection(...)`.

**Shell** (`lib/mobile/app/`):
- `mobile_shell.dart`: `MobileShell` builds tabs lazily and keeps them alive. `_AppTab` maps each `MobileTab` to its screen, and the `tabBuilders` parameter lets tests swap tabs.
- `mobile_tabs.dart`: `MobileTab` is `{home, newAndHot, search, mine}` with ids `home`, `new`, `search`, `mine`.
  - `MobileTabController` provides `scrollController(tab)` (attach it to your tab's main scroll view so tapping the tab again scrolls to top), `addResetListener(tab, callback)` (a second tap resets the tab), `current` and `switches`.
  - See how `HomeScreen` and `SearchScreen` hook into it.

**Reference screens to copy patterns from:**
- `lib/mobile/screens/home_screen.dart`: loading, skeleton, per-row failure, retry, refresh, ad slots, tab-controller hookup.
- `lib/mobile/screens/search_screen.dart`: the pinned header with a field and chips.
- `lib/mobile/screens/discover_screen.dart`: the segmented control `_KindSwitch`, toggle pills, sections.
- `lib/mobile/screens/collection_screen.dart`: the paged grid.

---

## 7. How to work

### 7.1 Order for each phase
1. Read the phase spec (section 8) and the matching part of `docs/mobile_redesign_guide.md`.
2. Read the building blocks you'll use. Don't guess constructor parameters; open the file.
3. Put data logic in `lib/catalog/` as plain Dart classes with an injectable source and an injectable `now`, then unit-test it.
4. Build the screen in `lib/mobile/screens/` and small widgets in `lib/mobile/widgets/`. Prefer new small files over growing old ones.
5. Wire it in (for phase 5: replace `_NotYet` in `mobile_shell.dart`).
6. Add translations to all four files, then regenerate the codegen (section 3.3).
7. Write widget tests (7.2), preview it (7.3), analyze, run the full suite.
8. Delete any old code the phase made unused. Search with `grep -rn "ClassName" lib test` before deleting.
9. Report (section 9) and stop.

### 7.2 Tests
- Put test files in `test/`, named after the feature, e.g. `test/new_and_hot_screen_test.dart`.
- Test **behaviour**, not pixels:
  - what shows and in what order;
  - what a tap does;
  - empty and error states;
  - the accent appearing only where allowed.
- Copy the scaffolding from `test/home_screen_test.dart` and `test/discover_screen_test.dart`:
  - `dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');`
  - `SharedPreferences.setMockInitialValues({})`, then `sharedPrefsSingleton = await SharedPreferences.getInstance();`
  - wrap the screen in `MultiProvider` with `SettingsProvider` and `AppDependencyProvider`, then `MaterialApp`;
  - inject a fake data source through a constructor parameter. Never hit the network.
- In tests, `tr('key')` returns the key itself, so `find.text('coming_soon')` finds the translated label. Uppercase kickers come out as `find.text('COMING_SOON')`.
- `tester.scrollUntilVisible(finder, 200, scrollable: list)` needs a finder that matches **exactly one** widget; `.first` / `.at()` don't work in it. Pick the vertical list with:

  ```dart
  find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
  ```
- Copy the existing "small phone, large text, right to left: nothing overflows" test in `home_screen_test.dart` (around line 430) for every new screen.
- Copy the existing "accent only on the kicker and progress" test in `home_screen_test.dart` (around line 397) for every new screen, in Dark and Light.

### 7.3 Previewing without a device
To see your screen, write a **temporary** golden test and look at the PNG:
- create `test/_preview/<name>_test.dart`;
- load real fonts with `FontLoader`:
  - the Figtree files are in `assets/fonts/Figtree/` (`Figtree` = `Figtree-Medium.ttf`; check `pubspec.yaml` for which file each family uses);
  - the Phosphor fonts are in `~/.pub-cache/hosted/pub.dev/phosphor_flutter-2.1.0/`, loaded as families `packages/phosphor_flutter/PhosphorRegular`, `PhosphorFill` and `PhosphorBold`;
- use `tester.view.physicalSize = Size(1080, 2340); tester.view.devicePixelRatio = 2.625;`;
- use the real theme: `Styles.themeData(appThemeMode: 'dark' | 'light' | 'amoled', isM3Enabled: true, lightDynamicColor: null, darkDynamicColor: null, context: context, appColor: AppColor(cs: const ColorScheme.dark(), index: -1))` inside a `Builder`;
- `await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/<name>.png'));`, then run with `--update-goldens`.

A `MissingPluginException` from `path_provider` or the image cache is harmless in previews. **Delete `test/_preview/` before you finish.** It must not be left in the repo.

---

## 8. Phase specs

### Phase 5: New & Hot (do this now)

**Goal:** replace the placeholder New & Hot tab with a real screen.

**Files:**
- new: `lib/catalog/new_and_hot.dart` (data and logic);
- new: `lib/mobile/screens/new_and_hot_screen.dart`;
- new, if needed: small widgets in `lib/mobile/widgets/`;
- new: `test/new_and_hot_test.dart` (logic) and `test/new_and_hot_screen_test.dart` (widgets);
- edit: `lib/mobile/app/mobile_shell.dart` (`MobileTab.newAndHot => const NewAndHotScreen()`, then delete `_NotYet` if nothing else uses it);
- edit: the four translation files, then regenerate.

**Layout:**
1. **Header**, pinned. Page title "New & Hot" (key `new_and_hot` already exists) in `AppType.pageTitle` / `foreground`, with the top safe-area inset. Under it, a horizontally scrolling row of four pills using `FilterChips`:
   - **Coming Soon**
   - **Everyone's Watching**
   - **Top 10 Movies**
   - **Top 10 Series**

   The selected pill is `focusFill` and the rest `idleFill`. **No `TabBar`, no accent.** Tapping a pill switches the list below with a 180–220 ms cross-fade (`AnimatedSwitcher`). Keep each segment's scroll position, or scroll to top on switch; pick one and be consistent.
2. **Coming Soon**: a vertical list, grouped by date, soonest first, **future dates only** (today counts).
   - **Data:**
     - Movies come from `Endpoints.upcomingMoviesUrl(lang)`. TMDB's "upcoming" also returns titles already released, so filter by `releaseDate >= today`.
     - Series: `on_the_air` returns shows whose *first* air date is years old, so it can't be date-grouped. Instead, fetch **new series premieres** through TMDB discover: `/discover/tv?first_air_date.gte=<today yyyy-MM-dd>&first_air_date.lte=<today+60d>&sort_by=popularity.desc&language=<lang>&api_key=...`, built like the existing URLs in `Endpoints` or `CatalogHomeFeedSource`. Fetch through `CatalogController.loadRow`.
     - Merge both kinds, drop items with no date or no artwork (need a backdrop or poster), sort by date ascending then popularity descending, and group by calendar day.
   - **Each date group:**
     - a start-side date column: month abbreviation ("MAY") in `AppType.kicker` / `mutedText`, day number ("3") in `AppType.pageTitle` / `foreground`. Format with `DateFormat.MMM(locale)` / `DateFormat.d(locale)` from `intl`, using the context locale so Arabic and Hindi dates are localized;
     - then one item card per title in that group.
   - **Item card:**
     - 16:9 backdrop (`MediaArt`, `ArtSize.backdrop`, radius `AppRadii.card`);
     - the title logo (`TitleLogo`, max height about 48) or the title;
     - a kind label ("Movie" / "Series") plus the genre names, as one `metadata` line in `mutedText`. Genre names come from the genre lists: see how `HomeFeed.movieGenres` / `seriesGenres` are loaded with `CatalogController.loadGenres`;
     - a two-line synopsis in `secondaryText` with ellipsis;
     - a **My List** `PillButton`: plus icon, or check when saved, via `MyList.toggle` / `MyList.contains`;
     - a small kicker "COMING MAY 3" or "PREMIERES MAY 3" (the one allowed accent in this card).
     - **No "Remind me"**: there is no notification support.
     - Tapping the card opens details (`MobilePlayback.openDetails`); long press opens `showTitleSheet`.
3. **Everyone's Watching**:
   - Trending today for both kinds, from `trendingMoviesTodayUrl` / `trendingTVTodayUrl`, interleaved movie, series, movie, … Reuse the public top-level `interleave(...)` in `lib/catalog/home_feed_controller.dart`.
   - Show large backdrop cards with the title logo or title, a metadata line, a two-line synopsis, and two pills:
     - **Play** (`primary: true`, play icon), **only if `MobilePlayback.canPlay(context)`**, which calls `MobilePlayback.play(context, item)`;
     - **My List**.
   - Tapping the card opens details. At most 20 items.
4. **Top 10 Movies / Top 10 Series**: a vertical ranked list, **never more than 10 items**.
   - **Data:** trending today for that kind (the same lists Home's Top 10 uses; check `HomeList.trendingToday` in `CatalogHomeFeedSource`).
   - **Each row:** the big rank number (`TopTenRank`, the same painter as Home), a poster (`PosterCard`), then the title, one metadata line (year · rating), and a one-line synopsis.
   - Tap opens details; long press opens `showTitleSheet`.
5. **States**, per segment:
   - **Loading:** a skeleton that matches the segment's layout (copy `HomeSkeleton`'s pulse).
   - **Failure:** a quiet message in `mutedText` plus a Retry `PillButton`. One segment failing must not break the others.
   - **Empty:** a short message, for example when there are no upcoming titles.
6. **Ads:** one `HomeAdSlot`-style ad in Coming Soon after the third date group, with a new placement name `new_and_hot`. Never at the top. Tell the user this placement name is new, since they may need to configure it remotely.
7. **Tab integration:**
   - attach `MobileTabController.scrollController(MobileTab.newAndHot)` to the active segment's scroll view (tapping the tab again scrolls to top);
   - a second tap resets to the Coming Soon segment (see how `SearchScreen` registers its reset);
   - pull-to-refresh reloads the current segment, keeping the old content visible while it reloads.
8. **Performance:** load each segment lazily on first view and cache it for the session. Don't fetch all four at startup.

**Logic in `lib/catalog/new_and_hot.dart`:**
- `NewAndHotSource`: an interface with a real TMDB implementation, faked in tests.
- A pure function that turns movies + series + `now` into date groups, sorted and future-only.
- A Top 10 function that dedupes and caps at 10.
- The trending interleave.

**Tests (all required):**
- Date grouping: items on the same day are in one group; groups ordered soonest first; items within a group ordered by popularity.
- The future-only filter: yesterday is dropped, today is kept, and missing dates are dropped.
- Top 10 lists never exceed ten, even when the source returns 20.
- Tapping each pill shows that segment and hides the others.
- Play is absent when `displayWatchNowButton` is off.
- A segment failing shows Retry, and Retry reloads it.
- The accent appears only on the kicker, in Dark and Light.
- A 320-wide screen at text scale 1.3 in Arabic overflows nowhere.
- The ad is not in the first date group.

**Done when:** analyze shows only the 2 known issues, the full suite shows only the 2 known failures, `test/tv_*.dart` pass, the codegen is regenerated, `test/_preview/` is deleted, and the report is written.

---

### Phase 6: details pages (only when the user says go)
**Files:** new `lib/mobile/screens/movie_details_screen.dart` and `series_details_screen.dart`.
- They replace `MovieDetailPage` (`lib/screens/movie/movie_detail.dart`) and `TVDetailPage` (`lib/screens/tv/tv_detail.dart`) everywhere those are pushed on phones.
- **Keep the old class names and constructors as thin wrappers** that build the new screens, because deep links (`lib/services/deep_link_routes.dart`), `MobilePlayback.openDetails`, bookmarks, the sync screen, person pages and collection pages construct them.
- **The TV app has its own details screen**; don't touch it.

Follow guide section "Phase 6", with these specifics:
- **Load data** with `MediaDetailsController`. The in-page resume, next-episode and season logic must come from `ResumePoint`, `chooseEpisode`, `upNextFor` and `initialSeasonNumber`. **Never write new resume rules.**
- **The primary button** is a full-width `PillButton(primary: true)`:
  - its label is one of Play / Resume / Resume S2:E4 / Play S1:E1 / Next episode;
  - under it goes a thin progress bar (the accent) plus "23m left" when resuming;
  - it's hidden when `MobilePlayback.canPlay` is false;
  - it's hidden for unreleased titles; keep whatever availability check the current pages use.
- **Download:** a secondary full-width pill that reuses the existing download flow and quality sheet from the current detail pages. Find it in `movie_detail.dart` / `tv_detail.dart` and call it; don't rewrite it.
- **Action row:** My List · Trailer · Share · Watch providers. These are icon-over-label buttons in `foreground`, with no accent.
- **Series, episodes section:**
  - a "Season 2 ▾" pill opens a bottom sheet (scroll-controlled) of seasons, specials last;
  - each episode is a row: a 16:9 still at the start, then "3. Title", runtime · air date, a two-line synopsis, and a download icon at the end;
  - the in-progress episode shows a progress bar;
  - unaired episodes (`hasAired`) are dimmed with "Coming May 3";
  - the page opens on the season being watched.
- **Tabs:** don't use a Material `TabBar` (its theme uses the accent). Build a sticky pill row with three pills:
  - **More Like This**: a poster grid;
  - **Trailers & More**: the videos;
  - **Details**: cast and crew, images, the info table, watch providers, reviews, collection, and social links, moved from today's pages.
- **Keep every existing feature.** Restyle and reorder; delete nothing.
- **Ads** (`movie_detail`, `tv_detail` placements) go inside the Details tab only.
- **Once nothing references old widgets** in `movie_detail.dart` / `tv_detail.dart` / `movie_widgets.dart` / `tv_widgets.dart`, delete them. Grep first.
- **Tests:**
  - button label for each resume state;
  - default season;
  - specials last;
  - no Play when `displayWatchNowButton` is off;
  - deep-link tests still pass;
  - RTL and large-text overflow;
  - accent only on progress.

### Phase 7: My FlixQuest and restyles (only when the user says go)
- **New screen:** `lib/mobile/screens/my_flixquest_screen.dart`. Replace `legacy(const UserInfo())` for `MobileTab.mine` in `mobile_shell.dart`.
- **At the top:** the `UpdateBottom` banner. Move it out of Home's `homeRows(...)` and update the Home tests that expect it.
- **Header:** avatar, name, "Signed in" or "Guest". Reuse the logic in `lib/screens/user/user_info.dart`. A Profile pill opens `ProfileEdit` (`lib/screens/user/edit_profile.dart`).
- **Sections:**
  - Continue Watching (`ContinueRow`);
  - My List (`PosterRow`; "See all" opens `BookmarkScreen`, `lib/screens/common/bookmark_screen.dart`);
  - Downloads (the first three as list rows with status and progress; "See all" opens `DownloadsScreen`, `lib/screens/common/downloads_screen.dart`);
  - Viewing Insights (one card that opens `WellnessScreen`, `lib/screens/wellness/wellness_screen.dart`).
- **List rows** (`mutedText` icon, `foreground` label, chevron at the end): Settings (`Settings`, `lib/screens/common/settings.dart`) · Sync (`SyncScreen`) · Server status (`ServerStatusScreen`) · About (`AboutPage`) · Sign out (reuse `UserInfo`'s sign-out).
- **It must work fully offline:** Downloads first, and every network section fails quietly.
- **Restyle** Downloads, My List (`BookmarkScreen`), Settings and Profile to the tokens:
  - transparent app bar with a page title;
  - list rows and pills;
  - no accent except progress;
  - `DownloadsScreen`'s `_StatusChip` becomes neutral, with "Failed" in `colorScheme.error`.
- **Settings** has many Material `Switch`es and `Slider`s. The accent is allowed only on switch "on" states, but the user dislikes accent controls, so **ask the user before restyling Settings controls**. Don't assume.
- **Delete `UserInfo`** once nothing uses it.

### Phase 8: phone player restyle (only when the user says go; two repos)
- **The phone player controls** live in a **separate git repo**, `../flixquest-betterplayer`, in `lib/src/controls/better_player_material_controls.dart` and `better_player_material_progress_bar.dart`. It has its own history and tests. The TV controls there (`better_player_tv_controls.dart`) are the style reference; don't change them.
- **Restyle only:**
  - white icons;
  - the accent only on the played part of the timeline;
  - 44 px circular buttons on `black45`;
  - the overlay fades in over 160 ms and auto-hides after 3 s;
  - title at top start;
  - timeline at the bottom with remaining time;
  - play / back 10 / forward 10 at the start, and episodes / subtitles / speed / quality at the end.
- **In this repo, `lib/screens/common/player.dart`**, phone branch only (`!widget.useTvControls`):
  - restyle the IntroDB skip button as a white-outlined pill;
  - restyle the next-episode card to match the TV one.
  - **Do not change** IntroDB logic, completion detection, `shouldShowNextEpisodeTeaser`, sources, subtitles, or progress saving.
- **Run both repos' tests.** Report changes per repo; the user commits each separately.

### Phase 9: tablets, accessibility, polish (only when the user says go)
Follow the guide's "Phase 9" section:
- **Tablet:** at width ≥ 700, the bottom bar becomes a side rail with the same four items and no indicator; rows show more posters; details pages use two columns above 1000.
- **Accessibility:** semantic labels on every card (`mediaSemanticLabel`); tap targets ≥ 48×48; no clipping at 1.3× text.
- **Haptics:** a light impact on long press and on adding to My List.
- **One shared empty/error component.**
- **Delete dead widgets** from `movie_widgets.dart`, `tv_widgets.dart` and `app_ui_components.dart`, grepping each before deletion.

---

## 9. Report format (at the end of every phase)

Write a short report for the user. They are the app's developer; they don't need a lesson, but they do need the facts. Include:
1. **What the screen does now:** a few bullets from the user's point of view.
2. **Every place you departed from this file or the guide, and why.**
3. **Anything the user must do:** configure a new ad placement, answer a design question, press R.
4. **Verification, with the real numbers:**
   - the analyze result;
   - the test tally (for example "543 passed, 2 failed: the two known failures");
   - which themes and languages you previewed.

   If something failed, say so plainly, with the output.
5. **Files added, changed and deleted.**
6. **Confirm** that `test/_preview/` is gone, the codegen is regenerated, and nothing is committed.

Then **stop and wait** for the user before starting the next phase.
