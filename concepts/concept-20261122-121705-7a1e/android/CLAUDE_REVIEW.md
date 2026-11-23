# Claude Code Review

# Android review: Reaction Wheel (`concept-20261122-121705-7a1e`)

**Scope and evidence.** I reviewed `MainActivity.kt`, `ReactionModel.kt`, the unit test, the resources, the manifest and Gradle files, and the README against `UX_DESIGN.md` (rev 2) and `DESIGN_REVIEW.md`. I edited nothing and ran nothing.
- **Build and runtime:** I have no build, test, lint or runtime evidence of my own. The README's "BUILD SUCCESSFUL, 5 tests" is unverified by me.
- **Confirmed:** read directly from the code or resources.
- **Likely or guess:** inferred from Android framework behavior and not executed.
- **iOS:** the iOS code is not in this worktree. Cross-platform points rely on the documented contract only.

## Verdict
**Changes required.** There is one probable P0: the held gesture, which is the core feature, most likely crashes on first open. The README's own runtime evidence never exercised it. The only gesture check was an `adb input swipe`, which is not a hold.

---

## P0 blockers

**P0.1 Likely crash on the first held open, so the radial wheel never appears** (likely; the code path is certain, the crash is not executed)
- `MainActivity.kt:72` creates the overlay with `visibility = GONE`.
- `FrameLayout` does not measure or lay out `GONE` children, so `overlay.width` and `overlay.height` are 0 at the first open.
- `WheelOverlay.open` (`:192`) calls `place()` before it sets `visibility = VISIBLE`.
- In `place()` (`:193`), `margin..width-margin` is an empty range, so no candidate matches.
- The fallback `x.coerceIn(margin, width-margin)` has `max < min`. Kotlin throws `IllegalArgumentException: Cannot coerce value to an empty range`.
- The exception is thrown inside the 350 ms `Runnable` on the main thread, which crashes the app. `visibility` is never reached, so every open fails the same way.
- **Fix:** size from `root.width` and `root.height`, which are laid out, or use `INVISIBLE` instead of `GONE`, or set `VISIBLE` and use `post {}` before placing.
- **Fix:** replace `coerceIn` with `max(lo, min(hi, v))` so a window too small for the wheel can never throw.
- **Evidence needed:** an instrumented or manual 350 ms hold on the emulator. The README reports none.

---

## P1 bugs, logic, security and performance

1. **Stale-gesture commit during the dismiss fade** (confirmed by code)
   - After release, the overlay stays `VISIBLE` for 160 ms (`:199`).
   - A new touch in that window sees `overlay.visibility == VISIBLE` in `handleBubbleTouch` (`:145`, `:148`). Its MOVE goes to `overlay.track()` and its UP goes to `overlay.finish()`.
   - `finish()` calls `state.release()` against the old anchor and old centres, and can call `commit(oldMessage, i)`. A quick tap on a neighbouring bubble can therefore add a reaction to the previous message.
   - The new touch's 350 ms timer can also call `open()`. `open()` never cancels the running fade, so `end()` can hide the wheel mid-hold.
   - This violates §6.2, AC-18 and AC-33 (fast-forward, then treat as a fresh touch).
   - **Fix:** gate overlay routing on the gesture, for example `activeGesture == Held`, not on visibility. On DOWN, call `fastForwardDismiss()` (cancel the animator, run `end()`, reset state).

2. **Toggling "Dark appearance" wipes all state** (confirmed)
   - `AppCompatDelegate.setDefaultNightMode` (`:181`) recreates the Activity.
   - `messages`, `reduceMotionOverride`, `haptics` and `debug` are Activity fields (`:30-46`), so all reactions and every switch reset.
   - The settings `AlertDialog` is also leaked or killed.
   - Rotation, split-screen resize and font-scale changes cause the same reset, because there is no `configChanges` and no `onSaveInstanceState`.
   - **Fix:** move the state into a `ViewModel`, or `SavedStateHandle`, or declare `configChanges` and handle `onConfigurationChanged`.

3. **Placement diverges from §5.3** (confirmed)
   - The test is `s = 0` only, with a hard-coded 52 dp inset.
   - It ignores system bars, cutout, gesture insets, `uiScale`, the label, the `|s| ≤ 24` rule and the Compact fallback.
   - Left and right edge anchors, where x is below 52 dp or above `width-52`, match no axis. The code then clamps the centre and keeps the up axis, so items 0 and 1 land off-screen and cannot be selected. This is the independent-clamp failure that P0.5 asked to remove.
   - The `hold.anchorNearest ≥ 96` invariant is not enforced in the fallback.
   - A held gesture that does not fit never goes to Compact.
   - **Fix:** extract `Placement.compute(bounds, insets, uiScale, anchor, mode)` as a pure function, implement the shift `s` and the single fit test, and add the JSON fixtures from §13.

