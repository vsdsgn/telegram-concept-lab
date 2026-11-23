# Claude Code Review

Status: I read the full iOS source, `UX_DESIGN.md` rev 2 and `DESIGN_REVIEW.md` without editing or running anything. Every finding is from reading the code. I did no build, test or simulator run, and I did not inspect the Android code (outside my sandbox). The README says the build succeeded and that tests were compiled but never executed. I'm treating both as unverified.

Paths below are relative to `concepts/concept-20261122-121705-7a1e/ios/ReactionWheel/`.

## P0 blockers

**None confirmed from static reading.** Two gate risks can only be settled by running the app:
- **Scene lifecycle (guess, unverified).** `AppDelegate.swift:5` builds `UIWindow(frame: UIScreen.main.bounds)` with no scene manifest. iOS 26 already warns that UIScene adoption will become mandatory. Launch on the newest runtime must be checked. Fix: add a `SceneDelegate` plus `UIApplicationSceneManifest`, and size the window from `windowScene`.
- **Dark-mode plate colour (likely, unverified).** `ReactionWheelView.swift:41` and `:103`, and `MessageCell.swift:44`, store `Palette.*.cgColor` from dynamic colours. These resolve once, under whatever `UITraitCollection.current` is at that moment. The plate can render light in dark mode, and the chip border can keep the wrong accent after a theme switch. The design says a theme change must only re-tint. Fix: resolve with `color.resolvedColor(with: traitCollection)` in `registerForTraitChanges` or `layoutSubviews`.

## P1 bugs and logic (confirmed by reading)

1. **"Outside" state never clears.** `ReactionWheelView.swift:99`: `guard selected != index || outside` returns early for `(nil, outside:false)` when `selected` is already nil. After the finger goes Outside and returns toward the centre (ρ<32), the items stay at 0.6 alpha and the label keeps saying "Release to cancel". Fix: track an explicit `isOutside` flag and compare it too.
2. **Dead-zone state differs from the design.** `:89` sets `outside = rho >= 12` whenever nothing is selectable. At 32≤ρ<44 near an item the wheel dims and says "Release to cancel", but at 12–32 it does not. The design (§5.2) calls this region `Armed-idle` ("Slide to choose"). Fix: `outside` should require ρ≥12 and no item within `capture.stay` (96).
3. **The label covers items on left and right axes.** `WheelGeometry.swift:74` tests label clearance as a circle (`distance > selectedRadius + 28`), but the label is a fixed 220×40 rect (`ReactionWheelView.swift:58`). For the design's left-edge example, C=(42,500), the label centre is (206,500) and covers the middle two items at (144.7, 466.6/533.4). The design requires the label rect to be disjoint from every selected-size item circle (§5.3.1.2), and the label is drawn on top. Fix: use a rect-vs-circle test, and measure the label with `systemLayoutSizeFitting` (max width 240) for the fit test and for the label's `bounds`. The fixed height of 40 also clips two lines at AX sizes.
4. **The scroll lock is cancelled immediately.** `ChatViewController.swift:30` sets `isScrollEnabled = false`, then `openWheel` (`:35`) calls `cancelWheel(animated:false)`. With no wheel yet, `:39` sets `isScrollEnabled = true`. So AC-03 relies only on gesture exclusivity. Fix: lock after `openWheel`, or move the cleanup out of the open path.
5. **Every row reserves chip space.** `MessageCell.swift:59` pins the chip with `top = bubble.bottom + 4`, `height ≥ 28` and `bottom = contentView.bottom − 5`. `isHidden` does not remove it from layout. Each unreacted bubble gets about 37 pt of extra gap, and adding or removing a reaction never changes row height. This contradicts §5.1 and §8.3. Fix: toggle the height constraint (or use a stack view) and animate the row.
6. **The chip hit target is 28 pt.** §5.5 requires 48 pt (AC-26). Fix: override `point(inside:with:)` to expand the target 10 pt up and down.
7. **Placement does not follow the shared algorithm.**
   - `WheelGeometry.swift:40-58` returns the first axis that has any valid shift ≤120, searched on a 4-pt by 15° grid.
   - The design (§5.3.2) accepts the first axis with |s|≤24, otherwise the smallest valid |s|, and fixtures allow ±1.
   - In the left-edge example the code yields |s|=24, not 22.
   - Fix: compute the minimal shift per axis analytically or by bisection, and apply the 24 / smallest-|s| rule.
