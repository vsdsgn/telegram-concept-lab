# Reaction Wheel — UX & Interaction Design (iOS + Android)

Concept: `concept-20261122-121705-7a1e`
Stage: Design (Claude Code). Inputs: `AGENTS.md`, `DESIGN.md`, `SPEC.md`.
Status: design only. No application code. All data is public mock data. No Telegram trademarks or assets are used.

Conventions: **pt** (iOS) and **dp** (Android) are the same logical unit here. `ms` is milliseconds. `θ` is the clockwise angle from screen-up. Numbers in this document are the *design contract*. Values marked **(tunable)** may be adjusted by the implementer after on-device feel testing, but a change must be recorded in the README and applied to both platforms.

---

## 1. User problem

Choosing a reaction today is a two-step, low-expressiveness flow: long-press opens a strip or sheet, then the user lifts the finger and taps a second time. This causes three problems:

1. **Interruption.** Lift and re-tap breaks the "hold → choose → release" rhythm. The user can't scrub and explore.
2. **Low expressiveness.** A flat row gives no sense of choice. There is no preview, no tactile "detent" and no sense of the options being a physical place.
3. **Accidental commits.** The finger lands on the strip at the moment of tap, with no safe way to back out.

**Goal:** a one-gesture flow of press, hold, slide and release. A radial layout makes every option equidistant from the finger, so choosing is a *direction*, not a *target*. Cancelling is always possible (slide away or return to the centre, then release).

**Non-goals:** a custom emoji set, a "more reactions" picker, animated sticker reactions, sending to any backend, multi-reaction per user.

### Success criteria (user-level)
- A first-time user can select a reaction in one continuous gesture, unaided, in under 2 s after the wheel opens.
- Nobody commits a reaction by accident: releasing without sliding, or slipping away, never commits.
- The same flow is reachable with VoiceOver, TalkBack, Switch Control and a Reduced Motion setting.

---

## 2. Scope: demo app

A single-screen demo app on each platform. It is a chat-like list of public mock messages, plus a small settings sheet. It must be openly labelled as demo data.

### 2.1 Reaction set (fixed, 6)
Use system emoji fonts (Apple Color Emoji / Noto Color Emoji). Do not bundle emoji art.

| Index | Emoji | EN name (a11y) | RU name (a11y) |
|---|---|---|---|
| 0 | 👍 | Like | Нравится |
| 1 | ❤️ | Love | Люблю |
| 2 | 😂 | Laugh | Смешно |
| 3 | 😮 | Wow | Ого |
| 4 | 😢 | Sad | Грустно |
| 5 | 🔥 | Fire | Огонь |

Index order is the clockwise order along the arc (LTR). In RTL layouts, the index order is mirrored (index 0 at the clockwise end) so the first reaction sits on the reading-start side.

### 2.2 Mock messages (public, invented)
12+ messages, mixed incoming/outgoing, short and multi-line, one very long, one with only an emoji, one near full-width. Sender names are fictional (e.g. "Alex", "Sam", "Robin"). Texts are neutral (weekend plans, a recipe, release notes of an imaginary app). A persistent, non-dismissible banner reads: **"Demo data — not connected to Telegram"** (RU: «Демо-данные — без подключения к Telegram»).

---

## 3. User journey

| # | Step | User intent | System response |
|---|---|---|---|
| 1 | Open demo | See chat list | List with banner; messages at the bottom, scrolled to the latest. |
| 2 | Touch a message | Start a possible tap / scroll / long-press | Subtle pressed state after 100 ms (§6.1). |
| 3 | Hold still 350 ms | "Open reactions" | Haptic, scrim, wheel cascades in around the finger. |
| 4 | Slide toward an emoji | Explore | Nearest emoji grows, others retreat, a tick fires per change, label names it. |
| 5a | Release on emoji | Commit | Emoji flies to a chip under the message. |
| 5b | Release in the centre or outside the zone | Cancel | Wheel collapses, no change. |
| 5c | System interruption | — | Treated as cancel (§7). |
| 6 | Tap own chip | Remove reaction | Chip shrinks away. |
| 7 | Assistive tech | Do the same without a held gesture | Persistent wheel / custom actions (§10). |
| 8 | Settings | Test theme, reduced motion, haptics, debug | Settings sheet (§5.4). |

---

## 4. Wireframes (text)

### 4.1 Default: mid-screen, wheel opens upward

```
          [1.5x]                      Item label (fixed slot, §5.2)
     (3)         (4)                       "Wow"
  (2)                  (5)
 (1)                      (6)             <- 6 items on a 180° arc, R = 108
        ┌───────────┐
        │ message   │ ●  <- finger = anchor (touch-down point)
        └───────────┘
 scrim covers everything except the pressed message
```
(Numbering is illustrative; item 0 = leftmost, item 5 = rightmost for an upward arc.)

### 4.2 Near the left edge: wheel rotates to face right

```
|●  (0)
|     (1)
|        (2)
|        (3)
|     (4)
|   (5)
```

