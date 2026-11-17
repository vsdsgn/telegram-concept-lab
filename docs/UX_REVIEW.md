# Multi-Action Swipe — UX review and v2 acceptance criteria

## Evidence and scope
- Reviewed screenshots of both running standalone demos on 2026-11-17.
- iOS: oversized Chats header, hidden actions, only Settings button. No preview/tap-to-try, so the interaction is confusing without touch gestures.
- Android: compact header, but different chat fixtures, action semantics and emphasis. Text says how to swipe without showing what happens.
- Screenshots do not prove spring timing, haptics, 60fps, accessibility, or behavioral parity.

## P0: self-demonstrating prototype
1. Add a compact dismissible first-run coach mark near the first chat row: "Swipe left for actions" and show a graphical preview of the action tray.
2. Add a visible "Try demo" button that programmatically opens and then closes the first row without executing any action. Works with a mouse click.
3. Add persistent Help/Replay Demo control and keep Settings visible.
4. Give each row a discoverable context-menu or equivalent alternative to dragging. Do not trigger destructive actions from tutorial.

## P0: parity contract
- Same seeded mock chats in same order on both platforms: Maya Chen, Product Sync, Weekend Plans, Design Critique, Ava Thompson, Build Alerts. Same state.
- Swipe left: Archive, Mute, Delete. Swipe right: Read/Unread, Pin/Unpin, Favorite.
- Short swipe closes; release past threshold opens 3 actions. Opposite swipe closes/switches side.
- Full swipe commits only Archive (left) or Read/Unread (right); Archive supports Undo. Delete always needs two-step confirmation and Undo.
- Interrupted gestures/cancel and Reduce Motion; threshold implementation can be native but behavior equivalent.
- Settings reorder up to 3 actions on each side; save locally.
- Provide equivalent light/dark, labels, and accessible alternatives. Visible "MOCK DATA — not connected to Telegram" without dominating the UI.

## P1: visual quality
- Replace iOS giant navigation header with compact, native-feeling header. Android and iOS row density and typography should be comparable, not identical.
- No Telegram logos or reuse of restricted branding.
- Show immediate feedback for actions and visible Undo.
- Capture screenshot with an OPEN swipe tray on both platforms.

## Acceptance
- iOS xcodebuild successful; Android Gradle assembleDebug and unit tests successful.
- Install/launch both apps and use Try demo without a touch gesture.
- Capture open-tray screenshots and report precise commands and test evidence.
- Commit on existing feature branches, update draft PRs #2 and #3. No auto merge or store publishing.
- Clearly list unverified items.
