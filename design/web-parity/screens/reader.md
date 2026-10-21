# Reader (S2): web-parity spec

- **App route:** `/reader/:paperId`. It is full screen and outside the shell, with **no app nav bar** (README §2.5).
- **Web route:** `/library/[paperId]`:
  - `app/(app)/library/[paperId]/page.tsx`: header strip, error and no-PDF states.
  - `reader/PdfReaderLoader.tsx`: split layout, panel, show/hide buttons.
  - `reader/PdfReader.tsx`: PDF pane, zoom pill, selection popover, citation anchoring, back-to-page pill.
  - `reader/CitationPopover.tsx`
  - `reader/FloatingExplanationPopover.tsx`
  - `reader/FigureOverlay.tsx`
- **Components:** [`../components.md`](../components.md).
- **Side panel internals:** [`side-panel.md`](side-panel.md).

**References** (all in [`../reference/`](../reference/)):

| Shot | Use |
|---|---|
| [`reader.1280x800.png`](../reference/reader.1280x800.png), [`reader.800x1280.png`](../reference/reader.800x1280.png) | header strip, docked panel, zoom pill, page framing |
| [`reader.panel-hidden.1280x800.png`](../reference/reader.panel-hidden.1280x800.png), [`.800x1280`](../reference/reader.panel-hidden.800x1280.png) | full-width pane + floating "Show explanations" button |
| [`reader.selection-popover.*`](../reference/reader.selection-popover.1280x800.png), [`reader-android.selection-popover.*`](../reference/reader-android.selection-popover.1280x800.png) | selection popover |
| [`reader.highlight-rest.*`](../reference/reader.highlight-rest.1280x800.png), [`reader.highlight-hover.*`](../reference/reader.highlight-hover.1280x800.png) | user highlight wash at rest and on hover |
| [`reader.term-hover.*`](../reference/reader.term-hover.1280x800.png), [`reader-android.term-hover.*`](../reference/reader-android.term-hover.1280x800.png) | blue term mark hover |
| [`reader.mention-hover.*`](../reference/reader.mention-hover.1280x800.png) | teal in-document link ("Figure 1") hover |
| [`reader-android.term-click-focus-lock.*`](../reference/reader-android.term-click-focus-lock.800x1280.png) | **floating explanation popover** box and content only. Ignore the blurred backdrop, focus card and "Focus time" HUD, which are the web-only focus lock. |
| [`reader-android.1280x800.png`](../reference/reader-android.1280x800.png), [`.800x1280`](../reference/reader-android.800x1280.png) | pane with no docked panel (the panel-hidden look on a mobile OS) |
| *(none)* | **Citation popover**, figure pills, toasts: these could not be captured. Build them from components §10.2, §10.5 and §15. |

**Decisions applied (CMO):**

- **Panel mode by width:**
  - **≥ 1024:** the panel docks at 384, as on web desktop.
  - **640–1023:** overlay.
  - **< 640:** bottom sheet.
- **Floating explanation popover** (the `reader-android.*` look): it shows the newest explanation whenever the panel is not visible.
- **Zoom** stays where the web puts it: a sticky centred pill over the PDF.
- **Web-only items not reproduced:**
  - "Remove" in the header (the app reader has no delete);
  - the "Give feedback" button in the zoom pill;
  - focus lock;
  - the match notice. The app has no auto-matched papers. The component is specified in components §17 in case it is needed later.

---

## 1. Layout

```
┌──────────────────────────── header strip 52 + 1 ─────────────────────────────┐
│ ‹  Title …                         [tools] [‹ 3 / 12 ›] [⌕] [sync] [···]       │
├───────────────────────────────────────────────┬──────────────────────────────┤
│ PDF pane (scroll)        ┌─ zoom pill ─┐       │ side panel 384 (docked)      │
│  px-6 py-6               └─────────────┘       │  header 40 + 1               │
│        ┌───────── page ─────────┐               │  body (per tab)              │
│        │                         │               │                              │
```

| | 1280×800 | 800×1280 | < 640 |
|---|---|---|---|
| Header strip | 0–53 (52 + 1 px `gray800` border), plus `viewPadding.top` | same | same |
| Panel | **docked** at x 896–1280 (1 px `gray800` left border at x 895, 384 fill) | **overlay** 384 wide, right-anchored, y 53 → bottom, **closed by default** | **bottom sheet** (side-panel.md §1.3) |
| PDF pane | x 0–895, y 53–800. Inner padding 24 on all sides, so the page fits in **847** at fit-width. | x 0–800. Page max **752**. | window − 48 |
| Panel hidden | the pane spans 0–1280 (page max 1232) | n/a (overlay already floats) | n/a |