### 4.3 Near the top: wheel flips downward

```
 (0)                     (5)
     (1)             (4)
          (2)   (3)
                ●
```

---

## 5. Screens and states

### 5.1 Screen A — Chat demo (idle)

Layout (portrait, 390×844 reference):
- Top bar: 56 dp content + safe-area top. Title "Reaction Wheel", trailing "⚙" button (48×48 hit area).
- Banner: 28 dp high, secondary text 12 sp/pt, always visible below the bar.
- Message list: bubbles with 16 dp horizontal inset, 4 dp vertical gap within a sender group, 10 dp between groups. Max bubble width 78 % of the list width.
- Bubble: corner radius 18; padding 12 horizontal / 8 vertical; text 16 (system font, scales with Dynamic Type / font scale); time 11, secondary.
- Reaction chip row: under the bubble, 4 dp gap, chip height 28, corner radius 14, padding 8 horizontal; emoji 16 + count 13.

Message states:

| State | Visual |
|---|---|
| Idle | Normal. |
| Pressing (100–350 ms after touch-down) | Bubble scales to 0.98 over 120 ms, ease-out. |
| Lifted (wheel open) | Bubble sits above the scrim at scale 1.0, a soft shadow in light, a 1 dp 8 % white border in dark. |
| Reacted | Chip row shows the emoji + count 1 with the "mine" highlight (§5.5). |

### 5.2 Screen B — Wheel open (the core overlay)

Layers, bottom to top: list → scrim → lifted message → wheel plate → emoji items → label → (debug overlay if on).

**Tokens (all sizes pt/dp):**

| Token | Value | Notes |
|---|---|---|
| `wheel.radius` R | 108 | Multiplied by `uiScale` (below). |
| `wheel.arc` | 180° | 6 items, 36° apart: φ = −90, −54, −18, +18, +54, +90 from the arc axis. |
| `item.size` | 48 | Layout box, also the min hit/target size on both platforms. |
| `item.glyph` | 28 | Emoji font size inside the 48 box. |
| `item.selectedScale` | 1.40 | → 67 pt. Fits in the 66.7 chord between neighbours. |
| `item.idleScale` | 1.00 | |
| `item.retreatScale` | 0.90 | Applied to the non-selected items only while one is selected. |
| `item.retreatPush` | 10 | Tangential push away from the selected item. Falls off linearly to 0 at 2 steps away. |
| `plate.thickness` | 64 | Arc-shaped "track" behind items (stroke along the arc). Radius R, round caps. |
| `plate.cornerBlur` | none | Plain translucent fill on both platforms (no blur dependency, for parity). |
| `label.height` | 32 | Pill, text 13 semibold, 12 horizontal padding, max 2 lines at large font scale. |
| `label.slot` | arc axis, R + 56 from the arc centre | Fixed (does not follow the finger) to avoid jitter. Clamped to the safe rect. |
| `safe.margin` | 8 | Plus `item.selectedScale × item.size / 2 = 34`, so item centres stay ≥ 42 inside the safe rect. |
| `uiScale` | clamp(fontScale, 1.0, 1.3) | At large font scales, R and item.size grow, max 1.3×. |

**Hit-testing tokens:**

| Token | Value | Meaning |
|---|---|---|
| `arm.distance` | 12 | The finger must move ≥ 12 from the open anchor before any selection is allowed. Prevents tremor selects. |
| `capture.enter` | 80 | A new item is captured when the finger is within 80 of its *final* centre. |
| `capture.stay` | 96 | The selected item stays selected up to 96 (hysteresis). |
| `switch.margin` | 8 | To move selection A→B, the finger must be ≥ 8 closer to B than to A. |
| `hold.anchorNearest` | ≥ 96 | **Invariant:** the open anchor is at least 96 from every item centre. Prevents accidental select at open. |

Hit-testing uses the **final** (target) positions, never the animated ones, so a fast scrub during the cascade behaves identically on both platforms.

**Wheel states:**

| State | Trigger | Visuals | Label text (EN / RU) |
|---|---|---|---|
| `Opening` | 350 ms hold | Scrim fades in, items cascade (§8.1) | — |
| `Armed-idle` | Opened, no selection | All items 1.0; plate full opacity | "Slide to choose" / «Проведите, чтобы выбрать» |
| `Selected(i)` | Finger captured item `i` | Item i 1.4× and lifted by a 56 disc (selected fill); others 0.9× and pushed | Reaction name |
| `Outside` | Finger further than `capture.stay` from every item and past `arm.distance` | Wheel plate + items dim to 0.5 over 120 ms; the label shows cancel | "Release to cancel" / «Отпустите для отмены» |
| `Committing` | Release in `Selected(i)` | §8.3 | — |
| `Cancelling` | Release in `Armed-idle`/`Outside`, or interruption | §8.4 | — |
| `Persistent` | Opened via accessibility | §10 | "Choose a reaction" |

