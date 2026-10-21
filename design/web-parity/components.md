# Web-parity components (M3)

Each component that the in-scope paper.college screens paint is mapped here to a Flutter widget spec: exact box, type, colour and every interaction state. The screen files in [`screens/`](screens/) place these components; this file defines them.

- **Source of truth (read-only):** RPR `/home/minimax/research-paper-helper/src`. Paths below are relative to `src/`. Classes are quoted verbatim; only the `dark:` side paints (see [`tokens.md`](tokens.md) §1, §3).
- **Token names** are from `design/tokens/paper_tokens.dart`:
  - `PaperWeb.*`: exact Tailwind colours.
  - `PaperColors` roles (`c.*`).
  - `PaperSpacing.tw*`
  - `PaperRadii.*`
  - `PaperElevation.shadow*`
  - `PaperTypography.*`
  - `PaperHitTarget.*`
  - `PaperMotion.*`
  - `PaperLayer.*`
- **Widget names** (`PaperButton`, `PaperCard`, …) are the proposed Flutter API. Engineers may rename them, but the box and states must not change.
- **Units:** 1 CSS px = 1 logical px. Heights include borders.
- **Colour transitions:** every state change below is a colour-only transition of `PaperMotion.colors` (150 ms, `PaperMotion.standard`). It is 0 ms under reduced motion (`PaperMotion.of`). Nothing scales or moves unless stated.
- **Interaction rules:**
  - No ripples: the theme already sets `NoSplash`.
  - **Hover** applies to mouse, trackpad and stylus hover only.
  - **Pressed** is the web `active:` colour. When the web has no `active:` class, the pressed colour is the hover colour.
  - **Focus** means keyboard focus only (`FocusHighlightMode.traditional`), drawn with [`PaperFocusRing`](#20-paperfocusring).
- **Text style shorthand:** `14/20 500` = size 14, line height 20, weight 500. Geist unless noted.

Contents:

1. [Type and colour shorthands](#1-type-and-colour-shorthands)
2. [Buttons](#2-buttons)
3. [Icon buttons](#3-icon-buttons)
4. [Text inputs](#4-text-inputs)
5. [Checkbox](#5-checkbox)
6. [Cards](#6-cards)
7. [Table and list rows](#7-table-and-list-rows)
8. [Segmented control and panel tabs](#8-segmented-control-and-panel-tabs)
9. [Chips and badges](#9-chips-and-badges)
10. [Popover surfaces](#10-popover-surfaces)
11. [Reader chrome](#11-reader-chrome)
12. [Side panel container](#12-side-panel-container)
13. [Menus](#13-menus)
14. [Dialogs](#14-dialogs)
15. [Toasts](#15-toasts)
16. [Spinner, progress, skeleton](#16-spinner-progress-skeleton)
17. [Empty, error and notice blocks](#17-empty-error-and-notice-blocks)
18. [Links, rating, tooltip, disclosure](#18-links-rating-tooltip-disclosure)
19. [Icons](#19-icons)
20. [PaperFocusRing](#20-paperfocusring)

---

## 1. Type and colour shorthands

| Shorthand | Tailwind | Dart |
|---|---|---|
| `xs` | `text-xs` 12/16 | `PaperTypography.textXs/leadingXs` (`caption` for 400 gray-400) |
| `sm` | `text-sm` 14/20 | `bodyMedium` (400), `labelLarge` (500), `cardTitle` (600) |
| `sm-relaxed` | `text-sm leading-relaxed` 14/22.75 | `explanationBody` (gray-300), `explanationBodyCompact` (gray-200) |
| `11` | `text-[11px]` 11/16 | `labelSmall` (500) |
| `0.65` | `text-[0.65rem]` 10.4/inherit (use 16) | `text0_65rem` |
| `lg` | `text-lg` 18/28 600, −0.45 | `sectionTitle` |
| `2xl` | `text-2xl` 24/32 600, −0.6 | `pageTitle` |
| eyebrow | `text-xs font-semibold uppercase tracking-wide` 12/16 600 +0.3 | `eyebrow` (upper-case the string) |

| Role | Hex | Dart |
|---|---|---|
| page `bg` | `#0A0A0A` | `PaperWeb.gray950` / `c.background` |
| surface | `#171717` | `PaperWeb.gray900` / `c.surface` |
| hover fill | `#262626` | `PaperWeb.gray800` |
| pressed fill (ghost) | `#404040` | `PaperWeb.gray700` |
| structure border | `#262626` | `PaperWeb.gray800` / `c.border` |
| control border | `#404040` | `PaperWeb.gray700` / `c.outline` |
| ink | `#F5F5F5` | `PaperWeb.gray100` / `c.textPrimary` |
| body ink | `#D4D4D4` | `PaperWeb.gray300` / `c.textSecondary` |
| control label | `#E5E5E5` | `PaperWeb.gray200` / `c.secondary` |
| muted | `#A3A3A3` | `PaperWeb.gray400` / `c.textMuted` |
| subtle | `#737373` | `PaperWeb.gray500` |
| accent | `#818CF8` | `PaperWeb.accent` |
| accent hover | `#A5B4FC` | `PaperWeb.accentHover` |
| accent soft / ink | `#1E1B4B` / `#C7D2FE` | `PaperWeb.accentSoft` / `accentInk` |
| on-accent | `#1E1B4B` | `PaperWeb.indigo950` |
| row hover (gray-800/50 on gray-900) | `#1F1F1F` | `PaperWeb.gray800Half` |

---

## 2. Buttons

All buttons share these properties:

- `inline-flex items-center justify-center`, and `rounded-md` 6 unless noted.
- Font 500. Label and icon gap 8 (`gap-2`) when there is an icon.
- **Disabled:** whole-widget opacity 0.5 (`PaperTheme`), no pointer or hover, and focus is skipped.
- **Loading:** the web never shows a spinner in a button. It swaps the label ("Signing in…", "Saving…", "Removing…", "Importing…") and disables the button. Copy this: label swap + disabled, with the width free to change.

**Sizes**, verified against `library.*`, `sign-in.*` and `reader.*` pixels:

| Size | Padding | Text | Height, no border | Height, bordered | Web uses |
|---|---|---|---|---|---|
| `md` | `px-4 py-2` 16×8 | `sm` 14/20 | **36** | **38** | default `.btn-*` |
| `sm` | `px-3 py-1.5` 12×6 | `sm` 14/20 | **32** | 34 | toast CTA (`btn-primary px-3 py-1.5 text-sm`), selection popover buttons, file chooser |
| `xs` | `px-2.5 py-1` 10×4 | `xs` 12/16 | **24** | **26** | row actions (`btn-ghost px-2.5 py-1 text-xs`), Remove/Delete outline, inline Save/Cancel |
| `xxs` | `px-2 py-1` 8×4 | `xs` 12/16 | **24** | — | "Mark read" (`btn-ghost px-2 py-1 text-xs`), panel tabs (§8.2) |

### 2.1 `PaperButton.primary`

**Source:** `app/globals.css` `.btn-primary`. It is used by `library/AddPaperDisclosure.tsx`, `auth/SignInForm.tsx` and `settings/ProfileSettingsForm.tsx`.

| State | Fill | Label | Other |
|---|---|---|---|
| Rest | `PaperWeb.accent` #818CF8 | `PaperWeb.indigo950` #1E1B4B | no border, no shadow |
| Hover | `accentHover` #A5B4FC | same | |
| Pressed | `accentHover` #A5B4FC | same | `active:bg-accent-hover` |
| Focus | rest | rest | `PaperFocusRing(gap: surface under it)` |
| Disabled | rest @ 0.5 | | |
| Loading | rest @ 0.5 | swapped label | |

- **Full width:** `w-full` on sign-in.
- **Trailing chevron:** the "Add a paper" button uses the trailing chevron `chevron-down.svg` 16 in the label colour, rotated 180° when open (`PaperMotion.fast`).

### 2.2 `PaperButton.secondary`

**Source:** `.btn-secondary`, plus `SignInForm.tsx` "Continue with Google" and `ObsidianDisconnectDialog.tsx` "Cancel".

| State | Fill | Border | Label |
|---|---|---|---|
| Rest | `gray900` #171717 | 1 `gray700` #404040 | `gray200` #E5E5E5 |
| Hover | `gray800` #262626 | same | same |
| Pressed | `gray800` | same | same |
| Focus | rest + ring | | |
| Disabled | @ 0.5 | | |

- **`border-transparent` has no effect.** The `.btn-secondary dark:border-gray-700` rule wins over `border-transparent`, so a bordered secondary always shows a #404040 hairline. The zoom ± buttons prove it (pixel-sampled in `reader*.png`).
- **No icon:** the Google button has no "G" glyph on the web. The app's `google_g.svg` is dropped for parity.

### 2.3 `PaperButton.ghost`

**Source:** `.btn-ghost`, `library/PaperTableRow.tsx` and `library/ReadPapersDisclosure.tsx`.

| State | Fill | Label |
|---|---|---|
| Rest | transparent | `gray400` #A3A3A3 |
| Hover | `gray800` #262626 | `gray100` #F5F5F5 |
| Pressed | `gray700` #404040 | `gray100` |
| Focus | rest + ring | |
| Disabled | @ 0.5 | |
| **Active/pressed-toggle** (`aria-pressed`, e.g. "Mark read" when read) | transparent | `accent` #818CF8 (`dark:text-accent`) |
| **Open disclosure** | transparent | `gray100` (`text-gray-900 dark:text-gray-100`) |

### 2.4 `PaperButton.destructive` (outline)

**Source:** `library/DeletePaperButton.tsx` and `settings/ObsidianDisconnectDialog.tsx` `DISCONNECT_ROW_OUTLINE`. Classes:

```
rounded-md border font-medium dark:border-red-900 dark:bg-gray-900 dark:text-red-400 dark:hover:bg-red-950 dark:active:bg-red-950 focus-visible:ring-red-500
```

| State | Fill | Border | Label |
|---|---|---|---|
| Rest | `gray900` #171717 | 1 `red900` #7F1D1D | `red400` #F87171 |
| Hover | `red950` #450A0A | same | same |
| Pressed | `red950` | same | same |
| Focus | rest | | `PaperFocusRing(color: PaperWeb.red500)`, offset 2 |
| Disabled / loading | @ 0.5, label "Removing…" | | |

- **Sizes:**
  - `xs` (26 tall) in rows and the reader header ("Remove").
  - `md` (`px-4 py-2 text-sm`, 38) in dialogs.
- **Inline error:** to the left, `text-xs red400`, gap 8 (`DeletePaperButton` `flex items-center gap-2`).

### 2.5 `PaperButton.quiet` (popover/card action, not `.btn-*`)

**Source:** `reader/FigureHighlightsPanel.tsx` `SECONDARY_BUTTON` and `ExplanationSidebar.tsx` visual Play button:

```
rounded px-2 py-1 text-xs font-medium dark:text-gray-300 dark:hover:bg-gray-800
```

| State | Fill | Label |
|---|---|---|
| Rest | transparent | `gray300` #D4D4D4 |
| Hover / pressed | `gray800` | `gray300` |
| Focus | | `outline-2 outline-accent`, offset 0 → `PaperFocusRing(offset: 0)` |
| Disabled | @ 0.6 | |
| **Confirm** (second tap of Remove) | transparent, `ring-1` `red-300/30` (`#5C4242` over gray-900) | `red300` #FCA5A5; hover fill `red950` |

- **Box:** radius 4 (`rounded`), 24 tall.
- **Use:** card-footer actions in the side panel (Add note, Remove, Jump to page, Re-explain).

### 2.6 `PaperButton.popover` (selection popover items)

**Source:** `reader/PdfReader.tsx` L4451–4485.

| Variant | Rest | Hover / pressed | Label |
|---|---|---|---|
| primary ("Explain & save") | `accent` | `accentHover` | `indigo950` 14/20 500 |
| highlight ("🖍 Highlight") | transparent | `PaperWeb.yellow900Hover` #3B2715 | `gray200` |
| neutral ("Copy") | transparent | `gray800` | `gray200` |
| destructive (app-only "Delete" in the highlight picker) | transparent | `red950` | `red400` |

- **Box:** radius 4, `px-3 py-1.5`, **32 tall**, `whitespace-nowrap`.
- **Focus:** `ring-2 ring-accent ring-offset-1` with an offset gap of `gray900` → `PaperFocusRing(offset: 1, gap: #171717)`. This is `focus:`, not `focus-visible:`; the app still shows it for keyboard only.
- **Copy feedback:** the label becomes "Copied!" or "Copy failed" in place. There is no toast.

---

## 3. Icon buttons

**`PaperIconButton`:** a square box, centred glyph, radius 6, no border unless `bordered`.

| Size | Glyph | Web source | States |
|---|---|---|---|
| **24** (`h-6 w-6`) | text `×` 16/16 (`text-base leading-none`) | `ExplanationSidebar` `DismissButton`, `CitationPopover` close | Rest: transparent, glyph `gray400`. Hover/pressed: fill `gray800`, glyph `gray100`. **Error tone** (inside red cards): glyph `red300`, hover fill `red900` #7F1D1D + glyph `red100` #FEE2E2, ring `red500`. Placed with `-mr-1 -mt-1` (visual box overhangs the card padding by 4). |
| **28** (`p-1` around a 20 glyph, `-m-1`) | `reader-back.svg` 20 | `library/[paperId]/page.tsx` back | Rest glyph `gray400`; hover/pressed fill `gray800`, glyph `gray100`. Layout box 20 (the −4 margins), visual 28. |
| **32** (`h-8 w-8`, `-m-1`) | `panel-hide.svg` 20 | `PdfReaderLoader.tsx` "Hide explanations" | Same as 28. Layout box 24, visual 32. Also the toast dismiss (`btn-ghost h-8 w-8 p-0`, glyph `×` 16 gray-400). |
| **36 bordered** (`h-9 w-9`) | `panel-show.svg` 20 | `PdfReaderLoader.tsx` "Show explanations" | Rest: fill `gray900`, border 1 `gray700`, glyph `gray300`, `shadowSm`. Hover/pressed: fill `gray800`, glyph `gray100`. |
| **26 bordered** (zoom ±) | text `−` / `+` 16/16 | `PdfReader.tsx` L3762–3787 (`btn-secondary border-transparent px-2 py-1 text-base leading-none`) | Rest: fill `gray900`, border 1 `gray700` (shown, see §2.2), glyph `gray200`. Hover/pressed: fill `gray800`. Disabled at min/max zoom: @ 0.5. Width 26 (8+~8+8+2). |

- **Focus (all sizes):** `ring-2 ring-accent`. There is no offset on the 24/28/32 sizes and offset 2 elsewhere.
- **Tooltip:** every icon-only button gets a `PaperTooltip` with the same text as its semantics label. The web uses the native `title`.
- **Hit area:** the hit area is the box. There is no 48 dp padding (brief).

---

## 4. Text inputs

### 4.1 `PaperTextField` (`.field-input`)

**Source:** `globals.css` `.field-input`. It is used by `SignInForm.tsx`, `ProfileSettingsForm.tsx`, `ImportPaperForm.tsx`, `GlossarySearch.tsx` and `PaperTableRow.tsx` (rename).

| Size | Padding | Text | Height | Use |
|---|---|---|---|---|
| `md` | `px-3 py-2` | `sm` 14/20 400 | **38** | forms, search |
| `md-base` (< 640 wide, sign-in only) | `px-3 py-2` | `text-base` 16/24 | **42** | `text-base sm:text-sm` on sign-in |
| `sm` | `px-2.5 py-1` | `sm` 14/20 | **30** | inline rename in a table row |
| `xs` | `px-2.5 py-1` | `xs` 12/16 | **26** | reader find bar (`PaperSelectionList` project field pattern) |
| textarea | `px-3 py-2`, `resize-y` | `sm` | 38 at one row, +20 per extra row | "Import from a link", note composer |

| State | Fill | Border | Text |
|---|---|---|---|
| Rest | `gray900` #171717 | 1 `gray700` #404040 | `gray100`; placeholder `gray400` #A3A3A3 |
| Hover | no change (the web has none) | | |
| Focus | same | **2 px accent edge**: border `accent` + `ring-1 accent` outside. In Flutter: `focusedBorder` width 2 `#818CF8`, with content padding reduced by 1 so the height stays 38. | caret `accent` |
| Disabled | @ 0.5 | | |
| Error | same | 1 `red500` #EF4444; focused: 2 `red500` | message below: `text-sm red400`, mt 6 (forms) or `text-xs red400`, mt 4 (inline) |

- **Field labels:** the label sits above the field, `flex flex-col gap-1.5`. Label text is `sm` 14/20 500 `gray300`, with a gap of 6 to the field (`SignInForm.tsx` L177).
- **Every `TextField`** passes `style: PaperTypography.input(c)` and `isDense: true` (tokens.md §15).
- **Selection colour** is `c.selection`.

### 4.2 `PaperSearchField`

**Source:** `glossary/GlossarySearch.tsx` (`field-input w-full`).

- The box is `PaperTextField.md`.
- **No leading search icon:** the web has none, so the app's `Symbols.search` prefix is dropped.
- **Clear:** when text is present, a `PaperIconButton` 24 with `×` sits inside the right edge (8 from the border). This is app-only (it is the existing clear action), with the glyph in `gray400`.
- **Placeholder:** `gray400`.
- **Width:** `w-full` in the panel and 320 (`max-w-xs`) in the library toolbar.

### 4.3 File chooser (`PaperFilePickerButton`)

**Source:** `UploadPaperForm.tsx` / `ProfileSettingsForm.tsx`. The native `<input type=file>` is styled with:

```
file:rounded-md file:px-3 file:py-1.5 file:text-sm file:font-medium dark:file:bg-gray-800 dark:file:text-gray-200 dark:hover:file:bg-gray-700
```

- **Button:** fill `gray800`, label `gray200` 14/20 500, radius 6, 32 tall, no border.
- **Hover/pressed:** `gray700`.
- **Status text:** 12 to the right (`file:mr-3`), `sm` 400 `gray400`, e.g. "No file chosen" or the picked file name.
- **Disabled:** @ 0.5.
- **Focus:** ring 2 accent, no offset.

---

## 5. Checkbox

### 5.1 `PaperCheckbox` (native dark checkbox)

**Source:** `library/PapersTable.tsx` and `PaperTableRow.tsx`:

```
h-4 w-4 rounded dark:border-gray-700 accent-accent focus-visible:ring-2 ring-accent ring-offset-2 dark:ring-offset-gray-950
```

The colours are pixel-sampled from `library.full.800x1280.png`: Chromium's dark native checkbox paints, and the Tailwind border classes do not.

| State | Box | Mark |
|---|---|---|
| Unchecked | 16×16, radius 2, fill `#3B3B3B`, border 1 `#858585` | — |
| Hover | border `#A3A3A3` (Chromium dark hover, approximate) | — |
| Checked | fill `accent` #818CF8, no visible border | check glyph `#0A0A0A`, 2 stroke, round. Chromium picks a dark check on a light accent; **verify against a live checked capture** (none was captured). |
| Indeterminate | fill `accent` | 8×2 bar `#0A0A0A` |
| Focus | `PaperFocusRing(offset 2, gap #0A0A0A)`. The web uses gray-950 even inside the table card. | |
| Disabled | @ 0.5 | |

- **Size `lg`, 20×20:** `settings/BetaFeaturesToggle.tsx` `h-5 w-5`. It is the web "switch". Every app `Switch`/`SwitchListTile` on restyled screens becomes this checkbox, right-aligned in its row and `mt-0.5` (2) from the row top (tokens.md §14).
- **Hit box:** the 16/20 box plus its label when there is one (`<label>`). Wrap the row in `MergeSemantics` + `InkWell`-free `GestureDetector`.

---

## 6. Cards

### 6.1 `PaperCard` (`.card`)

**Source:** `globals.css` `.card`.

- **Box:** fill `gray900` #171717, border 1 `gray800` #262626, radius 8, **no shadow**.
- **Padding variants** (web usage):

| Padding | px | Used by |
|---|---|---|
| `p-3` | 12 | figure / highlight item (`FigureHighlightsPanel` FigureCard) |
| `p-4` | 16 | explanation card, progress card, cards in the panel |
| `p-5` | 20 | settings sections, upload/import cards, glossary entry |
| `p-6` | 24 | no-PDF placeholder, reader error |
| `p-8` | 32 | empty states (centred) |

- **States:** cards are not interactive. Where the whole card is tappable (glossary entry header, figure item), only the inner button gets hover (text `accent` for the term button, `group-hover:underline` for the figure label) and focus (ring 2 accent).
- **Card heading:** `cardTitle` (14/20 600 `gray100`). The first row after the heading is at `mt-4` (16).

### 6.2 Surfaces that look like cards but are not `.card`

| Surface | Box | Source |
|---|---|---|
| Popover card | `gray900`, border 1 **`gray700`** #404040, radius 8, `shadowXl` | `CitationPopover.tsx` |
| Floating shell | `gray950`, border 1 `gray800`, radius 8, `shadowXl` | `FloatingExplanationPopover.tsx` |
| Toast | `#161616` (`gray900/90` over the page), border 1 `gray800`, radius 8, `shadowMd`, backdrop blur 12 | `CiteAddToast.tsx` |
| Dialog | `.card` + `shadowXl`, `max-w-md` 448, `p-5` | `ObsidianDisconnectDialog.tsx` |

---

## 7. Table and list rows

### 7.1 `PaperTable` (papers table)

**Source:** `library/PapersTable.tsx` and `PaperTableRow.tsx`. The geometry is pixel-checked on `library.full.800x1280.png`.

| Part | Spec |
|---|---|
| Container | `PaperCard` (no padding), `overflow-hidden`, so rows clip to radius 8. Table `min-w-[44rem]` = **704**; below that it scrolls horizontally inside the card. |
| Header row | **48** tall (web: 12 + a 24 line box from the select-all cell + 12). Cells `px-4 py-3`. Label = eyebrow 12/16 600 uppercase +0.3 **`gray400`**, left-aligned; "Action" right-aligned. Bottom border 1 `gray800`. Fill = card `gray900`. |
| Body row | `px-4 py-3`, `align-middle`. Height = content + 24. With the 64-tall thumbnail it is **88** + 1 divider (`divide-y gray800`). |
| Row hover | fill `#1F1F1F` (`dark:hover:bg-gray-800/50`, `PaperWeb.gray800Half`), 150 ms. Touch press: same colour while pressed. |
| Row selected | **no tint.** The web's `bg-accent-soft/40` generates nothing (tokens.md §3); the checkbox carries selection. The app has no row selection. |
| Row focus | the row is not a focus stop. Its title link and buttons are. |
| Expanded detail row | under the row, fill `#1F1F1F`, `px-4 pb-3` (no top padding). Content: a `flex-wrap gap-1` row of `PaperButton.ghost xs`. Error/notice lines `mt-1.5 text-xs` `red400` / `gray400`. |
| Name cell | `max-w-[18rem]` (288) content width. Title is a link: `sm` 14/20 500 `gray100`, single-line ellipsis. Hover: text `accent` + underline (offset 2). Focus: ring 2 accent, no offset, radius 6. An optional **Read** badge (§9.1) sits 8 to the right. Meta below `mt-0.5` (2): `xs` 12/16 `gray400` ellipsis ("uploaded 11 Oct 2026"). |
| Thumbnail cell | `PaperThumbnail.row` (§7.2). |
| Text cell | `xs` 12/16 `gray400`, wraps (as in the web "Size" column). Empty value: `—` `xs` **`gray500`** with a semantics label. |
| Action cell | `flex items-center justify-end gap-1`: `PaperButton.ghost xs` "Open", `PaperButton.ghost xs` "···" (`aria-expanded`), then `PaperButton.destructive xs`. |

### 7.2 `PaperThumbnail.row`

**Source:** `library/PaperThumbnail.tsx` `row`.

- **Box:** 48×64 (`h-16 w-12`), radius 6, border 1 `gray700`, fill `gray800`, `overflow-hidden`.
- **Image:** the first page, `object-cover object-top`.
- **Placeholder:** `file.svg` 20 in `gray600` #525252, centred.
- **Offline-dimmed** (app state): image opacity 0.5.

### 7.3 `ReadMeter`

**Source:** `library/ReadMeter.tsx`.

- **Size:** 40×16 sparkline.
- **Read:** stroke 2 `accent`.
- **Unread:** stroke 1.5 `gray500`, dashed 3/3.
- **Points:** see tokens.md §13. Draw with a `CustomPainter`.

### 7.4 `PaperListRow` (settings / Obsidian vault rows)

**Source:** `ObsidianSettingsSection.tsx` L430:

```
flex flex-col gap-3 border-b border-gray-800 py-3 last:border-0 dark:hover:bg-gray-800/50 focus-within:ring-2 ring-inset ring-accent sm:flex-row sm:items-center sm:justify-between
```

- **Layout:** `py-3` with no horizontal padding (it inherits the card's `p-5`). Rows sit `mt-3` under their intro text.
- **Bottom border:** 1 `gray800`, except on the last row.
- **Hover:** `#1F1F1F`.
- **Focus within:** inset ring 2 accent.
- **Left:** title `sm` 500 `gray100` and sub `xs` `gray400`.
- **Right:** controls (buttons, checkbox, segmented), gap 12.

---

## 8. Segmented control and panel tabs

The web has **no** segmented control and **no** tabs. Both app components are built only from web parts:

- the toolbar-pill container (`PdfReader.tsx` L3756);
- the active-nav colours (`DashboardSidebar` `bg-accent-soft text-accent-ink`);
- `.btn-ghost` metrics.

### 8.1 `PaperSegmented`

**Use:** the app's `SegmentedButton`s:

- reader `ToolModeSegmented`;
- notes sort;
- settings "Reduce motion" and "Panel style";
- library filter (All / Downloaded / Unread).

**Container:**

- `rounded-md` 6, fill `gray900`, border 1 `gray800`.
- Padding: `p-px` (1) in size `sm`, `p-0.5` (2) in size `md`.
- Gap between segments 1 (`sm`) / 2 (`md`).

| Size | Segment box | Text / icon | Total height |
|---|---|---|---|
| `sm` | radius 4, `px-2 py-1` (icon-only: 24×24) | `xs` 12/16 500, or a 16 icon | **28** (fits the 52-tall reader header) |
| `md` | radius 4, `px-3 py-1.5` | `sm` 14/20 500 | **38** (same as inputs and `.btn-secondary`) |

| Segment state | Fill | Label / icon |
|---|---|---|
| Rest | transparent | `gray400` |
| Hover | `gray800` | `gray100` |
| Pressed | `gray700` | `gray100` |
| **Selected** | `accentSoft` #1E1B4B | `accentInk` #C7D2FE; hover/pressed keep these colours |
| Focus | ring 2 accent, offset 1, gap `gray900` | |
| Disabled | @ 0.5 | |

- **No check icon:** use `showSelectedIcon: false`.
- **Width:** each segment sizes to its content; do not use equal widths.
- **Semantics:** `selected: true` on the selected segment.

### 8.2 `PanelTabs` (side panel: Notes · Highlights · Glossary · Explanation)

Each tab is a `PaperButton.ghost xxs`: `px-2 py-1 text-xs font-medium`, radius 6, **24 tall**, gap 4 (`gap-1`). It sits in the panel header (side-panel.md §2), left-aligned, with the hide button on the right.

| State | Fill | Label |
|---|---|---|
| Rest | transparent | `gray400` |
| Hover | `gray800` | `gray100` |
| Pressed | `gray700` | `gray100` |
| **Selected** | `accentSoft` | `accentInk`; weight stays 500 (the web never changes weight on selection) |
| Focus | ring 2 accent, offset 2, gap `gray950` | |
| **New result** (dot) | — | 6×6 dot `accent` (`h-1.5 w-1.5 rounded-full bg-accent`), 6 after the label. Semantics label `panelTabNewResult`. |

- **No underline indicator:** the old 3 dp indicator is removed.
- **Width check:** label widths at 12 px Geist 500 are about 33 + 65 + 52 + 72. That gives 222 + 4×16 padding + 3×4 gaps = **298** px. This fits the 320 available (384 − 24 header padding − 32 hide button − 8 gap). Keep the row non-scrolling, with `SingleChildScrollView` only as a safety net.

---

## 9. Chips and badges

All chips are `rounded-full` with no border unless noted. Text uses `11` (11/16 500) unless noted. Chips are **20 tall** (`py-0.5` + 16 line).

| Widget | Box | Fill | Text | Source |
|---|---|---|---|---|
| 9.1 `ReadBadge` | `px-2 py-0.5` | `accentSoft` | `accentInk` | `PaperTableRow.tsx` L414 |
| 9.2 `TagChip.type` (closed vocabulary: method, concept, dataset …) | `px-2 py-0.5 leading-4` | `accentSoft` | `accentInk` | `glossary/TagChip.tsx` |
| 9.3 `TagChip.topic` (open vocabulary) | same | `gray800` | `gray300` | same |
| 9.4 `NeutralChip` (project names, app status chips "From account", "On this device only") | `px-2 py-0.5` | `gray800` | `gray300`; the "+N more" variant uses `gray400` | `PaperTableRow.tsx` L481/491 |
| 9.5 `CountChip` (panel section count) | `px-1.5 py-0.5`, `0.65` 10.4/16 500 tabular | `gray800` | `gray300` | `FigureHighlightsPanel.tsx` L270 |
| 9.6 `FilterPill` (glossary tag filter, a toggle button) | `px-2.5 py-1`, `xs` 12/16 500, **24 tall** | rest `gray800`, hover `gray700`; **active** `accent` + `ring-1 accent` | rest `gray400`; active `indigo950` | `GlossarySearch.tsx` L149 |
| 9.7 `StatusChip.error` (app sync error) | as 9.4 | `red950` | `red300` | app-only; uses the error-banner pair |
| 9.8 Figure-label pill on the PDF | `px-2 py-0.5 text-xs 500`, `shadowSm`, `ring-1` `#0A0A0A` @ .10 | `white` | `gray900` | `FigureOverlay.tsx` L92 |

- **`FilterPill` focus:** ring 2 accent, offset 2, gap `gray950`. It is a toggle: semantics `toggled`.
- **Other chips** are not interactive and have no states.

---

## 10. Popover surfaces

Placement and anchoring are per popover in `screens/reader.md`. These are the boxes.

### 10.1 `SelectionPopover` / `HighlightPicker`

**Source:** `PdfReader.tsx` L4433–4500, `[data-selection-popover] role=dialog aria-label="Highlight actions"`.

- **Box:** fill `gray900`, **no border**, radius 6, `p-1` (4), `gap-1` (4), `shadowLg`.
- **Height:** **40** (4 + 32 + 4).
- **Layer:** `PaperLayer.selectionPopover` (10).

**Children, left to right:**

1. `PaperButton.popover.primary`: "Explain" (app `selectionExplain`). App-only offline hint: a trailing `cloud-off` 14 glyph in `indigo950`, plus a tooltip.
2. **Highlight swatches (app feature):** one `PaperButton.popover.highlight` box per hue, **32×32**, radius 4.
   - Each holds a 14×14 disc filled with `hue.wash` and a 1.5 `hue.ring` border.
   - The current hue shows a 10 px check `#171717` in the disc.
   - Hover fill `#3B2715`.
   - This replaces the web's single "🖍 Highlight" button.
3. A 1×20 divider `gray700`, centred vertically (the zoom-pill divider, sampled #404040).
4. `PaperButton.popover.neutral`: "Note" and "Copy". Copy swaps its label to "Copied!", which replaces the app's snackbar.
5. **`HighlightPicker` only:** `PaperButton.popover.destructive` "Delete".

**States:**

- **Disabled** (no text layer): the affected buttons are @ 0.5.
- **Opening:** the web has no animation, so the popover appears and disappears instantly.
- **Overflow:** wider than the clamp rect means the row scrolls horizontally. It is never taller than 40.

### 10.2 `CitationPopover`

**Source:** `reader/CitationPopover.tsx` L1046–1090.

**Box:**

- `w-80` **320**, `max-h-80` **320** (scrolls inside), `p-4`.
- Fill `gray900`, border 1 `gray700`, radius 8, `shadowXl`.
- Layer `PaperLayer.citationPopover` (30).

**Header:** `mb-2 flex items-start justify-between gap-2`.

- Title `cardTitle` (14/20 600 `gray100`), e.g. "Reference 12" or "Rombach et al., 2022".
- Close `PaperIconButton` 24 `×`, `-mr-1 -mt-1`.

**Body:** `flex-col gap-3`. Each entry:

- `border-t gray800 pt-3`; the first entry has none.
- Label "Reference N": `xs` 600 `gray400`.
- Text `mt-1`, `sm-relaxed` `gray200`, `break-words`.
- Missing text: `mt-1 sm italic gray400` ("Looking up reference…" / "… not found in the bibliography.").

**In your library block:**

- Box: `mt-2`, radius 6, fill `accentSoft`, `px-2.5 py-2`.
- "In your library": `xs` 600 `accentInk`.
- Link `mt-0.5`: `xs` 500 `accentInk`, underline offset 2; hover removes the underline.

**Link-out** ("View at doi.org ↗", app "Open source"):

- `xs` 500 `accent`, `gap-1`, hover underline.
- `↗` is a text glyph.
- Focus ring 2 accent, offset 2, gap `gray900`.

**Add-to-library button** (`CITE_ADD_BUTTON_CLASS`):

- Fill `accent`, hover `accentHover`, `px-2.5 py-1`, `xs` 500, label **`indigo950`** (`dark:text-indigo-950`). The class has the dark override, so it is not white.
- Radius 6, `shadowSm`, **24 tall**.
- Disabled @ 0.6.
- Its status lines are `xs`: success `green400` 500, error `red400`, offline/neutral `gray400`.

**Preview thumbnail** (when present):

- `h-32` 128, radius 4, border 1 `gray700`, fill white, `object-contain`.
- Loading: `h-32 w-24`, radius 4, border `gray700`, fill `gray800`, pulse.
- Missing: the same box with a dashed border and `xs gray400` centred text.

### 10.3 `FloatingExplanationPopover`

**Source:** `reader/FloatingExplanationPopover.tsx` L248–262.

**Shell:**

- Width `min(320, viewportWidth − 16)`, `max-h-[70vh]` (70 % of the window height), scrolls inside with `overscroll-contain`.
- Fill `gray950`, border 1 `gray800`, radius 8, `shadowXl`.
- Layer `PaperLayer.floatingExplanation` (40).

**Content:** exactly one `ExplanationCard` (§12.3), whose own `.card` border sits inside the shell border. Two hairlines overlap at the edge, which is visible in `reader-android.term-click-focus-lock.*` as a slightly brighter rim. Keep it.

**Placement** (`computePopoverPosition`):

- Prefer **below** the anchor + 8.
- Flip **above** (anchor top − height − 8) if it fits there and not below.
- Otherwise use the roomier side.
- Horizontally centre on the anchor.
- Clamp both axes to an 8 inset from the clamp rect (screens/reader.md §5).

**Dismiss:** outside tap, Escape, or the card's `×`. It appears instantly, with no animation.

### 10.4 Term / mention / citation / appendix **hover**

This is **not a popover.** On the web, hovering a reader mark only changes the mark:

- rest wash → `full` fill with a 1.5 ring;
- scale ×1.02 for lines and ×1.04 for words;
- 40 ms hover delay, 150 ms reveal.

All values are `PaperReaderMark.*` and `PaperMotion.*` (tokens.md §2, §10). The mark families are:

| Family | Mark | Example |
|---|---|---|
| term | blue | `reader.term-hover.*` |
| appendix | teal | "Figure 1", `reader.mention-hover.*` |
| citation | indigo | |
| mention | gray | |

External mentions also carry a native `title` tooltip on the web. In the app, use `PaperTooltip` (§18.3) after 500 ms hover, pointer devices only. Keyboard focus on a mark: a 2 px `#4F46E5` ring (`PaperWeb.markFocusRing`).

### 10.5 Figure action pills (on the PDF)

**Source:** `FigureOverlay.tsx` L113–141. These sit at the figure's top-right inside (`right-1 top-1`, 4), as a `flex-col items-end gap-1`.

**Pill:**

- `rounded-full`, fill white, `px-2.5 py-1`, `xs` 500 `gray900`, `shadowSm`, `ring-1` `#0A0A0A` @ .15. **24 tall.**
- Hover fill `gray100` #F5F5F5.
- Focus ring 2 `#4F46E5`.
- Disabled @ 0.6.

**Error pill:**

- Radius 6, fill white, `px-2 py-1`, `xs red700` #B91C1C (live: white background), `ring-1` red-700 @ .2, `max-w-56` 224, right-aligned.

**App mapping:** `FigurePopover` Save / Note / Close become three of these pills. The Material icons are dropped and each pill is a text label.

---

## 11. Reader chrome

### 11.1 `ReaderHeader` (strip)

**Source:** `app/(app)/library/[paperId]/page.tsx` L130:

```
flex shrink-0 items-center gap-2 border-b dark:border-gray-800 dark:bg-gray-950 px-4 py-3
```

- **Height:** **52 + 1** border = 53 (`PaperChrome.readerToolbar*` = 52 content).
- **Fill:** `gray950`. Bottom border 1 `gray800`.
- **Padding and gap:** `px-4` 16 (+ `viewPadding.left/right`), `py-3` 12 (+ `viewPadding.top`). Gap 8.
- **Children:**
  - Back `PaperIconButton` 28.
  - Title: `sectionTitle` (18/28 600 −0.45 `gray100`), `flex-1`, single-line ellipsis.
  - The app controls (screens/reader.md §2), each ≤ 28 tall so the strip stays 52.

### 11.2 `ZoomPill`

**Source:** `PdfReader.tsx` L3753:

```
sticky top-0 z-20 mx-auto mb-4 flex w-fit items-center gap-1.5 rounded-md border dark:border-gray-800 dark:bg-gray-900 px-2 py-1 shadow-sm
```

- **Box:** fill `gray900`, border 1 `gray800`, radius 6, `px-2 py-1`, gap 6, `shadowSm`. **36 tall** (sampled).
- **Children:**
  - `−` `PaperIconButton` 26 bordered.
  - Percentage label: `pageIndicator` (12/16 400 tabular `gray300`), `min-w-12` 48, centred, e.g. "100%".
  - `+` 26 bordered.
- **Layer:** `PaperLayer.readerChrome` (20). Placement is in screens/reader.md §3.
- **Web-only content not copied:** the web pill also holds a 1 px divider + "Give feedback" (`FeedbackButton`). This is a web-only feature and is not reproduced.

### 11.3 `ShowPanelButton`

`PaperIconButton` 36 bordered, with `panel-show.svg`. Position: screens/reader.md §3.

### 11.4 `ReturnPill` (back-to-page)

**Source:** `PdfReader.tsx` L4566:

```
fixed bottom-6 left-1/2 rounded-full border dark:border-gray-700 dark:bg-gray-900 px-4 py-2 text-sm font-medium dark:text-gray-100 shadow-lg dark:hover:bg-gray-800
```

- **Box:** 38 tall, radius full.
- **Label:** `↩ ` text glyph + label.
- **Hover/pressed:** `gray800`.
- **Focus:** ring 2 accent (no offset).
- **Layer:** `readerChrome`.

### 11.5 `FindBar` (app-only, in the header strip)

All in-strip, 28 tall max:

- `PaperTextField.xs`: 26 tall, 256 wide (`w-64`), placeholder `gray400`.
- Match count: `xs` tabular `gray400`, e.g. "3 / 12".
- `PaperIconButton` 24: previous `↑` / next `↓`, using `chevron-down.svg` 16, rotated for previous.
- Match-case toggle: `PaperSegmented.sm` single segment "Aa", selected = `accentSoft`/`accentInk`.
- Close `×` 24.

### 11.6 `ToolDock` (app-only, < 640 wide)

- **Container:** a floating `ZoomPill`-style box (`gray900`, border `gray800`, radius 6, `px-2 py-1`, gap 6, `shadowSm`).
- **Children:** 28 icon buttons (ghost colours; selected tool `accentSoft`/`accentInk`).
- **Position:** bottom-centred, `bottom: 24 + viewPadding.bottom`.

---

## 12. Side panel container

### 12.1 `ReaderPanel` frame

**Source:** `PdfReaderLoader.tsx` L852–906:

```
<aside class="flex w-96 flex-col overflow-y-auto border-l dark:border-gray-800 dark:bg-gray-950">
```

- **Width** **384** (`PaperBreakpoints.readerPanelWeb`). Fill `gray950`, left border 1 `gray800`.
- **Header** (sticky, z 10): `flex items-center px-3 py-2`, bottom border 1 `gray800`, fill `gray950`. **40 + 1 = 41 tall** (sampled at 53→94 in `reader.*`).
  - App: `PanelTabs` (§8.2) on the left.
  - Hide button `PaperIconButton` 32 (`-m-1`, layout 24) on the right, gap 8.
- **Body:** a scroll region. Its content is per tab (screens/side-panel.md).
- **Modes** (docked, overlay, sheet): screens/side-panel.md §1.

### 12.2 `PanelSectionHeader`

**Source:** `FigureHighlightsPanel.tsx` L263–272.

- **Section box:** `px-4 pt-4 pb-4`, bottom border 1 `gray800`.
- **Heading:** `mb-3`, eyebrow 12/16 600 uppercase +0.3 `gray400`, then `CountChip`, gap 8.
- **List:** `flex-col gap-2`.

### 12.3 `ExplanationCard`

**Source:** `reader/ExplanationSidebar.tsx` L587–700.

**Box:** `PaperCard p-4`.

**Header:** `mb-2 flex items-start justify-between gap-2`.

- Term: `cardTitle` `gray100`, `break-words`.
- `×` `PaperIconButton` 24 ("Close explanation").

**Tags:** `mb-2 flex-wrap gap-1` `TagChip`s.

**Cached note:** `mb-2 xs gray400` (app `aiCachedExplanation`; web "Already in your glossary — showing your saved explanation.").

**Prose:**

- `explanationBody` (14/22.75 `gray300`), whitespace pre-wrap.
- Inline code: `code` style, fill `gray800`, radius 4, `px-1`.
- App-only section headings ("Analogy", "Formal"): eyebrow `gray400`, `mt-3 mb-1`. The first heading has no top margin.

**Re-explain error:** `mt-2 xs red400`.

**Visual aid:** `mt-3`.

- Video box: radius 6, border 1 `gray700`, fill black.
- Controls row `mt-2 gap-2`:
  - `PaperButton.quiet` "Play"/"Pause";
  - seek slider (track `accent`, `h-1`);
  - time label `GeistMono` 11.2 tabular `gray400`.
- Caption `mt-2 xs leading-relaxed gray400`.

**Timestamp:** `mt-3 xs gray400` ("1 day ago").

**Rating:** `mt-3 PaperRating` (§18.2). This replaces the app's `StarRating`.

**Card actions** (app: Re-explain, Jump to page, Show visual): `mt-2 flex justify-end gap-1`, `PaperButton.quiet`.

**State variants:**

| State | Spec |
|---|---|
| **Pending / loading** (`ProgressCard`) | `PaperCard p-4`. Term `mb-3`. `PaperProgressBar.indeterminate`. Caption `mt-2 xs gray400`. |
| **Error** | `rounded-lg border red900 bg red950 p-4`. Title `sm 600 red200`. `×` 24 error tone. Body `mt-2 sm-relaxed red300`. Retry: `mt-3 PaperButton.secondary xs`. |
| **Offline (queued)** | `PaperCard p-4`. Term + `xs gray400` line (app `aiOfflineCardBody`) + `info-small.svg` 16 `gray400` before it, gap 8. |

---

## 13. Menus

The web has no dropdown menus. It uses native `<select>` (`field-input`) only, and the "···" row action expands a detail row (§7.1). The app keeps `PopupMenuButton` / `MenuAnchor` in four places:

- reader overflow;
- library sort;
- notes card "more";
- the sync sheet entry.

These use a menu surface derived from the popover card.

**`PaperMenu`:**

- **Surface:** fill `gray900`, border 1 `gray700`, radius 8, `shadowLg`, padding 4.
  - Width: min 160 (`w-40`), max 320; intrinsic in between.
  - Layer: `PaperLayer.popover` (30).
- **Placement:** below the anchor, 4 gap, aligned to the anchor's right edge when the anchor sits right of centre. Clamp 8 from the window edges (+ insets).
- **Item:** `PaperButton.popover.neutral` geometry: radius 4, `px-3 py-1.5`, **32 tall**, `sm` 14/20 500 `gray200`, left-aligned, full width.
  - Leading icons are dropped (the web never shows icons in text actions).
  - Hover/pressed `gray800`.
  - Focus: fill `gray800` (menu keyboard focus is a fill, like a native select, not a ring).
  - Disabled @ 0.5, with an optional second line `xs gray400`.
- **Selected item** (sort, radio): label `gray100` + trailing `check.svg` 16 `accent`.
- **Destructive item:** label `red400`, hover `red950`.
- **Divider:** 1 `gray800`, margin 4 vertical.
- **Motion:** opens instantly, no scale or fade (web parity). Close on outside tap or Escape.

**Trigger** for sort: `PaperButton.ghost md` with the label "Recently opened" and a trailing `chevron-down.svg` 16, rotated 180° while open. For row/notes "more": `PaperButton.ghost xs` with the text `···`.

---

## 14. Dialogs

**`PaperDialog`**

**Source:** `settings/ObsidianDisconnectDialog.tsx` L83–135.

**Barrier:**

- `PaperWeb.dialogBackdrop` `#0A0A0A` @ 0.60, full-bleed.
- No blur.
- Layer `PaperLayer.dialog` (50).

**Card:**

- `PaperCard` + `shadowXl`, `w-full max-w-md` (**448**), padding **20** (`p-5`).
- Window inset 24 horizontal (`px-6`) + `viewPadding`, centred vertically.

**Content:**

- Title: `cardTitle` 14/20 600 `gray100`.
- Body: `mt-2 sm gray400`.
- Extra paragraphs: `mt-3`.
- Inline error: `mt-3 sm red400`.
- Fields: `mt-4`, `PaperTextField.md`.
- Checkbox rows: `mt-4`, `PaperCheckbox` 16 + `sm gray300` label, gap 8.

**Actions:** `mt-5 flex justify-end gap-3`, `md` buttons:

- cancel `PaperButton.secondary`;
- confirm `PaperButton.primary`, or `PaperButton.destructive md` for destructive confirms (delete paper, sign out and discard, remove all downloads).

**Motion:** none (the web dialog mounts instantly). The app may keep a ≤150 ms barrier fade under `PaperMotion.of`; design-motion decides.

**Focus:** focus moves to the first focusable element, is trapped, and Escape cancels.

**App dialogs** that use this:

- rename (only where inline rename can't be used, see library.md);
- import-from-link fallback (< 640);
- delete confirmations;
- sign-out (`sign_out_dialog.dart`; its `CheckboxListTile` becomes a checkbox row);
- sync sheet (`sync_sheet.dart`, `max-w-md`, rows as `PaperListRow`);
- storage "Remove all".

---

## 15. Toasts

**`PaperToast`**

This replaces `SnackBar` on restyled screens. **Source:** `reader/CiteAddToast.tsx` L283–410.

| Part | Spec |
|---|---|
| Box | `max-w-xs` **320** (min 240). Fill `PaperWeb.gray900Toast` #161616 (gray-900 @ .9). Border 1 `gray800`, radius 8, `p-3` (12), `shadowMd`. `BackdropFilter` blur σ 6 (`backdrop-blur-md` 12 px): one small fixed overlay is cheap enough. |
| Position | `bottom: 24 + viewPadding.bottom`, `right: 24 + viewPadding.right` (`fixed bottom-6 right-6`). Layer `PaperLayer.toast`. Stacking: newest replaces the current one (web shows one). |
| Body row | `flex items-start gap-2`. Status icon 16 (`toast-check.svg` `green400`, `toast-error.svg` `red400`, `spinner.svg` `accent`), then text. Headline `sm` 600 `gray100`; detail `xs gray400`; error text `xs red400`. Plain messages ("Added to your library.") use `xs gray400` with no icon. |
| Action row | `mt-3 flex items-center justify-between gap-2`. Left: action `PaperButton.primary sm` (32 tall), e.g. "Undo" or "Open paper". Right: dismiss `PaperIconButton` 32 `×`. When there is no action: an empty left side + dismiss. |
| Loading | Body row only, no action row. |
| Timing | Auto-dismiss **2000 ms** for success. Messages with an action keep the app's current durations (undo windows). Hover or focus pauses the timer. |
| Motion | The web uses `animate-cite-add-toast-in/out` (defined in tailwind.config; design-motion owns the curve). Reduced motion: instant. |
| Semantics | `liveRegion: true`; errors announced assertively. |

The selection-popover "Copy" confirmation is **not** a toast. The label swaps instead (§2.6).

---

## 16. Spinner, progress, skeleton

| Widget | Spec | Source |
|---|---|---|
| `PaperSpinner` | `spinner.svg` 16: track circle @ .25 + arc, stroke 2, `accent`. Rotates 360° per `PaperMotion.spin` (1 s linear). Reduced motion: static. Sizes 16 (default) and 20. | `CiteAddToast.tsx` `SpinnerIcon` |
| `PaperProgressBar.indeterminate` | Track `h-1.5` (6) full width, radius full, `gray700`. Bar `w-1/3` radius full `accent`, translateX −100 % → 300 % over `PaperMotion.progressIndeterminate` (1.2 s ease-in-out, infinite). Reduced motion: a static 1/3 bar at the left. | `ExplanationSidebar.tsx` `ProgressCard` |
| `PaperProgressBar.determinate` (app import upload %) | Same track. Bar width = progress, `accent`. Width change 150 ms `standard`. | app-only, built from the above |
| `PaperSkeleton` | Block fill `gray800`, radius 4 (`rounded`), opacity pulse 1 → .5 → 1 over 2 s (`PaperMotion.pulse`, `pulseCurve`). Reduced motion: static. Text-line blocks are 12 tall (xs) or 14 tall (sm), never full width (40–70 %). | `CitationPopover.tsx` preview loading, figure crop |

---

## 17. Empty, error and notice blocks

| Widget | Spec | Source |
|---|---|---|
| `EmptyStateCard` (page level) | `PaperCard p-8 text-center`. Title `sm 600 gray100`. Body `mt-1 sm gray400`. Action row `mt-4 flex justify-center` (one button). | `AddPaperDisclosure.tsx` L80, `PaperSelectionList.tsx` L593 |
| `EmptyStateText` (panel level, no card) | `px-2 py-10 text-center`, `sm-relaxed gray400`. App: optional title above, `sm 600 gray100` + `mt-1`. | `ExplanationSidebar.tsx` L843 |
| `EmptyStateCard.compact` (no-match) | `PaperCard p-8 text-center sm gray400`, one sentence. Optional `mt-4` `PaperButton.secondary` (e.g. "Clear search"). | `GlossarySearch.tsx` L188 |
| `ErrorBanner` | `rounded-lg border red900 bg red950 p-4 sm red300`, `role=alert`. Reader-level: `p-6`. App retry: `mt-3 PaperButton.secondary xs` (on red950 the secondary keeps its gray900 fill). | `LibraryCentrePapers.tsx` L125, `[paperId]/page.tsx` L218 |
| `PlaceholderCard` (neutral info) | `rounded-lg border gray800 bg gray900 p-6 sm gray300`. First line `font-medium gray100`, then `mt-1`. | `[paperId]/page.tsx` L203 (no PDF) |
| `NoticeStrip` (full-width info) | `flex items-start gap-3 border-b gray800 bg accentSoft px-4 py-2.5 sm accentInk`. `info.svg` 16 `mt-0.5`. Text `flex-1`. Inline link `font-medium underline offset-2`, hover no underline. Dismiss: `rounded-md px-2 py-0.5 xs 500`, hover fill black @ .20 (`#000` 20 % over accent-soft). | `reader/MatchNotice.tsx` L99–139 |
| `InlineStatus` | `sm` (forms) or `xs` (rows). Neutral `gray400`/`gray300`, success `green400`, error `red400` (`role=alert`), warning `amber400`. | `ImportPaperForm.tsx`, `ProfileSettingsForm.tsx` |

---

## 18. Links, rating, tooltip, disclosure

### 18.1 Links

| Variant | Spec | Source |
|---|---|---|
| `PaperLink.accent` | `accent`, 500, underline offset 2 (always underlined in prose; hover-only in actions). Hover `accentHover`. Focus ring 2 accent, radius 6. | `GlossaryEntryCard.tsx` L111, `ObsidianSettingsSection.tsx` L490 |
| `PaperLink.strong` | `gray100` 500, no underline at rest, hover underline offset 2. | `SignInForm.tsx` "Create an account" |
| `PaperLink.nav` | `px-2 py-1`, `sm` 400 `gray400`, hover `gray100`, radius 6, no fill. | `app/layout.tsx` `navLinkClass` (app bar "Sign in", README §2.2) |

### 18.2 `PaperRating` (replaces `StarRating`)

**Source:** `glossary/TermRating.tsx`. It appears in explanation and glossary cards (`reader.*` panel shots).

- **Row:** `flex-wrap items-center gap-2`. Label "Rate this explanation" `xs gray400`. Buttons group `gap-1`. Value text `xs gray400` ("4/5" or "Not rated").
- **Button:** **24×24**, radius 6, `xs` 500 tabular, centred digit 1–5.

| State | Fill | Digit |
|---|---|---|
| Rest | `gray800` | `gray400` |
| Hover / pressed | `gray700` | `gray100` |
| **Selected** (the chosen value only, not 1..n) | `accent` | `indigo950` |
| Focus | ring 2 accent, offset 2, gap `gray900` | |
| Disabled (saving) | @ 0.5 | |
| Error | row below `mt-1.5 xs red400` | |

- **Re-tap:** tapping the selected value clears it (web title "click to clear").

### 18.3 `PaperTooltip`

The web shows native `title` tooltips. The app themes `Tooltip` (already in `PaperTheme`):

- fill `gray900`, border 1 `gray700`, radius 6;
- `px-2 py-1`, `xs` `gray100`;
- `shadowMd`;
- wait 500 ms; never shown on touch long-press for elements that have a visible label.

### 18.4 Disclosure trigger

`PaperButton.ghost md` (or `.primary` for "Add a paper"):

- label + `chevron-down.svg` 16, gap 8;
- the chevron rotates 180° in 150 ms when open; reduced motion means instant;
- the panel appears **without animation** (`animate-expand-in` is undefined, tokens.md §3);
- on open, focus moves to the first field in the panel; on close, back to the trigger (`AddPaperDisclosure.tsx` L40–47);
- the open-state ghost label is `gray100`.

Glossary entry chevron:

- `chevron-right-small.svg` 14 `gray500`, rotates 90° in 150 ms when expanded;
- the term button hovers to `accent`.

---

## 19. Icons

Web SVGs are in `design/web-parity/icons/`. Render them with `flutter_svg`, `colorFilter: ColorFilter.mode(color, BlendMode.srcIn)`.

- **Web glyphs** keep their own viewBox and stroke (tokens.md §13).
- **Text glyphs** stay `Text` in Geist.
- **App-only glyphs with no web source** use **Lucide** paths, which are the same line family as the web's paths. Re-export each at:
  - 24 viewBox, **stroke-width 1.5**, round caps and joins, `currentColor`, drawn at 16 (inline);
  - or stroke 1.75 / 20 viewBox at 20 (header and chrome buttons).

  Do not use the Lucide font: its stroke is 2. Store them as `design/web-parity/icons/app/*.svg` with the same conventions. **Remove `material_symbols_icons`** from every restyled widget.

| App use (current `Symbols.*`) | Web-parity glyph | Size / colour |
|---|---|---|
| Reader back (`arrow_back`) | `reader-back.svg` | 20 `gray400` |
| Panel toggle (`right_panel_open/close`) | `panel-show.svg` (floating), `panel-hide.svg` (panel header) | 20 |
| Close (`close`) | text `×` 16 | `gray400` |
| Overflow (`more_vert`) | text `···` in `PaperButton.ghost xs` | |
| Add / zoom in, zoom out (`add`, `remove`) | text `+` / `−` 16 | |
| Undo pill (`undo`) | text `↩` | |
| Open in new (`open_in_new`) | text `↗` | |
| Sort / disclosure chevrons | `chevron-down.svg` 16 | |
| Glossary row chevron (`chevron_right`) | `chevron-right-small.svg` 14 `gray500` | |
| Page prev/next (`chevron_left/right`) | `nav-back.svg` 16, mirrored for next | |
| Find up/down (`keyboard_arrow_up/down`) | `chevron-down.svg` 16, rotated 180° for up | |
| Check / success (`check`, `check_circle`) | `check.svg` / `toast-check.svg` 16 `green400` | |
| Error / warning (`error`, `warning`) | `alert-circle.svg` / `toast-error.svg` 16 `red400` | |
| Info / offline strip (`cloud_off`) | `info.svg` 16 inherits | |
| Spinners (`CircularProgressIndicator`) | `spinner.svg` 16 `accent` | |
| Files (`description`), papers nav | `file.svg` / `nav-papers.svg` 16 | |
| Settings nav | `nav-profile.svg` 16 | |
| Highlight tool / highlights (`ink_highlighter`) | `highlighter.svg` 16 | |
| Glossary (`menu_book`) | `lines.svg` 16 | |
| Timer / sync pending | `timer.svg` 16 | |
| Select tool (`arrow_selector_tool`) | Lucide `mouse-pointer-2` | 16 |
| Pen tool (`stylus`) | Lucide `pen-line` | 16 |
| Figure tool (`crop_free`) | Lucide `scan` | 16 |
| Eraser (`ink_eraser`) | Lucide `eraser` | 16 |
| Search (`search`) | Lucide `search` | 16 |
| Note (`sticky_note_2`) | none: action buttons are text-only ("Note") | |
| Explain (`auto_awesome`) | none: text-only "Explain" | |
| Copy (`content_copy`), Delete (`delete`) | none: text-only | |
| Refresh / retry (`refresh`) | none: text button "Try again" | |
| Link import (`link`) | none: text menu items | |
| Sync badge states (`cloud_*`, `sync`, `devices`) | Lucide `cloud`, `cloud-off`, `refresh-cw`, `monitor-smartphone`, stroke 1.5 | 16 `gray400`; error `red400`; syncing spins like `PaperSpinner` |
| Match case (`match_case`) | text `Aa` 12 500 | |
| Grid/list view (`grid_view`, `view_list`) | **removed**: the library is table-only (library.md) | |

---

## 20. PaperFocusRing

**Reproduces:** Tailwind `focus-visible:ring-2 ring-accent ring-offset-2 ring-offset-<surface>`. These are two box-shadows outside the border box:

- the offset colour, spread 2;
- the ring colour, spread 4.

`BorderSide` cannot draw this.

**API**

```dart
PaperFocusRing({
  required Widget child,
  required BorderRadius radius,         // the child's own corner radius
  Color color = PaperWeb.accent,        // red500 for destructive, white on thumbnails, markFocusRing on the PDF
  double width = 2,                     // ring-2
  double offset = 2,                    // ring-offset-2; 1 for popover buttons; 0 for icon buttons/links
  Color? gap,                           // ring-offset colour = the surface UNDER the child; null when offset == 0
  bool inset = false,                   // ring-inset (list rows)
  bool show,                            // focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional
})
```

**Painting** (a foreground `CustomPainter`, no layout change, no clipping):

1. If `offset > 0` and `gap != null`: fill the ring-shaped area between `rect.inflate(0)` and `rect.inflate(offset)` with `gap`. Use RRect radii `r` and `r + offset`. Paint it as a stroke of width `offset` centred on `rect.inflate(offset/2)` with radius `r + offset/2`.
2. Stroke the ring: width `width`, centred on `rect.inflate(offset + width/2)`, radius `r + offset + width/2`, colour `color`.
3. `inset: true`: stroke inside the rect (`rect.deflate(width/2)`, radius `r − width/2`), no gap.

**Rules:**

- **Gap colour:** `#0A0A0A` on the page, the app bar, the panel and the reader header. `#171717` inside cards, popovers, dialogs and toasts. Pass the actual parent surface, never transparent: the web paints it.
- **Never animate** the ring. It appears and disappears in one frame, like `:focus-visible`.
- **Not on touch:** touch or stylus taps never show it (`highlightMode == touch`).
- **Clipping:** parents that clip (`ListView`, `ClipRRect` cards) clip the ring too. That is web parity (`overflow-hidden` cards clip rings), so don't fight it, except for the table title link: give its cell a 4 px inner padding budget, as the web's `px-4` already does.
- **Inputs do not use it:** inputs use the 2 px accent border (§4.1).
- **Reader marks do not use it:** marks use `markFocusRing` 2 px with no gap.

| Variant | color | offset | gap |
|---|---|---|---|
| Buttons, nav items, checkboxes, pills on the page | accent | 2 | `#0A0A0A` |
| Buttons inside cards / popovers / toast CTA | accent | 2 | `#171717` |
| Selection-popover buttons, segmented | accent | 1 | `#171717` |
| Icon buttons 24/28/32, links, glossary term button, title link | accent | 0 | — |
| Destructive outline | `red500` | 2 | surface |
| Figure pills, thumbnail overlay | `markFocusRing` / white | 0 / 2 | transparent |
| List rows (`focus-within`) | accent | inset | — |
