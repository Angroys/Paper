# Paper app — Adaptive layout system (UX spec)

**Product:** Paper (paper.college) native client · **Platforms:** Android tablets, Windows, macOS
**Fidelity:** Lo-fi structure only. Grayscale, no color/type decisions (design-ui owns tokens; design-copy owns strings; design-motion owns timings).
**Units:** `dp` = Flutter logical pixels. Breakpoints are evaluated on **window width** (`MediaQuery.sizeOf(context).width`), never device type — a resized desktop window and a split-screen tablet both re-flow.

Companion docs: [flows.md](./flows.md) · [screens/](./screens/)

---

## 1. Users and goals

| Persona | Device / modality | Primary job |
| --- | --- | --- |
| **Student reader** (primary) | Android tablet, finger + stylus, often landscape on a desk or portrait in hand; frequently offline (library, train) | Read assigned papers, highlight confusing passages with a pen, get a plain-language explanation |
| **Researcher at a desk** | Windows laptop / Mac, trackpad or mouse + keyboard, large external monitor | Work through several papers, keep notes and glossary open beside the PDF, navigate by keyboard |
| **Returning web user** | Already has a paper.college account and library | Find the same library, highlights and glossary in the native app with no re-learning |

**Explicit goals the layout system serves**

- **L1 — Reading never janks.** Chrome never re-lays the PDF canvas on every frame; panels resize the viewport, they do not re-flow page content mid-gesture (see §6).
- **L2 — Reading area is maximised.** Chrome is minimal and collapsible at every size; the PDF always gets the dominant share.
- **L3 — Same mental model everywhere.** The three destinations (Library, Reader, Settings) and the three panel tabs (Notes, Glossary, Explanation) exist at every window class; only *placement* changes.
- **L4 — Input-appropriate targets.** Touch/stylus targets 48dp; pointer-only dense controls may go to 32dp *only* when the window class is laptop/desktop **and** the last input was a pointer.

---

## 2. Information architecture (anchored on RPR web)

RPR web today (`src/app/(app)`): `library`, `library/[paperId]` (reader), `glossary`, `projects`, `settings`. Reader chrome: sticky zoom toolbar, selection popover, `CitationPopover`, `ExplanationSidebar` (newest-first card stack: pending → complete → error / re-explaining), `FigureHighlightsPanel`.

Native v1 keeps the reader-centric subset; Projects and the standalone Glossary page are **out of v1** (glossary lives inside the reader side panel, scoped to the open paper).

```
App
├── Sign-in                    (unauthenticated root)
├── Library   [top-level dest] /library
│   └── Reader                 /paper/:id   (full-screen route, pushes over shell)
│       └── Side panel tabs: Notes · Glossary · Explanation
└── Settings  [top-level dest] /settings
    ├── Account
    ├── Appearance (theme: System / Light / Dark, default Dark)
    ├── Reader
    ├── Storage & offline
    ├── Sync
    └── About
```

Global, always reachable: **SyncBadge** (in nav chrome) → opens **SyncSheet** (see `screens/sync-status.md`).

Deep links: `paper://auth-callback` (OAuth return), `paper://paper/:id` (open a paper; reserved, v1 handles only if already in library).

---

## 3. Window classes and breakpoints

> **Naming = tokens.** Class ids are `PaperWindowClass` from `design/tokens/paper_tokens.dart` (`PaperBreakpoints`): `compact` < 600 · `medium` 600–839 · `expanded` 840–1199 · `large` 1200–1599 · `extraLarge` ≥ 1600. Brief terms map as: phone / tablet split-screen = `compact`, tablet portrait = `medium`, tablet landscape = `expanded`, laptop = `large`, large desktop = `extraLarge`. Panel widths and gutters below are UX values for design-ui to reconcile into tokens.