Returning to the centre after a selection (finger beyond `capture.stay` of the selected item and not near another item) clears the selection → `Outside` (if far) or `Armed-idle` (if near the anchor, within 40). No haptic on clearing.

**Current reaction marker.** If the message already has reaction X, item X shows a 2 dp accent ring and, when selected, the label reads "Remove 👍" / «Убрать 👍». Selecting X toggles it off; selecting a different Y replaces X (single reaction per user).

### 5.3 Placement and edge handling (all four edges, notch, gesture inset)

Anchor = touch-down point `A`. The wheel centre `C` is normally `A`. Arc axis direction `δ` is normally up (0°).

**Safe rect** = window bounds minus: system bars, display cutout / Dynamic Island, home indicator, **and** on Android horizontal system-gesture insets (≈ 24–32 dp). Then inset by `safe.margin + 34`. The window (not the screen) is used, so split view / multi-window / foldables work.

**Algorithm (deterministic; must match on both platforms):**

1. Candidate axes in preference order: up (0°), down (180°), right (90°), left (270°), down-right (135°), down-left (225°), up-right (45°), up-left (315°).
2. For each candidate, compute the minimal translation `s` of `C` (vector, 0 if none needed) so that all 6 item centres lie within the safe rect. Reject the candidate if `|s| > 120`, or if the invariant `hold.anchorNearest` fails with that `C`.
3. Accept the **first** candidate (in preference order) with `|s| ≤ 24`.
4. If none: choose the valid candidate with the smallest `|s|`.
5. If still none (pathological window < ~240 dp): clamp each item centre into the safe rect, and switch the hit-test to nearest-item only. Document as a known limitation.
6. `C = A + s`. The finger is not moved; only the wheel is. The pressed message stays in place.

Worked examples (390×844, safe top 59, safe bottom 34, R = 108; computed by hand, to be confirmed with the debug overlay):

| Case | Anchor A | Result | Item centres (x, y) |
|---|---|---|---|
| Mid-screen | (195, 500) | up, s = 0 | (87,500) (107.6,436.5) (161.6,397.3) (228.4,397.3) (282.4,436.5) (303,500) ¹ |
| Left edge | (20, 500) | right (90°), s = (22, 0) → C = (42, 500) | (42,392) (105.5,412.6) (144.7,466.6) (144.7,533.4) (105.5,587.4) (42,608) |
| Top centre | (195, 110) | down (180°), s = 0 | ends at y = 110, middle items at y ≈ 212.7 |
| Top-left corner | (20, 110) | down-right (135°), s = (98, 67) → C = (118, 177) | first item (194,101), last (42,253) |

¹ Index 0 is the leftmost item for an upward arc.

Notes:
- Near the bottom, the default up-facing arc has room. If a message sits under a keyboard or bottom bar, the same rules apply to the visible window (insets include IME on Android / keyboard layout guide on iOS).
- Near the top, the arc flips down; the label slot flips with it (stays on the arc axis, outside the arc).
- The label slot is clamped into the safe rect; if it would overlap the wheel, it moves to the opposite side of the finger.
- A tall message (taller than the window): the anchor is still the touch point; the lifted message is clipped to the list viewport.
- The orientation is fixed for the life of the gesture. It is never recomputed while dragging.

### 5.4 Screen C — Settings sheet (demo-only controls)

Bottom sheet (iOS: `UISheetPresentationController` medium; Android: modal bottom sheet), title "Demo settings".

| Control | Type | Default | Behaviour |
|---|---|---|---|
| Theme | Segmented: System / Light / Dark | System | Applies immediately, no restart. |
| Reduce motion | Segmented: Follow system / Always on | Follow system | The override is OR-ed with the OS setting. |
| Haptics | Switch | On | Does not override OS-level haptics-off. |
| Show hit zones | Switch | Off | Debug overlay: capture circles, anchor, arm radius, current axis. |
| Reset reactions | Destructive text button | — | Confirmation dialog first ("Remove all demo reactions?"), then clears. |
| About | Static | — | "Demo data — not connected to Telegram. Not affiliated with Telegram." |

### 5.5 Reaction chip

- Idle chip: fill `chip.fill`; "mine" chip: fill `chip.mine` + 1 dp `accent` border.
- Tap on the "mine" chip removes it (shrink 1→0.6 + fade, 140 ms). Tap on a non-mine chip (none exist in this demo, since only the local user reacts) is a no-op.
- A chip must not move the surrounding layout by more than one row height; the list inserts the row with a 180 ms height animation (instant in Reduced Motion).

### 5.6 Colour tokens (own palette; no Telegram colours)

