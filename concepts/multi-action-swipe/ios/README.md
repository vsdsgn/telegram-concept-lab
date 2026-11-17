# Multi-Action Swipe — iOS

A standalone UIKit interaction concept for configurable chat-row swipe actions. The app uses only local, explicitly labeled mock data and does not connect to Telegram or any backend.

## Requirements

- macOS with Xcode 16 or newer
- An iOS 16+ Simulator runtime

No external packages or paid tools are required.

## Build

From the repository root:

```bash
xcodebuild \
  -project concepts/multi-action-swipe/ios/MultiActionSwipe.xcodeproj \
  -scheme MultiActionSwipe \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath concepts/multi-action-swipe/ios/.derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Or open `MultiActionSwipe.xcodeproj`, choose any iOS Simulator, and press Run.

## Demo script

1. Tap **Try Demo** in the first-run coach mark. The first row opens its real Archive / Mute / Delete tray, performs no action, and closes after four seconds.
2. Dismiss the coach mark, then tap **Replay Demo** in the navigation bar to restore the hint and replay the same safe demonstration.
3. Swipe any chat slowly to the right. Each of the three action slots is revealed progressively and produces a selection haptic at its threshold.
4. Release past the first threshold to spring the row open; release before it to cancel and spring closed. A full swipe commits only Read/Unread on the right or Archive on the left.
5. Tap an action. Read/Unread, Pin/Unpin, Mute/Unmute, and Favorite update the mock row. Archive removes it with Undo. Delete requires confirmation and then also offers Undo.
6. Long-press a row to use the native context-menu alternative without dragging.
7. Tap **Settings** to reorder the three parity actions on either side, then Save. The order is persisted locally with `UserDefaults`.
8. While a row is animating, grab it again to verify the animation is interrupted cleanly.

For VoiceOver, focus a chat row and use the Actions rotor to invoke the same commands without dragging.

## Gesture state contract

- **Touch down:** prepares the light impact generator and applies the native row highlight.
- **Dragging:** begins only for a primarily horizontal pan; the foreground follows the finger using a transform, with rubber-band resistance after the last slot.
- **Threshold crossing:** each newly revealed 76pt action slot triggers selection feedback and receives a small scale emphasis.
- **Completion:** releasing beyond 55% of the first slot, or with sufficient projected velocity, opens all three actions and gives a light impact.
- **Full swipe:** crossing the full-swipe projection commits only Read/Unread from the leading side or Archive from the trailing side.
- **Cancellation:** release before the threshold, gesture cancellation, vertical intent, or list scrolling returns the row to idle.
- **Interruption:** a new drag stops the in-flight property animator at its current presentation state and continues from the current offset.
- **Action:** actions provide success/warning haptics. Destructive deletion always requires confirmation and supports Undo.

## Accessibility and adaptation

- Dynamic Type on all user-facing text
- VoiceOver labels, hints, native button semantics, and custom row actions
- A non-gesture alternative for every swipe action through the VoiceOver Actions rotor
- A visible Try Demo button, persistent Replay Demo control, and native row context menu provide single-pointer alternatives to dragging
- 44pt-or-larger interactive controls
- Semantic system colors for light and dark mode
- Reduce Motion replaces spring/translation choreography with short settling transitions
- Safe-area-aware layout on iPhone and iPad, including landscape

## Architecture

- `ChatListViewController`: mock inbox, action handling, confirmation, and Undo toast
- `SwipeActionCell`: gesture state machine, transform-only tracking, interruptible spring, haptics, and accessible actions
- `ActionConfigurationViewController`: native menus for reordering the three parity actions on each side
- `Models`: mock rows, action semantics, and local configuration persistence
- `MultiActionSwipeUITests`: launches the app, taps Try Demo, asserts the real tray, and records screenshot evidence

## Known limitations

- This is an interaction prototype; opening a chat shows a demo-only message.
- Haptic feedback is not physically reproduced by the iOS Simulator; test on a device to feel it.
- Mock chat edits reset at app launch. Action configuration persists locally.
- The project intentionally uses generated launch metadata and no app icon artwork.
- The prototype targets 60 fps with transform-only tracking, but no Instruments frame-time profile is included.

## Screenshot / recording

The checked-in screenshot [docs/try-demo-open-action-tray.png](docs/try-demo-open-action-tray.png) was captured by the UI test immediately after tapping **Try Demo**. It shows the real Archive / Mute / Delete tray open without an action being executed.

For a recording, use **File → Record Screen** (or `xcrun simctl io booted recordVideo demo.mov`). Record Try Demo, one slow swipe in each direction, one configuration change, and the Delete confirmation/Undo path. Keep the visible mock-data disclaimer in frame.

## Verification

Verified on 2026-11-17 with Xcode 27.1 (build 27A9275):

- `plutil -lint concepts/multi-action-swipe/ios/MultiActionSwipe.xcodeproj/project.pbxproj` → `OK`
- The exact `xcodebuild` command in **Build** → `** BUILD SUCCEEDED **` (arm64 and x86_64 Simulator slices)
- Installed and launched with `xcrun simctl` on an iPhone 16 Pro Max Simulator running iOS 18.3.1 → launch returned a live process identifier
- `xcodebuild -project concepts/multi-action-swipe/ios/MultiActionSwipe.xcodeproj -scheme MultiActionSwipe -configuration Debug -destination id=45CDBDC4-9BDD-4331-8CD2-43074D59B57A -derivedDataPath concepts/multi-action-swipe/ios/.derivedData -resultBundlePath /private/tmp/MultiActionSwipe-v2-final-ui-test.xcresult -only-testing:MultiActionSwipeUITests/MultiActionSwipeUITests/testTryDemoOpensRealActionTray test` → `** TEST SUCCEEDED **`
- The UI test launched the app, tapped Try Demo, asserted Archive / Mute / Delete existed as real buttons, and attached the checked-in 1320×2868 open-tray screenshot
- Visually inspected the first-run coach mark, compact header, six parity fixtures, persistent Replay Demo / Settings controls, and opened trailing tray in light appearance

Not verified in this v2 pass: physical-device haptics, Instruments-backed 60 fps measurement, dark appearance, largest Dynamic Type sizes, Reduce Motion behavior at runtime, every manual swipe/cancellation/full-swipe path, or Android runtime parity. The implementations for semantic dark colors, Dynamic Type, Reduce Motion, gesture cancellation/interruption, and parity fixtures were code-reviewed and compiled but those claims are not presented as runtime-tested.

The sandboxed build emitted host-environment warnings when it could not connect to CoreSimulatorService, so runtime verification was performed with direct Simulator access.
