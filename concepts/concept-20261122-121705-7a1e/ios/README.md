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

Re-verified after the Claude review fixes on 2026-11-22 with Xcode 27.1 (build 27A9275): `** BUILD SUCCEEDED **`. The build produced `ReactionWheel.app` for arm64 and x86_64 iOS Simulator architectures. The generated Info.plist contains `UIApplicationSceneManifest`; app launch itself could not be exercised because CoreSimulatorService was unavailable. Xcode emitted deprecation warnings for two UIKit compatibility hooks plus the expected App Intents metadata and local CoreSimulator warnings.

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

Re-verified result: `** TEST BUILD SUCCEEDED **`. Eight geometry tests now cover the four 1.0× design fixtures, the 1.3× fixture, minimal translation, safe/unique targets, label-to-item clearance, RTL order mirroring, held-anchor invariant, and compact fallback.

To execute them on a machine with an available runtime:

```sh
xcodebuild \
  -project ReactionWheel.xcodeproj \
  -scheme ReactionWheel \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath /tmp/reaction-wheel-tests-derived \
  test
```

Test execution is not claimed: the command above was attempted, reported `Unable to discover any Simulator runtimes` / an invalid CoreSimulatorService connection, and was stopped after it could not resolve the destination. Automated evidence is therefore test compilation only, not a passing test run.

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
- six-item semicircle, deterministic minimal-shift placement with the design's ≤24 pt preference, measured label clearance, RTL mapping, scale-aware selected extents, and compact fallback
- 44 pt selection entry / 32 pt exit dead zone; 80 pt capture, 96 pt stay, and 8 pt switch hysteresis
- interruptible spring cascade, live scrubbing with explicit Armed-idle/Outside state, selection haptics limited to one per 85 ms, and add/replace/remove/cancel state outcomes
- Dynamic Type, semantic dynamic colors, dark mode, Reduce Motion, Reduce Transparency-friendly opaque surfaces, EN/RU localization
- localized VoiceOver labels, message custom actions, modal persistent picker, 48 pt controls (including an expanded chip target), escape dismissal, ordered result announcements, and focus restoration
- interruption handling for backgrounding, rotation, gesture cancellation, and scroll restoration

## Known limitations and evidence gaps

- No physical-device check was available. Haptic feel, the 44/32 pt thumb thresholds, spring feel, and frame pacing remain unverified on hardware.
- No simulator runtime was available, so visual recordings, executed XCTest results, VoiceOver checks, AX5 layout inspection, landscape/small-window inspection, and measured frame pacing were not produced. These are not reported as passed.
- The compact fallback remains a single-column, non-scrolling panel. It does show the current reaction and removal semantics, but the design's two-column layout and pinned-header scrolling behavior remain to be implemented and visually verified.
- Keyboard focus uses UIKit accessibility/button behavior; custom arrow-key traversal and an explicit Tab focus trap are not implemented.
- The detailed motion design is still incomplete: there is no tangential neighbour push, selected removal badge, fly-to-chip, chip shrink, or staggered cancel collapse. The wheel plate is a rounded polyline rather than a true circular arc. These are fidelity gaps, not claimed as complete.
- The lifted bubble now has the specified shadow, but the delayed 0.98 pre-open pressing state is not implemented.
- Gesture/state-machine and arbitration behavior (including second-finger rejection and scroll restoration) is fixed in code but still lacks executable unit/UI coverage because the simulator could not run.
- The demo draws configured debug hit zones but does not print the full textual placement diagnostics described in the shared design.
- Contrast-motivated substitutions from the draft palette: dark secondary text is `#AEB8C3` (instead of `#8E99A6`), light secondary text is `#56616D` (instead of `#6B7480`), and accent tones are strengthened. Composited contrast still needs instrumented visual verification.
- Reaction state is intentionally in memory and resets when the app process exits.
