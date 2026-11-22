# Reaction Wheel — UX & Interaction Design (iOS + Android)

Concept: `concept-20261122-121705-7a1e`
Stage: Design (Claude Code), **revision 2** — updated after the independent review in `DESIGN_REVIEW.md`. Inputs: `AGENTS.md`, `DESIGN.md`, `SPEC.md`, `DESIGN_REVIEW.md`.
Status: design only. No application code. All data is public mock data. No Telegram trademarks or assets are used.

Conventions: **pt** (iOS) and **dp** (Android) are the same logical unit here. `ms` is milliseconds. `θ` is the clockwise angle from screen-up. Numbers in this document are the *design contract*. Values marked **(tunable)** may be adjusted by the implementer after on-device feel testing, but a change must be recorded in the README and applied to both platforms. Changes made in revision 2 are tagged `[R:P0.x]` / `[R:P1.x]`; every review item and its resolution (adopted, adapted, or disagreed with) is in **§16**.

---

## 1. User problem

Choosing a reaction today is a two-step, low-expressiveness flow: long-press opens a strip or sheet, then the user lifts the finger and taps a second time. This causes three problems:

1. **Interruption.** Lift and re-tap breaks the "hold → choose → release" rhythm. The user can't scrub and explore.
2. **Low expressiveness.** A flat row gives no sense of choice. There is no preview, no tactile "detent" and no sense of the options being a physical place.
3. **Accidental commits.** The finger lands on the strip at the moment of tap, with no safe way to back out.

**Goal:** a one-gesture flow of press, hold, slide and release. A radial layout makes every option equidistant from the finger, so choosing is a *direction*, not a *target*. Cancelling is always possible (slide away or return to the centre, then release).

**Non-goals:** a custom emoji set, a "more reactions" picker, animated sticker reactions, sending to any backend, multi-reaction per user.

### Success criteria (user-level)
- A user who has seen the on-screen hint (§5.1) can select a reaction in one continuous gesture, in under 2 s after the wheel opens. Unaided discovery (without the hint) is recorded informally as an observation, not a pass/fail gate. `[R:P1.1]`
- Nobody commits a reaction by accident: releasing without sliding, a small post-hold drift (< 44 from the anchor), or slipping away never commits. `[R:P0.1]`
- The same flow is reachable with VoiceOver, TalkBack, Switch Control, Voice Control, a hardware keyboard and a Reduced Motion setting, through the persistent picker (§10).

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

**Accessible names come from the string table above, never from system emoji pronunciation** (emoji names vary by OS version and locale). The emoji glyph itself is hidden from assistive tech (iOS: the glyph label is not an accessibility element; Android: `importantForAccessibility = no` on the glyph, `contentDescription` on the button). `[R:P1.3]`

**Index order is defined in screen coordinates, not as "clockwise"** `[R:P1.2]`:
- For the **up, down and diagonal** axes, the index increases toward **+x** (to the right) in LTR, and toward **−x** in RTL. Index 0 is always on the reading-start side.
- For the **left and right** axes, the index increases toward **+y** (downward) in both LTR and RTL.
- Placement uses physical sides in RTL (§5.3); only the index order mirrors.

Formally: item `i` has `φ_i = −90° + 36°·i` and sits at `θ_i = axis + σ·φ_i`, where `σ = +1` if the direction `(cos axis, sin axis)` points along the order direction defined above, else `σ = −1`. Consequence: an arc facing down still has index 0 on the left (LTR); it is *not* the clockwise mirror of the up-facing arc. A shared fixture file (§13) holds the expected geometry for every axis × LTR/RTL.

### 2.2 Mock messages (public, invented)
12+ messages, mixed incoming/outgoing, short and multi-line, one very long, one with only an emoji, one near full-width. Sender names are fictional (e.g. "Alex", "Sam", "Robin"). Texts are neutral (weekend plans, a recipe, release notes of an imaginary app). A persistent, non-dismissible banner reads: **"Demo data — not connected to Telegram"** (RU: «Демо-данные — без подключения к Telegram»).

---

## 3. User journey

| # | Step | User intent | System response |
|---|---|---|---|
| 1 | Open demo | See chat list | List with banner and hint; messages at the bottom, scrolled to the latest. |
| 2 | Touch a message | Start a possible tap / scroll / long-press | Subtle pressed state after 100 ms (§6.1). |
| 3 | Hold still 350 ms | "Open reactions" | Haptic, scrim, wheel cascades in around the finger. |
| 4 | Slide toward an emoji (≥ 44 from the anchor) | Explore | Nearest emoji grows, others retreat, a tick fires per change, label names it. |
| 5a | Release on emoji | Commit | Emoji flies to a chip under the message (add / replace, §8.3). |
| 5b | Release in the centre, in the dead zone, or outside | Cancel | Wheel collapses, no change. |
| 5c | Release on the *current* reaction | Remove | Wheel dismisses, the chip shrinks away, no fly-to-chip (§8.3b). |
| 5d | System interruption | — | Treated as cancel (§6.2). |
| 6 | Tap own chip | Shortcut to remove | Same removal path as 5c (§5.5). |
| 7 | Assistive tech / keyboard | Do the same without a held gesture | Persistent picker (§10); Compact picker when the radial layout cannot fit (§5.3.2). |
| 8 | Settings | Test theme, reduced motion, haptics, debug | Settings sheet (§5.4). |

---

## 4. Wireframes (text)

Item numbers are **indices** (0…5) in the screen-coordinate order of §2.1.

### 4.1 Default: mid-screen, wheel opens upward

Upward arc (LTR), R = 108, anchor A at the bottom centre; the label sits in a fixed slot on the arc axis (§5.3.1):

```
            (2)   (3)
        (1)             (4)
     (0)                   (5)        <- 6 items on a 180° arc
                  ● A  <- finger = anchor (touch-down point)
        ┌───────────┐
        │ message   │
        └───────────┘
 scrim covers everything except the pressed message
```

### 4.2 Near the left edge: wheel rotates to face right

```
|●  (0)
|     (1)
|        (2)
|        (3)
|     (4)
|   (5)
```
Index increases downward for left/right axes (§2.1). `[R:P1.2]`

### 4.3 Near the top: wheel flips downward

```
 (0)                     (5)
     (1)             (4)
          (2)   (3)
                ●
```
Index 0 stays on the left, as for the up-facing arc. `[R:P1.2]`

### 4.4 Persistent picker (accessibility / keyboard)

```
        (0)  (1)  (2)  ...      same arc, same placement rules
                (X)            <- close control at the arc centre C (48×48)
        [ Choose a reaction ]  <- label slot (static text)
```
No finger exists, so the close control sits at `C`, which is free space inside the arc. `[R:P0.5]`

### 4.5 Compact picker (fallback when no radial layout fits, §5.3.2)

```
┌──────────────────────────┐
│ Choose a reaction     (X)│
│ [👍 Like ]   [❤️ Love ]  │
│ [😂 Laugh]   [😮 Wow  ]  │
│ [😢 Sad  ]   [🔥 Fire ]  │
└──────────────────────────┘
```

---

## 5. Screens and states

### 5.1 Screen A — Chat demo (idle)

Layout (portrait, 390×844 reference):
- Top bar: 56 dp content + safe-area top. Title "Reaction Wheel", trailing **settings button** (48×48 hit area). Use the platform's native gear icon (SF Symbol `gearshape` / Material `settings`), **not** a text glyph; accessible name "Demo settings" / «Настройки демо». `[R:P1.1]`
- Banner: 28 dp high, secondary text 12 sp/pt, always visible below the bar.
- **Hint row** `[R:P1.1]`: 28 dp high under the banner, secondary text 12, always visible, not dismissible: "Hold a message, slide to a reaction, then release." / «Удерживайте сообщение, проведите к реакции и отпустите.» It wraps to 2 lines at large font scale (the row grows). It is hidden from nothing: assistive tech reads it as static text.
- Message list: bubbles with 16 dp horizontal inset, 4 dp vertical gap within a sender group, 10 dp between groups. Max bubble width 78 % of the list width.
- Bubble: corner radius 18; padding 12 horizontal / 8 vertical; text 16 (system font, scales with Dynamic Type / font scale); time 11, secondary.
- Reaction chip row: under the bubble, 4 dp gap, chip height 28, corner radius 14, padding 8 horizontal; emoji 16 + count 13. The chip's **touch target is expanded to 48 pt/dp high** (extends 10 up and 10 down from the visual chip, and wins over the bubble in the overlap). `[R:P1.9]`