| Token | Light | Dark |
|---|---|---|
| `bg.chat` | `#EEF2F5` | `#0F1419` |
| `bubble.in` | `#FFFFFF` | `#1C242D` |
| `bubble.out` | `#DCEBFF` | `#2B4F7E` |
| `text.primary` | `#111418` | `#F2F5F7` |
| `text.secondary` | `#6B7480` | `#8E99A6` |
| `accent` | `#2A7DE1` | `#4C9AFF` |
| `scrim` | `#000000` @ 28 % | `#000000` @ 55 % |
| `wheel.plate` | `#FFFFFF` @ 92 % | `#232C36` @ 94 % |
| `wheel.selectedDisc` | `#E3EEFF` | `#34506F` |
| `label.fill` | `#111418` @ 88 % | `#F2F5F7` @ 92 % |
| `label.text` | `#FFFFFF` | `#111418` |
| `chip.fill` | `#E6ECF1` | `#26303A` |
| `chip.mine` | `#D3E5FF` | `#2F5D93` |
| `shadow.wheel` | 0 6 20 @ 18 % black | none; 1 dp `#FFFFFF` @ 8 % border |

Contrast: every text/background pair must reach ≥ 4.5:1 (≥ 3:1 for the selected ring/disc vs the plate). The implementer must **measure** and report the numbers; the values above were chosen by eye and are unverified.
Theme changes while the wheel is open only re-tint; they must not cancel the gesture.

---

## 6. Gesture timelines

All times are from touch-down (`t = 0`). Only the first pointer is tracked.

### 6.1 Happy path: hold → slide → release

| t (ms) | Event | Behaviour |
|---|---|---|
| 0 | Touch-down on a bubble | Record `A`, start the 350 ms long-press timer. No visual change. |
| 100 | Still held, moved ≤ 8 | Pressing state: bubble scale 0.98, 120 ms ease-out. (The delay avoids flashing during a scroll start.) |
| < 350 | Move > 8 from `A` | **Long-press aborted.** Press visual reverts in 120 ms; the touch becomes a scroll. |
| < 350 | Lift | A normal tap (no wheel, no reaction). Press visual reverts. |
| 350 | Timer fires | Haptic `open` (§9). Compute placement (§5.3). Start the cascade (§8.1). The list's scroll is **locked** for the rest of the gesture. Bubble returns to 1.0 and lifts above the scrim. |
| 350+ | Move | Each move event: update the selection (§5.2 rules) in the same frame. Fire the selection haptic on each change (rate limited, §9). |
| any | Cross `arm.distance` | Selection enabled. |
| any | Capture item i | `Selected(i)` springs (§8.2); label crossfades 80 ms. |
| any | Move beyond `capture.stay` | `Outside`: dim 120 ms; label "Release to cancel". |
| any | Lift in `Selected(i)` | Commit (§8.3). |
| any | Lift otherwise | Cancel (§8.4). |

The long-press timeout is **350 ms on both platforms**, with a movement tolerance of **8**. (Do not use the OS default timeout; it differs per platform and per user setting. Parity is a requirement.) **(tunable)**

### 6.2 Interruption timeline (during the open state)

| Event | Result |
|---|---|
| `touchesCancelled` / `ACTION_CANCEL` (system gesture, call, notification shade, app switch) | Cancel (§8.4), with no haptic. |
| App goes to the background / window loses focus | Cancel instantly, with no animation (state must be clean on return). |
| Rotation / window resize / fold change | Cancel instantly with no animation. |
| Second finger touches down | Ignored. Does not change the selection. Releasing the second finger does nothing. |
| First finger lifts while a second is down | Treated as release of the primary gesture (commit or cancel by state). |
| Theme or font scale change | Re-tint only; geometry is not recomputed mid-gesture. |
| New touch during the dismiss animation | Fast-forward the dismiss to its end and process the touch normally. |
| Lift during the cascade | Commit or cancel by the current selection; running springs retarget with velocity preserved. |
| Predictive back / edge back swipe (Android), interactive pop (iOS) | See §11. Treated as a cancel if it takes the touch. |

### 6.3 Cancel forms (user-intended)
1. Release at the centre (before `arm.distance`, or after returning near the anchor).
2. Release in the `Outside` zone (anywhere farther than the capture radius from all items).
3. Slide off any edge of the screen and release.
All are silent (no error styling). The label has already told the user: "Release to cancel".

---

## 7. State machine

```
Idle ──touchDown──► Pressing ──350ms──► Opening ──cascade done/any move──► ArmedIdle
  ▲                    │ move>8 / lift          │                             │ ▲
  │                    ▼                        │                  capture i  │ │ clear
  └────────────── (scroll / tap)                │                             ▼ │
                                                └────────────────────►  Selected(i) ◄──► Outside
 ArmedIdle / Outside ──lift/interrupt──► Cancelling ──► Idle
 Selected(i) ──lift──► Committing ──► Idle     Selected(i) ──interrupt──► Cancelling ──► Idle
 Idle ──a11y action──► Persistent ──select──► Committing ; ──dismiss──► Cancelling
```

Invariants: exactly one wheel exists at a time; `Committing`/`Cancelling` can be fast-forwarded; no state retains a reference to a gesture after `Idle`.

---

## 8. Motion spec