| Class id | Width (dp) | Typical device | Nav pattern | Columns | Outer margin | Gutter |
| --- | --- | --- | --- | --- | --- | --- |
| `compact` | < 600 | Phone, tablet split-screen 1/3, tiny desktop window | **Bottom NavigationBar** (2 dests) | 4 | 16 | 8 |
| `medium` | 600 – 839 | Tablet portrait, half-split desktop | **NavigationRail** (collapsed, icons + labels below) | 8 | 24 | 16 |
| `expanded` | 840 – 1199 | Tablet landscape, small laptop window | **NavigationRail** (collapsed) | 12 | 24 | 24 |
| `large` (laptop) | 1200 – 1599 | Laptop full-screen | **Extended rail / sidebar** (icon + label rows, 240dp, user-collapsible to rail) | 12 | 32 | 24 |
| `extraLarge` (desktop) | ≥ 1600 | External monitor | **Extended sidebar** (256dp, default open) | 12 | 40 | 24 (content max-width 1440, centred in library/settings) |

Hysteresis: to avoid flicker while a user drags a desktop window edge across a breakpoint, a class change commits only when width has been on the new side for ≥ 1 frame **and** ≥ 8dp past the boundary. (Engineering hint: `LayoutBuilder` → `PaperWindowClass.of(width)` wrapped in an app-side hysteresis helper that also takes the previous class; the token resolver itself is stateless.)

Height rule: if window height < 480dp on any class, the reader toolbar auto-hides on scroll (same as `compact`) and the side panel cannot be in split mode (overlay only).

### 3.1 Navigation per class

| Class | Library / Settings shell | Inside Reader |
| --- | --- | --- |
| `compact` | Bottom bar: Library · Settings. SyncBadge in the top app bar trailing slot. | No nav bar. Back arrow in ReaderToolbar returns to Library. |
| `medium` | NavigationRail (72dp) left: Library, Settings; SyncBadge pinned to rail bottom. | Rail hidden (reader is a full-screen route). Back arrow in toolbar. |
| `expanded` | Same as medium. | Same. |
| `large` | Sidebar 240dp: app mark, Library, Settings, divider, SyncBadge row ("Synced · 2 min ago"), account chip at bottom. Collapse toggle → rail. | Sidebar hidden. Back arrow + breadcrumb "Library / {paper title}". |
| `extraLarge` | Sidebar 256dp default open. | Same as large. |

Rationale: the reader is a focus surface; the shell nav never coexists with the PDF (gives back 72–256dp of width on every class).

---

## 4. Reader + side panel behaviour

Side panel = **ReaderSidePanel** with tabs Notes · Glossary · Explanation (`screens/reader-side-panel.md`).

| Class | Panel mode | Default width | Min | Max | Resize | Open by default? |
| --- | --- | --- | --- | --- | --- | --- |
| `compact` | **Modal bottom sheet** (DraggableScrollableSheet: snap 40% / 90% height) | full width | — | — | Drag sheet handle vertically | No |
| `medium` | **Overlay side sheet** from right, scrim over PDF, PDF does not resize | 360 | 320 | 85% width | No horizontal resize | No |
| `expanded` | **Resizable split** (PDF shrinks; overlay if the user prefers, Settings › Reader › "Panel style") | 360 | 300 | 50% window | SplitDragHandle | No (opens on first highlight-explain) |
| `large` | **Resizable split** | 380 | 300 | 50% window | SplitDragHandle | Restores last state per device |
| `extraLarge` | **Resizable split** | 420 | 320 | 45% window (and PDF never < 720) | SplitDragHandle | Restores last state; default open on first run |

**Constraint solver:** PDF viewport min width = 480dp. If a split would push the PDF below 480, the panel falls back to overlay mode for that window size (announced once via a non-blocking hint `readerPanelOverlayHint`).

**SplitDragHandle**
- Visual: 1dp divider with a 24×48 grabber centred vertically. Hit area **16dp wide** (pointer) / **24dp wide** (touch), extending into both sides.
- Pointer: hover → resize cursor (`SystemMouseCursors.resizeColumn`); drag; **double-click resets** to class default width.
- Touch/stylus: long-press not required — direct drag on grabber.
- Keyboard: handle is focusable; `←/→` resize by 16dp, `Shift+←/→` by 64dp, `Home` = min, `End` = max. Semantics: `slider`, label `readerPanelResizeLabel`, value = width percent.
- Dragging below min − 48dp snaps the panel **closed** (with haptic tick on tablets); a closed panel is reopened via toolbar button or shortcut.
- **Performance contract:** during drag the PDF view receives the new viewport width at most once per frame; page bitmaps are *scaled* during the drag and re-rasterised at the new zoom only on drag end (prevents 120fps jank). Width persisted on drag end only.

