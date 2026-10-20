# Paper app: motion and performance spec

**Product:** Paper (paper.college) native client · **Platforms:** Android tablets, Windows, macOS · **Framework:** Flutter (Dart 3, Flutter ≥ 3.35 per `design/tokens/README.md`)
**Owner:** design-motion · **Consumers:** tech-mobile (implementation), CTO (perf acceptance)
**Inputs:** `design/tokens/paper_tokens.dart` + `paper-tokens.json` (`PaperMotion`, `PaperWindowClass`, `PaperLayer`, `PaperElevation`), `design/specs/layout-system.md`, `flows.md`, `screens/*.md`, `design/brand/splash/splash.md`. Web precedent: RPR `design/motion/cite-add-toast-motion.md` (same values: press 80, reveal 150, settle 200; transform and opacity only; no bounce).

**Window class names.** This document uses the token enum `PaperWindowClass`: `compact` < 600, `medium` 600–839, `expanded` 840–1199, `large` 1200–1599, `extraLarge` ≥ 1600. Older UX docs may still say `fallback / compact / medium / expanded / large` for the same ranges, one step lower. Where this spec and an older UX name disagree, go by the dp range.

**The one rule.** Smooth reading (60–120 fps scroll and zoom on large PDFs) matters more than any animation in this file. If a transition costs a dropped frame on the reference devices (§1.9), make it simpler or cut it. Cutting an animation is always allowed; adding one is not.

**Personality.** Quiet and soft. Things fade in and settle. Nothing bounces, springs, overshoots, wobbles, pulses for attention or loops for decoration. Moves are short (4–8 dp) or come from a screen edge. Scale is used only for dialogs (0.98 → 1.0).

---

## 0. Tokens used (no new curves)

| Token | Value | Typical use here |
| --- | --- | --- |
| `PaperMotion.instant` | 80 ms | press deepen, popover/menu **exit**, toggles |
| `PaperMotion.fast` | 150 ms | hover/focus reveal, popover/menu **enter**, tooltips, tab body crossfade, small fades |
| `PaperMotion.base` | 200 ms | settle/exit, colour changes, sync badge swap, toolbar hide/show, snackbar enter, splash exit |
| `PaperMotion.slow` | 300 ms | side sheet / bottom sheet / split panel slide, scrims, programmatic scroll to an adjacent page |
| `PaperMotion.page` | 300 ms | route transitions (fade only) |
| `PaperMotion.emphasis` | 420 ms | used only as the **hold** of the highlight flash. Never on a scroll path |
| `PaperMotion.hoverDelay` | 40 ms | pointer hover-in anti-strobe delay (not used for keyboard focus) |
| `PaperMotion.standard` | `Cubic(0.4,0,0.2,1)` | in-place changes, departures, crossfades |
| `PaperMotion.decelerate` | `Cubic(0,0,0.2,1)` | arrivals and reveals |
| `PaperMotion.accelerate` | `Cubic(0.4,0,1,1)` | exits that leave the screen (sheet out, toolbar hide) |
| `PaperMotion.linear` | linear | progress bars and the sync spinner only |
| `PaperMotion.pressScale` | 0.98 | dialog entry scale start (the only scale animation in the app) |

`markHoverScale` / `termHoverScale` are **not used on the PDF** (§2.12). Scaling a mark over a rasterised page blurs its edges and repaints the overlay every frame. AI marks change colour and ring only.

### 0.1 Constants the app adds (not in the token file; tech-mobile adds them to `lib/theme/motion_extras.dart`)

These are timings and thresholds, not curves. They reuse the token easings.

| Constant | Value | Why |
| --- | --- | --- |
| `kSpinPeriod` | 1000 ms per turn, `linear` | Syncing glyph rotation (§2.9) |
| `kToolbarHideThreshold` | 24 dp of scroll in one direction | Stops the toolbar flickering on small scroll jitters |
| `kRerasterIdle` | 120 ms after the last resize event | Re-render PDF tiles after live window resize or keyboard panel resize (§4.2) |
| `kSkeletonDelay` | 150 ms | Skeletons appear only if the load takes longer than this (from the side panel spec) |
| `kSyncingMinVisible` | 400 ms | Don't show `syncing` for syncs shorter than this (from the sync-status spec) |
| `kAnimatedScrollMaxDistance` | 1 viewport height | Programmatic scrolls longer than this jump instead of animating (§2.11) |
| `kUndoSnackbarDuration` | 5 s (highlight) / 8 s (library delete) | From flows F4 and F7. Stays while hovered or focused |

---

## 1. Performance rules (60–120 fps)

### 1.1 Frame budget

| Display | Budget per frame | UI-thread target (p99) | Raster-thread target (p99) |
| --- | --- | --- | --- |
| 60 Hz | 16.7 ms | ≤ 10 ms | ≤ 10 ms |
| 90 Hz | 11.1 ms | ≤ 7 ms | ≤ 7 ms |
| 120 Hz | **8.3 ms** | **≤ 6 ms** | **≤ 6 ms** |

The UI thread (build, layout, paint recording) and the raster thread (GPU) each have to fit inside the budget. Design for 120 Hz and you get 60 Hz for free. Leave ~25% headroom, because pdfium tile decoding and sync run on other threads and compete for the same cores.

### 1.2 Only animate transform and opacity, through `Animation`, never with `setState`

- Use the `*Transition` widgets: `FadeTransition`, `SlideTransition`, `ScaleTransition`, `RotationTransition`, `DecoratedBoxTransition`, `AlignTransition` (overlays only). They subscribe to the `Animation` and update a layer property. They don't rebuild or relayout.
- For custom painting (highlight flash ring, scrim colour), pass the animation as `CustomPainter(repaint: animation)` or use `AnimatedBuilder` **with the `child:` parameter**, so only the leaf rebuilds:

```dart
AnimatedBuilder(
  animation: _ctrl,
  child: const _ExpensiveToolbarContents(), // built once
  builder: (context, child) => Transform.translate(
    offset: Offset(0, -_toolbarHeight * _ctrl.value),
    child: child,
  ),
);
```