Springs are physical (mass 1). `ζ` = damping ratio, `k` = stiffness. Equivalent response times are given for iOS (`UISpringTimingParameters` / `CASpringAnimation`) and Android (`SpringForce` / `SpringAnimation`). Both platforms use the **same ζ and k**.

| Name | ζ | k | Used for |
|---|---|---|---|
| `spring.entry` | 0.62 | 220 | Cascade entry (position, scale). Overshoot ≈ 8 %. Settles in ≈ 450 ms. |
| `spring.select` | 0.70 | 420 | Selected item scale / disc. Overshoot ≈ 5 %. |
| `spring.retreat` | 0.80 | 300 | Non-selected scale and push. Little overshoot. |
| `spring.chip` | 0.60 | 380 | Chip pop-in (scale 0.7→1). |
| `spring.press` | 1.00 | 600 | Bubble press/lift (no overshoot). |

Springs always **retarget** (keep the current velocity) when the target changes. Never restart from rest, so a rapid scrub stays smooth.

### 8.1 Open cascade

- Scrim: 0 → 1 over 180 ms, curve (0.2, 0, 0, 1).
- Plate: fade 0 → 1 over 140 ms; scale 0.6 → 1 about `C` with `spring.entry`.
- Items in index order `i = 0…5`, **delay = 30 ms × i** (total stagger 150 ms; RTL mirrors the order).
- Each item, from `t = delay`:
  - start position = `C + 0.35 × (target − C)`, start scale 0.3, alpha 0
  - end position = target, scale 1.0, alpha 1
  - position and scale use `spring.entry`; alpha uses a 90 ms linear ramp.
- Label fades in at `t = 200 ms` (120 ms linear).
- Taps/moves are accepted from `t = 0` of the opening (hit-testing uses the final geometry).

### 8.2 Selection change
- New selected item: scale → 1.40 with `spring.select`; disc fades in, 90 ms.
- Previously selected item: scale → 0.9 (while another is selected) or 1.0, `spring.retreat`.
- Others: scale 0.9 and push 10 tangentially away from the selected item, falling off linearly to 0 two steps away (`spring.retreat`).
- Label crossfades 80 ms; the text is replaced, with no slide.
- Clearing the selection: all items return to 1.0 with `spring.retreat`.

### 8.3 Commit (release in `Selected(i)`)
| t (ms) | Behaviour |
|---|---|
| 0 | Haptic `commit`. Input locked for the animation. |
| 0–240 | The selected emoji moves to the chip slot (curve (0.3, 0, 0, 1)), scaling 1.4 → 0.57 (16/28). |
| 0–120 | Other items: scale → 0.6, fade out. Plate and label fade out. |
| 60–220 | Scrim fades out. The bubble returns to its normal elevation (`spring.press`). |
| 200 | Chip row appears (list height animation 180 ms) and the chip pops in with `spring.chip`. |
| 260 | Idle. Scroll unlocked. |
| — | VoiceOver / TalkBack announcement: "Reacted with Like" (§10). |

### 8.4 Cancel
| t (ms) | Behaviour |
|---|---|
| 0 | No haptic. |
| 0–160 | Items collapse towards `C` (scale → 0.3, alpha → 0) in reverse order, 12 ms stagger, curve (0.4, 0, 1, 1). |
| 0–140 | Plate and label fade out. Scrim fades out over 160 ms. |
| 160 | Idle. Scroll unlocked. |
Interruption cancels use the same animation, **except** background / rotation, which are instant.

### 8.5 Reduced Motion
Triggered by iOS `UIAccessibility.isReduceMotionEnabled`, or Android `ANIMATOR_DURATION_SCALE == 0` (reread each time the wheel opens), or the demo override.

| Aspect | Reduced behaviour |
|---|---|
| Open | Scrim + plate + all items fade in together over 100 ms at the final positions. No cascade, no travel, no overshoot. |
| Selected item | **No scaling and no push.** The selection is shown by the selected disc (fade 80 ms) + a 2 dp accent ring + the label. |
| Outside | Opacity dim only (it is a fade, so it stays). |
| Commit | 100 ms crossfade-out of the wheel; the chip fades in 100 ms. No fly-to-chip. |
| Cancel | 100 ms fade-out. |
| Chip add/remove | 100 ms fade; no layout animation. |
| Haptics | **Remain** (Reduced Motion does not mean reduced feedback). |
Information conveyed must be identical in both modes (the selection must be visible without scale).

---

## 9. Haptics

| Moment | iOS | Android | Notes |
|---|---|---|---|
| Open | `UIImpactFeedbackGenerator(.medium)` | `HapticFeedbackConstants.LONG_PRESS` | Fire at the same instant as the scrim starts. |
| Selection change (nil→i, i→j) | `UISelectionFeedbackGenerator.selectionChanged()` | API 34+: `SEGMENT_FREQUENT_TICK`; API 30–33: `CLOCK_TICK`; below: `KEYBOARD_TAP` | Rate limit: ≥ 40 ms between ticks, max ≈ 12/s. Not fired when clearing the selection. |
| Commit | `UIImpactFeedbackGenerator(.light)` | API 30+: `CONFIRM`; else `VIRTUAL_KEY` | |
| Cancel | none | none | Cancel is a non-event. |
| Persistent-mode select | `.light` impact | `CONFIRM` | Same as commit. |