Message states:

| State | Visual |
|---|---|
| Idle | Normal. |
| Pressing (100–350 ms after touch-down) | Bubble scales to 0.98 over 120 ms, ease-out. |
| Lifted (wheel open) | Bubble sits above the scrim at scale 1.0, a soft shadow in light, a 1 dp 8 % white border in dark. |
| Reacted | Chip row shows the emoji + count 1 with the "mine" highlight (§5.5). |
| Reaction changed | The chip stays in place; the emoji crossfades (§8.3). |
| Reaction removed | Chip row collapses (§8.3b). |

### 5.2 Screen B — Wheel open (the core overlay)

Layers, bottom to top: list → scrim → lifted message → wheel plate → emoji items → label → (close control in Persistent) → (debug overlay if on).

**Tokens (all sizes pt/dp):**

| Token | Value | Notes |
|---|---|---|
| `wheel.radius` R | 108 | Multiplied by `uiScale` (below). |
| `wheel.arc` | 180° | 6 items, 36° apart: φ = −90, −54, −18, +18, +54, +90 from the arc axis. |
| `item.size` | 48 | Layout box, also the min hit/target size on both platforms. At `uiScale` > 1 it is `48 × uiScale`. |
| `item.glyph` | 28 | Emoji font size inside the 48 box. |
| `item.selectedScale` | 1.40 | → 67.2 at 1.0×. Marginally wider than the 66.7 chord between neighbours; acceptable because the neighbours retreat to 0.9 (no overlap in practice). |
| `item.idleScale` | 1.00 | |
| `item.retreatScale` | 0.90 | Applied to the non-selected items only while one is selected. |
| `item.retreatPush` | 10 | Tangential push away from the selected item. Falls off linearly to 0 at 2 steps away. |
| `item.ring` | 2 | Drawn **inside** the item box (never extends the bounds). |
| `plate.thickness` | 64 | Arc-shaped "track" behind items (stroke along the arc). Radius R, round caps. |
| `plate.cornerBlur` | none | Plain translucent fill on both platforms (no blur dependency, for parity). |
| `label.height` | 32 min | Pill, text 13 semibold, 12 horizontal padding, max 2 lines at large font scale. **Size is measured at runtime** from the rendered text and is part of the fit test. |
| `label.maxWidth` | min(240, safe width) | |
| `safe.margin` | 8 | |
| `extent.item` | `0.5 × item.selectedScale × item.size × uiScale` | Selected-item radius = 33.6 × `uiScale`. `[R:P0.2]` |
| `extent.inset` | `ceil(safe.margin + extent.item)` | 42 at 1.0×, 52 at 1.3×. Item **centres** must lie ≥ `extent.inset` inside the safe rect. `[R:P0.2]` |
| `uiScale` | clamp(fontScale, 1.0, 1.3) | At large font scales R and `item.size` grow, max 1.3×. Read at each open. Text beyond the 1.3× cap scales freely (label wraps) — the Compact picker (§5.3.2) absorbs what the radial layout cannot. |

**Hit-testing tokens** (all distances in the screen coordinates of the touch; **not** scaled by `uiScale`, because they describe the thumb, not the artwork — **(tunable)**):

| Token | Value | Meaning |
|---|---|---|
| `arm.distance` | 12 | Tremor guard. Below it, the wheel is `Armed-idle` and `Outside` is not shown. It is **not** a commit guard. `[R:P0.1]` |
| `commit.enter` | **44** | **Dead zone.** A selection may begin (`nil → Selected(i)`) only when the finger is ≥ 44 from the anchor `A`. Tunable within 40–48. `[R:P0.1]` |
| `commit.exit` | **32** | Hysteresis. A selection is cleared when the finger returns to < 32 from `A`. `[R:P0.1]` |
| `capture.enter` | 80 | A new item is captured when the finger is within 80 of its *final* centre. Because circles overlap, selection is **nearest-centre among items within 80**, not six separate 48 pt targets. |
| `capture.stay` | 96 | The selected item stays selected up to 96 (hysteresis). |
| `switch.margin` | 8 | To move selection A→B, the finger must be ≥ 8 closer to B than to A. |
| `hold.anchorNearest` | ≥ 96 | **Invariant (held gesture only):** the open anchor is at least 96 from every item centre. Waived in Persistent (no finger). |

Why the dead zone is needed: item centres sit 96–108 from the anchor and `capture.enter = 80`, so an item can be captured after only ~16–28 of movement. `commit.enter = 44` makes the *safe* radial excursion explicit: a post-hold drift of 20–30 can never select, and therefore never commit.

**Commit predicate (evaluated on the release coordinates, not on stale state):** commit iff `ρ ≥ commit.exit` **and** the finger is within `capture.stay` of the selected item's centre **and** the state was `Selected(i)` — where `ρ = |F − A|`. Anything else cancels.

Hit-testing uses the **final** (target) positions, never the animated ones, so a fast scrub during the cascade behaves identically on both platforms.

**Wheel states:**

| State | Trigger | Visuals | Label text (EN / RU) |
|---|---|---|---|
| `Opening` | 350 ms hold | Scrim fades in, items cascade (§8.1) | — |
| `Armed-idle` | Opened, no selection (includes the dead zone 12 ≤ ρ < 44 when near an item) | All items 1.0; plate full opacity | "Slide to choose" / «Проведите, чтобы выбрать» |
| `Selected(i)` | Finger captured item `i` with ρ ≥ 44 | Item i 1.4× and lifted by a 56 disc (selected fill); others 0.9× and pushed | Reaction name |
| `Selected-remove(i)` | As above, and `i` is the user's current reaction | As `Selected(i)` plus a **"−" badge** (16 × 16, top-trailing corner) on the item `[R:P0.3]` | "Remove 👍" / «Убрать 👍» (a11y: "Remove Like reaction") |
| `Outside` | Finger further than `capture.stay` from every item and ρ ≥ `arm.distance` | Plate + items dim to 0.6 over 120 ms; **the label is never dimmed** `[R:P1.8]` | "Release to cancel" / «Отпустите для отмены» |
| `Committing` | Release in `Selected(i)` (add / replace) | §8.3 | — |
| `Removing` | Release in `Selected-remove(i)`, or chip tap, or Persistent "Remove" | §8.3b | — |
| `Cancelling` | Release in `Armed-idle`/`Outside`, or interruption | §8.4 | — |
| `Persistent` | Opened via accessibility / keyboard | §10 | "Choose a reaction" |
| `Compact` | Radial layout does not fit (§5.3.2) | Panel (§4.5) | "Choose a reaction" |

Selection clears (no haptic) when the finger leaves `capture.stay` of the selected item, or returns to ρ < 32. The state becomes `Outside` if far from all items and ρ ≥ 12, else `Armed-idle`.

**Current reaction marker.** If the message already has reaction X, item X shows a 2 dp accent ring. When selected it becomes `Selected-remove` (badge + "Remove" label). Selecting X toggles it off; selecting a different Y replaces X (single reaction per user).

### 5.3 Placement and edge handling (all four edges, notch, gesture inset)

Anchor = touch-down point `A`. The wheel centre `C` is normally `A`. Arc axis direction is normally up (0°).

**Safe rect** = window bounds minus: system bars, display cutout / Dynamic Island, home indicator, **and** on Android horizontal system-gesture insets (≈ 24–32 dp). The window (not the screen) is used, so split view / multi-window / foldables work.

#### 5.3.1 The single fit test `[R:P0.2][R:P0.5]`

`Fit(C, axis, uiScale, mode)` is true iff **all** of the following hold, computed from final rendered bounds at the active `uiScale`:

1. Every item centre is ≥ `extent.inset` inside the safe rect (equivalently: each *selected-size* item circle of radius `extent.item` plus `safe.margin` is inside).
2. **Label:** the measured label rect lies inside the safe rect (inset `safe.margin`) and is disjoint from every selected-size item circle and from the close control. The label tries these slots in order and takes the first that satisfies this: (a) on the arc axis, outside the arc, centre at `R·uiScale + 56` from `C`; (b) the opposite side of `C`; (c) docked at the top of the safe rect, horizontally centred; (d) docked at the bottom. If no slot works, `Fit` is false.
3. **Close control (Persistent only):** the 48×48 control centred at `C` lies inside the safe rect (inset `safe.margin`) and does not intersect any item's unscaled 48·uiScale box.
4. **Targets (Persistent only):** the six item boxes (`48·uiScale`) are pairwise disjoint and each ≥ 48×48 (guaranteed by the geometry; the test asserts it).
5. **Held gesture only:** `hold.anchorNearest ≥ 96` holds for this `C`.