**Panel position:** always right of the PDF (LTR). In RTL locales the panel mirrors to the left; the PDF content itself never mirrors.

---

## 5. Toolbar placement

| Class | ReaderToolbar | PageNavigator | Zoom control | Tool modes (select / highlight / pen / figure) |
| --- | --- | --- | --- | --- |
| `compact` | Top app bar 56dp: back, title (1 line, ellipsis), overflow menu. Auto-hides on scroll down, reappears on scroll up or tap on page margin. | Bottom floating pill "12 / 34" (tap → jump dialog) | Pinch only; zoom % in overflow | Bottom **ToolDock** (floating, 56dp tall, centred) |
| `medium` | Top bar 64dp: back, title, ToolModeSegmented, panel toggle, overflow. Auto-hide on scroll. | Bottom-right floating pill | Pinch + overflow | In top bar (segmented, icons only) |
| `expanded` | Top bar 64dp, persistent (not auto-hide), all controls inline. | Inline in toolbar: `[‹] 12 / 34 [›]` | Inline: `[–] 125% [+]` + fit menu | Inline segmented, icon + tooltip |
| `large` / `extraLarge` | Top bar 48dp (dense when pointer), persistent; title centred on macOS (in title-bar row, see §8). | Inline | Inline + fit-width / fit-page | Inline segmented with labels on `extraLarge` |

Toolbars never overlap the PDF on `expanded+` — they sit above it, so the PDF viewport is a stable rectangle (L1). On `medium`/`compact`, auto-hide uses a transform/opacity animation, **not** a size change, so the PDF never re-lays out.

Selection / citation popovers float over the PDF on all classes (see `screens/reader.md`).

---

## 6. Input modality

The app tracks `lastInputKind ∈ {touch, stylus, mouse, trackpad, keyboard}` from the most recent `PointerEvent.kind` / key event. Layout density keys off **window class + lastInputKind**, not platform.

| Concern | Touch / stylus | Pointer + keyboard |
| --- | --- | --- |
| Min target | **48×48dp** (visual may be 40 with padding) | **32×32dp** visual + hit; icon buttons in dense toolbars 32; list rows 40 |
| Hover states | None (never rely on hover to reveal actions) | Required for all interactive elements: hover overlay, tooltip after 500ms on icon-only buttons, cursor changes (text I-beam over PDF text in select mode, crosshair in figure mode, pen cursor in pen mode) |
| Secondary actions on PaperCard | Long-press → context sheet; also visible overflow (⋮) button | Right-click → context menu; overflow (⋮) shows on hover *and* on keyboard focus |
| Text selection | Long-press word → handles; drag handles | Click-drag; double-click word; triple-click line; Shift+click extend |
| Stylus | Pen mode: stylus draws highlight; finger scrolls/pans (palm rejection = ignore `touch` kind while a `stylus` pointer is down or within 300ms of lift). Stylus barrel button (if reported) = temporary eraser. | n/a |
| Focus ring | Shown only after keyboard input (focus-visible) | Always on keyboard navigation |
| Scroll | Kinetic fling | Wheel = scroll; Ctrl/Cmd+wheel = zoom; trackpad pinch = zoom |

Density switching does not animate layout of the PDF; only chrome (toolbar height 64 ↔ 48) changes, and only on window-class change, never mid-gesture.

---

## 7. Safe areas and insets

- All shells wrap in `SafeArea` except the PDF canvas, which extends edge-to-edge under the Android gesture/status bars and pads content by insets (so pages are never hidden behind system UI).
- Android: edge-to-edge, transparent status + nav bars. Bottom ToolDock and page pill offset by `viewPadding.bottom` + 16. Respect display cutouts in landscape (left/right insets).
- Android split-screen / freeform windows: window class recomputes; treat as desktop-like if a mouse is attached (`lastInputKind`).
- Keyboard (IME) on tablets: Notes editor and sign-in form scroll the focused field above `viewInsets.bottom`; bottom sheet raises with IME.