- **Forbidden:** `controller.addListener(() => setState(() {}))`, `Timer.periodic(Duration(milliseconds: 16), …)`, and `Future.delayed` loops that drive animation values.
- **Forbidden in the reader route** (and anywhere they would wrap the PDF): `AnimatedSize`, `SizeTransition`, `AnimatedContainer` animating width/height/padding/margin/constraints, `AnimatedPadding`, `AnimatedPositioned`, `AnimatedAlign`, `AnimatedList`'s default `SizeTransition` insert/remove, `AnimatedCrossFade` (it animates size). Each of these causes a relayout on every frame.
- Outside the reader these are still discouraged. Library and settings use instant layout changes plus a fade (§2).
- Implicit widgets that only touch transform, opacity or colour are fine: `AnimatedOpacity` (outside the PDF subtree), `AnimatedSlide`, `AnimatedScale`, `AnimatedRotation`, `TweenAnimationBuilder<Color>`. Prefer explicit controllers on hot paths (reader chrome), because implicit widgets rebuild their subtree on every tick unless the child is const.

### 1.3 Never animate the geometry of anything that contains the PDF viewport

The `PdfViewport` gets new constraints **at most once per frame**, and only at one of these commit points:

1. Gesture end (split drag end, pinch end).
2. The start or end of a panel transition (§2.3: "slide, then commit" when opening, "commit, then slide" when closing).
3. Window-class change. This is debounced by the layout system's hysteresis, never mid-gesture.
4. Live window resize settled (`kRerasterIdle`, §4.2).

Between commit points, the viewport's size is fixed and its children are moved or scaled by a `Transform` only. Put the `PdfViewport` behind a **relayout boundary**: a `SizedBox` with explicit size from the `LayoutBuilder`, so chrome changes (toolbar text, badge width, snackbar) never relayout the page list.

### 1.4 `RepaintBoundary` placement (mandatory)

| Boundary | Wraps | Why |
| --- | --- | --- |
| **B1** `PdfViewport` | the whole scrolling page list | Chrome animations never repaint the PDF |
| **B2** per page | each page's raster tiles plus its static highlight washes | Scrolling is just moving layers. The page's own picture is reused |
| **B3** page overlay | per visible page: selection, find matches, hover ring, highlight **flash** | Flash and selection repaint the overlay only, never the page raster or the multiply washes |
| **B4** `InkLayer` | the live stylus stroke for the active page | Repaints at input rate (up to 240 Hz pen events, coalesced per frame) without touching B2 |
| **B5** `ReaderToolbar` (plus page pill, `ToolDock`) | chrome | Toolbar hide/show is a transform on a cached layer |
| **B6** `ReaderSidePanel` | panel body | Panel scrolling and tab fades don't dirty the PDF |
| **B7** popover layer | `SelectionPopover`, `CitationPopover`, `HighlightPicker`, menus | Popover fades don't dirty the page below |
| **B8** `SyncBadge` glyph | the rotating icon only | The 1 Hz spin repaints a 20 dp box, not the toolbar |
| **B9** snackbar host | `AppSnackbar` / `DeleteUndoSnackbar` | Enter and exit are isolated |

Check it in DevTools → Flutter Inspector → **Highlight repaints** (or `debugRepaintRainbowEnabled = true`):

- While scrolling the PDF, only B1/B2 layers change.
- During any chrome animation, B1/B2 never flash.

Don't add boundaries elsewhere by reflex. Each one costs memory. Add one only where this table says, or where a profile proves it helps.

### 1.5 Split drag: scale the live raster, re-rasterise on gesture end

- During the `SplitDragHandle` drag, the panel width follows the pointer. The PDF viewport keeps its **pre-drag constraints**. Its visible content is drawn through `Transform.scale(scale: newWidth / oldWidth, alignment: Alignment.topLeft)` (fit-width zoom), or clipped/translated (fixed zoom), using the existing page bitmaps.
- Make **no pdfium render calls** and no page-list relayout during the drag. Coalesce pointer moves to one update per frame (`SchedulerBinding.scheduleFrameCallback`). Don't update on every `PointerMoveEvent`.
- On drag end, commit the new viewport width once. Keep the reading anchor (top visible page index + fractional offset) and re-rasterise the visible tiles at the new scale. Swap tiles in **without** a crossfade (an instant swap from slightly-soft to sharp; a crossfade would need `saveLayer` over the page). Persist the width now, not before.
- Snap closed (dragged below min − 48 dp): the panel slides out over `base` 200 ms `accelerate` (§2.3 close), then the viewport commits to full width.
- Double-click reset and keyboard resize (`←/→`, `Shift+←/→`, `Home/End`) **jump** to the target width with no tween. One relayout, then re-rasterise after `kRerasterIdle`. Animating these would be a width animation of the viewport.

### 1.6 Pinch zoom and step zoom: transform the cached raster, then render tiles

- Pinch, trackpad pinch and `Ctrl/Cmd+wheel`: apply `Transform` (scale around the focal point) to B1's content using the existing bitmaps. Make no relayout of the page list and no pdfium calls mid-gesture.
- At gesture end, compute the settled scale, re-lay the page list **once** (anchored at the focal point), then render tiles for visible pages first and ±1 viewport second, at device pixel ratio × scale. Keep showing the scaled old bitmaps until each new tile is ready. Never show blank.
- Step zoom (`Ctrl/Cmd+=/-`, `[–]`/`[+]`, Fit width/page) and double-tap zoom: animate the same `Transform` from the old scale to the target over `base` 200 ms `standard` (double-tap: `slow` 300 ms `standard`), then commit and re-render as above. Reduced motion: commit instantly.
- Zoom % label updates once at commit (plus a polite announcement), not every frame.
- Keep tile rendering off the UI isolate (pdfrx renders on a background thread or isolate). Upload decoded bitmaps as `ui.Image` and draw them with `RawImage` / `canvas.drawImageRect`. Don't use `Image.memory` re-decode per frame.

### 1.7 Things that are banned over or around the PDF