Placement is re-run on every open, so a font-scale change between opens is honoured; geometry is never recomputed mid-gesture.

#### 5.3.2 Algorithm (deterministic; must match on both platforms) `[R:P0.5]`

1. Candidate axes in preference order: up (0°), down (180°), right (90°), left (270°), down-right (135°), down-left (225°), up-right (45°), up-left (315°).
2. For each candidate, compute the minimal translation `s` of `C` (vector, 0 if none needed) such that `Fit(A + s, axis, …)` is true. Reject the candidate if no such `s` exists or `|s| > 120` (item-centre condition only drives `s`; label/close/invariant are then checked at `C = A + s`).
3. Accept the **first** candidate (in preference order) with `|s| ≤ 24`.
4. If none: choose the valid candidate with the smallest `|s|` (ties: preference order).
5. **If none is valid → Compact picker.** There is no independent clamping of item centres, and no nearest-item-only hit testing. Compact is a persistent, tap-driven picker:
   - A modal panel centred in the safe rect, max width min(320, safe width − 16). Contents: title "Choose a reaction", a **close control (48×48)**, and the six reactions as buttons in index order: 2 columns × 3 rows when the panel is ≥ 240 wide, else 1 column × 6 rows. In RTL the columns mirror, the order stays 0…5 in reading order.
   - Each button ≥ 48×48, shows glyph (28 × uiScale) + localized name (13, scales with font, wraps to 2 lines; the row grows). Current reaction: ring + "Remove" semantics.
   - If the content is taller than the safe height, the **panel scrolls vertically**; the title and close control stay pinned.
   - Focus/reading order = index order, then close. Cancellation: close control, scrim tap, Back / Escape / VoiceOver Z-scrub. Focus returns to the originating message.
   - A held gesture that lands in Compact ends with the finger lift **without** committing; the panel stays open and the user taps. Transitions use the 100 ms fade of Reduced Motion in all modes; commits use the fade (no fly-to-chip). Haptics: `commit` on select.
6. `C = A + s`. The finger is not moved; only the wheel is. The pressed message stays in place.

Persistent mode uses the same algorithm with `A` = centre of the originating bubble (clamped into the safe rect) and mode = Persistent in `Fit`.

**Worked examples at 1.0×** (390×844, safe top 59, safe bottom 34, R = 108, `extent.inset` = 42; computed by hand and checked only as invariants — see AC-12):

| Case | Anchor A | Result | Item centres (x, y), index 0 → 5 |
|---|---|---|---|
| Mid-screen | (195, 500) | up, s = 0 | (87,500) (107.6,436.5) (161.6,397.3) (228.4,397.3) (282.4,436.5) (303,500) |
| Left edge | (20, 500) | right (90°), s = (22, 0) → C = (42, 500) | (42,392) (105.5,412.6) (144.7,466.6) (144.7,533.4) (105.5,587.4) (42,608) |
| Top centre | (195, 110) | down (180°), s = 0 | index 0 at the left: (87,110) … (303,110); middle items at y ≈ 212.7 |
| Top-left corner | (20, 110) | down-right (135°), s ≈ (98.4, 67.4) → C ≈ (118.4, 177.4); \|s\| ≈ 119.3 ≤ 120 | index 0 (42,253.8) … index 5 (194.8,101) |

(The left-edge case has \|s\| = 22 ≤ 24 and is accepted at step 3. The top-left corner is accepted at step 4. Rows 3–4 were corrected in revision 2: index 0 is on the left/bottom side per §2.1.)

**Worked example at 1.3×** (Android 200 % font → `uiScale` 1.3; 360×800 window, safe top 48, bottom 24; R = 140.4, `extent.item` = 43.7, `extent.inset` = 52; safe x ∈ [52, 308]): anchor (180, 500).
- Up / down: the arc needs 2·140.4 = 280.8 of horizontal span but only 256 is available → rejected.
- Right (90°): item x ∈ [C.x, C.x + 140.4] → C.x ∈ [52, 167.6]; minimal shift `s = (−12.4, 0)`, C = (167.6, 500); every item is > 120 from A, so the anchor invariant holds. Label slot (a) would need x ≈ 364 → off-window; slot (b) is off-window; slot (c) (top dock) is free → used. `|s| = 12.4 ≤ 24` → accepted at step 3.
- On a 240-dp-wide window (split-screen), nothing is valid → **Compact**.

Notes:
- Near the bottom, the default up-facing arc has room. If a message sits under a keyboard or bottom bar, the same rules apply to the visible window (insets include IME on Android / keyboard layout guide on iOS).
- A tall message (taller than the window): the anchor is still the touch point; the lifted message is clipped to the list viewport.
- The orientation is fixed for the life of the gesture. It is never recomputed while dragging.
- The pure placement function must be unit-testable with synthetic bounds (§14, AC-12).

### 5.4 Screen C — Settings sheet (demo-only controls)

Bottom sheet (iOS: `UISheetPresentationController` medium; Android: modal bottom sheet), title "Demo settings".

| Control | Type | Default | Behaviour |
|---|---|---|---|
| Theme | Segmented: System / Light / Dark | System | Applies immediately, no restart. |
| Reduce motion | Segmented: Follow system / Always on | Follow system | The override is OR-ed with the OS setting. |
| Haptics | Switch | On | Does not override OS-level haptics-off. |
| Show hit zones | Switch | Off | Debug overlay: capture circles, dead zone, anchor, arm radius, current axis. |
| Reset reactions | Destructive text button | — | Confirmation dialog first ("Remove all demo reactions?"), then clears. This is the **only** confirmed destructive action; removing a single reaction never asks. |
| About | Static | — | "Demo data — not connected to Telegram. Not affiliated with Telegram." |

### 5.5 Reaction chip `[R:P0.3][R:P1.9]`

- Idle chip: fill `chip.fill`; "mine" chip: fill `chip.mine` + 1 dp `accent` border.
- **The chip is a button** (all chips in this demo are "mine"). Pressed state: scale 0.94 + fill darkened by one step (`chip.mine` pressed token = 8 % black overlay in light, 8 % white in dark), 80 ms. A touch that turns into a scroll cancels the press and does not fire (standard button cancel on movement beyond touch slop).
- Tap removes the reaction through the `Removing` path (§8.3b), **no confirmation** (low impact, immediately reversible by reacting again). The wheel's toggle-off (§5.2) is the primary removal path; chip tap is a documented shortcut.
- Accessibility: role button; label "Your reaction: Like"; action/hint "Remove Like reaction"; after activation, announce "Reaction removed" and return focus to the message (§10.2).
- A chip must not move the surrounding layout by more than one row height; the list inserts/removes the row with a 180 ms height animation (instant in Reduced Motion).

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

