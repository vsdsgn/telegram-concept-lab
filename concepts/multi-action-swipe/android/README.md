# multi-action-swipe — Android (Kotlin, Views)

Standalone native Android demo of a **multi-action swipe on chat-list rows**: spring physics, haptics, configurable actions, undo, accessibility alternatives.

> **All data is MOCK.** The 24 chats are fictional (`ChatStore.kt`), the app is not connected to Telegram, uses no Telegram code, APIs, assets or trademarks, and "open chat" is a stub toast.

Why plain Views (not Compose): Telegram for Android is a View/Canvas-based codebase, so the row is a single custom `View` that draws on a Canvas and is animated with `androidx.dynamicanimation` springs. Dependencies: `core-ktx`, `recyclerview`, `dynamicanimation` only.

## Build & run

Requirements: Android SDK (platform 36), a **JDK 17** (Gradle 8.14 does not run on JDK 25), an emulator or device (minSdk 26).

```bash
cd concepts/multi-action-swipe/android
export JAVA_HOME=/path/to/jdk17            # e.g. a Temurin 17
export ANDROID_HOME=$HOME/Library/Android/sdk
echo "sdk.dir=$ANDROID_HOME" > local.properties   # git-ignored
./gradlew assembleDebug testDebugUnitTest          # builds the APK + runs JVM tests
./gradlew installDebug                             # with an emulator/device attached
adb shell am start -n lab.telegramconcept.multiswipe/.MainActivity
```
APK: `app/build/outputs/apk/debug/app-debug.apk`. Android Studio can open this folder directly.

## What to try (demo script)

1. **Swipe left** on a row: Delete / Mute / Archive appear and share the revealed width. Release past ~50% of their width → row springs open; tap a button.
2. **Keep going left** past ~70% of the screen: the primary action (Archive, outermost) expands to fill the row, with a threshold haptic; release → row flies off and the chat is archived; an **Undo** bar appears.
3. **Swipe right**: Read/Unread and Pin. Full swipe = Read/Unread (row springs back, badge changes).
4. **Delete** is two-step: first tap turns the button dark red ("Confirm?"), second tap deletes (mock) with Undo. Delete is never a full-swipe action.
5. Change your mind mid-gesture: drag back below the threshold (haptic + primary shrinks back), lift early (springs closed), or **catch a row while it is still moving**.
6. **Long-press** a row: menu with every enabled action (non-gesture alternative).
7. Tune icon (top right) → **Swipe settings**: tick up to 3 actions per side, reorder with ↑/↓ (first = primary/outer), toggle haptics, restore mock chats.

## Gesture states

`IDLE → PRESSED → DRAGGING → SETTLING → IDLE | OPEN` (all in `ChatRowView.kt`; pure maths in `SwipeLogic.kt`).

| Phase | Behaviour |
|---|---|
| Touch-down | Row highlighted; long-press timer starts. If the row is still springing, it is caught (spring cancelled, `GESTURE_START` haptic) and dragging continues from where it is. Any other open row closes. |
| Drag start | Horizontal movement > touch slop and > vertical movement; parent `RecyclerView` is told not to intercept. Vertical-first movement is left to the list. |
| Dragging | Row follows the finger 1:1 while it reveals actions; rubber-bands (diminishing returns) where a side has no actions or past the screen limit. Revealed buttons share the width (iOS-like). |
| Threshold 1 – "will open" (50% of button width) | Light tick. Crossing back ticks again (hysteresis 10 dp, no chatter). |
| Threshold 2 – "will commit" (max(buttons+56 dp, 62% width), ≤ 80%) | Stronger threshold haptic (API 34 `GESTURE_THRESHOLD_ACTIVATE`, `VIRTUAL_KEY` below), primary button springs to fill the row, its icon scales up. Only if the primary action is non-destructive. |
| Release | `SwipeLogic.decide`: beyond threshold 2 → **commit**; fast fling forward → open (or commit if very fast); fast fling back → close; otherwise nearest of open/closed. |
| Commit | `CONFIRM` haptic. Removing actions (archive/delete): row springs off-screen, then the action runs (touching during the slide **cancels** it). Toggle actions (pin/read/mute): action runs, row springs back. |
| Cancel / interrupt | `ACTION_CANCEL` (list scrolls, system takes over) returns the row to its previous rest state. Scrolling the list closes an open row; opening another row closes the previous one. |
| Springs | Open: stiffness 520 / damping 0.72 (slight overshoot). Close: 650 / 0.9, clamped at 0 so it never swings into the opposite side's actions. Commit slide-off: 700 / 1.0. Expand pop: 700 / 0.6. Release velocity feeds the spring. |

