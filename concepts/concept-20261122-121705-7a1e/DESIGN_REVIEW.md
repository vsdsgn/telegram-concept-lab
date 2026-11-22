# Reaction Wheel — Independent Design Review

Reviewed: `UX_DESIGN.md`, repository `DESIGN.md`, and `SPEC.md`.

## Decision: changes required

The proposal is unusually complete in its state model, cancellation paths, reduced-motion treatment, edge placement intent, and cross-platform acceptance criteria. It is not ready to implement unchanged, however. The P0 items below contain behavioral contradictions or geometry/gesture choices that can produce accidental reactions, clipped controls at accessibility sizes, or platform-specific failures. Resolve the P0 items in the shared design contract before implementation. P1 items may be resolved during implementation only if the chosen behavior is documented identically for both platforms.

## P0 — blocking issues

### P0.1 — The effective commit dead zone is much smaller than the stated safety model implies

`arm.distance = 12` only gates selection; it does not define a safe radial excursion. With item centres roughly 103–108 pt from the anchor and `capture.enter = 80`, an item can be captured after only about 23–28 pt of movement toward it. A small post-hold thumb drift can therefore select and commit on release. This conflicts with the success criterion that slipping away must not commit and with the stated rationale that the wheel prevents accidental commits. The overlapping 80 pt capture circles also make selection primarily a nearest-centre computation rather than six 48 pt targets, which is reasonable but should be explicit.

**Required change:** define a separate minimum radial selection/commit excursion, initially 40–48 pt/dp, that must be crossed before `nil -> Selected(i)`. Keep the 12 pt threshold only as tremor/arming feedback if desired. Require release to satisfy both the radial threshold and the selected sector/capture rule. Add acceptance cases for diagonal drift, 20–30 pt drift followed by release, and a slow return across the dead zone. Validate and tune on physical phones with one-handed thumb use; do not approve 12 pt as the only commit guard based on emulator testing.

### P0.2 — Large-text geometry uses an unscaled safe inset

The design scales both `item.size` and the wheel radius up to 1.3×, but the placement safe inset remains `safe.margin + 34`, where 34 is the half-size of a selected item only at 1.0×. At 1.3×, a selected item is about 87 pt/dp across and needs approximately 44 pt/dp of clearance before the extra safe margin. An item can pass placement while idle and then clip into an edge, cutout, or system-gesture inset when selected. This contradicts AC-12 and AC-26.

**Required change:** derive all placement extents from final rendered bounds at the active `uiScale`: selected item radius, ring/stroke, shadow allowance if applicable, label bounds, and close button in persistent mode. Re-run candidate placement whenever font scale changes before an open. Add worked examples and tests at Android 200% and iOS AX5 on the smallest supported window, including corner anchors and persistent mode. If six scaled items plus label cannot fit, specify a deterministic compact/list fallback rather than independently clamping item centres into an overlapping layout.

### P0.3 — Removing an existing reaction has no coherent commit transition or accessible result

The wheel says choosing the current reaction removes it, but §8.3 always flies the selected emoji to a chip slot, makes a chip appear, and announces “Reacted with …”. That is the opposite of removal. Direct chip removal also has no explicit VoiceOver/TalkBack action/result announcement or focus-restoration rule. This is a destructive toggle, albeit a low-severity and easily reversible one, so confirmation is unnecessary; clear preview and result feedback are necessary.

**Required change:** define a distinct `Removing` result path. On selection, keep the “Remove <reaction>” label and a removal-specific accessible label. On release, dismiss the wheel and remove/fade the existing chip without a fly-to-chip animation; announce “Reaction removed” and return accessibility focus to the message. Define whether tapping the chip is supported, expose it as a button with “Remove <reaction>”, and specify its announcement and focus behavior. Add toggle-on, replace, toggle-off, and chip-removal acceptance tests.

### P0.4 — Gesture ownership is underspecified and the proposed iOS/Android mechanisms do not guarantee the promised behavior

The contract promises that moving more than 8 pt/dp before 350 ms aborts into normal scrolling. On iOS, a `UILongPressGestureRecognizer` attached inside a scroll view needs an explicit failure/simultaneous-recognition and touch-cancellation policy; merely setting duration and allowable movement does not specify when the scroll pan wins or whether the bubble receives a normal tap. On Android, a child handling a custom timer cannot simply “become a scroll” after consuming the initial down event; parent interception, touch slop, cancellation, nested scrolling, and `requestDisallowInterceptTouchEvent` timing must be defined. A fixed 8 dp also may differ materially from the platform’s configured touch slop.