**Contrast `[R:P1.8]`:** these values were chosen by eye and are **unverified**. Before freezing, the implementer must measure **composited** pairs (the final pixel colours, not the token values) and report numbers for:
- text on bubbles, banner/hint secondary text on `bg.chat`, chip text on `chip.fill`/`chip.mine`;
- `label.text` on the composited `label.fill` over scrim over list content, worst case (white and black list content behind);
- selected disc and ring vs the composited plate (≥ 3:1);
- dimmed `Outside` state: items at 0.6 opacity vs the plate (≥ 3:1 for the glyph's silhouette is not required; the label is the carrier of the information and must stay ≥ 4.5:1 and undimmed);
- with Increase Contrast / Reduce Transparency / high-contrast text on.
Targets: ≥ 4.5:1 for text, ≥ 3:1 for non-text selection indicators. Any substitution is recorded in the README as a shared-contract change applied to both platforms (no silent per-platform theming).

Theme changes while the wheel is open only re-tint; they must not cancel the gesture.

---

## 6. Gesture timelines

All times are from touch-down (`t = 0`). Only the first pointer is tracked.

### 6.1 Happy path: hold → slide → release

`slop` = the **effective** pre-open movement tolerance (§11): `max(8, platform touch slop)` on Android (`ViewConfiguration.getScaledTouchSlop()`), and 10 pt on iOS (matches the scroll view's own pan threshold; assumption to verify). The README records the values actually used. **8 is a target, not a requirement that may override the platform: the list's scroll must win as soon as the platform's own scroll slop is exceeded.** `[R:P0.4]`

| t (ms) | Event | Behaviour |
|---|---|---|
| 0 | Touch-down on a bubble | Record `A`, start the 350 ms long-press timer. **Not started if the touch interrupts a fling/deceleration (E12).** No visual change. |
| 100 | Still held, moved ≤ slop | Pressing state: bubble scale 0.98, 120 ms ease-out. (The delay avoids flashing during a scroll start.) |
| < 350 | Move > slop from `A` | **Long-press aborted.** Press visual reverts in 120 ms; the touch becomes a scroll (the list owns it). |
| < 350 | Lift | A normal tap (no wheel, no reaction). Press visual reverts. |
| 350 | Timer fires | Haptic `open` (§9). Compute placement (§5.3). Start the cascade (§8.1) — or open the Compact picker if placement says so. **The wheel takes ownership of the touch; scrolling is locked** for the rest of the gesture (§11). Bubble returns to 1.0 and lifts above the scrim. |
| 350+ | Move | Each move event: update the selection (§5.2 rules, including the dead zone) in the same frame. Fire the selection haptic on each change (rate limited, §9). |
| any | Cross `commit.enter` (44) | Selection becomes possible. (`arm.distance` 12 only suppresses `Outside`.) |
| any | Capture item i (ρ ≥ 44) | `Selected(i)` / `Selected-remove(i)` springs (§8.2); label crossfades 80 ms. |
| any | Move beyond `capture.stay` | `Outside`: dim 120 ms; label "Release to cancel". |
| any | Return to ρ < 32 | Selection clears silently. |
| any | Lift satisfying the commit predicate (§5.2) | Commit (§8.3) or removal (§8.3b). |
| any | Lift otherwise | Cancel (§8.4). |

The long-press timeout is **350 ms on both platforms**. (Do not use the OS default timeout; it differs per platform and per user setting. Parity is a requirement.) **(tunable)**

### 6.2 Interruption timeline (during the open state)

| Event | Result |
|---|---|
| `touchesCancelled` / `ACTION_CANCEL` (system gesture, call, notification shade, app switch) | Cancel (§8.4), with no haptic. Scroll lock is released. |
| App goes to the background / window loses focus | Cancel instantly, with no animation (state must be clean on return). |
| Rotation / window resize / fold change | Cancel instantly with no animation. |
| Second finger touches down | Ignored. Does not change the selection. Releasing the second finger does nothing. |
| First finger lifts while a second is down | Treated as release of the primary gesture (commit or cancel by state). |
| Theme or font scale change | Re-tint only; geometry is not recomputed mid-gesture. |
| **New touch during the dismiss animation** | **There is no input lock.** The reaction model is updated at the release instant (not at animation end). A new touch-down fast-forwards the dismissal to its end state, scrolling is unlocked, and the touch is then processed as a fresh touch-down (350 ms timer starts at that moment). `[R:P0.4]` |
| Lift during the cascade | Commit or cancel by the current selection and the commit predicate; running animations retarget with velocity preserved. |
| Predictive back / edge back swipe (Android), interactive pop (iOS) | See §11. Treated as a cancel if it takes the touch. |

### 6.3 Cancel forms (user-intended)
1. Release at the centre or in the dead zone (ρ < 44 without a standing selection, or ρ < 32).
2. Release in the `Outside` zone (anywhere farther than the capture radius from all items).
3. Slide off any edge of the screen and release.
All are silent (no error styling). The label has already told the user: "Release to cancel" (in `Outside`) or "Slide to choose" (in the dead zone).

---

## 7. State machine

```
Idle ──touchDown──► Pressing ──350ms──► Opening ──cascade done/any move──► ArmedIdle
  ▲                    │ move>slop / lift       │                             │ ▲
  │                    ▼                        │            capture i (ρ≥44) │ │ clear (ρ<32 or leave stay)
  └────────────── (scroll / tap)                │                             ▼ │
                                                └────────────────────►  Selected(i) ◄──► Outside
                                                                      (Selected-remove(i) if i is current)
 ArmedIdle / Outside ──lift/interrupt──► Cancelling ──► Idle
 Selected(i) ──lift (predicate true)──► Committing ──► Idle     (add or replace)
 Selected-remove(i) ──lift (predicate true)──► Removing ──► Idle
 Selected(i)/Selected-remove(i) ──lift (predicate false)/interrupt──► Cancelling ──► Idle
 Idle ──a11y action / keyboard──► Persistent ──select──► Committing | Removing ; ──dismiss──► Cancelling
 Idle ──held gesture, no radial fit──► Compact ──select──► Committing | Removing ; ──dismiss──► Cancelling
 Idle ──chip tap──► Removing ──► Idle
 Committing | Removing | Cancelling ──new touch──► (fast-forward) Idle ──► Pressing
```

Invariants: exactly one wheel exists at a time; `Committing`/`Removing`/`Cancelling` can be fast-forwarded; the model is updated at the release instant; no state retains a reference to a gesture after `Idle`; every path out of the open state calls the same idempotent `endGesture()` that restores scroll and system-gesture state (§11).

---

## 8. Motion spec

Springs are physical (mass 1). `ζ` = damping ratio, `k` = stiffness. The values below are the **recommended starting parameters and target behaviour**; each platform may parameterize its native spring (`CASpringAnimation` / `UISpringTimingParameters` / `SpringAnimation` / Compose `spring`) differently as long as the **observable behaviour** in the table below is met and measured. `[R:P1.6]`

| Name | ζ | k | Used for |
|---|---|---|---|
| `spring.entry` | 0.62 | 220 | Cascade entry (position, scale). Overshoot ≈ 8 %. Settles in ≈ 450 ms. |
| `spring.select` | 0.70 | 420 | Selected item scale / disc. Overshoot ≈ 5 %. |
| `spring.retreat` | 0.80 | 300 | Non-selected scale and push. Little overshoot. |
| `spring.chip` | 0.60 | 380 | Chip pop-in (scale 0.7→1). |
| `spring.press` | 1.00 | 600 | Bubble press/lift (no overshoot). |

**Observable behaviour (the actual contract):**
- Position and scale are continuous: when the target changes mid-flight there is **no visible jump**; velocity carries over (retarget). On iOS, if exact velocity preservation through presentation-layer state is impractical, a retargeted critically/over-damped transition from the current presentation value is acceptable, provided no jump occurs.
- Overshoot ≤ 10 % for `entry` and `select`, ≈ 0 for `press` and `retreat`.
- Settle (within 2 % of the target) ≤ 500 ms for `entry`, ≤ 350 ms for the others.
- During drag use transforms and opacity only; **at most one animator per item for position+scale** (driven by a retargetable value), never a new animation object per move event. Record the measured overshoot/settle per platform in the README.

### 8.1 Open cascade

- Scrim: 0 → 1 over 180 ms, curve (0.2, 0, 0, 1).
- Plate: fade 0 → 1 over 140 ms; scale 0.6 → 1 about `C` with `spring.entry`.
- Items in index order `i = 0…5`, **delay = 30 ms × i** (total stagger 150 ms; RTL follows the same index order, which already mirrors in space).
- Each item, from `t = delay`:
  - start position = `C + 0.35 × (target − C)`, start scale 0.3, alpha 0
  - end position = target, scale 1.0, alpha 1
  - position and scale use `spring.entry`; alpha uses a 90 ms linear ramp.
- Label fades in at `t = 200 ms` (120 ms linear).
- Moves are accepted from `t = 0` of the opening (hit-testing uses the final geometry).

### 8.2 Selection change
- New selected item: scale → 1.40 with `spring.select`; disc fades in, 90 ms; badge (remove) fades in with the disc.
- Previously selected item: scale → 0.9 (while another is selected) or 1.0, `spring.retreat`.
- Others: scale 0.9 and push 10 tangentially away from the selected item, falling off linearly to 0 two steps away (`spring.retreat`).
- Label crossfades 80 ms; the text is replaced, with no slide.
- Clearing the selection: all items return to 1.0 with `spring.retreat`.

### 8.3 Commit — add or replace (release in `Selected(i)`)
| t (ms) | Behaviour |
|---|---|
| 0 | Model updated. Haptic `commit`. **No input lock** (§6.2). |
| 0–240 | The selected emoji moves to the chip slot (curve (0.3, 0, 0, 1)), scaling 1.4 → 0.57 (16/28). |
| 0–120 | Other items: scale → 0.6, fade out. Plate and label fade out. |
| 60–220 | Scrim fades out. The bubble returns to its normal elevation (`spring.press`). |
| 200 | **Add:** chip row appears (list height animation 180 ms) and the chip pops in with `spring.chip`. **Replace:** no row animation; the chip's emoji crossfades old → new in 120 ms with a 1.0 → 1.1 → 1.0 scale pulse (`spring.chip`). |
| 260 | Idle. Scroll unlocked. |
| — | Announcement (VoiceOver / TalkBack): add: "Reacted with Like" / «Реакция: Нравится»; replace: "Reaction changed to Like" / «Реакция изменена: Нравится». Focus returns to the message. |

### 8.3b Removal `[R:P0.3]`
Removal is its own path. It is not the add animation reversed, and it never flies an emoji anywhere.

| t (ms) | Behaviour |
|---|---|
| 0 | Model updated. Haptic `commit` (same semantic as a commit: the action was confirmed). Wheel items keep the "Remove" label until they fade. |
| 0–120 | Items, plate and label fade out and scale to 0.6 (the selected item does **not** travel). Scrim fades out 60–220. |
| 60–200 | Existing chip shrinks 1 → 0.6 and fades (140 ms). |
| 200–380 | Chip row collapses (list height animation 180 ms). |
| 380 | Idle. Scroll unlocked. |
| — | Announcement: "Reaction removed" / «Реакция убрана». **Accessibility focus returns to the message**, whose value now reads "No reaction". |

The same path serves a chip tap (no wheel layers; chip shrink starts at t = 0) and the Persistent / Compact "Remove" activation. Reduced Motion: 100 ms fade of wheel and chip, row collapses instantly.

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
| Selected item | **No scaling and no push.** The selection is shown by the selected disc (fade 80 ms) + a 2 dp accent ring + the label (+ the "−" badge for removal). |
| Outside | Opacity dim only (it is a fade, so it stays). |
| Commit (add/replace) | 100 ms crossfade-out of the wheel; the chip fades in (or its emoji crossfades) in 100 ms. No fly-to-chip. |
| Removal | 100 ms fade of wheel and chip; row collapses instantly. |
| Cancel | 100 ms fade-out. |
| Chip add/remove | 100 ms fade; no layout animation. |
| Compact picker | Always 100 ms fades. |
| Haptics | **Remain** (Reduced Motion does not mean reduced feedback). |
Information conveyed must be identical in both modes (the selection must be visible without scale).

---

## 9. Haptics `[R:P1.5]`

The contract is **semantic**: which moments produce feedback, and how often. Each platform uses its native feedback within those semantics. Identical strength or waveform is **not** required and OEM variation is expected; verify on physical devices where available.

| Moment | iOS (suggested) | Android (suggested) | Notes |
|---|---|---|---|
| Open | `UIImpactFeedbackGenerator(.medium)` | `HapticFeedbackConstants.LONG_PRESS` | Fire at the same instant as the scrim starts. |
| Selection change (nil→i, i→j) | `UISelectionFeedbackGenerator.selectionChanged()` | API 34+: `SEGMENT_FREQUENT_TICK`; API 30–33: `CLOCK_TICK`; below: `KEYBOARD_TAP` | **Single enforced minimum interval: ≥ 85 ms between ticks (≈ 11.7/s max).** Not fired when clearing the selection. |
| Commit / removal | `UIImpactFeedbackGenerator(.light)` | API 30+: `CONFIRM`; else `VIRTUAL_KEY` | Removal uses the same semantic as commit. |
| Cancel | none | none | Cancel is a non-event. |
| Persistent / Compact select | `.light` impact | `CONFIRM` | Same as commit. |

- Call `prepare()` on iOS generators at `t = 250 ms` (before the open) to avoid latency.
- Respect the OS settings: do not use `FLAG_IGNORE_GLOBAL_SETTING` on Android; iOS honours system haptics automatically. The demo switch can only turn haptics **off**.
- Never vibrate during a Reduced-Motion transition solely because of it.

---

## 10. Accessibility

### 10.1 Principle
A held gesture is not operable for many users. Every action is also reachable through a **persistent, non-gestural path**. The **persistent picker is the conformance route**; the held gesture under a screen reader is not a supported route. `[R:P1.3]`

### 10.2 Message element
- iOS: one accessibility element per bubble. Label: "Alex, message, `<text>`, 10:42". Value: "No reaction" / "Your reaction: Like". Custom actions: **"React…"** (primary; opens the persistent picker) and, **only if a reaction exists**, "Remove reaction". There are **no** per-reaction custom actions on the message (the six reactions are inside the picker). `[R:P1.3]`
- Android: each bubble is a focusable node with the same content description. `AccessibilityNodeInfo` custom actions: "React…" and, conditionally, "Remove reaction"; `ACTION_LONG_CLICK` also opens the persistent picker (so TalkBack's double-tap-and-hold works).
- **Result feedback:** add → "Reacted with Like"; replace → "Reaction changed to Like"; remove (wheel, picker, chip or action) → "Reaction removed". After any of these, accessibility focus is on the message. Cancel is silent. (RU strings in the string table.)
- The reaction chip is a button (§5.5) with its own "Remove Like reaction" action.

### 10.3 Persistent picker (`Persistent` state; same contract for `Compact`)
- Opened by "React…" / long-click / keyboard (below). Anchor = the centre of the bubble (placement §5.3 applies). Cascade follows Reduced Motion rules. If no radial layout fits → Compact, same semantics.
- The container is modal: iOS `accessibilityViewIsModal = true`; Android: pane title "Reaction wheel", content behind marked `importantForAccessibility = noHideDescendants`.
- On open, focus moves to item 0. A screen-changed announcement (iOS) / pane-title announcement (Android): "Reaction wheel. 6 options."
- **Semantic order is linear `0…5`, then the close control, independent of visual rotation, axis or RTL** (RTL does not reverse focus order; index 0 is still first). Items are buttons labelled "Like, 1 of 6" (+ "selected" for the current reaction; the current reaction's action reads "Remove Like reaction"). Activation commits (§8.3) or removes (§8.3b) and announces per §10.2.
- Dismiss: iOS two-finger "Z" scrub (`accessibilityPerformEscape`), visible close control (48×48, "Close"); Android system Back and the same close control; Escape key; a tap on the scrim. After dismissal, focus returns to the originating message.

### 10.4 Held gesture with assistive tech running
Not a conformance route. When VoiceOver/TalkBack owns touch exploration, selection changes are **not** announced during the scrub (to avoid repeated speech); haptics are unchanged. Users are directed to "React…". `[R:P1.3]`

### 10.5 Keyboard, Switch Control, Voice Control (acceptance-level, not optional) `[R:P1.4]`
- A message with keyboard/switch focus: `Space`/`Enter` opens the persistent picker.
- Inside the picker: initial focus on item 0. `Tab` / `Shift-Tab` move next/previous in semantic order (item 5 → close; focus is trapped inside the modal). Arrow keys: `Down` and the arrow pointing toward the reading direction (`Right` in LTR, `Left` in RTL) = next; `Up` and the opposite horizontal arrow = previous; no wrap at the ends. `Enter`/`Space` activates. `Escape` (hardware keyboard) / Back dismisses. Scrim tap dismisses. Focus returns to the originating message.
- Switch Control and Voice Control address the six buttons and the close control by their accessible names ("Like", "Love", …, "Close"); every one is a focusable, ≥ 48×48 element.

### 10.6 Other requirements
- **Touch targets:** items 48×48 minimum (also at the 1.0× scale); the close, settings and chip controls 48×48 (chip via expanded hit area).
- **Font scale / Dynamic Type:** text (label, bubble, chip count, banner, hint) follows system scale. Android up to 200 %, iOS up to AX5. The emoji glyphs scale with `uiScale` up to 1.3×. The label wraps to 2 lines max, then truncates with an ellipsis (the accessible label is never truncated). The chip height grows with the text. Geometry is derived from the final scaled bounds (§5.3.1), with the Compact picker as the deterministic fallback.
- **Contrast:** §5.6. Selection must not rely on colour alone (scale or ring + label; "−" badge for removal).
- **Reduce Transparency / Increase Contrast (iOS), high-contrast text (Android):** the plate becomes opaque; the ring thickens to 3 (drawn inward).
- **Colour independence:** reaction state ("mine") shown by border + a11y value as well as colour.
- **Localization:** EN and RU string tables. All visible and a11y strings are externalised; none hard-coded in code.

---

## 11. Native differences (parity of behaviour, not pixels)

### 11.1 Gesture arbitration contract `[R:P0.4]`

Shared outcome (both platforms): (1) **before open**, the list's scroll wins as soon as the platform's own scroll slop is exceeded, and a lift before 350 ms is a plain tap; (2) **at open**, the wheel takes ownership of the touch and scrolling is locked; (3) **every** end path (lift, cancel, interruption, background, rotation, dispose) calls one idempotent `endGesture()` that restores scroll and system-gesture state; (4) a touch that stops a fling never opens the wheel (E12).

| Topic | iOS | Android |
|---|---|---|
| Recognizer | A custom `UILongPressGestureRecognizer` on the list: `minimumPressDuration = 0.35`, `allowableMovement = 10` (effective slop; recorded). `cancelsTouchesInView = true` (default: cancels the bubble touch only once recognized), `delaysTouchesBegan = false`. Delegate `gestureRecognizer(_:shouldReceive:)` returns `false` when `scrollView.isDecelerating` (E12) or the touch is not on a bubble. | Handle in the list's touch pipeline (`RecyclerView.OnItemTouchListener` or the bubble view's `onTouchEvent`) with a custom 350 ms `Handler` timer, **not** the OS long-press timeout. Compose: custom `awaitEachGesture` with `withTimeout(350)`; do not use `detectDragGesturesAfterLongPress` (it uses the OS timeout). |
| Before open (t < 350) | The scroll pan runs normally and is **not** blocked or required to fail. If the finger moves beyond `allowableMovement`, the long-press recognizer fails and the pan owns the touch. | Do **not** call `requestDisallowInterceptTouchEvent` before open. The child returns `true` for `ACTION_DOWN`; if the parent intercepts after slop, the child receives `ACTION_CANCEL` → cancel the timer, mark `aborted`. The timer runnable checks `aborted` (and the pointer id) before opening, so a slop/timer race on the main thread cannot open the wheel after an abort. |
| At open | On `.began`: set `scrollView.isScrollEnabled = false`; disable `interactivePopGestureRecognizer` if a nav stack exists; keep tracking `.changed`/`.ended`. | `parent.requestDisallowInterceptTouchEvent(true)`; additionally consume the pointer's events so a Compose `Scrollable` ignores them (mark changes consumed). Set `systemGestureExclusionRects` (≤ 200 dp per edge) around the touch strip. |
| Restore (`endGesture()`) | `isScrollEnabled = true`, re-enable the pop gesture, in `.ended`, `.cancelled`, `.failed`, `applicationWillResignActive`, trait/size change, and `deinit`/dismissal. Idempotent. Test asserts `isScrollEnabled == true` after every path. | `requestDisallowInterceptTouchEvent(false)`, clear exclusion rects, in `ACTION_UP`, `ACTION_CANCEL`, `onDetachedFromWindow`, `onWindowFocusChanged(false)`, config change. Idempotent. |
| System edge gestures | Control Centre / Notification edges produce `touchesCancelled` → cancel. | The back gesture can still win → `ACTION_CANCEL` → cancel. Predictive back must not leave the wheel visible. |
| Touch slop | 10 pt (assumed to match the scroll pan threshold; verify). | `getScaledTouchSlop()` (record the value, typically ≈ 8 dp). |

### 11.2 Other platform topics

| Topic | iOS | Android |
|---|---|---|
| Safe area | `safeAreaInsets` of the window (Dynamic Island, home indicator). | `WindowInsets` systemBars + displayCutout + systemGestures (+ IME). |
| Springs | Native spring (`CASpringAnimation` / `UISpringTimingParameters`), tuned to the §8 behaviour. | `SpringForce` via `SpringAnimation` (or Compose `spring(dampingRatio, stiffness)`). |
| Haptics | Impact/selection generators. | `View.performHapticFeedback` constants with API-level fallbacks. |
| Reduced motion | `UIAccessibility.isReduceMotionEnabled` + notification. | `Settings.Global.ANIMATOR_DURATION_SCALE`. |
| A11y | `UIAccessibilityCustomAction`, modal views, `.screenChanged` / `.announcement` posts. | `AccessibilityNodeInfo` actions, pane titles, `announceForAccessibility`. |
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
| E1 | Release without any move | Cancel (ρ < 44). No reaction. |
| E2 | Tiny finger tremor after open | Ignored under 12 (no `Outside`); never selects (< 44). |
| E2b | Post-hold drift of 20–30 toward an item, then release `[R:P0.1]` | Cancel. The dead zone (44) prevents selection. |
| E2c | Selecting an item, then slowly returning toward the anchor `[R:P0.1]` | Selection clears at ρ < 32 (silent); release then cancels. |
| E3 | Release outside the capture zone | Cancel; the label has already shown "Release to cancel". |
| E4 | Slide past the wheel to the screen edge and back | The selection follows the rules; the edge does not cancel by itself. |
| E5 | Finger leaves the screen bounds (Android off-screen coordinates) | Treated as `Outside`. |
| E6 | Message at the left / right / top edge or corner | §5.3. |
| E7 | Message at the bottom, under the bottom bar or keyboard | Up-facing arc within the visible window. |
| E8 | Landscape, short windows | The single fit test (§5.3.1) includes the label. If no candidate passes, **Compact** (§5.3.2). The label is never allowed to overlap items. |
| E9 | Split-screen / foldable / tablet | Use the window bounds. R does not scale with the window size. If the window is too small, **Compact**. A fold/size change while open cancels (§6.2). |
| E10 | RTL | Index order mirrors for up/down/diagonal axes (§2.1); placement uses physical sides; focus order stays 0…5. |
| E11 | Large font scale | `uiScale` ≤ 1.3 for geometry; the label wraps to 2 lines; extents are recomputed at each open (§5.3.1); Compact if needed. |
| E12 | Long-press while the list is still decelerating (fling) `[R:P0.4]` | **A touch that stops a fling never opens the wheel on either platform** (Android's list intercepts that `DOWN`; iOS ignores the touch via the delegate). The user lifts and holds again. This replaces the earlier "timer starts from that touch" rule. |
| E13 | Reaction already present | Ring + "Remove" label + "−" badge; toggles via `Removing` (§8.3b). |
| E14 | Rapid repeated gestures | Each open/close fast-forwards the previous one (§6.2). Max one wheel. |
| E15 | Message deleted/scrolled while open | Not possible: the list is locked. Programmatic changes are out of scope. |
| E16 | Reduced Motion toggled while open | Applies from the **next** open. |
| E17 | Theme toggled while open | Re-tint only. |
| E18 | Haptics unsupported (simulator, some emulators) | Silent no-op; never throws or logs errors repeatedly. |
| E19 | Mouse / stylus (simulator / emulator pointer) | Press-and-hold works the same; hover is ignored. |
| E20 | Touch-down on a chip or the banner/hint | The wheel does not open there (only on bubbles). A chip tap removes (§5.5). |
| E21 | Very long press (> 10 s) with no move | The wheel stays open; no timeout. |
| E22 | Memory warning / low memory | State is dropped to Idle; the demo reactions are in memory only (documented). |
| E23 | Chip tap that becomes a scroll `[R:P1.9]` | The press is cancelled; nothing is removed. |
| E24 | Replace reaction (X → Y) | Chip stays, emoji crossfades; announces "Reaction changed to Y" (§8.3). |
| E25 | Persistent opened on a message whose bubble centre is near an edge | Same placement/fit rules with `A` clamped into the safe rect; Compact if it cannot fit. |

---

## 13. Instrumentation for verification

Stable test identifiers (iOS `accessibilityIdentifier`, Android `contentDescription` is for users, so use `testTag` / `resource-id`):

`chat.list`, `chat.hint`, `chat.message.<n>`, `chat.chip.<n>`, `wheel.root`, `wheel.scrim`, `wheel.plate`, `wheel.item.0`…`wheel.item.5`, `wheel.label`, `wheel.close`, `compact.root`, `compact.item.0`…`compact.item.5`, `compact.close`, `settings.open`, `settings.theme`, `settings.reduceMotion`, `settings.haptics`, `settings.debug`, `settings.reset`.

Debug overlay (`settings.debug`) draws: the anchor, the wheel centre, the arm radius (12), the **commit.enter (44) and commit.exit (32) rings around the anchor**, the capture (80) and stay (96) circles per item, the chosen axis, the shift `s`, the chosen label slot, the fit result, and the current state name. It must never be shown by default.

**Shared geometry fixtures** `[R:P1.2][R:P1.7]`: a single data file (JSON, committed in the concept folder and consumed by both platforms' tests) holds, for the pure placement function: synthetic window bounds + insets, `uiScale`, mode, anchor, and the expected axis, `s` (±1 for density rounding), `Compact` yes/no, and the invariants (all items inside the safe rect, unique targets, label/close disjoint). It covers every axis × LTR/RTL, the four 1.0× examples, the 1.3× example, a 240-dp window, landscape and a fold-sized window. Item angles are asserted from §2.1's formula.

**Gesture/state tests** (pure state machine, driven by synthetic events with an injected clock): tap, slow scroll, fling-stop then drag, hold then scrub, hold then 20–30 drift then release, slow return across the dead zone, parent cancellation, new touch during dismissal, background during open, second pointer.

---

## 14. Cross-platform acceptance criteria

Each criterion must pass **on both iOS and Android**, in light and dark, unless noted. **Evidence classes:** **A** = automated test (unit / state machine / fixtures), **E** = simulator/emulator recording or logged measurement, **P** = physical device. A criterion may only be marked passed with the evidence class actually obtained; if no physical device is available, record "P: not run" — never claim it. Nothing may be marked passed without having been run.

**Reference profiles (name the ones used in the README):** iOS Simulator, an iPhone 15-class device (390×844 pt) on the latest available iOS; Android Emulator, a Pixel 8-class AVD (API 34) plus a minimum-API AVD for the haptic/emoji fallbacks. Anything else used is recorded as an additional profile. (Assumption: these profiles are available on the build machine; substitute and record if not.)

### Gesture & logic
- **AC-01** (A, E) Touch-down + still hold of 350 ± 30 ms opens the wheel. A lift before 350 ms is a tap and never opens it.
- **AC-02** (A, E) A move beyond the **effective slop** (§6.1; value recorded) before 350 ms aborts the long-press and the list scrolls. No wheel opens after an abort, including under a slop/timer race.
- **AC-03** (A, E) Once open, the list does not scroll, and the finger can move freely without lifting.
- **AC-04** (E) The wheel shows 6 items on a 180° arc in the §2.1 index order with the radius and sizes of §5.2.
- **AC-05** (A, E) `[R:P0.1]` Releasing with ρ < 44 from the anchor never commits, including: (a) no movement, (b) 20–30 drift toward an item in any direction including diagonals, (c) selecting an item then returning below ρ = 32 and releasing. Selecting requires ρ ≥ 44; the selection persists down to ρ = 32.
- **AC-06** (A, E) Sliding to an item (ρ ≥ 44) selects the nearest one (80 enter, 96 stay, 8 switch margin); the label shows its name. The commit predicate is evaluated on the release coordinates.
- **AC-07** (E) Releasing on a selected item commits the reaction and shows a chip under that message.
- **AC-08** (A, E) Releasing at the centre, in the dead zone, or outside the zone cancels; no reaction is added or changed; "Release to cancel" is visible before release in `Outside`.
- **AC-09** (A, E) `[R:P0.3]` Toggle-on adds; replace changes the chip in place; toggle-off (selecting the current reaction) uses the `Removing` path: "Remove" label + badge while selected, no fly-to-chip on release, chip shrinks, "Reaction removed" announced, focus on the message. Tapping the chip does the same with no confirmation.
- **AC-10** (A, E) `ACTION_CANCEL`/`touchesCancelled`, backgrounding, rotation: the wheel closes, with no reaction and no stuck scrim or locked scroll (scroll-enabled state asserted after every end path).
- **AC-11** (A) A second finger never changes the selection.
- **AC-12** (A) `[R:P1.7]` Placement is verified as **invariants and fixtures** (§13), not hand-computed pixels on a device: for every fixture, all item centres are inside the safe rect by `extent.inset`, targets are unique, the label and (in Persistent) close control are inside and disjoint from items, the correct axis/`Compact` result is chosen, and `s` matches within ±1 for density rounding. The four 1.0× examples and the 1.3× example of §5.3.2 are among the fixtures. With a notch or gesture inset present, no item overlaps it.
- **AC-13** (A) The `hold.anchorNearest ≥ 96` invariant holds in every held placement; the wheel never selects an item on open.
- **AC-31** (A, E) `[R:P0.2]` At Android 200 % font and iOS AX5, on the smallest supported window, with corner anchors and in Persistent mode: either the radial layout passes the fit test (no item, label or close control clipped in idle *or* selected state) or the Compact picker opens. Re-checked after a font-scale change between opens.
- **AC-32** (A, E) `[R:P0.5]` Compact picker: all six buttons ≥ 48×48 and non-overlapping, index/focus order 0…5 then close, scrolls when taller than the window, cancellation works (close, scrim, Back/Escape), current reaction shown; verified on a small window, split-screen, landscape and a fold-sized window. A held gesture that lands in Compact does not commit on lift.
- **AC-33** (A, E) `[R:P0.4]` Arbitration tests of §13 pass on both platforms: tap, slow scroll, fling-stop then drag (never opens the wheel), hold then scrub, parent cancellation, new touch during dismissal (fast-forward + processed as a fresh touch), and the recorded effective slop values.

### Motion & feel
- **AC-14** (E) The cascade runs with a 30 ms stagger; entry overshoot is visible but ≤ 10 % and settles ≤ 500 ms. Measured values are recorded per platform (§8).
- **AC-15** (E) The selected item scales to 1.40 and the others to 0.90 with a tangential push; the change is continuous (no jump) on fast scrubs, and animations retarget without restarting from rest.
- **AC-16** (E) Commit, removal and cancel follow §8.3 / §8.3b / §8.4 within ±30 ms of the stated durations.
- **AC-17** (E, P if available) Frame pacing: while dragging with the wheel open, ≥ 95 % of frames meet the display's budget (16.7 ms at 60 Hz) on the named reference profile. Report the tool and the number (iOS: Instruments / `CADisplayLink` drops; Android: `dumpsys gfxinfo` or a Perfetto trace). No layout/measure pass per move event. Emulator numbers are labelled as such.
- **AC-18** (A, E) A new touch during a dismiss animation is processed without a visible glitch or a dropped touch (no input lock; §6.2).

### Haptics
- **AC-19** (A via call log; P for feel) There is exactly one `open` haptic, one tick per selection change with ≥ 85 ms between ticks, one `commit` (also for removal) haptic, and none on cancel. On the simulator/emulator, verify the call is made via a log. Physical feel is checked on a device if available; no waveform parity is required.
- **AC-20** (A) The haptics switch off stops all calls, and the OS-level setting is respected.

### Theme & layout
- **AC-21** (E) Light and dark both use the §5.6 tokens, with **composited** contrast measured and reported for the pairs listed there (≥ 4.5:1 text; ≥ 3:1 selection ring/disc; label undimmed in `Outside`). The theme can change while the wheel is open without cancelling it.
- **AC-22** (E) Layout is correct in portrait and landscape, on a small phone (≈ 360 dp wide) and a large one; RTL mirrors the index order for up/down/diagonal axes and keeps focus order 0…5.

### Accessibility
- **AC-23** (A, E) Reduce Motion (OS or override): no cascade, no scale, no push, no fly-to-chip; opening is a ≤ 100 ms fade; the selection remains clearly visible (disc + ring + label, and badge for removal); haptics remain.
- **AC-24** (E) `[R:P1.3][R:P1.4]` VoiceOver and TalkBack: every message exposes **"React…"** (and "Remove reaction" when a reaction exists); the persistent picker opens, focus lands on item 0, items read "Name, n of 6", activation commits, and Escape/Back/Close/scrim dismiss and return focus to the message. Keyboard and Switch/Voice Control: open with `Space`/`Enter`; `Tab`/arrows traverse in semantic order 0…5 then close (verified under RTL and a rotated axis); `Enter` activates; `Escape` closes; focus is restored.
- **AC-25** (E) Results are announced: "Reacted with …", "Reaction changed to …", "Reaction removed"; cancel is silent. Rapid held-gesture selection changes are **not** announced.
- **AC-26** (A, E) Items and controls are ≥ 48×48 (chip via hit area); the layout survives font scale 200 % (Android) and AX5 (iOS) with no clipped text in the wheel label (wraps to 2 lines) — see AC-31.
- **AC-27** (E) With Increase Contrast / Reduce Transparency, the plate is opaque and the ring is thicker.
- **AC-34** (E) `[R:P1.1]` The hint row is always visible with EN and RU strings; the settings button has an accessible name "Demo settings".

### Product & compliance
- **AC-28** (E) The demo banner "Demo data — not connected to Telegram" is always visible; the EN and RU strings are present.
- **AC-29** (A) Only public mock data is used. No Telegram logos, icons, emoji art or sounds are bundled. No network calls are made.
- **AC-30** (E) Each platform runs independently, and its README documents the exact build and run commands, with the results of those commands as actually executed, the reference profiles used, and which evidence classes (A/E/P) were obtained for each AC.

---

## 15. Open questions / assumptions

1. **Assumption:** `commit.enter = 44` / `commit.exit = 32` suit one-handed thumb use. They are derived from the geometry and the reviewer's 40–48 range, **not yet validated on a physical phone**. Tune on a device if one is available; otherwise ship the initial values marked "unverified on physical device" in the README. **(tunable)**
2. **Assumption:** `capture.enter = 80` with nearest-item selection suits finger use; on large tablets it may feel small. If feel-testing demands it, scale it with `uiScale` only. **(tunable)**
3. **Assumption:** the 350 ms timeout is slightly shorter than the OS defaults (iOS 500 ms, Android 400 ms), to make the wheel feel responsive. If it causes accidental opens while scrolling, raise it to 400 ms on both. **(tunable)**
4. **Assumption:** the iOS effective slop of 10 pt matches `UIScrollView`'s pan threshold; verify and record.
5. **Assumption:** the corner case (§5.3, shift up to 120) is rare in a real chat layout because bubbles are inset; it is a documented limitation rather than a primary flow.
6. **Assumption:** the reference profiles of §14 are available; substitute and record if not.
7. **Not designed (out of scope):** reaction sync, notifications, animated emoji, multiple reactions per user, "more" picker.
8. **Unverified:** all contrast ratios, the spring values' feel, and Android haptic strength on OEM devices are design estimates until measured.

---

## 16. Review resolution log (revision 2) and explicit design decisions

Reviewer: Codex (`DESIGN_REVIEW.md`). Status key: **Adopted** = done as requested; **Adapted** = intent adopted, mechanism changed; **Disagree** = deliberate decision, rationale given.

### P0

| Item | Status | Resolution |
|---|---|---|
| P0.1 dead zone | **Adopted** (+ one **Disagree**) | `commit.enter = 44` (within 40–48), `commit.exit = 32`; `arm.distance = 12` kept only as the tremor / `Outside` guard; commit predicate on release coordinates; nearest-centre selection stated explicitly; AC-05 and E2b/E2c cover diagonal drift, 20–30 drift, slow return. **D-1 (Disagree):** physical-device validation is *recommended and recorded*, but is **not a build gate**: a demo may ship with the initial values flagged "unverified on physical device" rather than blocking on hardware the build may not have. |
| P0.2 scaled inset | **Adopted** (+ **Disagree** on shadow) | Inset derived from the rendered selected-item radius at the active `uiScale` (`extent.inset`); single fit test includes label and close control; re-run every open; worked 1.3× example; AC-31. **D-2 (Disagree):** the decorative `shadow.wheel` is **excluded** from extents (it may fade beyond the safe rect but never beyond the window); the 2 dp ring is drawn *inside* the item box, so it adds no extent. Including a 20-dp blur would shrink usable space for no functional gain. **D-3:** the `uiScale` cap of 1.3 is kept; beyond it the Compact picker, not larger geometry, absorbs the difference. |
| P0.3 removal | **Adopted** | `Selected-remove` state (label + "−" badge), distinct `Removing` path (§8.3b), "Reaction removed" announcement, focus to the message, chip is a button with its own action and press state, replace has its own in-place crossfade and announcement. No confirmation (as the reviewer agreed). |
| P0.4 gesture ownership | **Adopted** (+ **Adapted** slop) | Per-platform arbitration contract (§11.1) with the same user outcome, idempotent `endGesture()`, recorded effective slop (8 is a target; the platform scroll slop wins), "input locked" contradiction resolved (no lock; model updated at release; new touch fast-forwards). **D-4:** a touch that stops a fling never opens the wheel on either platform (E12) — Android's list intercepts that `DOWN`, so "timer from that touch" was not implementable; making iOS match preserves parity. |
| P0.5 fallback | **Adopted** (+ **Adapted** form) | Independent clamping and nearest-item-only hit testing removed. The single fit test covers items at selected size, label, close control and insets; the deterministic fallback is the **Compact picker**. **D-5 (Adapted):** Compact is an in-app panel, not a platform menu, so both platforms behave identically, it can host the close control and long names, and it scrolls. |

### P1

| Item | Status | Resolution |
|---|---|---|
| P1.1 discoverability | **Adopted** (+ **Disagree**) | Persistent hint row; gear replaced by a native icon with accessible name "Demo settings"; success criterion rewritten to "after the hint". **D-6 (Disagree):** unaided discovery is *observed*, not a pass/fail gate, since a demo with a visible hint is the intended experience. |
| P1.2 mapping | **Adopted** (+ **Disagree**) | Mapping defined in screen coordinates (index grows toward +x for up/down/diagonal axes, +y for left/right), RTL rule, formula, wireframes and worked examples corrected (the old 4.3 wireframe contradicted "clockwise"), shared fixtures (§13). Label/haptic preview before commit already exists. **D-7 (Disagree):** arc rotation near edges is **kept**; a stable non-radial layout is not used except as the Compact fallback, because rotation with a fixed screen-coordinate ordering keeps horizontal muscle memory for the common up/down cases and only left/right axes (edge cases) re-map. Revisit if testing shows errors. |
| P1.3 too many a11y actions | **Adopted** | "React…" primary, "Remove reaction" conditional; per-reaction message actions **dropped** (they live in the picker); held-gesture announcements dropped; emoji names come from the string table. |
| P1.4 keyboard/focus | **Adopted** | §10.5, semantic order 0…5 + close, arrows/Tab/Enter/Escape, focus restoration; moved from P2 into AC-24. |
| P1.5 haptics | **Adopted** | Semantic contract; single enforced minimum interval 85 ms (≈ 11.7/s); platform-native constants are suggestions; no waveform parity; AC-19. |
| P1.6 springs | **Adapted** | ζ/k kept as *recommended starting parameters*; the contract is the observable behaviour (continuity, overshoot ≤ 10 %, settle times, one animator per item). **D-8:** I keep numeric starting values rather than removing them, so the two builds begin from the same feel; platforms may deviate if measured outcomes are recorded. |
| P1.7 verification | **Adopted** (+ **Adapted**) | AC-12 now tests invariants/fixtures; reference profiles named; evidence classes A/E/P; physical checks never claimed if not run. **D-9:** the worked-example coordinates stay in the document as illustrations and fixtures, not as ±2 on-device pixel assertions. |
| P1.8 colour | **Adopted** | Composited-contrast measurement list; label never dimmed; `Outside` dim 0.5 → 0.6; substitutions recorded in the shared contract. |
| P1.9 chip affordance | **Adopted** | Pressed state, button semantics, 48-pt hit area, scroll-cancel (E23), wheel toggle-off as primary, chip tap as shortcut, no confirmation. |

### Additional inconsistencies found and fixed while revising
- §4.3 wireframe put index 0 on the right for a down-facing arc, contradicting "clockwise"; resolved by §2.1.
- `item.selectedScale` comment claimed 67 fits a 66.7 chord; corrected (it overlaps by 0.5, neighbours retreat).
- Haptic "40 ms rate limit / max ≈ 12/s" contradiction → one 85 ms interval.
- AC-24 required "one action per reaction" on messages, contradicting P1.3 → removed.
- "Input locked" vs "new touch fast-forwards" → no lock.
- Settings glyph "⚙" (text, unspecified a11y name) → native icon + name.
- Old step 5 of placement and E8 allowed label/item overlap → fit test includes the label.
- No state existed for removal, replacement, compact or chip press → added.