- **Docked split:** the existing `ReaderSplitView` keeps its drag handle (existing feature). Default and reset width is 384, and the divider is the 1 px `gray800` border. The grabber appears only on hover: 4×32, radius full, `gray700`, centred on the border, with a hit width of 16.
- **Viewport stability:** the PDF viewport is never resized by the panel in overlay or sheet modes (motion.md P-rules).
- **Panel transitions:** showing or hiding the panel is **instant** on the web. design-motion may keep the app's existing ≤ 200 ms slide under `PaperMotion.of`; with reduced motion it must be instant.

---

## 2. Header strip (`ReaderHeader`, components §11.1)

| Part | Spec |
|---|---|
| Box | Fill `gray950`. Bottom border 1 `gray800`. Padding `px-4` (+ `viewPadding.left/right`), `py-3` (+ `viewPadding.top`). Content height **28**, gap **8**. |
| Back | `PaperIconButton` 28 with `reader-back.svg` 20 `gray400`; hover fill `gray800` + `gray100`. Tooltip `readerBack`. The left edge of the glyph box is at x = 12, because of `-m-1` with a 16 padding. |
| Title | `sectionTitle` 18/28 600 −0.45 `gray100`, `flex-1`, one line, ellipsis. Min width 120 before controls collapse. |
| **Tool mode** (≥ 640) | `PaperSegmented.sm` with 4 icon segments: select · highlight · pen · figure (components §19 glyphs, 16). 28 tall, about 103 wide. Selected = `accentSoft`/`accentInk`. Tooltips only, no labels. |
| **Page navigator** (≥ 640) | `PaperIconButton` 24 prev (`nav-back.svg` 16) · the label `PaperButton.ghost xxs` "3 / 12" (`xs` tabular `gray400`, opens the existing go-to-page dialog) · `PaperIconButton` 24 next (mirrored). Gap 2. |
| **Find** | `PaperIconButton` 28 with Lucide `search` 16 (chrome stroke 1.75, drawn at 16). Opens the find bar (§9). |
| **Sync badge** | `SyncBadge` icon form, 28 box, 16 glyph `gray400` (components §19). Absent in offline-only builds. |
| **More** | `PaperButton.ghost xs` with the text "···" (24 tall). It opens a `PaperMenu`: "Fit width", "Paper info", and below 640 also "Go to page…" and "Find". The old zoom items leave the menu because the zoom pill is always visible. |
| Panel toggle | **Removed from the strip.** Hide is in the panel header; show is the floating button (§3.3). The `Mod+\` shortcut (`TogglePanelIntent`) is unchanged. |

At **< 640**:

- the tools move to the existing `ToolDock` (components §11.6);
- the page navigator moves into the "···" menu;
- the strip shows: back · title · find · sync · ···.

---

## 3. PDF pane

### 3.1 Backdrop and pages

- **Pane:**
  - Fill `gray950`, full-bleed.
  - Padding 24 on all sides (`px-6 py-6`) + `viewPadding.left/right/bottom` for the page layer.
- **Pages:**
  - White (`c.pdfPage`), centred (`mx-auto`), stacked with a **16** gap (`mb-4`).
  - Each page has a 1 px **outer** hairline `PaperWeb.white10` (`ring-1 ring-white/10`). There is no shadow and no radius.
- **Page placeholder** (before render): the same box, filled `gray800`, with the same hairline. No spinner.
- **Selection colour:** `PaperWeb.pdfSelection` (indigo-600 @ .30).
- **Highlights and reader marks:** `PaperHighlightColors.whitePaper` (rest alpha 0.10) and `PaperReaderMark.*` (tokens.md §2). These are already implemented. Verify the rest-wash alpha dropped to 0.10.

### 3.2 Zoom pill

`ZoomPill`, components §11.2:

- **Box:** 36 tall, about 130 wide (8 + 26 + 6 + 48 + 6 + 26 + 8 + 2).
- **Position:** fixed over the pane, horizontally **centred on the pane** (not the window). Its top is **24 below the pane top**, so y = 77 at both sizes (53 + 24) + `viewPadding.top`.
- Pages scroll **under** it. It never scrolls away (`sticky top-0` inside the 24 px padding).
- **Layer:** `PaperLayer.readerChrome` (20). That is above the selection popover (10) and below the citation popover (30).
- **Behaviour:** `−` / `+` step the app's existing zoom levels. They are @ 0.5 and disabled at the limits. The percentage label is `pageIndicator` with `min-w-12`. Tapping the label keeps the app's existing action (fit width), with no new behaviour.
- **At 1280 docked:** the pill centre is at x ≈ 447. At 800 (overlay closed) it is at x = 400.

### 3.3 Show-panel button

- **Box:** `PaperIconButton` 36 bordered with `panel-show.svg` 20 `gray300`, `shadowSm`.
- **Position:** `top: 12`, `right: 12 + viewPadding.right` inside the pane (`absolute right-3 top-3`).
- **When shown:** only while the panel is hidden or closed, in every mode.
- **Placement at 1280:** x 1232–1268, y 65–101.
- **Action:** it opens the panel in the current mode.

### 3.4 Return pill

The app's `ReturnPill` maps to the web back-to-page pill (components §11.4):

- `bottom: 24 + viewPadding.bottom`, centred on the **pane**;
- label "↩ Back to page N" (existing copy);
- 38 tall.

### 3.5 Tool dock (< 640)

Components §11.6:

- bottom-centred in the pane, `bottom: 24 + viewPadding.bottom`;
- it hides while a popover is open (existing behaviour).

---

## 4. Selection and highlight popovers

These are `SelectionPopover` and `HighlightPicker` (components §10.1).

| Property | Spec |
|---|---|
| Box | `gray900`, no border, radius 6, padding 4, gap 4, `shadowLg`, **40 tall** |
| Content (selection) | **Explain** (primary, `indigo950` on `accent`) · 6 hue swatches 32×32 · 1×20 `gray700` divider · **Note** · **Copy** |
| Content (highlight tap) | 6 swatches (current hue checked) · divider · **Note** · **Explain** (primary) · **Delete** (destructive text) |
| Anchor | Horizontal centre = centre of the selection's bounding box. The **bottom edge sits 8 above the selection's top** (`top: anchor.top − 8`, `-translate-y-full`). |
| Clamp | The clamp rect is the PDF pane rect deflated by `viewPadding` + 8. The web clamps the anchor point to ≥ 40 from the content top. The app keeps its existing **flip**: if the popover would cross the clamp top (or the zoom pill band, y < 77 + 36 + 8), place it **8 below the selection's bottom** instead. Clamp horizontally to the rect. |
| Layer | `PaperLayer.selectionPopover` (10) |
| Motion | none. It appears on selection end and disappears on clear, in one frame. |
| Copy feedback | the label reads "Copied!" for 1.5 s (not a snackbar) |
| Offline (Explain) | stays enabled, with a trailing `cloud-off` 14 `indigo950` and a tooltip (`selectionExplainOffline`) |
| Pending highlight wash | while the popover is up, the selection paints `PaperHighlightColors.pending` (amber 400 @ .40), which is the web `highlight-mark--pending` |

---

## 5. Citation popover

`CitationPopover`, components §10.2. **No reference shot exists**, so build it from the source classes.

| Property | Spec |
|---|---|
| Box | **320** wide, max **320** tall (scrolls), `p-4`, fill `gray900`, border 1 **`gray700`**, radius 8, `shadowXl` |
| Anchor | Centred horizontally on the citation marker. The **top is 6 below the marker's bottom edge** (`top: marker.bottom + 6`). |
| Clamp / flip | Clamp horizontally to the pane rect − `viewPadding` − 8. If the bottom would cross the clamp bottom, flip **above** (bottom = marker top − 6). This is app behaviour; the web scrolls with the page instead. |
| Header | title `cardTitle` ("Reference 12") + `×` 24 close |
| Entries | `gap-3`, separated by `border-t gray800 pt-3`. Label `xs 600 gray400`. Text `sm-relaxed gray200`. |
| App content mapping | "In your library" block (accent-soft) when matched. Link-outs `xs 500 accent` ("Open source ↗"). "Add to library" = `CITE_ADD_BUTTON_CLASS` (24 tall, `indigo950` on `accent`). The app's "Jump to reference" = `PaperLink.accent xs` ("Go to reference ↓", text glyph). Offline line: `xs gray400` with `info-small.svg` 16. |
| States | **Resolving:** `sm italic gray400` "Looking up reference…". **Not found:** `sm italic gray400`. **Add pending:** `PaperSpinner` 16 + `xs gray400`. **Added:** `xs 500 green400`. **Error:** `xs red400`. |
| Layer | `PaperLayer.citationPopover` (30) |
| Dismiss | Escape, outside tap, `×`. Opening another popover closes this one. |

---

## 6. Explanation popover (floating)

`FloatingExplanationPopover`, components §10.3. The box and contents match `reader-android.term-click-focus-lock.800x1280.png` (the popover over the blurred card).

**When:** an explanation is requested (Explain on a selection, or tapping a cached term mark) **and the side panel is not visible**:

- the panel is hidden at ≥ 1024;
- the overlay is closed at 640–1023;
- the sheet is closed below 640.

When the panel is visible, the new card goes to the top of the Explanation tab instead (side-panel.md §3.4), as on web desktop.

| Property | Spec |
|---|---|
| Box | width `min(320, window − 16)`, max height 70 % of the window, fill `gray950`, border 1 `gray800`, radius 8, `shadowXl`, scrolls inside |
| Content | one `ExplanationCard` (components §12.3) with all its states: pending, progress, complete (tags, prose, timestamp, rating), error, offline |
| Anchor | the explained word's rect in window coordinates |
| Placement | **Below** the anchor + 8. **Flip above** (anchor top − height − 8) when it fits above and not below. Otherwise use the roomier side. Horizontal centre on the anchor. Both axes clamped 8 from the clamp rect (pane rect − `viewPadding`). |
| Layer | `PaperLayer.floatingExplanation` (40) |
| Dismiss | outside tap, Escape, the card's `×`. The explanation stays in the panel's Explanation tab. |
| Updates | If the card is pending, it fills in place. Its height change re-runs placement once, with no animation. |

---

## 7. Figure tool popover

The app's `FigurePopover` becomes the web figure pills (components §10.5):

- a column of white pills, `right 4 / top 4` inside the drawn figure rect, gap 4;
- "Save figure" / "Add note" / "Cancel" as text labels, with no icons;
- error pill below when saving fails.

The figure outline is a 1.5 dashed `#4F46E5` with offset 2 (tokens.md §8).

