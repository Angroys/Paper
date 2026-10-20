# Screen — Reader

**User goal:** Read a paper smoothly and capture what matters (highlights, notes, explanations) without losing my place.
Flows: [F4](../flows.md#f4-open--read--highlight), [F5](../flows.md#f5-ask-ai-explanation--glossary--citations--visuals-with-offline-fallback). Side panel: [reader-side-panel.md](./reader-side-panel.md). Anchor: RPR `PdfReader.tsx` (sticky zoom toolbar, selection popover, `CitationPopover` z-30 dialog, "Back to page N" bottom-centre return pill, `FigureOverlay`).

## Regions
1. **ReaderToolbar** — back, title, `ToolModeSegmented`, `PageNavigator`, `ZoomControl`, find, panel toggle, overflow (Download/Remove download, Rename, Paper info, Shortcuts), `SyncBadge` (compact form).
2. **PdfViewport** — continuous vertical scroll of pages (default), pinch/Mod+wheel zoom, pan when zoomed. Overlays: `HighlightMark`s, `InkLayer`, `FigureSelectionBox`, `SelectionPopover`, `CitationPopover`, `HighlightPicker`.
3. **Floating chrome** — page pill (compact/medium), `ToolDock` (compact), "Back to page N" return pill after following an internal link/citation (bottom-centre).
4. **ReaderSidePanel** (split or overlay per class).
5. **FindBar** (slides under toolbar).

## Wireframes

### compact (<600)
```
┌──────────────────────────────┐
│ ←  Attention Is All Yo…  ⋮   │ auto-hides on scroll down
├──────────────────────────────┤
│ ┌──────────────────────────┐ │
│ │        page 12           │ │
│ │  ▒▒▒▒▒ highlighted ▒▒▒   │ │
│ │                          │ │
│ └──────────────────────────┘ │
│        ( 12 / 34 )           │ page pill
│  [▸ Select][✎ Hi][🖊 Pen][▢][▤]│ ToolDock (▤ = panel → bottom sheet)
└──────────────────────────────┘
```

### medium (600–839, portrait tablet)
```
┌──────────────────────────────────────────────┐
│ ←  Attention Is All You Need   [▸|✎|🖊|▢]  ▤  ⋮ │ 64dp, auto-hide
├──────────────────────────────────────────────┤
│        ┌────────────────────────────┐        │
│        │          page              │        │
│        │                            │        │
│        └────────────────────────────┘        │
│                                   ( 12/34 ) │
└──────────────────────────────────────────────┘
Panel ▤ → overlay side sheet from right (360dp) with scrim.
```

### expanded (840–1199, landscape tablet) — split open
```
┌─────────────────────────────────────────────────────────────────────┐
│ ← Title…  [▸|✎|🖊|▢]  ‹ 12 / 34 ›  [–]125%[+]  🔍  ◎  ▤  ⋮          │ persistent 64dp
├───────────────────────────────────────────┬─╫─┬─────────────────────┤
│   ┌───────────────────────────────┐       │ ║ │ Notes|Glossary|Expl │
│   │           page                │       │ ║ │  …                  │
│   │                               │       │ ║ │                     │
│   └───────────────────────────────┘       │ ║ │                     │
└───────────────────────────────────────────┴─╨─┴─────────────────────┘
                                    SplitDragHandle
```

### large / extraLarge (desktop) — macOS shown; Windows: caption buttons right instead of traffic lights left
```
┌───────────────────────────────────────────────────────────────────────────────┐
│ ●●●  ← Library / Attention Is All You Need   [Select|Highlight|Pen|Figure]     │
│        ‹ 12 / 34 ›   [–] 125% [+] Fit ▾    🔍   ◎ Synced   ▤   ⋮              │ 48–52dp title row
├──────────────────────────────────────────────────────┬─╫─┬────────────────────┤
│                                                      │ ║ │ Notes Glossary Expl│
│        ┌──────────────────────────────┐              │ ║ │                    │
│        │            page              │              │ ║ │                    │
│        └──────────────────────────────┘              │ ║ │                    │
│                 ( ↩ Back to page 4 )                 │ ║ │                    │
└──────────────────────────────────────────────────────┴─╨─┴────────────────────┘
```

## Page navigation & zoom
- **PageNavigator**: `‹` / `›` buttons, "12 / 34" button → `PageJumpDialog` (numeric field, range-validated `readerPageOutOfRange`). Thumbnail strip is v1.1 (not in scope).
- Current page = page occupying viewport centre; updated at most every 100ms during scroll.
- **ZoomControl**: −/+ steps (50, 75, 100, 125, 150, 200, 300, 400%); Fit width (default on open for first time), Fit page. Pinch zoom is continuous 25–800%. Double-tap (touch) toggles fit-width ↔ 200% at tap point. Zoom % announced politely on change (as RPR `aria-live` on %).
- **Performance:** zoom gesture scales the existing raster (transform), re-rasterises visible pages at the settled scale after gesture end; never relayout the page list mid-gesture.

## Tool modes (`ToolModeSegmented`)
| Mode | Touch | Stylus | Mouse |
| --- | --- | --- | --- |
| **Select** (default on mouse/finger) | long-press → selection | stylus acts as finger (drag selects) | click-drag selects |
| **Highlight** | drag over text → highlight on lift | same | drag → highlight on release |
| **Pen** (default once a stylus is detected) | finger scrolls/pans only | stroke → highlight snapped to text lines; on non-text → ink mark | mouse draws ink (rare; allowed) |
| **Figure** | drag rectangle → `FigureSelectionBox` | same | same, crosshair cursor |
Esc / tapping the active mode returns to Select. Mode persists per device.

### Stylus mode details
- First stylus contact on a page: `StylusModeHint` coach mark once ("Pen mode on — your finger still scrolls", `readerStylusHint`) with [Got it] [Turn off auto-switch].
- Stroke feedback: live translucent stroke under the pen (rendered at input rate on a separate layer — must not trigger page repaint); on lift, snaps to text-run rectangles in 1 frame.
- Pressure ignored for width in v1 (consistent highlight height).
- Eraser (stylus tail or barrel button where reported, or `Eraser` toggle in ToolDock): stroke over highlight deletes it → undo snackbar.
- Palm rejection: ignore `touch` pointers while stylus is in proximity/down + 300ms.

## SelectionPopover
Appears above selection (below if < 56dp space above; never covers selection). On touch, placed clear of the system selection handles.
```
┌───────────────────────────────────────────────────┐
│ ● ● ● ● ● ●  │ ✦ Explain │ ✎ Note │ ⧉ Copy │ ⋯ │
└─────────────────────────────────────────────────────┘
  └ HighlightPicker colours (tap = highlight in that colour)
```
- ⋯ = Search the web for selection, Look up in Glossary (if exists).
- Offline: Explain shows a small offline glyph; still tappable → queued card (F5).
- Keyboard: popover is reachable via Tab from selection; shortcuts H, 1–6, E, N, Mod+C.

## HighlightPicker (on existing highlight)
Tap/click a highlight → picker anchored to it:
```
┌───────────────────────────────────────────┐
│ ● ● ● ● ● ●   │ ✎ Note │ ✦ Explain │ 🗑 Delete │
└─────────────────────────────────────────────┘
```
6 colours with names, in token order (`PaperHighlightColor`): Yellow (default), Green, Blue, Pink, Purple, Orange (keys `highlightColorYellow` … `highlightColorOrange`; shortcuts 1–6 in that order). Selected colour shows a check glyph, not just a ring. Hover (pointer) over a highlight shows an outline + tooltip of note preview if any.

## CitationPopover
Tap/click an in-text citation marker ([12], (Smith 2020)) → anchored dialog:
```
┌──────────────────────────────────────────┐
│ [12]  Vaswani, A. et al. (2017)          │
│ Attention Is All You Need. NeurIPS.      │
│ ── online ─────────────────────────────  │
│ [ Import into library ] [ Open link ↗ ]  │
│ [ Go to reference ↓ ]                    │
│ ── offline ────────────────────────────  │
│ citationOfflineHint                      │
│ [ Go to reference ↓ ]                    │
└──────────────────────────────────────────┘
```
States: loading metadata (skeleton lines), resolved, not resolvable (`citationNotFound` – raw reference text only), importing (`importInProgress`), imported (`citationImported` [Open]), in library (`citationInLibrary` [Open]), error (`citationImportFailed` [Retry]). "Go to reference" jumps and shows the "Back to page N" pill.

## Notes on highlights
> Colour and notes persistence: see [flows.md › Data-model gap](../flows.md#data-model-gap-highlight-colour-notes-edit-timestamps-needs-cto-decision). Until the CTO decides, colour and notes are local-first (SQLite) and sync only where the server schema has a column.

`NoteEditorInline` opens from Note: multi-line field anchored near highlight (`compact` / `medium`, no split) or focuses the Notes tab with the new note (split classes). Autosaves on blur / 1s idle; never a Save button only.

## FindBar
`[🔍 term____] 3 of 17 [↑][↓] [Aa] [×]` — matches highlighted transiently; results count announced.

## States
| State | Display |
| --- | --- |
| Opening (cached) | First page from cache instantly; no spinner. |
| Opening (downloading) | `ReaderLoadingState`: title + progress bar "Downloading {done} of {total}" (`readerDownloading`) + [Cancel]; pages appear as they become renderable. |
| Render error | `ReaderErrorState(readerRenderFailed)` [Re-download] [Back]. |
| Download error | `ReaderErrorState(readerDownloadFailed)` [Retry] [Back]. |
| Paper deleted elsewhere | `ReaderErrorState(readerPaperDeleted)` [Back to library]. |
| No highlights yet | One-time subtle hint near toolbar: `readerFirstHighlightHint` (input-aware variant: `readerFirstHighlightHintPen`). |
| Offline | Reading/highlight/notes fully functional; AI & citation-import show offline states; SyncBadge offline. |
| Pending sync | SyncBadge count; no per-highlight spinners. |
| Scanned PDF (no text layer) | Banner `readerNoTextLayer`: text highlight & Explain disabled; Figure + Pen ink still work. |

## Components
`ReaderScreen`, `ReaderToolbar`, `ToolModeSegmented`, `ToolDock`, `PdfViewport`, `PageNavigator`, `PageJumpDialog`, `ZoomControl`, `FindBar`, `SelectionPopover`, `HighlightPicker`, `HighlightMark`, `InkLayer`, `FigureSelectionBox`, `CitationPopover`, `NoteEditorInline`, `StylusModeHint`, `ReaderLoadingState`, `ReaderErrorState`, `SyncBadge`, `ReaderSidePanel`, `SplitDragHandle`, `AppSnackbar`.

## Microcopy keys
`readerBack`, `readerBackToPage`, `readerToolSelect`, `readerToolHighlight`, `readerToolPen`, `readerToolFigure`, `readerToolEraser`, `readerPageIndicator`, `readerPrevPage`, `readerNextPage`, `readerGoToPage`, `readerPageJumpTitle`, `readerPageJumpField`, `readerPageOutOfRange`, `readerZoomIn`, `readerZoomOut`, `readerZoomLevel`, `readerFitWidth`, `readerFitPage`, `readerFind`, `readerFindResultCount`, `readerFindNoResults`, `readerFindMatchCase`, `readerTogglePanel`, `readerMore`, `readerPaperInfo`, `readerDownloading`, `readerDownloadFailed`, `readerRenderFailed`, `readerRedownload`, `readerPaperDeleted`, `readerFirstHighlightHint`, `readerFirstHighlightHintPen`, `readerStylusHint`, `readerStylusAutoSwitchOff`, `readerNoTextLayer`, `readerGotIt`, `selectionExplain`, `selectionExplainOffline`, `selectionNote`, `selectionCopy`, `selectionCopied`, `selectionMore`, `selectionSearchWeb`, `selectionLookUpGlossary`, `highlightColorYellow`, `highlightColorGreen`, `highlightColorBlue`, `highlightColorPink`, `highlightColorPurple`, `highlightColorOrange`, `highlightDelete`, `highlightCreatedUndo`, `highlightDeletedUndo`, `highlightSaveFailed`, `highlightAnnouncement`, `figureSaveHighlight`, `figureAddNote`, `figureCancel`, `citationLoading`, `citationNotFound`, `citationImport`, `citationOpenLink`, `citationGoToReference`, `citationImported`, `citationInLibrary`, `citationOpen`, `citationImportFailed`, `citationOfflineHint`, `noteInlinePlaceholder`, `noteSaved`, `readerFindActOnMatch`.

## Accessibility
- Page semantics: each page node labelled `readerPageIndicator` ("Page 12 of 34") with its extracted text; screen readers can read linearly.
- Highlights exposed as custom semantics actions on the page node ("Highlight: '{excerpt}', yellow" → actions: change colour, add note, explain, delete) so they're operable without precise pointing.
- Tool mode buttons are a radio group; current mode announced.
- Popovers trap focus lightly (Tab cycles; Esc closes and returns focus to the selection/marker).
- Keyboard text selection: in Select mode with focus on a page, Shift+arrow extends a caret-based selection (caret browsing toggle F7) — v1 minimum: Find → select match → H/E to act on match (`readerFindActOnMatch`).
- Colour names always shown in tooltip/semantics; selected state indicated by a check glyph.
- Reduced motion: popovers fade only; no page-flip animations.
- Minimum touch targets 48dp for SelectionPopover buttons even when visually compact.
