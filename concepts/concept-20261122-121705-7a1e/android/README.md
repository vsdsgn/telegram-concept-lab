# Reaction Wheel — Android demo

A native Kotlin/Android Views prototype of the shared Reaction Wheel interaction. All conversation content is invented mock data and is visibly labelled **“Demo data — not connected to Telegram.”** There is no network or Telegram backend integration, bundled brand asset, analytics, or persistence.

## Build and run

Requirements: JDK 17 and Android SDK 36. From this directory:

```sh
ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew testDebugUnitTest assembleDebug
ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew installDebug
adb shell am start -n dev.telegramconceptlab.reactionwheel/.MainActivity
```

The APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

## Demo

1. Hold any message bubble for 350 ms without scrolling.
2. Keep the pointer down, slide at least 44 dp toward a reaction, and release over it.
3. Release near the original touch or outside the wheel to cancel.
4. Choose the current reaction again, or tap its chip, to remove it.
5. With TalkBack or a keyboard, focus a message and activate **React…** to use the persistent button picker. Back, Escape, the close button, or outside dismissal cancels.
6. Demo settings switches dark mode, a Reduced Motion override, haptics, and geometry diagnostics. Reset reactions requires confirmation.

The effective pre-open movement tolerance is Android's `ViewConfiguration.scaledTouchSlop`; the tested emulator reported the platform value rather than overriding it with a fixed 8 dp. The radial state machine uses `commit.enter = 44 dp`, `commit.exit = 32 dp`, capture enter/stay of 80/96 dp, an 8 dp switch margin, and an 85 ms haptic tick interval.

## Verification performed (2026-11-22)

Reference runtime: connected Android emulator `emulator-5554`, API 36, 432 × 2160 px, large system font scale.

```sh
ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew testDebugUnitTest assembleDebug --offline
```

Result after the independent-review fixes: **BUILD SUCCESSFUL**; 12 tests, 0 failures, 0 skipped. The state tests additionally prove that release cannot create a previously invisible selection and that release outside a visible selection cancels. Pure placement tests cover mid-screen/up, left-edge/right with whole-wheel translation, down-axis ordering, RTL mirroring, and 240 dp Compact fallback.

Runtime result after the fixes: `adb install -r app/build/outputs/apk/debug/app-debug.apk` succeeded; a cold launch returned `Status: ok`. A stationary 600 ms `adb shell input swipe` exercised the first held-open path that previously used zero-sized overlay bounds. `MainActivity` remained `topResumedActivity`, and the filtered recent `AndroidRuntime` fatal log was empty. This proves the first hold no longer crashes; reaction selection is **not** claimed from that stationary synthetic gesture.

Lint command attempted:

```sh
ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew lintDebug --offline
```

Result: **not run to completion** because the Gradle cache did not contain Android lint 31.11.1 artifacts and offline mode prevented download. This is an environment limitation, not a passing lint result.

Evidence obtained: automated unit/build (A) and emulator launch/visual inspection (E). Physical-device evidence (P), haptic feel, TalkBack traversal, hardware keyboard traversal, dark-mode screenshot, frame pacing, rotation/split-screen/foldable behavior, and a screen recording were not run.

## Accessibility and motion

- Message bubbles are focusable nodes with `React…` and conditional `Remove reaction` accessibility actions.
- The conformance route is a modal, scrollable picker of six real Android buttons in semantic order, followed by Close; controls are at least 48 dp.
- Reaction names are explicit English/Russian strings rather than platform emoji pronunciation. Results announce add, replace, and removal, then restore focus to the message.
- Text follows system font scale. At the tested large font scale the banner, hint, messages, and controls remained readable; the picker scrolls if it exceeds the window.
- Reduced Motion follows system animator scale zero or the demo override. It removes travel/scaling and retains a short fade, ring/disc, label, badge, and haptics.
- Light/dark semantic colors are separate. Primary text pairs exceed 4.5:1 by token calculation. Secondary text was strengthened from the original unverified `#6B7480/#8E99A6` to `#59636F` (light) and `#AAB4BF` (dark) for readable small banner/time text. Full composited contrast and high-contrast-mode measurement remain unverified.

## Known limitations

- Placement now uses window/system/cutout/gesture insets, `uiScale`, whole-wheel translation, the 96 dp held-anchor invariant, specified axis preference, LTR/RTL index ordering, and Compact fallback. The complete shared JSON fixture suite and label/close collision fit tests remain unimplemented; the current label is clamped rather than participating in placement.
- Radial item entry is drawn immediately rather than the specified per-item spring cascade. Selection scale, cancellation fade, rate-limited haptics, Reduced Motion, and add/replace/remove state semantics are implemented. Frame pacing is unmeasured.
- English and Russian result, removal, message-description, and reset-confirmation strings are localized.
- Activity recreation preserves reactions and demo switches. Process-death persistence remains intentionally out of scope for mock data.
- The lifted-message layer, tangential selection push, fly-to-chip/row animations, full settings bottom-sheet/segmented controls, pinned Compact header, and gesture-exclusion rectangles remain design-fidelity gaps. They were not P0/P1 correctness blockers in the independent review remediation order.
- In-memory reactions reset on process death. This is intentional mock behavior.
- Physical-device tuning of the 44/32 dp thresholds and OEM haptic behavior is still required.