## Accessibility & settings

- Each row exposes **TalkBack custom actions** for every enabled action (labels follow state: Pin/Unpin, Read/Unread, Mute/Unmute), plus a spoken summary (name, preview, time, unread, pinned, muted). Double-tap opens the chat (stub) or closes an open row.
- Long-press menu is a non-gesture path for everyone.
- **Reduce motion**: when the system animator duration scale is 0 ("Remove animations"), springs are skipped and the row snaps.
- Text sizes are in `sp`; row height and button width grow with font scale; labels in buttons are hidden if they would not fit (the icon stays).
- Light/dark colour resources (`values` / `values-night`). Touch targets ≥ 48 dp. Undo bar is a polite live region.
- Haptics respect both the in-app switch and the system "touch feedback" setting.

## Verification (what was actually run)

Machine: macOS, Android SDK platform 36 / build-tools 36.1, JDK 17.0.20 (Temurin, from the Gradle JDK cache), Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20.

| Command | Result |
|---|---|
| `./gradlew assembleDebug testDebugUnitTest` | **BUILD SUCCESSFUL**; 6/6 unit tests pass (`SwipeLogicTest`: rubber band, resistance, release decisions, hysteresis, thresholds) |
| `./gradlew installDebug` + launch on an arm64 emulator (Android 16, API 36.1, Google APIs, 1080×2400) | Installs and runs, no crash in logcat |

Exercised on the emulator with `adb shell input` (screenshots in `docs/`):
- trailing and leading reveal in dark mode (`docs/01-…`, `docs/02-…`), and light mode during development;
- full swipe → archive → Undo bar (`docs/03-…`);
- two-step Delete arming ("Confirm?"), long-press actions menu, tap-to-open stub.

**Not verified:** haptics (emulators don't vibrate — feel on a real device), TalkBack, "Remove animations", large font scale, Settings screen beyond a successful build, RTL, tablets/landscape, 60 fps measurement (the software-rendered emulator is not representative). Spring timing/feel was judged only from static screenshots.

A bug found during emulator testing and fixed: a fast fling could be decided on a stale offset because batched `MOVE` events were not yet applied at `ACTION_UP`; `ChatRowView` now applies the final position before deciding.

### Recording a short demo
```bash
adb shell screenrecord --time-limit 30 /sdcard/demo.mp4   # perform the demo script, then:
adb pull /sdcard/demo.mp4
```
(`adb shell input swipe x1 y1 x2 y2 700` drives a swipe; keep duration ≥ 500 ms for a stable result on slow emulators.) No video is committed.

## Known limitations

- Not integrated into Telegram; no real chat data, no folders, no conversation screen. State is in memory and resets when the process dies; settings persist in local SharedPreferences.
- Starting a right swipe at the very left screen edge may trigger the system back gesture (no gesture-exclusion rects set).
- Icons are simple vector drawables made for this demo (the pin/check/tune glyphs follow common Material shapes); the app has no custom launcher icon.
- Archive/Delete only hide the row (Undo restores it); nothing is persisted.
- Delete button label `Confirm?` and other strings are English only.
- On a loaded emulator the first launch can show a "System UI isn't responding" dialog unrelated to the app.

## Layout
```
app/src/main/java/lab/telegramconcept/multiswipe/
  ChatRowView.kt     custom View: drawing, touch state machine, springs, a11y
  SwipeLogic.kt      pure gesture maths (unit-tested)
  SwipeAction.kt     action pool (pin/read/mute/archive/delete) and their rules
  SwipeConfig.kt     user-configurable sides/order/limit, persisted
  Haptics.kt         haptic constants per event
  ChatStore.kt       in-memory store + MOCK data
  MainActivity.kt / ChatAdapter.kt / SettingsActivity.kt
```
