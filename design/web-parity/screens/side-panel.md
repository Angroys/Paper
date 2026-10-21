# Reader side panel (S3): web-parity spec

- **App:** inside `/reader/:paperId`:
  - `features/panel/reader_side_panel.dart` (`ReaderSidePanel`, `PanelTabBar`)
  - `notes_tab.dart`, `highlights_tab.dart`, `glossary_tab.dart`, `explanation_tab.dart`, `ai_states.dart`
  - `split_view.dart`
- **Web:** `reader/PdfReaderLoader.tsx` `<aside aria-label="Explanations" class="w-96 … border-l … bg-gray-950">`, plus `reader/ExplanationSidebar.tsx` and `reader/FigureHighlightsPanel.tsx`.
- **Components:** [`../components.md`](../components.md).
- **Glossary tab body:** [`glossary.md`](glossary.md).

**References:**

| Shot | Use |
|---|---|
| [`reader.1280x800.png`](../reference/reader.1280x800.png), [`reader.800x1280.png`](../reference/reader.800x1280.png) | docked panel: header, card stack, explanation cards with tags, timestamp and rating |
| [`reader.selection-popover.1280x800.png`](../reference/reader.selection-popover.1280x800.png) | the same panel at the 1280 crop, with three cards visible |
| [`reader.panel-hidden.1280x800.png`](../reference/reader.panel-hidden.1280x800.png) | hidden state |
| [`reader-android.term-click-focus-lock.800x1280.png`](../reference/reader-android.term-click-focus-lock.800x1280.png) | the card as it appears in the floating popover |
| *(none)* | figure highlights section: build it from source (components §12.2) |

**Decision applied (CMO):** the web panel has **no tabs**. The app keeps its four tabs (Notes · Highlights · Glossary · Explanation), drawn in the web's ghost/active-nav language (components §8.2). Each tab body reuses a web component:

| Tab | Web component |
|---|---|
| Explanation | `ExplanationSidebar` |
| Highlights | `FigureHighlightsPanel` items |
| Glossary | `GlossarySearch` + `GlossaryEntryCard` |
| Notes | `.card` + `.field-input` |

---

## 1. Panel modes

The panel is always **384** wide except as a sheet.

### 1.1 Docked (window ≥ 1024)

- **Position:** right of the PDF pane, from below the reader strip (y 53 + `viewPadding.top`) to the window bottom.
- **Box:** fill `gray950`, left border 1 `gray800`. Background and border extend under the right and bottom cutout/bar areas; the content is inset (§5).
- **Default:** open. Hide sets the PDF pane to full width (instant on the web; see reader.md §1).
- **Split drag handle:** existing feature, reader.md §1.
- **Panel style setting:** when the existing Settings › Reader › "Panel style" preference is **Overlay**, the panel uses §1.2 at this width too. Split is the default and matches the web.

### 1.2 Overlay (640 ≤ window < 1024, e.g. 800×1280 portrait)

- **Position:** same box and position, floating over the PDF pane, right-anchored.
- **Box:** fill `gray950`, left border 1 `gray800`, `shadowXl`. **No scrim**: the PDF stays visible and interactive to the left.
- **Default:** closed. It opens from the show-panel button (reader.md §3.3), the shortcut, or a new explanation *if the user had it open before*. Otherwise new explanations use the floating popover (reader.md §6).
- **Close:** the hide button in the panel header. No edge swipe (README §4.5).
- **Layer:** `PaperLayer.sidePanelOverlay` (40).

### 1.3 Bottom sheet (window < 640)

- **Box:** full width, anchored to the bottom.
- **Height:** 70 % of the window by default (the existing snap points stay).
- **Fill and border:** `gray950`, top border 1 `gray800`, top corners radius 8 (`rounded-lg`), `shadowXl`.
- **Drag handle:** 32×4, radius full, `gray700`, centred 8 from the top (app affordance; the web has none).
- **Modal barrier:** `dialogBackdrop` @ .60.
- **Contents:** the same header (§2) and bodies, full width. Cards stretch to window − 32.

---

## 2. Panel header

| Part | Spec |
|---|---|
| Box | `px-3 py-2` (12 / 8). Bottom border 1 `gray800`. Fill `gray950`. **Sticky** at the top of the panel body scroll (z 10). Total **41** (40 + border), sampled 53→94 in `reader.*` at 1280. |
| Tabs | `PanelTabs` (components §8.2), left-aligned: Notes · Highlights · Glossary · Explanation (the order from `readerPanelTabsProvider`). Each is 24 tall, `px-2`, `xs` 500, radius 6, gap 4. Selected = `accentSoft` fill + `accentInk` label; rest `gray400`, hover `gray800` + `gray100`. New-result dot 6 `accent`. |
| Hide button | `PaperIconButton` 32 with `panel-hide.svg` 20 `gray400`, right-aligned, `-m-1` (layout 24), tooltip `panelClose`. Hover `gray800` + `gray100`. |
| Gap | 8 between the tab group and the hide button |