4. **Arc index order does not follow §2.1** (confirmed from `itemCenters`, `:194`)
   - The code always uses `φ = -90 + 36i` with σ = +1, which is the clockwise mapping the revision rejected.
   - Down axis: index 0 is on the right, where the spec says left.
   - Left axis: index 0 is at the bottom, where the spec says the index increases downward.
   - Diagonals run toward −x, where the spec says +x.
   - RTL is not mirrored.
   - **Fix:** apply σ per axis and RTL, then assert the angles in fixtures.

5. **Second-finger handling breaks AC-11** (likely)
   - `event.rawX` and `rawY` read pointer index 0.
   - There is no `ACTION_POINTER_UP` case and no pointer-id tracking. If finger 1 lifts while finger 2 is down, tracking jumps to finger 2, and the final `ACTION_UP` can commit from finger 2's position.
   - The spec says the first finger lifting is the release.
   - **Fix:** store `pointerId`, use `findPointerIndex`, and treat `POINTER_UP` of that id as release.

6. **Release re-selects (`ReactionModel.kt:27`)**
   - `release()` calls `move()` again, so a UP coordinate that differs slightly from the last MOVE can newly capture an item.
   - The user never saw that item's tick or label, and it can commit.
   - §5.2 says commit only if the state was already `Selected(i)`.
   - **Fix:** evaluate the predicate on the pre-release `selected`.

7. **Picker dismiss clobbers announcements** (likely; the code is confirmed, the timing is inferred)
   - The dismiss listener (`:165`) announces the full message description on every dismiss, including Close and Back.
   - That breaks "cancel is silent" (AC-25). On commit, it can interrupt "Reacted with Like", because `Dialog.dismiss` posts the listener after `commit()` runs.
   - **Fix:** announce only on commit, and only restore focus on cancel.
   - `announceForAccessibility` is also deprecated at API 36 (the `targetSdk`).

8. **Missing system-bar and edge-to-edge handling in dark mode** (confirmed in resources, rendering not seen)
   - `windowLightStatusBar=true` is set unconditionally in `values/styles.xml`, and there is no night override.
   - Status icons are dark on `#0F1419`.
   - `statusBarColor` and `navigationBarColor` are ignored once edge-to-edge is enforced at targetSdk 35+.
   - **Fix:** use `WindowInsetsControllerCompat.isAppearanceLightStatusBars = !isNight()`, or add a `values-night` style.

9. **Hard-coded English strings violate §10.6 localization** (confirmed)
   - `"Remove X"` is used as a wheel label.
   - These are also hard-coded: `"Reacted with"`, `"Reaction changed to"`, `"Reaction removed"`, `"Your reaction:"`, `"No reaction"`, `"message"`, `"N of 6"`, `"Remove X reaction"`, and the reset dialog text `"Reset all mock reactions?"`.
   - The README admits only the announcements. The visible wheel label and the dialog are also English-only.
   - The reset text differs from the spec's "Remove all demo reactions?".
   - **Fix:** move them to `strings.xml` and `values-ru`, using the spec's «Убрать 👍» wording.

10. **Draw-path cost** (likely, no profiling)
    - Every `onDraw` calls `reducedMotion()`, which reads `Settings.Global`, once per item plus once for the label.
    - It also calls `getColor`, `getString`, `Locale.getDefault()`, `measureText` and builds string templates.
    - §8 and AC-17 say no per-move work beyond transforms.
    - **Fix:** cache the values at open.

11. **Privacy and hygiene in a public repo**
    - README lines 33 and 43 embed `/Users/vsdsgn/Library/Android/sdk`, which discloses a local username.
    - **Fix:** use `$ANDROID_HOME` or `~`.

---

## UX fidelity (confirmed unless noted)

| Spec | Android |
|---|---|
| Scrim 180 ms, cascade (30 ms stagger, `spring.entry`) | The wheel pops in instantly (`alpha = 1`). Only Reduced Motion fades in. The README discloses the missing cascade. |
| Selected 1.4× with `spring.select`, others 0.9× plus 10 dp tangential push | The scale is set instantly. There is no spring and no push, and the README does not disclose this. |
| Lifted message above the scrim | The overlay draws a scrim over everything, including the pressed bubble. |
| `Outside` dims to 0.6, label undimmed | There is no dim. |
| Selection disc and 2 dp ring, current-reaction ring, "−" badge | There is no ring anywhere. The disc `chip_mine` on a white plate is about 1.4:1 (my calculation). In dark mode it is about 2:1. Under Reduced Motion the scale is off, so the selection is nearly invisible. The "−" is plain text, not a 16 dp badge. |
| Label slot on the arc axis at `R+56`, measured, ≤2 lines, within the safe rect | Fixed at `cy + 54 dp`, not measured, not clamped horizontally, in `dp` (not `sp`) so it ignores font scale. For right and left axes and for longer RU strings it probably overlaps items 3 and 4. That is arithmetic from the geometry, not observed. |
| `uiScale` (≤1.3) for R, item size and inset | Not implemented. R, item size and inset are fixed dp. |
| Commit fly-to-chip, chip pop-in, replace crossfade, removal shrink, row animation | None. The chip is destroyed and recreated in `refresh()`. |
| Chip 28 dp visual with 48 dp hit area, mine border, pressed state | The chip is a 48 dp tall visual with a 14 dp corner radius. It has no border and no pressed feedback. Its label is "Remove X reaction", not "Your reaction: X". |
| Bubble max width 78% of the list | Every bubble is fixed at 78% of the screen width (`:116`), so the emoji-only and short bubbles are not varied. |
| Settings: modal bottom sheet, Theme System/Light/Dark, Reduce motion Follow/Always, About text | A framework `AlertDialog` with a binary dark switch, no System option, and no About or "Not affiliated" text. |
| Debug overlay: 12, 44, 32, 80, 96 rings, axis, state | Only the 44 and 32 rings. |
| System gesture exclusion rects | Not set. |