| Banned | Cost | Use instead |
| --- | --- | --- |
| `Opacity` widget (any value strictly between 0 and 1) over B1 | `saveLayer` / offscreen pass of the whole page stack every frame | Fade the **chrome**, or fade a solid `ColoredBox` curtain by colour alpha (§2.1) |
| `FadeTransition` / `AnimatedOpacity` whose subtree contains B1 | same, an offscreen pass per frame | same |
| `BackdropFilter`, `ImageFilter.blur`, frosted panels/toolbars | reads back and blurs the framebuffer every frame, the most expensive thing you can do while scrolling | Solid `surface` / `surfaceRaised` with a 1 dp border (the token rule) |
| `ShaderMask`, `ColorFiltered`, `ImageFiltered` over pages | offscreen pass | Bake into the tile render, or skip |
| `Clip.antiAliasWithSaveLayer`, `ClipPath` with a complex path over pages | `saveLayer` | `Clip.hardEdge` on the viewport. Page corners are square |
| Shadows (`BoxShadow`, `elevation`, `PhysicalModel`) on pages, list items, cards or toolbars | blur rasterised per frame while moving | Tonal surface + border (`PaperElevation` already sets this). Shadows only on dialogs, menus and popovers, light theme only, and never **animated** (fade the popover; don't tween the shadow) |
| Animating highlight wash alpha | the per-colour multiply `saveLayer` is re-rasterised every frame | Animate the **ring** on the B3 overlay (§2.8) |
| `Hero` from a library thumbnail into the reader | flies a widget over two routes, causes a layout jump at the end and a raster mismatch with the real page | Route fade-through (§2.1) |

`saveLayer` is fine in **static** content (the highlight per-colour multiply layer in the token README is drawn once per page raster). The ban is on `saveLayer` that is **re-run every frame because something is animating**.

### 1.8 Ticker hygiene

- Every `AnimationController` uses the widget's `TickerProvider` (`SingleTickerProviderStateMixin`), so `TickerMode` mutes it automatically on routes that aren't visible (the library under the reader).
- Repeating animations (sync spin, indeterminate progress) run only while visible **and** only while the state needs them. Stop with `controller.stop()`; don't leave `repeat()` running at opacity 0.
- **Idle must be idle.** When the user is reading and nothing changes, the engine should schedule **zero** frames. A leaked repeating controller turns a reading session into a constant 120 Hz drain on battery and heat. CTO check: §1.9 item P10.
- `MaterialApp(themeAnimationDuration: Duration.zero)`. The default 200 ms `AnimatedTheme` lerp rebuilds the whole tree for every frame of a theme switch. Theme changes are instant.

### 1.9 Profiling and the perf acceptance checklist (CTO)

**How to measure**

- Always `flutter run --profile` (or `--release`) on a **physical** device or machine. Debug-mode and emulator numbers are meaningless.
- DevTools → Performance: the frame chart (UI and raster bars against the budget line), "Track widget builds" and "Track layouts" to catch per-frame rebuilds, and Highlight repaints (§1.4).
- Automated: an `integration_test` driven in profile mode with `IntegrationTestWidgetsFlutterBinding.watchPerformance()` (or `traceAction` + `TimelineSummary`). Record the 90th and 99th percentile build and raster times per scenario. Judge 120 Hz runs against the percentile targets in §1.1. Ignore the summary's "missed budget" counts there, because those assume a 16 ms budget.
- Check the display actually runs at high refresh: Android → `adb shell dumpsys SurfaceFlinger | grep -i refresh` (or the developer option "Show refresh rate"); macOS ProMotion → DevTools frame intervals ≈ 8.3 ms.

**Reference hardware** (minimum set): one 60 Hz mid-range Android tablet, one 120 Hz Android tablet with a stylus, one Windows laptop on integrated graphics, one Apple-silicon Mac (ProMotion if available).

**Reference documents:** (a) a 300+ page text-heavy paper, (b) a 40–60 page image-heavy or scanned PDF, (c) a paper with vector-heavy figures, plus 200 highlights spread over its pages.

| # | Scenario | Pass criteria |
| --- | --- | --- |
| P1 | Fling-scroll doc (a) top to bottom for 10 s, at fit-width | p99 UI ≤ 6 ms and raster ≤ 6 ms on 120 Hz (≤ 10 ms on 60 Hz). Under 1% of frames over budget. No frame over 2× budget |
| P2 | Same on doc (b) and (c) | Same, except a blank or placeholder tile is allowed for ≤ 2 frames when entering a new page |
| P3 | Pinch zoom 100% → 400% → 100% for 5 s | Zero pdfium render calls during the gesture (log counter). Frame criteria as P1. Visible pages sharp ≤ 250 ms after the gesture ends |
| P4 | Split drag back and forth for 5 s (`expanded`+) | Zero pdfium renders and zero `PdfViewport` layouts during the drag (DevTools "Track layouts"). Frame criteria as P1. Exactly one relayout at drag end |
| P5 | Open and close the side panel 10× in every window class | No frames over budget during the slide. PDF relayout happens once per open and once per close, at the commit points |
| P6 | Toolbar auto-hide/show while scrolling (`compact`, `medium`) | PDF B1/B2 never repaint because of the toolbar (repaint rainbow). PdfViewport size unchanged |
| P7 | Select text → popover, highlight, flash-on-jump from a note card | Only the B3/B7 overlays repaint. No B2 repaint except when the highlight is created or deleted |
| P8 | Stylus stroke 3 s on a 120 Hz tablet | Ink follows within 1 frame. B2 never repaints mid-stroke. Snap-to-text happens in the single frame after lift |
| P9 | Library → reader → library, 10× (doc a, cached) | Transition frames within budget. First page visible when the transition ends. No `Opacity`/`saveLayer` around B1 (check with `debugDisableOpacityLayers`, which must not change visuals of the PDF during the transition) |
| P10 | Idle: reader open, no input, synced, for 10 s | **Zero frames** scheduled (DevTools timeline flat) |
| P11 | Syncing with 500 queued ops while scrolling doc (a) | P1 criteria still hold (sync runs in a background isolate; the badge spin repaints only B8) |
| P12 | Live window resize (Windows, macOS) for 5 s | Frame criteria as P1 while resizing. No animations triggered. Re-raster only after the resize settles |
| P13 | Reduced motion on (each platform, §3) | Every catalog row shows its fallback. Widget test: under `MediaQuery(disableAnimations: true)`, one `pump()` reaches the end state for every transition that's 0 ms in §2 |
| P14 | Static source checks (CI grep or `custom_lint`) | No `Timer.periodic` used for animation. No `Opacity(`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask`, `AnimatedSize`, `SizeTransition`, `AnimatedCrossFade` or `Hero(` under `lib/features/reader/` |

---

## 2. Motion catalog

Legend:

- **RM** = reduced-motion fallback (§3).
- `of` = duration via `PaperMotion.of(context, d)` (0 ms under reduced motion).
- `fade` = duration via `PaperMotion.fade(context, d)` (capped at 150 ms under reduced motion).
- "Enter" / "exit" are listed as `duration · curve`.

### 2.0 Master table

| # | Transition | Trigger | Property animated | Enter (duration · curve) | Exit (duration · curve) | RM fallback | Flutter primitive |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Route change (Library ↔ Settings, Sign-in → Library, generic push/pop) | navigation | opacity of the incoming route (route has no PDF) | `page` 300 · `decelerate` | `page` 300 · `standard` (reverse curve) | instant cut (controller auto-scales to 5%, see §3.2) | `PaperFadePageTransitionsBuilder` (tokens) → `FadeTransition` |
| 2 | Library → Reader open; Reader → Library back | tap / Enter on `PaperCard`; back / `Esc` / `Cmd+[` | **fade-through**: library opacity out (0–40%), then a solid `background` curtain over the reader fades by colour alpha (40–100%). **The PDF is never under an opacity layer** | `page` 300 total · out part `accelerate`, in part `decelerate` | `page` 300 mirrored · `standard` | instant cut | `ReaderPageTransitionsBuilder` (§2.1) using `FadeTransition` on the library only + `ColoredBox` curtain via `AnimatedBuilder` |
| 3 | Side panel open/close, `compact` (< 600): bottom sheet | ▤ / `Mod+\` / Explain / Note; close ✕, swipe down, scrim tap, Esc | sheet `translateY` from 100%; scrim colour alpha 0 → `scrim` | `slow` 300 · `decelerate` | `base` 200 · `accelerate` | sheet appears/disappears instantly; scrim fade `fade(fast)` | `DraggableScrollableSheet` in a `ModalBottomSheetRoute` with `sheetAnimationStyle` or custom `SlideTransition`; `AnimatedModalBarrier` for the scrim |
| 4 | Side panel open/close, `medium` (600–839) and any forced-overlay case | same | panel `translateX` from +100% (RTL: −100%); scrim colour alpha. PDF does not resize | `slow` 300 · `decelerate` | `base` 200 · `accelerate` | instant; scrim `fade(fast)` | `SlideTransition` over a `RepaintBoundary` panel (B6); `AnimatedModalBarrier` |
| 5 | Side panel open/close, `expanded` / `large` / `extraLarge` (split) | same | **Open:** panel slides in as an overlay (`translateX` +100% → 0) over the PDF, *then* the viewport commits to the narrower width in one frame. **Close:** viewport commits to full width under the panel, *then* the panel slides out | `slow` 300 · `decelerate` | `base` 200 · `accelerate` | instant layout change (one commit), no slide | `SlideTransition` + commit callback on `AnimationStatus.completed` / before `reverse()` (§2.3) |
| 6 | Split drag resize | drag `SplitDragHandle` | panel width follows the pointer. PDF scaled raster (§1.5) | gesture-driven (no duration) | snap-closed: `base` 200 · `accelerate` | gesture still direct; snap-closed is instant | `GestureDetector` + `Transform.scale` on B1 content; commit on `onHorizontalDragEnd` |
| 7 | Panel tab switch (Notes · Glossary · Explanation) | tap, `Mod+Alt+1/2/3`, ←/→ | incoming tab body opacity 0 → 1 (outgoing removed instantly). Tab indicator `translateX` | body `fast` 150 · `standard`; indicator `base` 200 · `standard` | (none) | body `fade(fast)`; indicator jumps | `IndexedStack` (keeps scroll per tab) + `FadeTransition` on the active child; `TabBar` indicator driven by `TabController(animationDuration: of(base))` |
| 8 | Tab "new result" dot | background result on a non-active tab | dot opacity | `fast` 150 · `decelerate` | `instant` 80 · `standard` | `fade(fast)` | `FadeTransition` |
| 9 | `SelectionPopover` | selection settles (handle lift / mouse up / long-press end) | opacity 0 → 1 + `translateY` 4 dp toward the anchor (from below if the popover is above the selection) | `fast` 150 · `decelerate` | `instant` 80 · `standard` (opacity only) | `fade(fast)` in, instant out; no translate | `FadeTransition` + `SlideTransition` in an `OverlayPortal` (B7, `PaperLayer.popover`) |
| 10 | `CitationPopover` | tap/click citation marker | as #9 | `fast` 150 · `decelerate` | `instant` 80 · `standard` | as #9 | as #9. Loading → resolved content: **instant swap, no size tween** (the box snaps to the new height) |
| 11 | `HighlightPicker` | tap/click a highlight; auto-shows for 2 s after drag-highlight | as #9 | `fast` 150 · `decelerate` | user dismiss `instant` 80; 2 s auto-dismiss `base` 200 · `standard` | as #9 | as #9 |
| 12 | Popover re-anchor while the selection changes | handle drag | popover **hides** while dragging (opacity → 0 `instant`), reappears at the new anchor on lift (#9). It never slides along with the handle | `fast` 150 · `decelerate` | `instant` 80 | instant | same controller as #9 |
| 13 | `NoteEditorInline`, context menus (`PaperContextMenu`, overflow, `ImportMenu`, fit menu) | open | opacity + 4 dp `translateY` | `fast` 150 · `decelerate` | `instant` 80 · `standard` | `fade(fast)` / instant out | `MenuAnchor` with custom `style`, or `OverlayPortal` + `FadeTransition` |
| 14 | Tooltip | pointer hover 500 ms (UX) or long-press | opacity | `fast` 150 · `decelerate` | `instant` 80 | `fade(fast)` | `TooltipThemeData(waitDuration: 500ms, exitDuration: 0, …)`; Material tooltip fade is opacity-only |
| 15 | Dialogs (`ImportUrlDialog`, `RenameDialog`, `PageJumpDialog`, `SignOutDialog`, delete-many confirm, `ShortcutsDialog`) | open / close | dialog opacity 0 → 1 + scale 0.98 → 1.0; barrier colour alpha | `fast` 150 · `decelerate` | `instant` 80 · `standard` (opacity only, no scale) | `fade(fast)` in, instant out, no scale | `showDialog(… )` → custom `DialogRoute` / `showGeneralDialog(transitionDuration: fast, transitionBuilder: Fade+Scale)` |
| 16 | `AppSnackbar` / `DeleteUndoSnackbar` / `ConflictNotice` | event; auto-dismiss after `kUndoSnackbarDuration` (paused while hovered/focused) | opacity + `translateY` 16 dp from below. **Never** changes the reader/library layout (floating) | `base` 200 · `decelerate` | `fast` 150 · `accelerate` | `fade(fast)`, no translate | Own `SnackbarHost` overlay (B9, `PaperLayer.toast`) with `SlideTransition` + `FadeTransition`. If Material `ScaffoldMessenger` is used: `SnackBarBehavior.floating` + `snackBarAnimationStyle: AnimationStyle(duration: base, reverseDuration: fast)`. Never the fixed (height-clip) behaviour |
| 17 | Snackbar replace (new event while one shows) | event | old exits fully (#16 exit), then new enters. Never stack more than one | as #16 | as #16 | instant swap | queue in `SnackbarHost` |
| 18 | Undo countdown | (none) | **no visible countdown animation** (no shrinking bar) | (none) | (none) | (none) | `Timer` for dismissal (wall-clock 5 s / 8 s, not frame-based) |
| 19 | Library card delete (single) | Delete / menu | card opacity 1 → 0 + scale 1 → 0.98, then remaining cards **reflow instantly** (no position tween) | (none) | `fast` 150 · `accelerate` | instant removal | `FadeTransition` + `ScaleTransition` on the card's boundary; remove from the list on completion |
| 20 | Library card restore (Undo) / import tile → `PaperCard` | Undo / import success | card opacity 0 → 1 at its original index (others jump) / crossfade tile → card | `base` 200 · `decelerate` | (none) | `fade(fast)` | `FadeTransition`; `AnimatedSwitcher(transitionBuilder: fade, layoutBuilder: stack-topStart)` for tile → card |
| 21 | Library grid ↔ list toggle; filter/sort/search results change | toggle / typing (150 ms debounce) | view toggle: crossfade. Result changes: **instant** (no list animation) | toggle `fast` 150 · `standard` | (none) | instant | `AnimatedSwitcher` (fade, stack layout) for the toggle only |
| 22 | `PaperThumbnail` load | first-page render or disk cache ready | opacity 0 → 1 **only if not synchronously available** | `fast` 150 · `decelerate` | (none) | instant | `Image(frameBuilder:)`: return the child directly when `wasSynchronouslyLoaded`, else `AnimatedOpacity(fast)` (thumbnails are not in the PDF viewport) |
| 23 | `SyncBadge` state change (synced / syncing / pending / offline / error) | sync engine state, after the 400 ms debounce (`kSyncingMinVisible`) | icon + short text crossfade. Text width change is **instant** (badge lives in B5/sidebar, outside the PDF relayout boundary) | `base` 200 · `standard` | (crossfade) | `fade(fast)` | `AnimatedSwitcher(duration: base, switchInCurve: standard, switchOutCurve: standard, transitionBuilder: FadeTransition, layoutBuilder: stack)` keyed by state |
| 24 | Syncing indicator | state == `syncing` | rotation of the arrows glyph, 1 turn per `kSpinPeriod` (1000 ms), `linear` | loop while syncing **and** visible | stops at the next whole turn (≤ 1 s) or immediately when hidden | **static** arrows glyph (no rotation) | `RotationTransition(turns: _spin)` wrapping a `RepaintBoundary` (B8). `_spin.repeat()` only while syncing; `TickerMode` mutes it when hidden or auto-hidden |
| 25 | `OfflineBanner` / `AuthErrorBanner` / `aiOfflineStrip` | connectivity change / auth error | banner opacity. The space it takes is inserted **instantly** (never in the reader viewport: in the reader the strip lives inside the side panel, B6) | `fast` 150 · `decelerate` | `fast` 150 · `standard` | `fade(fast)` | `AnimatedSwitcher` / `FadeTransition`; no `AnimatedSize` |
| 26 | Toolbar auto-hide/show (`compact`, `medium`, and any class with window height < 480) | scroll down ≥ `kToolbarHideThreshold` → hide; scroll up ≥ threshold, tap page margin, any toolbar shortcut → show | toolbar `translateY` 0 → −100% of its height; page pill and `ToolDock` `translateY` 0 → +100% + safe-area inset. Toolbar overlays the PDF (the PDF has a constant top inset), so the viewport never resizes | show `base` 200 · `decelerate` | hide `base` 200 · `accelerate` | `fade(fast)` only (no translate) | `SlideTransition` on B5. One controller drives toolbar + pill + dock. Direction detection from `UserScrollNotification` / accumulated `ScrollUpdateNotification.scrollDelta`; **not** proportional per-pixel tracking |
| 27 | `FindBar` | `Mod+F` / 🔍 | slides down from under the toolbar as an overlay (doesn't push the PDF) | `base` 200 · `decelerate` | `fast` 150 · `accelerate` | `fade(fast)` | `SlideTransition` + `ClipRect` on the bar only (B5) |
| 28 | "Back to page N" return pill | after jump-to-reference / jump-to-highlight | opacity + `translateY` 8 dp | `base` 200 · `decelerate` | `fast` 150 · `accelerate` | `fade(fast)` | `FadeTransition` + `SlideTransition` |
| 29 | Highlight create (text, figure, stylus snap) | selection colour tap / drag lift / `H` / pen lift | **none**: wash appears in the same frame as commit | (none) | (none) | (none) | re-record B2 page picture once (and B3 overlay) |
| 30 | Highlight colour change / delete | picker / eraser / delete | **none**: immediate repaint; undo snackbar #16 | (none) | (none) | (none) | same |
| 31 | Highlight **flash on jump** (from note card, glossary, explanation ↗, find "act on match") | jump lands (after #32) | `focusRingOnPaper` 2 dp **ring** around the highlight rects. Ring alpha 0 → 1, **hold**, 1 → 0. The wash itself never animates | in `fast` 150 · `decelerate` → hold `emphasis` 420 → out `slow` 300 · `standard` (≈ 870 ms total, plays once) | (see enter) | **static ring for 1 s**, then removed instantly | `CustomPainter(repaint: _flash)` on the B3 overlay; `TweenSequence` on one controller |
| 32 | Programmatic scroll (page `‹ ›`, PageUp/Down, jump to page/highlight/reference, find next) | command | scroll offset | distance ≤ 1 viewport: `slow` 300 · `standard`; farther: **jump** (`jumpTo`) | (none) | always `jumpTo` | `ScrollController.animateTo` / `jumpTo`. Never animate across many pages: it would rasterise every page in between |
| 33 | Card hover → highlight outline in PDF (pointer) | hover a note/explanation card | outline ring opacity on the B3 overlay | after `hoverDelay` 40: `fast` 150 · `decelerate` | `fast` 150 · `standard` | instant on/off | `CustomPainter(repaint:)` on B3 |
| 34 | AI mark / highlight hover (pointer) | hover a mark on the page | fill alpha rest → full and 1.5 dp ring (tokens). **No scale** | after `hoverDelay` 40: `fast` 150 · `decelerate` | `fast` 150 · `standard` | instant | B3 overlay painter (the mark overlay, not the wash layer) |
| 35 | Hover on chrome (buttons, rows, cards, tabs) | pointer enter/exit | background overlay colour | after `hoverDelay` 40: `fast` 150 · `decelerate` | `fast` 150 · `standard` | instant colour change | `WidgetStateProperty` overlay colours via the theme; `ButtonStyle(animationDuration: fast)`; the PaperCard hover overlay as `TweenAnimationBuilder<Color?>` |
| 36 | Keyboard focus ring | focus-visible | **none**: ring appears instantly (focus must never lag the keyboard) | (none) | (none) | (none) | theme `focusColor` / `FocusableActionDetector` |
| 37 | Press / active | pointer down | background deepen (colour only). Touch: `InkRipple` (Android). Desktop: `NoSplash` + colour | `instant` 80 · `decelerate` | `base` 200 · `standard` | instant | theme (`splashFactory` already set per platform in tokens) |
| 38 | Tool mode segmented / toggles / switches | tap | selected fill colour, thumb `translateX` | `instant` 80 · `standard` (switch thumb `base` 200 · `standard`) | (same) | instant | `SegmentedButton` / `Switch` with theme durations |
| 39 | Stylus ink | pen down / move / up | **none**: stroke drawn at input rate; on lift, snaps to text-run rects in the next frame (no morph, no fade) | (none) | (none) | (none) | `CustomPainter(repaint: strokeNotifier)` in B4; `Listener` (raw pointer events, not `GestureDetector`) |
| 40 | `FigureSelectionBox` | drag rectangle | **none**: box tracks the pointer | (none) | (none) | (none) | B3 overlay painter |
| 41 | Text selection handles / caret | selection | **none** (platform behaviour) | (none) | (none) | (none) | `SelectableRegion` / custom handles |
| 42 | Skeletons (`SkeletonCard`, `SkeletonRow`, citation loading lines, storage bar) | load takes longer than `kSkeletonDelay` (150 ms) | **static** (no shimmer, no pulse). When content arrives: content opacity 0 → 1 over the skeleton's removal | content `base` 200 · `decelerate` | (none) | instant swap | `AnimatedSwitcher(fade, stack layout)` keyed by loaded/not-loaded; skeleton = plain `ColoredBox` blocks in `surfaceVariant` |
| 43 | `ExplanationCard` arrives in the stack (pending → complete, new card on top) | AI result / new request | new card opacity 0 → 1. Cards below **jump** down (no slide, no `SizeTransition`). Pending → complete: content crossfade inside the card; height snaps | `base` 200 · `decelerate` | (none) | `fade(fast)` | `FadeTransition` on the new item; inner `AnimatedSwitcher(fade)`; **not** `AnimatedList`'s default insert |
| 44 | Explanation pending progress | card pending | indeterminate linear bar | loop while pending and the panel is visible | (none) | static bar + "explaining…" text | `LinearProgressIndicator` inside its own `RepaintBoundary` (B6 child). Under RM, `LinearProgressIndicator(value: null)` is swapped for a static track |
| 45 | `GlossaryTermTile` expand/collapse | tap › | body appears/disappears **instantly** (height snaps); body opacity fade-in; chevron rotation 0 → 0.25 turn | body `fast` 150 · `decelerate`; chevron `fast` 150 · `standard` | chevron `fast` 150 · `standard`; body removed instantly | instant, chevron jumps | `FadeTransition` + `RotationTransition`; no `ExpansionTile` default (it uses `SizeTransition`) or override its animation style to zero |
| 46 | Downloads / import / sync progress values | progress events | bar fill (determinate) | value set directly, no tween (updates are frequent; tweening lags) | (none) | (none) | `LinearProgressIndicator(value:)` in its own `ValueListenableBuilder` (not a list-wide rebuild) |
| 47 | Coach marks (`StylusModeHint`, `CoachMark`, `readerFirstHighlightHint`, `readerPanelOverlayHint`) | first-time condition | opacity + 4 dp `translateY` | `base` 200 · `decelerate` | `fast` 150 · `standard` | `fade(fast)` | `FadeTransition` + `SlideTransition` in `OverlayPortal` |
| 48 | Onboarding carousel | swipe / arrow keys / PageDown / Next | swipe: gesture-driven `PageView` physics. Next/keys: page scroll `slow` 300 · `standard`. Indicator dot colour `base` 200 | (see trigger) | (none) | swipe still direct; Next/keys `jumpToPage`; dot instant | `PageView` + `PageController.animateToPage` / `jumpToPage`. On `expanded`+ (single card): content crossfade `base` 200 · `standard` via `AnimatedSwitcher` |
| 49 | Sign-in state swaps (form ↔ `AuthBrowserWaitState` ↔ `MagicLinkSentState`) | auth flow | crossfade, layout snaps | `base` 200 · `standard` | (crossfade) | `fade(fast)` | `AnimatedSwitcher` (fade, stack layout) |
| 50 | Splash exit | first frame ready **and** session restored (cap 2 s) | splash opacity 1 → 0 over the app (no logo animation) | (none) | `base` 200 · `standard` | **cut**, no fade (splash spec) | Android: `FlutterNativeSplash.remove()`; Android 12+ system exit animation, not overridden. Desktop `SplashGate`: `FadeTransition` over the first app frame (the app below is library chrome or skeleton, not the PDF) |
| 51 | Window-class change (resize or rotation across a breakpoint) | layout hysteresis commit | **none**: shell swaps instantly (rail ↔ sidebar ↔ bottom bar; panel split ↔ overlay) | (none) | (none) | (none) | `LayoutBuilder` → `PaperWindowClass` with hysteresis; no `AnimatedSwitcher` around shells |
| 52 | Sidebar collapse ↔ rail (library/settings, `large`+) | toggle | width snaps (no tween, which would relayout the grid every frame); labels fade in | labels `fast` 150 · `decelerate` | labels removed instantly | instant | `FadeTransition` on labels |
| 53 | Theme switch (light / dark / system) | Settings | **none** | (none) | (none) | (none) | `MaterialApp(themeAnimationDuration: Duration.zero)` |
| 54 | Visual aid video (`VisualAidPlayer`) | play | video only; no autoplay under RM | (none) | (none) | no autoplay, poster frame shown | platform video player in its own `RepaintBoundary`. Pause when the panel is hidden or the tab is inactive |

### 2.1 Library → Reader fade-through (detail for #2)

The generic `PaperFadePageTransitionsBuilder` would put the whole reader, PDF included, under an `OpacityLayer` for 300 ms. That is exactly the `saveLayer`-over-PDF case §1.7 bans. The reader route uses its own builder instead. The library fades out, then the reader is revealed by a solid curtain whose **colour alpha** fades. Painting a solid rect costs nothing; an opacity layer over the page stack costs an offscreen pass.

```dart
/// Reader route only. The PDF subtree is never wrapped in Opacity/FadeTransition.
class ReaderPageTransitionsBuilder extends PageTransitionsBuilder {
  const ReaderPageTransitionsBuilder();

  @override
  Duration get transitionDuration => PaperMotion.page; // 300

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondary, Widget child) {
    final bg = Theme.of(context).extension<PaperColors>()!.background;
    // 0.0–0.4: reader hidden (library fading out under it, see below).
    // 0.4–1.0: curtain alpha 1 → 0 reveals the reader.
    final curtain = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.4, 1.0, curve: PaperMotion.decelerate),
      reverseCurve: const Interval(0.4, 1.0, curve: PaperMotion.standard),
    );
    return AnimatedBuilder(
      animation: animation,
      child: child, // ReaderScreen: built once, keeps laying out (tiles start rendering)
      builder: (context, child) => Stack(fit: StackFit.expand, children: [
        Visibility(visible: animation.value >= 0.4, maintainState: true,
            maintainAnimation: true, maintainSize: true, child: child!),
        if (animation.value < 1.0)
          IgnorePointer(child: ColoredBox(
              color: bg.withValues(alpha: 1.0 - curtain.value))),
      ]),
    );
  }
}
```

- The **library** (outgoing) fades with `FadeTransition(opacity: ReverseAnimation(secondary interval 0–0.4, accelerate))`. That's fine, because the library has no PDF. Register it through the library route's `secondaryAnimation` (or a `DelegatedTransition` on Flutter versions that have it).
- Pop runs the same timeline in reverse: curtain fades in, the reader hides at 0.4, the library fades back in.
- Under reduced motion the controller runs at 5% duration (§3.2). Also short-circuit: if `MediaQuery.disableAnimationsOf(context)`, return `child` directly.
- The first page is visible from cache at the end of the transition (reader spec: "first page from cache instantly"). Tile rendering starts during the hidden phase because `maintainSize` keeps the reader laid out.

### 2.2 Panel overlay (#3, #4)

- The scrim is `AnimatedModalBarrier(color: ColorTween(transparent → PaperColors.scrim).animate(…))`. This animates colour, not opacity: one rect, no layer.
- The panel content is behind B6. The `SlideTransition` moves a cached layer.
- With the scrim up, the PDF underneath is inert (`ExcludeFocus` + `AbsorbPointer` on B1) and keeps its last frame. Nothing repaints it.

### 2.3 Split panel (#5): slide, then commit; commit, then slide

```
Open (expanded+):  t=0      panel mounted off-screen right, PDF at full width (unchanged)
                   0→300ms  panel SlideTransition +100% → 0, overlaying the PDF's right edge
                   300ms    commit: PdfViewport width = window − panel − handle (ONE relayout),
                            reading anchor kept; old bitmaps drawn scaled; tiles re-rendered async
