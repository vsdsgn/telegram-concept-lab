# Reaction Wheel — iOS demo

Native UIKit prototype of the shared Reaction Wheel interaction. All conversation content is invented mock data, is labelled in the app, and is kept in memory. The app has no network code, Telegram assets, backend integration, analytics, or persistence.

## Requirements

- macOS with Xcode 27.1 or newer (the project targets iOS 17+)
- An installed iOS Simulator runtime for launching and executing tests

## Build

From this directory:

```sh
xcodebuild \
  -project ReactionWheel.xcodeproj \
  -scheme ReactionWheel \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath /tmp/reaction-wheel-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Verified on 2026-11-22 with Xcode 27.1 (build 27A9275): `** BUILD SUCCEEDED **`. The build produced `ReactionWheel.app` for arm64 and x86_64 iOS Simulator architectures. Xcode emitted only the expected App Intents metadata warning and local CoreSimulator service warnings.

## Test

Compile the app and unit-test bundle:

```sh
xcodebuild \
  -project ReactionWheel.xcodeproj \
  -scheme ReactionWheel \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath /tmp/reaction-wheel-tests-derived \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Verified result: `** TEST BUILD SUCCEEDED **`. Geometry tests cover the six unique targets, preferred up placement, RTL order mirroring, held-anchor invariant, and compact fallback.

To execute them on a machine with an available runtime:

```sh
xcodebuild \
  -project ReactionWheel.xcodeproj \
  -scheme ReactionWheel \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath /tmp/reaction-wheel-tests-derived \
  test
```

Test execution was not claimed here: CoreSimulatorService was unavailable in the build environment (`Unable to discover any Simulator runtimes`). Automated evidence is therefore test compilation only, not a passing test run.

## Run and demo

Open `ReactionWheel.xcodeproj`, select an installed iPhone simulator, and Run. Hold a message for 350 ms, keep the finger down, slide toward a reaction, and release. Releasing near the anchor or outside the wheel cancels. Choosing the current reaction toggles it off; tapping its reaction chip is a shortcut for removal.

Useful checks:

1. Try messages at the top, sides, and bottom; the arc rotates or uses the compact picker when it cannot fit.
2. In Demo settings, switch light/dark appearance, force Reduce Motion, disable haptics, or show hit-test circles.
3. With VoiceOver, focus a message and use the `React…` custom action. The persistent picker exposes six named buttons and a Close button; the two-finger escape gesture dismisses it.
4. Change the simulator language to Russian to verify the RU string table.
5. Rotate while the wheel is open; it cancels and restores scrolling.

## Implemented behavior

- 350 ms native long press with 10 pt pre-open movement tolerance and scroll arbitration
- six-item semicircle, deterministic axis preference, RTL mapping, scale-aware selected extents, and compact fallback
- 44 pt selection entry / 32 pt exit dead zone; 80 pt capture, 96 pt stay, and 8 pt switch hysteresis
- spring cascade, live scrubbing, selection haptics limited to one per 85 ms, add/replace/remove/cancel outcomes
- Dynamic Type, semantic dynamic colors, dark mode, Reduce Motion, Reduce Transparency-friendly opaque surfaces, EN/RU localization
- VoiceOver labels, message custom actions, modal persistent picker, 48 pt controls, escape dismissal, result announcements, and focus restoration
- interruption handling for backgrounding, rotation, gesture cancellation, and scroll restoration

## Known limitations and evidence gaps

- No physical-device check was available. Haptic feel, the 44/32 pt thumb thresholds, spring feel, and frame pacing remain unverified on hardware.
- No simulator runtime was available, so visual recordings, executed XCTest results, VoiceOver checks, AX5 layout inspection, landscape/small-window inspection, and measured frame pacing were not produced. These are not reported as passed.
- The compact fallback uses a single-column panel rather than the optional two-column arrangement. All controls remain at least 48 pt.
- Keyboard focus uses UIKit accessibility/button behavior; custom arrow-key traversal and an explicit Tab focus trap are not implemented.
- The demo draws configured debug hit zones but does not print the full textual placement diagnostics described in the shared design.
- Contrast-motivated substitutions from the draft palette: dark secondary text is `#AEB8C3` (instead of `#8E99A6`), light secondary text is `#56616D` (instead of `#6B7480`), and accent tones are strengthened. Composited contrast still needs instrumented visual verification.
- Reaction state is intentionally in memory and resets when the app process exits.