The old 48-tall Material tab bar, the 3 dp indicator and the close icon are removed.

---

## 3. Tab bodies

All bodies are a vertical scroll region under the header. The default body padding is **16** (`p-4`), and card stacks use gap **12** (`gap-3`) unless noted. At 384 wide, a card is **352** wide.

### 3.1 Notes (app-only data in web components)

| Element | Spec |
|---|---|
| Toolbar | `flex items-center justify-between`, `mb-3`. Left: `PaperSegmented.sm` "Page order" · "Recently edited" (`notesSortPageOrder` / `notesSortRecent`), which replaces the sort popup. Right: nothing. |
| Composer | `PaperCard p-4`. `PaperTextField` textarea (min 1 row, 38; grows to 6 rows), placeholder `notesComposerPlaceholder`. Below it, `mt-2 flex justify-end`: `PaperButton.primary xs` "Save" (`commonSave`), disabled @ .5 while empty. This replaces `IconButton.filled +`. |
| Note card | `PaperCard p-4`. Optional quoted highlight first: `xs leading-relaxed gray400`, max 2 lines, left 2 px `hue.ring` bar with 8 padding (app feature; uses the hue ring colour). Body `noteBody` (14/22.75 `gray300`), pre-wrap. Meta row `mt-3 flex items-center gap-2`: `xs gray400` "Edited 2 h ago", then status chips (`NeutralChip` "On this device only" / "Waiting to sync"; `StatusChip.error` "Couldn't sync"), then a spacer and `PaperButton.ghost xs` "···" opening `PaperMenu` (Jump to highlight · Delete in red). |
| Inline edit | Tapping the body turns it into `PaperTextField` textarea + `mt-2` Save/Cancel (`primary xs`, `secondary xs`), gap 8. |
| Delete | Immediate, then a `PaperToast` "Note deleted" with Undo. |
| Footer | `mt-3 xs gray400` local-only explainer (`syncLocalOnlyExplainer`), centred. |
| Empty | `EmptyStateText`: title `notesEmptyTitle`, body `notesEmptyBody` / `…Pen`. |
| Error | `ErrorBanner` + "Try again". |

### 3.2 Highlights

The structure is `FigureHighlightsPanel` (components §12.2). The section header is part of the body, not sticky.

| Element | Spec |
|---|---|
| Section | `px-4 pt-4 pb-4`. The web's bottom border is dropped, because nothing follows inside this tab. |
| Heading | eyebrow `HIGHLIGHTS` (`panelTabHighlights` upper-cased) `xs 600 +0.3 gray400` + `CountChip` (count), gap 8, `mb-3` |
| List | `flex-col gap-2` |
| Item | `PaperCard p-3`. A tappable row `flex items-start gap-3` jumps to the highlight. **Figure highlight:** 80×64 crop box (radius 4, border 1 `gray700`, white fill, `object-contain`). **Text highlight:** 12×12 disc (`hue.wash` fill, 1.5 `hue.ring`), `mt-1`. Text column: label `sm 600 gray100` "Page 3" (group-hover underline), then excerpt `mt-1 xs leading-relaxed gray300`, max 2 lines. |
| Item actions | `mt-2 flex justify-end gap-1`: `PaperButton.quiet` "Delete" (`highlightDelete`). First tap → confirm variant (red, `ring-1 red-300/30`, label "Confirm"); blur resets. This replaces the trailing `IconButton` delete. |
| Empty | `EmptyStateText` body `readerFirstHighlightHint` (no title). |

### 3.3 Glossary

See [`glossary.md`](glossary.md).

### 3.4 Explanation

This is `ExplanationSidebar` (components §12.3).

| Element | Spec |
|---|---|
| Stack | `flex-col gap-3 p-4`, **newest first**. New cards prepend with no animation (live-region announcement). |
| Card | `ExplanationCard` with every state: pending/progress, complete, error, offline queued. |
| Complete card anatomy (top to bottom) | term + `×` (mb 8) · tags (mb 8) · cached note (mb 8) · prose · re-explain error (mt 8) · visual aid (mt 12) · timestamp (mt 12) · rating (mt 12) · actions (mt 8, quiet buttons "Explain again", "Go to page N", "Show visual") |
| Card width | 352 docked or overlay; window − 32 in the sheet |
| Empty | `EmptyStateText`: `px-2 py-10 text-center`, title `explanationEmptyTitle` `sm 600 gray100`, body `mt-1 sm-relaxed gray400` (`explanationEmptyBody`) |