Close:             t=0      commit: PdfViewport width = full (ONE relayout, under the still-visible panel)
                   0→200ms  panel SlideTransition 0 → +100% (accelerate), revealing the widened PDF
```

The PDF re-layouts exactly twice per open/close cycle, never during a frame of the slide. The split divider and handle are part of the panel's sliding layer.

### 2.4 Toolbar auto-hide (#26)

- The toolbar, page pill and dock are positioned over the PDF in a `Stack`. The PDF's scrollable has a **fixed** top padding equal to the toolbar height plus the inset. The padding doesn't change when the toolbar hides, so content is never re-laid out (L1 in the layout spec).
- State machine: `shown` ⇄ `hidden`. Accumulate `scrollDelta` and reset it when the direction flips. Fire only when |accumulated| ≥ `kToolbarHideThreshold`. Never hide while a popover, the find bar, a menu or keyboard focus is inside the toolbar.
- `expanded`+ toolbars (≥ 840 dp) are persistent. No auto-hide unless the window height is < 480 dp.

---

## 3. Reduced motion

### 3.1 Signals

| Platform | OS setting | Reaches Flutter as |
| --- | --- | --- |
| Android | Settings → Accessibility → "Remove animations" (animator duration scale 0) | `MediaQuery.disableAnimations` = true |
| Windows | Settings → Accessibility → Visual effects → "Animation effects" off | `MediaQuery.disableAnimations` = true (verify on the target Flutter version, P13) |
| macOS | System Settings → Accessibility → Display → "Reduce motion" | `MediaQuery.disableAnimations` / `accessibleNavigation` (verify on the target Flutter version, P13) |

Because platform propagation has varied between Flutter versions, the app adds a user override: **Settings › Appearance › "Reduce motion": System (default) / On**. It's applied once at the root:

```dart
MediaQuery(
  data: MediaQuery.of(context).copyWith(
    disableAnimations: systemReduce || userPrefReduce,
  ),
  child: child,
)
```

Every widget reads only `MediaQuery.disableAnimationsOf(context)` (through `PaperMotion.of` / `PaperMotion.fade`), so the override and the OS signal behave the same.

### 3.2 Mapping rules

| Kind of motion | Under reduced motion | Helper |
| --- | --- | --- |
| Spatial: slide, translate, scale, rotate, sheet slide, toolbar slide, popover rise, dialog scale | **Removed.** The element appears at its final position | `PaperMotion.of(ctx, d)` → `Duration.zero` |
| Opacity fades that help comprehension (popover, menu, dialog, snackbar, banner, tab body, badge state, toolbar hide) | **Kept**, capped at `fast` 150 ms, curve unchanged | `PaperMotion.fade(ctx, d)` |
| Route transitions (#1, #2) | Instant cut. `AnimationController`'s default `AnimationBehavior.normal` already scales durations to 5% when the platform disables animations. The reader builder also short-circuits (§2.1) | built in + check |
| Splash (#50) | Cut, no fade (splash spec) | check `disableAnimations` before calling the fade |
| Loops: sync spin, indeterminate progress, skeleton | **Static.** Never call `repeat()`. Note that `repeat()` is **not** auto-scaled, so check before starting it | `if (!paperReducedMotion(ctx)) _spin.repeat();` |
| Flash on jump (#31) | Static ring for 1 s, then removed | (none) |
| Programmatic scroll (#32), step and double-tap zoom, onboarding Next | `jumpTo` / instant commit | (none) |
| Gesture-driven motion (scroll, fling physics, pinch, split drag, sheet drag, swipe) | **Unchanged.** It's direct manipulation and the content follows the finger. Fling physics stay platform-default | (none) |
| Hover, press, colour changes | Instant colour change | `PaperMotion.of` |
| Video visual aid | No autoplay | (none) |

Suggested helper (tech-mobile adds it next to `motion_extras.dart`; don't edit the token file):

```dart
bool paperReducedMotion(BuildContext c) => MediaQuery.disableAnimationsOf(c);
```

### 3.3 Test

Widget test per animated component: wrap it in `MediaQuery(data: …copyWith(disableAnimations: true))`, trigger the transition, call `tester.pump()` once, and assert the end state for every 0 ms row. For fade rows, `pump(PaperMotion.fast)` reaches the end state. This is checklist item P13.

---

## 4. Platform notes

### 4.1 Android: predictive back (Android 14+)

- Enable it: `android:enableOnBackInvokedCallback="true"` on `<application>`. The system back-to-home preview (from the Library root) is the OS's animation. Don't override it.
- **In-app back (Reader → Library)**: the back gesture **drives the fade-through timeline in #2 directly**. Gesture progress p ∈ [0,1] maps linearly to `animation.value = 1 − p × 0.6`, so a full swipe reaches the curtain-covered point but not the cut. Commit: run the remaining timeline over `fast` 150 ms `standard`. Cancel: return to 1.0 over `fast` 150 ms `decelerate`. **No scale-down or edge-shift of the reader** (the Android default predictive transition scales the page). That conflicts with the quiet personality, and it would make the PDF jump at commit.
- Implementation: on Flutter versions with `PredictiveBackPageTransitionsBuilder`, wrap `ReaderPageTransitionsBuilder` so that when `route.popGestureInProgress` is true, the same curtain is driven by the route's gesture-controlled animation. Use the route's `handleStartBackGesture` / `handleUpdateBackGestureProgress` / `handleCommitBackGesture` / `handleCancelBackGesture` hooks, and check the names against the pinned Flutter version.
- Back closes the topmost transient first, with that component's own exit, never with a predictive preview. The order is: popover / menu / tooltip (#9–#14) → find bar (#27) → overlay panel or sheet (#3, #4) → selection → route. Use `PopScope(canPop: false, onPopInvokedWithResult: …)` on each.
- On the Library root, back defers to the system (back-to-home).

### 4.2 Windows / macOS: live window resize

- **No animation runs because of a resize.** Window-class changes swap shells instantly (#51) and only commit through the layout hysteresis (≥ 8 dp past the boundary for ≥ 1 frame).
- While the user is dragging the window edge, treat the PDF like a split drag (§1.5). Keep pages scaled from the existing bitmaps (fit-width) or clip/translate them (fixed zoom), and re-render tiles `kRerasterIdle` (120 ms) after the last size change. Where the platform reports live-resize start and end (for example `window_manager`'s `onWindowResize` / `onWindowResized`, macOS `windowWillStartLiveResize`, Windows `WM_ENTERSIZEMOVE` / `WM_EXITSIZEMOVE`), use the end event as the commit and the debounce as a fallback.
- Any in-flight animation (popover, snackbar, panel slide) **jumps to its end state** when a resize starts (`controller.value = target`). This avoids animating against changing constraints.
- The macOS full-screen enter/exit and Windows Snap / maximise animations belong to the OS. Don't add app animation on top. Only commit the new size when the OS reports the final frame.
- The native window background is `#0A0A0A` (dark) / `#FAFAFA` (light) per the splash spec, so the area the OS exposes while resizing never flashes white.