---

## 8. Term and mention hover

There is no popover; the mark changes (components §10.4):

| Mark | Rest | Hover / focus | Press |
|---|---|---|---|
| Cached term (blue) | `#60A5FA` @ .10 multiply | `rgba(59,130,246,.55)` + 1.5 ring `#2563EB`, scale 1.04 | `.68` |
| User highlight (amber/hue) | wash @ .10 | `hue.reveal` @ .55 + 1.5 `hue.ring`, scale 1.02 | `.68` |
| In-document link (teal) | `#2DD4BF` @ .10 | `rgba(20,184,166,.55)` + ring `#0D9488` | |
| External mention (gray) | `#A3A3A3` @ .10 | `rgba(115,115,115,.55)` + ring `#525252`, plus `PaperTooltip` with the mention name after 500 ms (pointer only) | |
| Citation (indigo) | `#818CF8` @ .10 | `rgba(99,102,241,.55)` + ring `#4F46E5` | opens §5 |

- **Timing:** hover delay 40 ms, reveal 150 ms decelerate, settle 200 ms standard, press 80 ms. Reduced motion: instant, no scale.
- **Focus:** a 2 px `#4F46E5` ring.
- **Rect radius:** marks are 2.

---

## 9. Find bar (app-only)

When open, it replaces the strip's tool/page/find controls. The title stays, and the bar is right-aligned:

- `PaperTextField.xs` 256×26 (autofocus);
- match count `xs` tabular `gray400`;
- prev/next `PaperIconButton` 24;
- `Aa` toggle (`PaperSegmented.sm`, single segment);
- `×` 24.

The strip height does not change. Escape closes the bar and returns focus to the find button. Find hits paint `PaperReaderMark.term` hover colours on the current hit and the rest wash on the others (existing behaviour).

---

## 10. States

| State | Spec |
|---|---|
| **Loading document** | The strip renders (title if known, else empty). Inside the pane `p-6`: `PlaceholderCard`-style box `rounded-lg border gray800 bg gray900 p-8 text-center sm gray400` "Preparing the reader…" (`commonLoading` or the existing reader loading copy). No skeleton pages. Source: `PdfReaderLoader.tsx` L69. |
| **Pages rendering** | Per-page `gray800` placeholders (§3.1). |
| **Open error** | The pane holds `ErrorBanner` with `p-6` inside a `p-6` wrapper: `rounded-lg border red900 bg red950 p-6 sm red300` + the app's retry `mt-3 PaperButton.secondary xs`. Source: `[paperId]/page.tsx` L218. |
| **No PDF / not downloaded offline** | `PlaceholderCard` (`p-6`, `gray800` border, `gray900` fill, `sm gray300`, first line `font-medium gray100`). Source: `[paperId]/page.tsx` L203. The app's download action is `mt-3 PaperButton.primary sm`. |
| **AI unavailable / offline** | Inside the explanation card and panel only (side-panel.md §4). The reader itself does not change. |