**Required change:** specify the recognizer arbitration contract per platform while preserving the same user outcome. Before open, the list pan must be allowed to win once platform touch slop is exceeded; at open, the wheel takes ownership and scrolling is locked; every end/cancel path restores the prior scroll state. Treat 8 as a target, not a requirement that overrides native touch slop—record the effective value. Add automated/state tests for tap, slow scroll, fast fling-stop then drag, hold then scrub, parent cancellation, and a new touch during dismissal. Clarify the current contradiction between “input locked” during commit and the requirement that a new touch fast-forwards dismissal and is processed.

### P0.5 — The fallback placement can destroy operability

For a window below roughly 240 dp, the proposed fallback clamps each item centre independently and switches to nearest-item hit testing. Multiple centres can collapse onto the same position, visual order can cease to match focus order, and 48×48 targets can overlap. The label is not included in candidate validity, and the persistent close target is not included either. This is not merely a known visual limitation; it can make choices ambiguous or unreachable.

**Required change:** replace independent clamping with a deterministic accessible fallback. A compact vertical/horizontal persistent picker or platform menu is acceptable when the radial layout plus final extents cannot fit. The fallback must preserve all six unique buttons, reading/focus order, cancellation, current-reaction state, and minimum targets. Define a single fit test that includes items at maximum selected size, label, close control, and safe insets, then add small-window, split-screen, landscape, and fold tests.

## P1 — important recommendations

### P1.1 — Core interaction discoverability is not supported by the idle screen

Nothing visible indicates that message bubbles can be held, yet success expects a first-time user to complete the gesture unaided. The instruction appears only after the hidden long press has succeeded. The settings gear also uses a glyph whose spoken/localized label is unspecified.

**Recommendation:** add a concise, persistent demo hint near the list such as “Hold a message, slide to a reaction, then release,” while retaining the separate demo-data disclosure. Give the settings button a localized visible or accessible name. Test discovery without coaching; otherwise rewrite the success criterion to measure the gesture after entry has been shown.

### P1.2 — Rotating the arc changes the learned spatial mapping

Up, down, side, and diagonal placements preserve index order but move reaction meanings to different physical directions. A user acting from muscle memory can choose the wrong reaction near an edge. The hand-drawn left-edge example also labels items `0…5` in a way that should be reconciled precisely with “clockwise” and RTL mirroring.

**Recommendation:** define mapping in screen coordinates for every axis and RTL case, not only “clockwise.” Prefer preserving reading-start-to-end order along the visible arc and require the label/haptic preview before commit. Include transition tables or generated geometry fixtures shared by both implementations. Consider a stable non-radial fallback near extreme edges if rotation proves error-prone in testing.

### P1.3 — Accessibility exposes too many equivalent entry actions

Each message proposes “React…”, six direct reaction actions, “Remove reaction”, long-click, and the persistent picker. On small action menus this is noisy and makes the primary route harder to find. TalkBack/VoiceOver held-gesture pass-through announcements are described as best-effort but add significant complexity and risk repeated speech during scrubbing.

**Recommendation:** make “React…” the primary custom action and “Remove reaction” conditional. Treat six direct actions as optional only if tested usable in both screen readers; otherwise keep them inside the persistent modal. Do not announce rapid held-gesture selection changes when a screen reader owns touch unless the platform reliably supports that path; the persistent picker should be the conformance route. Specify accessible names for emoji independent of locale/system emoji pronunciation.

### P1.4 — Persistent mode is missing complete non-touch keyboard/focus behavior

Keyboard support is called P2, but Switch Control, Voice Control, hardware keyboard reachability, focus order, and modal dismissal are part of the stated success criteria. The contract says arrows move focus without defining initial focus on RTL/rotated layouts or whether focus follows visual or semantic order.

**Recommendation:** define a linear semantic order `0…5` independent of visual rotation, Tab/arrow behavior, activation, Escape/Back, scrim dismissal, and focus restoration. Add these to AC-24 rather than leaving them as an optional implementation detail.