## Animation and accessibility

- **Good:**
  - The picker is a `Dialog` with a pane title, so it is a separate modal window. Focus lands on item 0, in order 0…5 and then Close.
  - Item labels read "Name, n of 6".
  - Reduced Motion drops scale and adds a fade, haptics remain, and the 85 ms tick limit is in place.
  - The RU reaction names match the table.
- **Persistent form:** the Persistent picker is always the Compact list. That is a documented deviation from §10.3's radial Persistent form. It needs to match iOS, which I cannot check here.
- **Pinned controls:** title and Close scroll with the content. §5.3.2 says they stay pinned.
- **Current-reaction cue in the picker:** it is exposed only in `contentDescription`. There is no visual ring, which breaks colour independence.
- **Custom action IDs:** `0x01020001/2` (`:105`, `:106`) sit in the framework `android.R.id` range. Use `ViewCompat.addAccessibilityAction` (likely, not verified on TalkBack).
- **Cancel animation under Reduced Motion:** it is instant (`alpha = 0; end()`), but §8.5 says a 100 ms fade.
- **Reduced Motion timing:** it is re-read during the gesture. The spec says it applies from the next open.
- **Focus and haptics:**
  - Hardware-keyboard focus visibility is unverified.
  - On API 26–33 the tick is `CLOCK_TICK` and the commit is `VIRTUAL_KEY`. §9 specifies `KEYBOARD_TAP` below API 30.

## Discrepancies with the documented iOS and shared behavior

- **Arc mapping and RTL:** Android's mapping is the rejected clockwise one (P1 #4). If iOS follows §2.1, the same gesture selects different reactions on the same edge. This is a user-visible cross-platform divergence.
- **Gesture arbitration:** the Android mechanism (a touch listener on the bubble, then a `ScrollView` intercept after touch slop) matches §11.1. The README says it records the platform slop, but it does not print the value. `scroll.isEnabled = false` does nothing, because `ScrollView` ignores it. Only `requestDisallowInterceptTouchEvent` locks scrolling. `end()` calls it on `root`, not the parent chain, so it is unreliable. The flag does reset on the next DOWN.
- **Tests and fixtures:** the JSON geometry fixtures, the placement tests and the arbitration tests are absent (AC-12, AC-13, AC-31, AC-33). Placement is not testable as written, because it lives in the `View`.
- **Test identifiers:** `resources.getIdentifier("chat_message_$i" | "compact_item_$i")` returns 0, because `ids.xml` declares only `chat_list`, `chat_hint` and `settings_open`. So 12 messages and 6 picker buttons get `id = 0`. The §13 identifiers `wheel.*`, `compact.*` and `settings.*` don't exist.
- **Unit test coverage:** the 5 tests cover drift, capture, dead-zone return, outside, and cancel. They miss the remove path, the switch margin, hysteresis, release without movement and the second pointer. The tests use dp-space synthetic centres, which is fine.

## Build and evidence gaps (not invented)

- The README reports `testDebugUnitTest assembleDebug` as successful and 5 tests passing. I did not rerun them.
- `kotlinOptions {}` with Kotlin 2.2.21 is a possible build or deprecation concern. I did not check it.
- Lint did not complete, so there is no lint result.
- There is no evidence of a held-gesture run. The README says gesture completion is not claimed, and it names the reference profile as a large-font emulator, not the Pixel 8 API 34 plus min-API AVDs in §14.
- There is no dark-mode screenshot, TalkBack, keyboard, rotation, split-screen, frame-pacing or physical-device evidence.
- Haptics are not logged, so AC-19 and AC-20 are unproven.

## Recommended remediation order for Codex

1. Fix P0.1, then run a real 350 ms hold on the emulator.
2. Fix the stale-gesture routing and the fast-forward (P1 #1).
3. Add state persistence (P1 #2).
4. Extract the pure placement function with fixtures, σ and RTL, and the Compact fallback (P1 #3, #4).
5. Add pointer-id tracking (P1 #5) and fix the release rule (P1 #6).
6. Add the selection ring and badge, the Outside dim, springs, and a measured label slot.
7. Move strings to resources, fix the dark status bar and the test IDs, and remove the local path from the README.