---

## 8. Desktop window chrome

### macOS
- Use a **unified, transparent title bar** (full-size content view). Traffic lights at top-left, inset **(x: 20, y: 18)** from window origin; reserve a **78 × 52dp** no-content zone top-left.
- Title-bar row height **52dp** (merged with toolbar on `large/extraLarge`): sidebar occupies it at left (traffic lights sit over the sidebar header); in the reader, the ReaderToolbar *is* the title bar row — back button starts at x = 86.
- Empty toolbar regions are draggable (window move); double-click empty area = system zoom behaviour.
- Full-screen mode: traffic lights hide; reclaim the 78dp reserve.
- Native menu bar (PlatformMenuBar): Paper · File (Import from URL…, Import file…, Close paper) · Edit · View (Toggle side panel, Zoom in/out, Actual size, Enter full screen) · Window · Help. Menu items mirror shortcuts in §9.

### Windows
- Custom title bar 40dp (or 48 when toolbar merged) with **caption buttons at top-right** (minimise / maximise-restore / close), each **46 × 32dp**, reserve **138dp** right zone. Support Windows 11 Snap Layouts hover on maximise (use native caption region / `window_manager` + `HTMAXBUTTON` equivalent).
- Draggable empty regions; double-click = maximise/restore.
- App title + icon at left of the title bar on Library/Settings; in the reader, title bar shows paper title.
- No menu bar; shortcuts discoverable through tooltips and a **Keyboard shortcuts** dialog (`Ctrl+/`).

### Window minimums
- Min window size: **480 × 560dp** (falls into `compact` layout). Default first-launch size: 1280 × 800, centred. Persist size/position per display.

---

## 9. Keyboard shortcuts (desktop + tablets with keyboards)

`Mod` = **Cmd** on macOS, **Ctrl** on Windows/Android. Shortcuts are scoped: **G** global, **L** library, **R** reader. Never steal shortcuts while a text field has focus except Esc and Mod-chords listed as G.