### P1.5 — Haptic parity is over-specified where native semantics differ

Android constants such as `LONG_PRESS`, `CLOCK_TICK`, and `CONFIRM` are device/OEM dependent and are not perceptually equivalent to iOS impact generators. A 40 ms rate limit permits 25 calls per second, while “max ≈ 12/s” implies at least about 83 ms; those requirements conflict.

**Recommendation:** specify semantic moments and a single enforceable minimum interval (at least 80–85 ms for 12/s), then allow platform-native feedback within those semantics. Verify on physical devices but do not require identical tactile strength or waveform.

### P1.6 — The spring contract is not equally implementable as written

Android `SpringAnimation` supports velocity-preserving retargets directly. On iOS, repeatedly retargeting independent `CASpringAnimation`s with presentation-layer state and velocity is substantially more complex, and `UISpringTimingParameters` does not expose the same `k`/`ζ` contract in a drop-in way. Requiring exact physical constants plus exact timing and uninterrupted velocity may encourage fragile animation plumbing.

**Recommendation:** prioritize observable behavior: continuous position/scale, no jump on scrub, bounded overshoot, and settled duration ranges. Permit native spring parameterization per platform, documented with measured outcomes. Use transforms and opacity only during drag, as already required, and cap concurrent animation objects rather than creating a new animation for every move event.

### P1.7 — Verification scope is larger than the demo’s likely build budget and contains non-deterministic pixel requirements

AC-12 requires hand-computed centres within ±2 even though safe areas, font scale, density rounding, emoji metrics, and window configuration vary. AC-17 asks for meaningful mid-range performance evidence but does not name reference OS/device profiles. Physical-device haptics and a broad accessibility matrix are also mandatory without distinguishing release-blocking evidence from documented limitations.

**Recommendation:** test geometry as invariants (inside safe rect, unique targets, correct radius/angles within density rounding) and unit-test the pure placement function with fixed synthetic bounds. Name one simulator/emulator profile per platform plus any available physical-device checks. Separate automated, emulator, and physical-device evidence, and never claim unavailable physical checks passed.

### P1.8 — Colour and state tokens remain unverified

The document acknowledges that contrast was chosen by eye. Secondary text, translucent labels/plates over variable content, disabled/dimmed wheel content, and selected-disc/ring combinations need composited contrast checks. A 0.5-opacity `Outside` state can make the cancellation label or items difficult to perceive.

**Recommendation:** measure composited foreground/background pairs before freezing tokens, including dimmed, high-contrast, and transparency-reduction states. Keep cancellation text at readable contrast even if the wheel items dim. Record substitutions in the shared contract rather than silently changing platform themes.

### P1.9 — “Tap own chip to remove” needs a clearer visual affordance

A reaction chip normally reads as status, not a destructive control. Removing it on a single tap is efficient but not discoverable and can be triggered accidentally while scrolling.

**Recommendation:** ensure the chip has a pressed state, button semantics, and an accessible “Remove …” action. Consider making wheel toggle-off the primary removal path and chip tap a documented shortcut. No confirmation dialog is needed because removal is low impact and immediately reversible.

## Strengths to preserve

- Cancellation and interruption cases are enumerated, including backgrounding, rotation, second pointers, and system gesture loss.
- Reduced Motion removes travel, scale, and spring motion while retaining non-motion selection cues.
- The persistent picker is the right accessibility strategy for a gesture that otherwise requires holding and scrubbing.
- Rendering guidance correctly avoids layout/measure work on pointer moves and should support the 60 fps target with six items.
- Demo-data disclosure, public mock content, system emoji use, and absence of backend/network behavior respect the repository constraints.
- Resetting all demo reactions is the only high-scope destructive action and appropriately requires confirmation; individual reaction removal should remain confirmation-free.

## Approval gate

Approval can be granted once P0.1–P0.5 are incorporated into the shared behavior contract and their acceptance criteria no longer contradict the interaction/motion sections. At minimum, the revised design must provide: a true commit dead zone; scale-aware fit geometry and a usable compact fallback; a distinct removal path; explicit iOS/Android gesture arbitration; and fit validation that includes persistent accessibility controls. P1 items should be either adopted or explicitly recorded as implementation limitations/decisions before platform work begins.
