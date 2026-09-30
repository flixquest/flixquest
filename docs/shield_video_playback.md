# Android TV video and renderer compatibility

## Diagnosis and workaround

`player.dart` and `live_player.dart` both use the local `better_player_plus`
plugin. Its Android backend renders Media3/ExoPlayer output into a Flutter
`SurfaceTexture`. The app uses Flutter 3.35.7 and previously had no Impeller
opt-out. Flutter issue [159503](https://github.com/flutter/flutter/issues/159503)
reports missing video (with working audio) on NVIDIA Shield, with multiple
device owners confirming that switching to Skia restores the picture.
[162526](https://github.com/flutter/flutter/issues/162526) is a duplicate covering
the same symptom with multiple video plugins.

The later Philips report is Android TV 14, build `UKN6.260116.009`, security
patch January 1, 2026; the comparison Xiaomi on Android TV 11 works. Screenshots
show player controls and a populated timeline over the previous loading page.
`handoffLoaderToPlayer` already removes the loader immediately, the player has
an opaque black Scaffold, and TV ambient glow is disabled. The route regression
test confirms loader disposal. Keeping old artwork despite those changes points
to retained GPU output or external video texture rendering, rather than an
unresolved provider request. A populated timeline alone does not prove video
frames reached the display.

Related upstream reports include
[177319](https://github.com/flutter/flutter/issues/177319), where
`better_player_plus` video on Android TV renders when Impeller is disabled,
[176695](https://github.com/flutter/flutter/issues/176695), involving texture
playback freezing on a Philips TV with Flutter 3.35.5, and
[189767](https://github.com/flutter/flutter/issues/189767), where Vulkan leaves
old UI composited over new UI on a TCL TV. These are supporting evidence, not
a confirmed reproduction on this Philips model or firmware. If audio and
playback position also fail, investigate the source, network, DRM and decoder
errors separately.

`FlixQuestApplication.attachBaseContext` installs a custom shared Flutter loader
on every Android TV: Android reports television mode or the Leanback feature.
There are no manufacturer, model or Android version filters. This avoids a
growing device allowlist for GPU/firmware-specific failures. Phones and tablets
retain Flutter's default loader and renderer. There is no application-wide
`EnableImpeller` manifest override.

The compatibility loader passes `--enable-impeller=false` at native initialization,
preserving unrelated engine arguments and removing conflicting Impeller flags.
It is registered before content providers and services run, without loading
Flutter during application attachment. In Flutter 3.35.7, both synchronous and
asynchronous initialization use the overridden method. This includes Firebase
Messaging and home-widget background startup before the activity opens.

Skia applies throughout the app on all Android TVs, including both streaming players;
ExoPlayer's hardware video decoding is unaffected. It requires a new APK and a
cold launch, not hot reload. Reassess the Flutter loader integration when
upgrading Flutter, and remove the workaround only after affected-device validation.

The tradeoff is UI rendering performance, including potential shader compilation
stutter and differences in animations or effects. The change does not disable
hardware acceleration or alter the source, codec, resolution, bitrate or video
decoder. TV navigation and playback need device smoke tests; Skia is a
compatibility policy for this Flutter version, not proof that every reported
playback failure is caused by Impeller. Flutter's
[renderer documentation](https://docs.flutter.dev/perf/impeller) describes the
Android opt-out and Impeller's shader compilation advantages.

Live playback also disables ambient glow in TV mode, matching the movie player.
Both settings listeners now preserve that TV restriction. This avoids costly
frame sampling; it is not the primary fix for the Impeller rendering issue.

## Validation with an affected TV owner

1. Install a newly built APK and force-stop/relaunch the app. Verify the startup
   log from `FlixQuestRenderer` says `policy=skia`, then check Flutter's own
   startup backend log (it should no longer select Impeller). The policy log
   records intended selection; the engine log and device test establish the
   actual result. Collect manufacturer, brand and model from this log when
   recording a device's playback results.
2. Play a previously failing movie/episode and live channel. Verify the picture,
   audio, controls and advancing position. Record TV model, Android version,
   app version and whether the original failure had audio.
3. Check pause/resume, seeking, quality/provider switching, channel switching,
   and returning from the home screen. Confirm video after any branded intro.
4. Smoke-test the same APK on a phone and the working Xiaomi Android TV 11.
   The phone retains its renderer; Xiaomi now also selects Skia. Check TV UI
   scrolling/animations as well as playback because the renderer change applies
   throughout the app.
5. Check a background messaging or widget launch before opening the activity,
   followed by playback, to confirm the renderer choice survives that path.

Capture renderer selection on a cold launch:

```sh
adb shell am force-stop dev.beamlak.flixquest_v2
adb logcat -v time -s FlixQuestRenderer:I flutter:I '*:S'
```

Open the app manually after starting the capture. If video is still missing,
enable the existing filtered diagnostics before opening the stream:

```sh
adb shell setprop log.tag.BetterPlayerStreaming DEBUG
adb logcat -v time -s BetterPlayerStreaming:D '*:S'
```

Capture the first-frame event, playback states and error codes while reproducing.
A first-frame callback means ExoPlayer submitted a frame, not that Flutter
successfully displayed it. These filtered diagnostics exclude URLs and headers;
avoid sharing unfiltered logs containing stream credentials.

Disable diagnostics afterwards:

```sh
adb shell setprop log.tag.BetterPlayerStreaming INFO
```

`TvRendererTest` covers TV mode and Leanback-feature detection, unknown TV brands,
the Philips Android 14 and Xiaomi Android 11 cases, early loader registration,
startup policy logging, preservation of the existing injector on phones, and
the final JNI initialization arguments
for foreground and background startup. JNI is replaced with a recorder in these
tests; they cannot establish playback correctness on physical TV hardware.