---

## 4. AI and account states (all AI tabs)

| State | Spec |
|---|---|
| **Offline** (`AiOfflineStrip`) | `NoticeStrip` (components §17) as the **first child of the body**, full width, no outer padding: `accentSoft` fill, `accentInk` `sm`, `info.svg` 16, `px-4 py-2.5`, bottom border 1 `gray800`. The card stack follows with its usual `p-4`. |
| **AI unavailable** (`AiUnavailableState`) | `EmptyStateCard` (`p-8`) inside `p-4`: title `aiUnavailableTitle`, body `aiUnavailableBody`, action `PaperButton.secondary md` "Try again". |
| **Guest** (`SignInPrompt` for Glossary/Explanation) | `EmptyStateCard` inside `p-4`: title and body from the existing prompt copy, action `PaperButton.primary md` "Sign in". |
| **Loading tab data** | Skeleton cards: `PaperCard p-4` with a 14×50 % bar, then two 12×90 % / 70 % bars, gap 8, pulse. Three of them, gap 12. |
| **Load error** | `ErrorBanner` (`p-4`) inside `p-4` + `mt-3 PaperButton.secondary xs` "Try again". |

---

## 5. Insets and IME

- **Docked and overlay:** the fill and `border-l` extend to the top/right/bottom window edges (under cutouts and bars).
  - Header content: + `viewPadding.right`.
  - Body content: + `viewPadding.right` and the last item + `viewPadding.bottom`.
  - The header sits under the reader strip, so it has no top inset.
- **Sheet:** the fill extends to the bottom/left/right edges. The content is inset left/right/bottom.
- **IME:** only the panel body lifts, with `Padding(bottom: viewInsets.bottom)` around the scroll view. The PDF and the reader strip never move. The composer, inline note edit and glossary search scroll into view.

---

## 6. Parity checklist

Compare with `reader.1280x800.png` and `reader.800x1280.png` (right column).

- [ ] Docked panel 384 wide at ≥ 1024 with a 1 px `#262626` left border and `#0A0A0A` fill; at 800 wide it floats as an overlay with `shadow-xl` and no scrim.
- [ ] Panel header 41 tall (40 + 1 px `#262626` bottom border), padding 12 horizontal / 8 vertical, sticky.
- [ ] Hide button: visual box 32×32, radius 6, 20 px glyph `#A3A3A3`, right-aligned at x = panel right − 12; hover fill `#262626`.
- [ ] Tabs 24 tall, Geist 12/16 500, padding 8×4, radius 6, gap 4; selected `#C7D2FE` on `#1E1B4B`; rest `#A3A3A3`; all four fit without scrolling.
- [ ] Card stack: 16 inset from the panel edges, 12 between cards, cards 352 wide.
- [ ] Explanation card: `#171717` fill, 1 px `#262626` border, radius 8, padding 16, no shadow.
- [ ] Card title Geist 14/20 600 `#F5F5F5`; `×` dismiss 24×24 at the top-right, overhanging the padding by 4, glyph `#A3A3A3`.
- [ ] Tag chips 20 tall: type tags `#C7D2FE` on `#1E1B4B`, topic tags `#D4D4D4` on `#262626`; Geist 11 500; gap 4.
- [ ] Prose Geist 14/22.75 `#D4D4D4`; timestamp 12/16 `#A3A3A3`, 12 below the prose.
- [ ] Rating row: label 12/16 `#A3A3A3`; squares 24×24 radius 6, rest `#262626` / `#A3A3A3`, selected `#818CF8` / `#1E1B4B`; value text "4/5" 12/16 `#A3A3A3`.
- [ ] Progress card: 6 px track `#404040`, 1/3-width `#818CF8` bar sweeping every 1.2 s.
- [ ] Highlights tab: eyebrow "HIGHLIGHTS" 12/16 600 uppercase `#A3A3A3` + count chip `#262626` / `#D4D4D4`; items `p-3` cards with a gap of 8.
- [ ] Offline strip: `#1E1B4B` fill, `#C7D2FE` 14/20 text, 16 px info glyph, padding 16×10, 1 px `#262626` bottom border.