- Call `prepare()` on iOS generators at `t = 250 ms` (before the open) to avoid latency.
- Respect the OS settings: do not use `FLAG_IGNORE_GLOBAL_SETTING` on Android; iOS honours system haptics automatically. The demo switch can only turn haptics **off**.
- Never vibrate during a Reduced-Motion transition solely because of it.

---

## 10. Accessibility

### 10.1 Principle
A held gesture is not operable for many users. Every action is also reachable through a **persistent, non-gestural path**.

### 10.2 Message element
- iOS: one accessibility element per bubble. Label: "Alex, message, `<text>`, 10:42". Value: "No reaction" / "Your reaction: Like". Custom actions: **"React…"** (opens the persistent wheel) plus one custom action per reaction ("React with Like", …); "Remove reaction" if one exists.
- Android: each bubble is a focusable node with the same content description. `AccessibilityNodeInfo` custom actions: "React…" and one per reaction; `ACTION_LONG_CLICK` also opens the persistent wheel (so TalkBack's actions menu and double-tap-and-hold both work).

### 10.3 Persistent wheel (`Persistent` state)
- Opened by "React…" / long-click. Anchor = the centre of the bubble (placement §5.3 applies). Cascade follows Reduced Motion rules.
- The wheel container is modal: iOS `accessibilityViewIsModal = true`; Android: pane title "Reaction wheel", content behind marked `importantForAccessibility = noHideDescendants`.
- On open, focus moves to item 0. A screen-changed announcement (iOS) / pane-title announcement (Android): "Reaction wheel. 6 options."
- Items are buttons in index order. Label: "Like, 1 of 6" (+ "selected" for the current reaction). Double-tap activates (commit §8.3, announcing "Reacted with Like").
- Dismiss: iOS two-finger "Z" scrub (`accessibilityPerformEscape`) and a visible close target (48×48, "Close") ; Android: system Back, and the same visible close target. A tap on the scrim also dismisses. After dismissal, focus returns to the originating message.
- Items are **never** reordered by the placement algorithm in a way that breaks index order (focus order is index order).

### 10.4 Held gesture with assistive tech running
If the held gesture is used with VoiceOver/TalkBack on (touch pass-through): the selection label changes are announced (debounced 150 ms, "Like, 1 of 6"); haptics unchanged. This path is best-effort; the persistent wheel is the supported route.

### 10.5 Other requirements
- **Touch targets:** items 48×48 minimum (also at the 1.0× scale); the close and settings controls 48×48.
- **Font scale / Dynamic Type:** text (label, bubble, chip count, banner) follows system scale. Android up to 200 %, iOS up to AX5. The emoji glyphs scale with `uiScale` up to 1.3×. The label wraps to 2 lines max, then truncates with an ellipsis (the accessible label is never truncated). The chip height grows with the text.
- **Contrast:** §5.6. Selection must not rely on colour alone (scale or ring + label).
- **Reduce Transparency / Increase Contrast (iOS), high-contrast text (Android):** the plate becomes opaque; the ring thickens to 3.
- **Colour independence:** reaction state ("mine") shown by border + a11y value as well as colour.
- **Switch Control / Voice Control / hardware keyboard:** reachable via the persistent wheel; on a message with keyboard focus, `Space`/`Enter` opens it, arrows move focus, `Enter` selects, `Esc`/Back closes. (Keyboard support: P2, but the persistent wheel's buttons must be focusable.)
- **Localization:** EN and RU string tables. All visible and a11y strings are externalised; none hard-coded in code.

---

## 11. Native differences (parity of behaviour, not pixels)

| Topic | iOS | Android |
|---|---|---|
| Gesture entry | A custom `UILongPressGestureRecognizer`: `minimumPressDuration = 0.35`, `allowableMovement = 8` (continues tracking after `.began`). | `onTouchEvent` / `GestureDetector` with a custom 350 ms timer and 8 dp slop (not the OS timeout). |
| Scroll conflict | Disable list scroll for the gesture duration; the recognizer must not leave the scroll view in an inconsistent offset. | `requestDisallowInterceptTouchEvent(true)` on open; restore on end. |
| System edge gestures | Disable the interactive-pop gesture while open (if a nav stack is used). Control Centre / Notification edges produce `touchesCancelled` → cancel. | Set `systemGestureExclusionRects` around the touch strip while open (≤ 200 dp per edge); the back gesture can still win → `ACTION_CANCEL` → cancel. Predictive back must not leave the wheel visible. |
| Safe area | `safeAreaInsets` of the window (Dynamic Island, home indicator). | `WindowInsets` systemBars + displayCutout + systemGestures. |
| Springs | `CASpringAnimation` / `UISpringTimingParameters` with the §8 (ζ, k). | `SpringForce` (stiffness k, `dampingRatio` ζ) via `SpringAnimation` (or Compose `spring(dampingRatio, stiffness)`). |
| Haptics | Impact/selection generators. | `View.performHapticFeedback` constants with API-level fallbacks. |
| Reduced motion | `UIAccessibility.isReduceMotionEnabled` + notification. | `Settings.Global.ANIMATOR_DURATION_SCALE`. |
| A11y | `UIAccessibilityCustomAction`, modal views, `.screenChanged` posts. | `AccessibilityNodeInfo` actions, pane titles, `announceForAccessibility`. |
| Emoji font | Apple Color Emoji (system). | Noto Color Emoji (system); check the emoji renders on API 24+ emulator images. |
| Dark mode | `traitCollection.userInterfaceStyle` + dynamic colours. | `uiMode` night qualifier / `DayNight` theme. |
| Corner shape / sheet | Continuous (squircle) corners are acceptable. | Plain rounded rect. |
| Navigation chrome | Large-title-free bar; sheet detents for settings. | Top app bar; modal bottom sheet for settings. |
| Rendering rule | Animate transforms/opacity of layers only; no Auto Layout passes while dragging. | Animate `View` properties (`translation`, `scale`, `alpha`) or Compose graphics layers only; no re-measure while dragging. |

Implementation choice (Views vs Compose) is left to Codex, per `AGENTS.md`. The behaviour above is independent of that choice.

---

## 12. Edge cases and decisions

| # | Case | Decision |
|---|---|---|
| E1 | Release without any move | Cancel (`arm.distance` not reached). No reaction. |
| E2 | Tiny finger tremor after open | Ignored under 12. |
| E3 | Release outside the capture zone | Cancel; the label has already shown "Release to cancel". |
| E4 | Slide past the wheel to the screen edge and back | The selection follows the rules; the edge does not cancel by itself. |
| E5 | Finger leaves the screen bounds (Android off-screen coordinates) | Treated as `Outside`. |
| E6 | Message at the left / right / top edge or corner | §5.3. |
| E7 | Message at the bottom, under the bottom bar or keyboard | Up-facing arc within the visible window. |
| E8 | Landscape, short windows | The algorithm uses the available height; the label may move to the opposite side. If it cannot fit, it is allowed to overlap the plate's outer side but never the items. |
| E9 | Split-screen / foldable / tablet | Use the window bounds. R does not scale with the window size. |
| E10 | RTL | Index order mirrored; placement rules use physical sides. |
| E11 | Large font scale | `uiScale` ≤ 1.3; the label wraps to 2 lines. |
| E12 | Long-press while the list is still decelerating (fling) | A touch-down stops the fling; the 350 ms timer starts from that touch. |
| E13 | Reaction already present | Ring + "Remove" label; toggles (§5.2). |
| E14 | Rapid repeated gestures | Each open/close fast-forwards the previous one (§6.2). Max one wheel. |
| E15 | Message deleted/scrolled while open | Not possible: the list is locked. Programmatic changes are out of scope. |
| E16 | Reduced Motion toggled while open | Applies from the **next** open. |
| E17 | Theme toggled while open | Re-tint only. |
| E18 | Haptics unsupported (simulator, some emulators) | Silent no-op; never throws or logs errors repeatedly. |
| E19 | Mouse / stylus (simulator / emulator pointer) | Press-and-hold works the same; hover is ignored. |
| E20 | Touch-down on a chip or the banner | The wheel does not open there (only on bubbles). |
| E21 | Very long press (> 10 s) with no move | The wheel stays open; no timeout. |
| E22 | Memory warning / low memory | State is dropped to Idle; the demo reactions are in memory only (documented). |

---

## 13. Instrumentation for verification

Stable test identifiers (iOS `accessibilityIdentifier`, Android `contentDescription` is for users, so use `testTag` / `resource-id`):

`chat.list`, `chat.message.<n>`, `chat.chip.<n>`, `wheel.root`, `wheel.scrim`, `wheel.plate`, `wheel.item.0`…`wheel.item.5`, `wheel.label`, `wheel.close`, `settings.open`, `settings.theme`, `settings.reduceMotion`, `settings.haptics`, `settings.debug`, `settings.reset`.

Debug overlay (`settings.debug`) draws: the anchor, the wheel centre, the arm radius (12), the capture (80) and stay (96) circles per item, the chosen axis `δ`, the shift `s`, and the current state name. It makes §5.3 examples checkable by eye. It must never be shown by default.

---

## 14. Cross-platform acceptance criteria

Each criterion must pass **on both iOS and Android**, in light and dark, unless noted. Evidence = a recording or a logged measurement. Nothing may be marked passed without having been run.

### Gesture & logic
- **AC-01** Touch-down + still hold of 350 ± 30 ms opens the wheel. A lift before 350 ms is a tap and never opens it.
- **AC-02** A move of more than 8 before 350 ms aborts the long-press and scrolls the list.
- **AC-03** Once open, the list does not scroll, and the finger can move freely without lifting.
- **AC-04** The wheel shows 6 items on a 180° arc in index order (§2.1) with the radius and sizes of §5.2.
- **AC-05** Releasing without moving ≥ 12 never commits.
- **AC-06** Sliding to an item selects the nearest one (80 enter, 96 stay, 8 switch margin); the label shows its name.
- **AC-07** Releasing on a selected item commits the reaction and shows a chip under that message.
- **AC-08** Releasing at the centre or outside the zone cancels; no reaction is added or changed; "Release to cancel" is visible before release.
- **AC-09** Selecting the current reaction removes it (label "Remove"); selecting another replaces it.
- **AC-10** `ACTION_CANCEL`/`touchesCancelled`, backgrounding, rotation: the wheel closes, with no reaction and no stuck scrim or locked scroll.
- **AC-11** A second finger never changes the selection.
- **AC-12** Placement: for the four cases of §5.3, the item centres equal the table values within ±2, and every item lies fully inside the safe rect. With a notch or gesture inset present, no item overlaps it.
- **AC-13** The `hold.anchorNearest ≥ 96` invariant holds in every placement; the wheel never selects an item on open.

### Motion & feel
- **AC-14** The cascade runs with a 30 ms stagger and the `spring.entry` parameters; the overshoot is visible but ≤ 10 %.
- **AC-15** The selected item scales to 1.40 and the others to 0.90 with a tangential push; the change is continuous (no jump) on fast scrubs, and springs retarget.
- **AC-16** Commit and cancel follow §8.3 / §8.4 within ±30 ms of the stated durations.
- **AC-17** Frame pacing: while dragging with the wheel open, ≥ 95 % of frames meet the display's budget (16.7 ms at 60 Hz) on a mid-range reference device or emulator. Report the tool and the number (iOS: Instruments / `CADisplayLink` drops; Android: `dumpsys gfxinfo` or a Perfetto trace). No layout/measure pass per move event.
- **AC-18** A new touch during a dismiss animation is processed without a visible glitch or a dropped touch.

### Haptics
- **AC-19** There is exactly one `open` haptic, one tick per selection change (rate-limited), one `commit` haptic, and none on cancel. (Verified on a physical device; on the simulator/emulator, verify the call is made via a log.)
- **AC-20** The haptics switch off stops all calls, and the OS-level setting is respected.

### Theme & layout
- **AC-21** Light and dark both use the §5.6 tokens, with contrast measured and reported (≥ 4.5:1 text; ≥ 3:1 selection ring/disc). The theme can change while the wheel is open without cancelling it.
- **AC-22** Layout is correct in portrait and landscape, on a small phone (≈ 360 dp wide) and a large one; RTL mirrors the index order.

### Accessibility
- **AC-23** Reduce Motion (OS or override): no cascade, no scale, no push, no fly-to-chip; opening is a ≤ 100 ms fade; the selection remains clearly visible (disc + ring + label); haptics remain.
- **AC-24** VoiceOver and TalkBack: every message exposes "React…" and one action per reaction; the persistent wheel opens, focus lands on item 0, items read "Name, n of 6", activation commits, and Escape/Back/Close dismiss and return focus to the message.
- **AC-25** The commit is announced ("Reacted with …"); cancel is silent.
- **AC-26** Items and controls are ≥ 48×48; the layout survives font scale 200 % (Android) and AX5 (iOS) with no clipped text in the wheel label (wraps to 2 lines).
- **AC-27** With Increase Contrast / Reduce Transparency, the plate is opaque and the ring is thicker.

### Product & compliance
- **AC-28** The demo banner "Demo data — not connected to Telegram" is always visible; the EN and RU strings are present.
- **AC-29** Only public mock data is used. No Telegram logos, icons, emoji art or sounds are bundled. No network calls are made.
- **AC-30** Each platform runs independently, and its README documents the exact build and run commands, with the results of those commands as actually executed.

---

## 15. Open questions / assumptions (for Codex's design review)

1. **Assumption:** `capture.enter = 80` with nearest-item selection suits finger use; on large tablets it may feel small. If feel-testing demands it, scale it with `uiScale` only. **(tunable)**
2. **Assumption:** the 350 ms timeout is slightly shorter than the OS defaults (iOS 500 ms, Android 400 ms), to make the wheel feel responsive. If it causes accidental opens while scrolling, raise it to 400 ms on both. **(tunable)**
3. **Assumption:** the corner case (§5.3, shift up to 120) is rare in a real chat layout because bubbles are inset; it is a documented limitation rather than a primary flow.
4. **Not designed (out of scope):** reaction sync, notifications, animated emoji, multiple reactions per user, "more" picker.
5. **Unverified:** all contrast ratios, the worked-example coordinates, and the feel of the spring values are design estimates until measured on devices.