| Action | Windows / Android | macOS | Scope |
| --- | --- | --- | --- |
| Search library / focus search | Ctrl+F (in Library) · Ctrl+K anywhere | Cmd+F · Cmd+K | L / G |
| Import from URL | Ctrl+Shift+O | Cmd+Shift+O | G |
| Import file | Ctrl+O | Cmd+O | G |
| Open selected paper | Enter | Return | L |
| Rename selected paper | F2 | Return (when card focused, macOS Finder convention) · also Cmd+R | L |
| Delete selected paper | Delete | Cmd+Backspace | L |
| Undo (delete, highlight, note edit) | Ctrl+Z | Cmd+Z | G |
| Redo | Ctrl+Y / Ctrl+Shift+Z | Cmd+Shift+Z | G |
| Settings | Ctrl+, | Cmd+, | G |
| Keyboard shortcuts help | Ctrl+/ | Cmd+/ | G |
| Back / close paper | Alt+← · Ctrl+W | Cmd+[ · Cmd+W | R |
| Find in paper | Ctrl+F | Cmd+F | R |
| Next / previous find match | F3 / Shift+F3 · Enter / Shift+Enter in find | Cmd+G / Cmd+Shift+G | R |
| Next / previous page | PageDown / PageUp · → / ← (when not zoomed past width) | same | R |
| First / last page | Home / End | Cmd+↑ / Cmd+↓ (also Home/End) | R |
| Go to page… | Ctrl+G | Cmd+Option+G (Cmd+G is find-next) | R |
| Zoom in / out | Ctrl+= / Ctrl+- · Ctrl+wheel | Cmd+= / Cmd+- · pinch | R |
| Actual size (100%) | Ctrl+0 | Cmd+0 | R |
| Fit width / fit page | Ctrl+1 / Ctrl+2 | Cmd+1 / Cmd+2 | R |
| Toggle side panel | Ctrl+\ | Cmd+\ | R |
| Side panel tab: Notes / Glossary / Explanation | Ctrl+Alt+1 / 2 / 3 | Cmd+Option+1 / 2 / 3 | R |
| Highlight selection (last colour) | H | H | R (with selection) |
| Highlight colour 1–6 (Yellow, Green, Blue, Pink, Purple, Orange) | 1 … 6 | 1 … 6 | R (with selection / picker open) |
| Explain selection (AI) | E | E | R (with selection) |
| Add note to selection | N | N | R (with selection) |
| Copy selection | Ctrl+C | Cmd+C | R |
| Tool: select / highlight / pen / figure | V / H (no selection) / P / F | V / H / P / F | R |
| Close popover / sheet / clear selection | Esc | Esc | G |
| Full screen | F11 | Ctrl+Cmd+F | G |
| Retry sync now | Ctrl+Shift+S | Cmd+Shift+S | G |

Single-letter shortcuts are disabled while any text input has focus and can be turned off in Settings › Reader › "Single-key shortcuts" (WCAG 2.1.4).

---

## 10. Accessibility baseline (applies to every screen)

- WCAG 2.2 AA target. Contrast is design-ui's gate; structure here guarantees: every icon-only button has a semantic label (`Semantics(label:)`, keys listed per screen), every state change has a live announcement (`SemanticsService.announce` or `liveRegion: true`).
- Focus order follows reading order: nav → toolbar → content → side panel. The reader exposes skip targets: "Skip to page content", "Skip to side panel".
- Text scaling to 200%: chrome reflows (toolbar overflows into the overflow menu; titles wrap to 2 lines max); PDF zoom is independent.
- Reduced motion (`MediaQuery.disableAnimations`): sheets/panels appear without slide; no parallax; skeleton shimmer becomes static.
- Never convey state by colour alone: highlight colours carry names (`highlightColorYellow`…) and the SyncBadge has icon + text.
- Screen readers (TalkBack, Narrator, VoiceOver): the PDF page exposes its extracted text as a semantics node per page; highlights are announced "Highlighted, {colour}".

---

## 11. Component inventory

Names are canonical — design-ui, design-copy and Flutter engineers should use these identifiers verbatim.

**Shell & navigation**
| Component | Purpose |
| --- | --- |
| `AppShell` | Window-class-aware scaffold choosing bottom bar / rail / sidebar |
| `PaperWindowClass` | Enum + resolver (`compact`, `medium`, `expanded`, `large`, `extraLarge`) with hysteresis |
| `AppNavigationBar` | Bottom nav (compact) |
| `AppNavigationRail` | Collapsed rail (medium/expanded; collapsed large) |
| `AppSidebar` | Extended sidebar (large/extraLarge) |
| `DesktopTitleBar` | macOS traffic-light reserve / Windows caption buttons + drag region |
| `CaptionButtons` | Windows min/max/close |
| `ShortcutsDialog` | Keyboard shortcuts reference |
| `AccountChip` | Avatar + name, opens account menu |

**Sync & connectivity**
| `SyncBadge` | Compact global sync indicator (5 states) |
| `SyncSheet` | Detail sheet/popover: pending list, last sync, retry |
| `OfflineBanner` | Inline, non-blocking notice when offline in a context that needs network |
| `ConflictNotice` | One-shot explanation of LWW overwrite |

**Library**
| `LibraryHeader` | Title, search, import button, sort/view toggle |
| `LibrarySearchField` | Search input with clear + shortcut hint |
| `ImportButton` / `ImportMenu` | Import from URL / file |
| `ImportUrlDialog` | URL entry + validation |
| `ImportProgressTile` | In-list row for an import in progress / failed |
| `PaperGrid` / `PaperList` | Grid (cards) or list (rows) of papers |
| `PaperCard` | Thumbnail, title, meta, DownloadStateBadge, overflow |
| `PaperRow` | Dense list variant of PaperCard |
| `PaperThumbnail` | First-page render / placeholder |
| `DownloadStateBadge` | Per-paper offline state (cloud only / downloading / available offline / failed / update pending) |
| `PaperContextMenu` | Open, Rename, Download/Remove download, Delete |
| `RenameDialog` | Inline-validated rename |
| `DeleteUndoSnackbar` | Delete confirmation with Undo |
| `EmptyState` | Generic illustration slot + title + body + action |
| `SkeletonCard` / `SkeletonRow` | Loading placeholders |
| `NoResults` | Search empty state |

**Reader**
| `ReaderScreen` | Route scaffold: toolbar, PDF view, side panel |
| `ReaderToolbar` | Top bar |
| `ToolModeSegmented` | Select / Highlight / Pen / Figure modes |
| `ToolDock` | Floating bottom variant (compact) |
| `PdfViewport` | pdfium-backed page list, zoom/pan |
| `PageNavigator` | `‹ n / N ›` + jump |
| `PageJumpDialog` | Go to page |
| `ZoomControl` | −/% /+ and fit menu |
| `FindBar` | In-document search |
| `SelectionPopover` | Highlight / colour / Explain / Note / Copy |
| `HighlightPicker` | 6 named colours (`PaperHighlightColor`: Yellow default, Green, Blue, Pink, Purple, Orange) + delete |
| `HighlightMark` | Rendered highlight overlay (text or ink) |
| `InkLayer` | Stylus strokes → highlight geometry |
| `FigureSelectionBox` | Rectangle capture for figure highlights |
| `CitationPopover` | Reference details + actions |
| `NoteEditorInline` | Quick note on a highlight (popover) |
| `ReaderLoadingState` / `ReaderErrorState` | Opening states |
| `StylusModeHint` | First-use coach mark for pen mode |

**Side panel**
| `ReaderSidePanel` | Container (split or overlay) |
| `SplitDragHandle` | Resize handle |
| `PanelTabBar` | Notes · Glossary · Explanation |
| `NoteCard` / `NotesList` | Notes tab |
| `NoteEditor` | Full note editor |
| `GlossaryList` / `GlossaryTermTile` | Glossary tab |
| `ExplanationCard` | Pending / complete / error / re-explaining (mirrors RPR `SidebarEntry` states) |
| `ExplanationStack` | Newest-first stack |
| `VisualAidPlayer` | Manim video (online only) |
| `AiOfflineState` | Panel-level offline fallback |

**Auth & settings**
| `SignInScreen`, `GoogleSignInButton`, `EmailSignInForm`, `AuthBrowserWaitState`, `AuthErrorBanner`, `MagicLinkSentState` |
| `SettingsScreen`, `SettingsSection`, `SettingsTile`, `ThemeSelector`, `StorageUsageBar`, `DownloadedPapersList`, `SignOutDialog` |

**Feedback**
| `AppSnackbar` | Single-line transient feedback, optional action |
| `InlineError` | Field/section error with retry |
| `OnboardingCarousel` / `OnboardingPage` | First run |
| `CoachMark` | Single contextual hint |

---

## 12. Microcopy slot keys (layout-level)

`readerPanelOverlayHint`, `readerPanelResizeLabel`, `navLibrary`, `navSettings`, `navCollapseSidebar`, `navExpandSidebar`, `shortcutsDialogTitle`, `shortcutsDialogSearchHint`, `skipToPageContent`, `skipToSidePanel`, `windowMinimize`, `windowMaximize`, `windowRestore`, `windowClose`, `menuImportUrl`, `menuImportFile`, `menuClosePaper`, `menuToggleSidePanel`, `menuZoomIn`, `menuZoomOut`, `menuActualSize`, `menuShortcuts`.

Onboarding (flow F1, no dedicated screen file): `onboardingReadTitle`, `onboardingReadBody`, `onboardingExplainTitle`, `onboardingExplainBody`, `onboardingOfflineTitle`, `onboardingOfflineBody`, `onboardingSkip`, `onboardingNext`, `onboardingGetStarted`, `onboardingPageIndicator`.

Full key list across all screens is in each screen file; the de-duplicated, sorted union is [`copy-keys.txt`](./copy-keys.txt) (one key per line) for ARB reconciliation.
