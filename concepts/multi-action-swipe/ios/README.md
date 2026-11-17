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

1. Swipe any chat slowly to the right. Each of the three action slots is revealed progressively and produces a selection haptic at its threshold.
2. Release past the first threshold to spring the row open; release before it to cancel and spring closed.
3. Tap an action. Read, Pin, Mute, and Favorite update the mock row. Archive removes it with Undo. Delete requires confirmation and then also offers Undo.
4. Swipe left to exercise the independent trailing action set.
5. Tap **Customize** to change any of the three actions on either side, then Save. The configuration is persisted locally with `UserDefaults`.
6. While a row is animating, grab it again to verify the animation is interrupted cleanly.

For VoiceOver, focus a chat row and use the Actions rotor to invoke the same commands without dragging.

## Gesture state contract

- **Touch down:** prepares the light impact generator and applies the native row highlight.
- **Dragging:** begins only for a primarily horizontal pan; the foreground follows the finger using a transform, with rubber-band resistance after the last slot.
- **Threshold crossing:** each newly revealed 76pt action slot triggers selection feedback and receives a small scale emphasis.
- **Completion:** releasing beyond 55% of the first slot, or with sufficient projected velocity, opens all three actions and gives a light impact.
- **Cancellation:** release before the threshold, gesture cancellation, vertical intent, or list scrolling returns the row to idle.
- **Interruption:** a new drag stops the in-flight property animator at its current presentation state and continues from the current offset.
- **Action:** actions provide success/warning haptics. Destructive deletion always requires confirmation and supports Undo.

## Accessibility and adaptation

- Dynamic Type on all user-facing text
- VoiceOver labels, hints, native button semantics, and custom row actions
- A non-gesture alternative for every swipe action through the VoiceOver Actions rotor
- 44pt-or-larger interactive controls
- Semantic system colors for light and dark mode
- Reduce Motion replaces spring/translation choreography with short settling transitions
- Safe-area-aware layout on iPhone and iPad, including landscape

## Architecture

- `ChatListViewController`: mock inbox, action handling, confirmation, and Undo toast
- `SwipeActionCell`: gesture state machine, transform-only tracking, interruptible spring, haptics, and accessible actions
- `ActionConfigurationViewController`: native menus for three leading and three trailing slots
- `Models`: mock rows, action semantics, and local configuration persistence

## Known limitations

- This is an interaction prototype; opening a chat shows a demo-only message.
- Haptic feedback is not physically reproduced by the iOS Simulator; test on a device to feel it.
- Mock chat edits reset at app launch. Action configuration persists locally.
- The project intentionally uses generated launch metadata and no app icon artwork.

## Screenshot / recording

In Simulator, use **File → Record Screen** (or `xcrun simctl io booted recordVideo demo.mov`). Record one slow swipe in each direction, one configuration change, and the Delete confirmation/Undo path. Keep the visible “MOCK DATA” label in frame.

## Verification

Verified on 2026-11-17 with Xcode 27.1 (build 27A9275):

- `plutil -lint concepts/multi-action-swipe/ios/MultiActionSwipe.xcodeproj/project.pbxproj` → `OK`
- The exact `xcodebuild` command in **Build** → `** BUILD SUCCEEDED **` (arm64 and x86_64 Simulator slices)
- Installed and launched with `xcrun simctl` on an iPhone 17 Pro simulator running iOS 26.1 → launch returned a live process identifier
- Captured and visually inspected temporary screenshots in both light and dark appearances; the mock-data label, chat list, semantic colors, and safe-area layout rendered correctly

The sandboxed build emitted host-environment warnings when it could not connect to CoreSimulatorService, but compilation and linking succeeded. Runtime verification was then performed with direct simulator access. No source or linker warnings were reported by the app target.
