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

0. **Try demo** (coach card on first run, then the persistent "Replay demo" button in the header): opens the first row's real action tray with no touch gesture — left tray, then right tray — and closes it. It never executes an action; touching the screen cancels it, and tapping a button of a demo-opened tray only closes it. The coach card ("Swipe left for actions", with a graphic of the tray) is dismissible; Settings stays visible.
1. **Swipe left** on a row: Archive / Mute / Delete appear (Archive outermost = primary) and share the revealed width. Release past ~50% of their width → row springs open; tap a button.
2. **Keep going left** past ~70% of the screen: Archive expands to fill the row, with a threshold haptic; release → row flies off and the chat is archived; an **Undo** bar appears.
3. **Swipe right**: Read/Unread, Pin/Unpin, Favorite. Full swipe = Read/Unread (row springs back, badge changes).
4. **Delete** is two-step: first tap turns the button dark red ("Confirm?"), second tap deletes (mock) with Undo. Delete is never a full-swipe action. From the long-press menu / TalkBack actions it asks for confirmation in a dialog.
5. Change your mind mid-gesture: drag back below the threshold, lift early (springs closed), or **catch a row while it is still moving**.
6. **Long-press** a row: menu with every enabled action (non-gesture alternative).
7. Tune icon → **Swipe settings**: tick up to 3 actions per side, reorder with ↑/↓, toggle haptics, restore mock chats.

## Shared fixtures (parity with iOS)

Same six mock chats in the same order: Maya Chen (pinned, 2 unread), Product Sync (muted, 3), Weekend Plans (8), Design Critique (favorite, 5), Ava Thompson (read), Build Alerts (muted, 12). Previews/times copied from the iOS fixtures where they exist (Product Sync's text and Build Alerts' "emulator" wording are Android-side choices; the shared state is not otherwise defined in the spec, so compare it with the iOS branch).

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

## Verification (what was actually run — UX v2, 2026-11-17)

Machine: macOS, JDK 17.0.20 (Gradle JDK cache), Gradle 8.14, Android SDK platform 36, arm64 emulator (Android 16, API 36, 1080×2400, already running as `emulator-5554`).

| Command | Result |
|---|---|
| `./gradlew assembleDebug testDebugUnitTest --offline` | succeeded; APK built; `SwipeLogicTest` 6 tests, 0 failures (read from the JUnit XML) |
| `adb install -r app-debug.apk`; `pm clear`; `am start -n lab.telegramconcept.multiswipe/.MainActivity` | installed and launched, no crash in logcat (`AndroidRuntime:E` empty) |
| `adb shell input tap` on **Try demo** (a tap, no swipe) | real tray opened; screenshots in `docs/` |

Screenshots (`docs/`): `v2-first-run-coach.png` (fresh install: compact header, mock label, coach card, six fixtures), `v2-try-demo-tray-trailing.png` (Delete / Mute / Archive tray open), `v2-try-demo-tray-leading.png` (Read / Unpin / Favorite tray open, row partly off-screen). Older v1 screenshots were removed because they showed the previous fixtures.

**Not verified:** swipe gesture parity on the v2 build was not re-run by `adb input swipe` (v1 gesture paths are unchanged but the row code gained Favorite, a star marker and the demo flag); full-swipe/Undo/two-step Delete were not re-exercised on v2; the delete confirmation dialog for the menu/TalkBack path was not opened; Settings screen with Favorite beyond a successful build; haptics, TalkBack, Reduce Motion, large font, RTL, landscape/tablet, 60 fps, dark mode of the new header and coach card (screenshots are light theme only); persistence of coach dismissal; behaviour parity with iOS was compared by reading its fixtures only, no iOS build was run. The emulator was very slow (first launch ~33 s), so demo timings (tray held ~3 s each) were tuned for that and are not representative.

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
- Tray order: Archive is outermost (primary) on the left swipe, so visually it reads Delete · Mute · Archive from the inside out. Delete button label `Confirm?` and other strings are English only.
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