---

## 11. Insets and IME (README §4.4, §4.6)

- **Header strip:** the fill and hairline extend under the top cutout and side cutouts. The content is inset `top/left/right`.
- **PDF pane:** the backdrop is full-bleed. The page layer, zoom pill, show-panel button, return pill and tool dock are inset by `viewPadding` (left/right/bottom; top via the strip).
- **Popovers:** clamp rect = pane rect deflated by `viewPadding` + 8.
- **Reader `Scaffold`:** `resizeToAvoidBottomInset: false`. Text fields in the panel or sheet lift only their own container. The find bar is in the strip and does not lift.

---

## 12. Parity checklist

Compare with `reader.selection-popover.1280x800.png`, `reader.800x1280.png`, `reader-android.term-hover.1280x800.png` and `reader-android.term-click-focus-lock.800x1280.png`.

- [ ] Header strip 52 tall + 1 px `#262626` bottom border (the border row is at y = 52), fill `#0A0A0A`, no app nav bar above it.
- [ ] Back chevron 20 px `#A3A3A3` at x ≈ 16–36; title Geist 18/28 600 −0.45 `#F5F5F5`, one line with ellipsis, 8 after the back box.
- [ ] Every control in the strip is ≤ 28 tall; segmented selected tool = `#C7D2FE` on `#1E1B4B`; no Material icons.
- [ ] Docked panel at ≥ 1024: 384 wide, 1 px `#262626` left border, panel header 41 tall (40 + border).
- [ ] PDF pane fill `#0A0A0A`, 24 padding, pages white with a 1 px `rgba(255,255,255,.1)` outer hairline, 16 between pages, no shadow.
- [ ] Zoom pill: 36 tall, `#171717` fill, 1 px `#262626` border, radius 6, top edge 24 below the strip, centred on the pane; ± buttons 26×26 with a visible 1 px `#404040` border and a `#E5E5E5` glyph; label 12/16 tabular `#D4D4D4`, min width 48.
- [ ] Selection popover: `#171717` fill, no border, radius 6, 4 padding, 40 tall, `shadow-lg`; "Explain" 32 tall, `#818CF8` fill, `#1E1B4B` 14/20 500 label; secondary items `#E5E5E5`, hover `#262626`.
- [ ] Selection popover bottom edge 8 above the selection; flips below only when clipped by the clamp rect or the zoom pill.
- [ ] Citation popover 320 wide, ≤ 320 tall, padding 16, `#171717` fill, 1 px `#404040` border, radius 8, `shadow-xl`, top 6 below the marker.
- [ ] Floating explanation popover: 320 wide, `#0A0A0A` shell, 1 px `#262626` border, radius 8, containing a `p-4` `#171717` card; placed 8 below the term (or above when it doesn't fit), 8 from the edges.
- [ ] Explanation card: term Geist 14/20 600 `#F5F5F5`, prose 14/22.75 `#D4D4D4`, timestamp 12/16 `#A3A3A3`, rating squares 24×24 with the selected one `#818CF8` + `#1E1B4B` digit.
- [ ] Term hover: the blue fill appears after about 40 ms with a 1.5 px `#2563EB` ring and slight scale; teal for "Figure N" links (`reader.mention-hover`).
- [ ] Panel hidden: a 36×36 bordered button (`#171717`, 1 px `#404040`, radius 6) at 12/12 from the pane's top-right; the pane takes the full width.