### 4.3 High-refresh displays (90 / 120 Hz, ProMotion)

- All timing comes from the `Ticker` (`AnimationController`, the `*Transition` widgets, scroll physics). These adapt to the display's vsync automatically. **Never** hard-code frame intervals: no `Duration(milliseconds: 16)` timers, no "advance one step per frame" counters, no frame-count delays. Durations in this spec are wall-clock milliseconds and look the same at 60 and 120 Hz.
- Wall-clock `Timer`s are fine for non-visual timing: snackbar dismissal, the 2 s picker auto-hide, debounces (150 ms search, 100 ms page indicator, 1 s reading-position save, `kRerasterIdle`).
- To coalesce high-rate input (stylus at 240 Hz, pointer moves during split drag), apply the latest value once per frame (`SchedulerBinding.instance.scheduleFrameCallback`). Don't process every event through layout.
- Android: some OEMs keep apps at 60 Hz unless they ask for more. Verify with the refresh-rate overlay (§1.9). If a 120 Hz tablet stays at 60 Hz, request the highest refresh mode on the reader route (for example the `flutter_displaymode` plugin `setHighRefreshRate()`) and drop back to default when the app is idle or backgrounded to save battery.
- macOS ProMotion: confirm 120 Hz frame intervals in DevTools on Apple-silicon MacBooks. Flutter's macOS embedder follows the display link.
- Fling and scroll physics stay platform-native (`ClampingScrollPhysics` on Android and Windows, `BouncingScrollPhysics` on macOS trackpad). Bounce at the scroll edge is the platform's behaviour, not brand motion, and is allowed. Don't add custom over-scroll effects (stretch / glow cost a `saveLayer`-like pass on some backends). Use `StretchingOverscrollIndicator` default on Android 12+ only if P1 passes with it. Otherwise set `ScrollConfiguration(behavior: …copyWith(overscroll: false))` on the PDF viewport.

### 4.4 Rendering backend

- Impeller is the default on Android and macOS. It precompiles shaders, so first-run animation jank there should be minimal. Windows may still be on Skia depending on the pinned Flutter version, so profile the first run of every catalog row on Windows with a fresh install (P9 and P12 on a clean profile). If a transition janks on first use there, the fix is to simplify it (for example drop the dialog scale), not to warm up shaders.

---

## 5. Out of scope

- Lottie, video assets and illustration animation: none in v1. The splash has no logo animation and the onboarding illustrations are static. Asset weight is 0 KB.
- Marketing-site / landing-page motion (web, handled elsewhere).
- Page-flip, page-curl or horizontal paging animations (the reader scrolls continuously, and the reader spec says "no page-flip animations").