8. **The wheel can sit under the navigation bar.** The safe rect is `window.bounds` inset by `window.safeAreaInsets` (`ChatViewController.swift:35`), which excludes the nav bar. The wheel is a subview of `view`, beneath the bar, so items near the top can be hidden. Likely, unverified. Fix: use `view.safeAreaLayoutGuide.layoutFrame`, or host the wheel in a window-level overlay.
9. **Selection animations can be overridden during the open cascade.** The delayed open animation (`:105`, no `beginFromCurrentState`) can reset a selected item to identity scale when it fires. This is plausible during a fast scrub in the first ~150 ms. Unverified.
10. **A new touch during dismissal is swallowed.** The fading wheel stays interactive for 0.16 s (`ChatViewController.swift:39`), so a new touch hits its scrim instead of the table. The design (§6.2) says there is no input lock. Fix: set `w.isUserInteractionEnabled = false` when dismissal starts.
11. **Hard-coded English in accessibility labels.** `ReactionWheelView.swift:49` builds `"…, \(i+1) of 6"` in English, so Russian reads mixed. "You" in `Models.swift` is also unlocalised. Fix: add a localized key such as `a11y.itemOfCount`.
12. **Animation work on every move.** While Outside, the `|| outside` clause re-runs six `UIView.animate` calls per move event (`:103`). The design says no new animation object per move. Fix: fix #1 also removes this.
13. **Second finger is not ignored (likely).** `g.location(in:)` returns the centroid of all touches, so a second finger would shift the selection (AC-11). Fix: ignore updates when `g.numberOfTouches > 1`.

## UX fidelity (confirmed missing)

- **Lifted message and press state:** the pressed message is not lifted above the scrim and has no shadow. `setLifted` only sets identity, and the 0.98 pressing state is never applied (`MessageCell.swift:90`).
- **Open cascade:** the scrim and plate have no fade-in. Items scale and fade but do not travel from `C + 0.35·(target − C)`, and the label has no fade at 200 ms.
- **Selection visuals:** there is no selected disc, no "−" badge for `Selected-remove`, and no tangential push of the other items.
- **Plate shape:** the plate is a mitred polyline through the item centres (`:39-41`), not an arc of radius R.
- **Outcome animations:**
  - Commit has no fly-to-chip (§8.3).
  - Removal has no chip shrink (§8.3b).
  - Cancel has no staggered collapse (§8.4); everything is a 0.16 s alpha fade.
  - The README's "add/replace/remove/cancel outcomes" overstates this, and the limitations list omits it.
- **Colours:** the label pill is fixed black/white rather than the `label.fill` / `label.text` tokens. The Outside dim applies to items only, not the plate.
- **Compact picker:**
  - It has no scrolling, so it overflows in landscape and at large type.
  - It shows no current-reaction ring or "Remove" cue.
  - Its buttons carry no string-table accessibility label, so VoiceOver may read the emoji name.
- **Persistent anchor:** it is not clamped into the safe rect (E25).
- **Anchor point:** the anchor is the recognition-time location, which can drift up to 10 pt from touch-down. The design says touch-down.

## Animation and accessibility

- `prepare()` is never called on the haptic generators (§9), so the first tick may lag. The open haptic uses a fresh generator each time.
- `finishWheel` (`ChatViewController.swift:38`) posts `.announcement` and then immediately `.layoutChanged`. The focus move likely interrupts the announcement. Unverified without VoiceOver. Fix: move focus first, then post the announcement.
- Dismissing the persistent picker (close, scrim, Escape) posts no focus-restore to the originating message (§10.3).
- The "Reaction wheel. 6 options." screen-changed announcement is missing. Current-reaction items get a hint but no "selected" trait or label.
- Increase Contrast and Reduce Transparency are not handled: no opaque plate, and the ring is not 3 pt (§10.6). The README's "friendly" wording is not an implementation.
- Keyboard and Switch Control (AC-24): the README admits there is no Tab trap, arrow keys, Escape or Space/Enter. The design makes these acceptance-level, so this is a known gap against the contract, not an optional one.
- Settings switches and the segmented control have no explicit `accessibilityLabel` (guess).
- `adjustsFontForContentSizeCategory` is not set on labels, so there is no live Dynamic Type update (low).
- Debug overlay: rings are drawn in the view's own layer, beneath the plate, scrim and items (`:110`). It omits the 96 stay circle and the state text.

## Discrepancies with the shared (Android) contract

I could not diff against the Android code.
- The placement search differs from the shared algorithm (P1.7). The same fixtures would likely fail on iOS beyond ±1.
- The palette substitutions (`Palette.swift`) must be mirrored on Android as a shared-contract change.
- The Compact picker is single-column on iOS, where §5.3.2 specifies two columns at 240 pt or wider.
- Reduce motion is a Switch on iOS where §5.4 specifies a segmented "Follow system / Always on". The behaviour is equivalent.

## Test and evidence gaps

`ReactionWheelTests/WheelGeometryTests.swift` has four pure-geometry tests:
- Missing: no JSON fixtures, no left-edge, corner, 1.3×, RTL-placement or persistent-mode cases, and no state-machine or arbitration tests.
- Not met: AC-05, AC-11 and AC-33 have no automated evidence.
- Not run: the tests were not executed, per the README.
- Not run: no recordings, VoiceOver, AX5, landscape or frame-pacing evidence, and no physical-device haptics.

## Verified as correct (by reading)

- The index-order formula in `centers()` matches §2.1 for all eight axes in LTR and RTL.
- The `commit.enter` / `commit.exit` / capture / stay / switch constants match.
- The commit predicate is evaluated on release coordinates.
- The haptic interval is 85 ms, with no haptic on cancel.
- Interruption paths (resign-active, rotation, `.cancelled`) are handled.
- The EN and RU key sets are in parity.

