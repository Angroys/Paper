# Library (S1): web-parity spec

- **App route:** `/library`, inside the shell, with the app nav bar.
- **Web route:** `/library` (`app/(app)/library/page.tsx` → `LibraryCentrePapers`, `AddPaperDisclosure`, `UploadPaperForm`, `ImportPaperForm`, `PaperSelectionList`, `PapersTable`, `PaperTableRow`).
- **Components:** [`../components.md`](../components.md).
- **Chrome and insets:** [README §2, §3.3, §4.4](README.md).

**References:**

| Shot | What to compare |
|---|---|
| [`library.1280x800.png`](../reference/library.1280x800.png), [`library.full.1280x800.png`](../reference/library.full.1280x800.png) | page title, "Add a paper" button, "Your papers" heading, table header (landscape) |
| [`library.800x1280.png`](../reference/library.800x1280.png), [`library.full.800x1280.png`](../reference/library.full.800x1280.png) | table rows, thumbnails, row actions, row height (portrait) |
| [`library.add-paper-open.1280x800.png`](../reference/library.add-paper-open.1280x800.png), [`library.add-paper-open.800x1280.png`](../reference/library.add-paper-open.800x1280.png) | open disclosure with the Upload and Import cards |

**Decisions applied (CMO):**

- **The web's centre column is replicated:** add-paper disclosure, then the "Your papers" table.
- **`PaperCard` grid mode is dropped.** The grid/list `SegmentedButton` is removed, and the library is table-only at every width.
- **Not added**, because they are web-only features:
  - `DashboardSidebar` (profile tile, Dashboard/Statistics/Profile, progress donut);
  - `FeaturedPapersRow` and the "Read papers" disclosure;
  - the Projects rail;
  - the "Show filed papers" checkbox;
  - row selection and bulk actions.
- **The compact FAB is removed.** "Add paper" is the inline primary button at every width, as on the web.

---

## 1. Layout

The app nav bar (README §2.2) is 48 tall, and its bottom 1 px is the `gray800` hairline. Below it, one vertical scroll region fills the window.

### 1.1 Container

| | 1280×800 (`xl`) | 800×1280 (`md`) | < 640 (base) |
|---|---|---|---|
| Container | `mx-auto max-w-7xl px-6`: box ≤ 1280, side padding 24 (+ `viewPadding.left/right`) | same | same |
| Content width | **1232** | **752** | window − 48 |
| Top padding (below the bar) | **48** (`sm:py-12`) | **48** | **40** (`py-10`) |
| Bottom padding | 48 + `viewPadding.bottom` | same | 40 + `viewPadding.bottom` |

**Column geometry gap:** this is the parity gap in README §3.3. The web's centre column at 1280 is about 672 wide (between a 208 sidebar and a 288 rail). The app's centre column spans all **1232**. The table therefore matches the web's **styles and row geometry**, but not its column x-positions or widths at `xl`/`lg`. At 800 the web is single-column too, so its geometry matches except for the dropped sidebar and featured blocks above the table.

### 1.2 Vertical stack

Logical y values are measured from the top of the window, with no cutout.

| # | Element | Spacing | Height | y @ 1280×800 | y @ 800×1280 |
|---|---|---|---|---|---|
| 0 | App nav bar | — | 48 | 0–48 | 0–48 |
| 1 | `h1` "Library": `pageTitle` 24/32 600 −0.6 `gray100` | pt 48 | 32 | 96–128 | 96–128 |
| 2 | **Add-paper trigger**: `PaperButton.primary md` "Add paper" + `chevron-down.svg` 16, gap 8 | `mt-8` 32 | 36 | 160–196 | 160–196 |
| 2a | Add-paper panel (when open, §3) | `mt-4` 16 | 194 (equal-height cards) | 212–406 | 212–406 |
| 2b | Import progress cards (app, §3.3), one per job | `mt-4` 16, gap 8 | 54 each | — | — |
| 3 | `h2` "Your papers": `sectionTitle` 18/28 600 −0.45 `gray100` | `mt-8` 32 | 28 | 228–256 (closed) | 228–256 |
| 4 | **Toolbar row** (§2.1) | `mt-4` 16 | 38 | 272–310 | 272–310 |
| 4a | Result count (only while searching): `xs gray400`, `px-1` | `mt-2` 8 | 16 | — | — |
| 5 | **Papers table** (§2.2) | `mt-3` 12 | 48 header + 89 × n | 322 → header ends 370, rows 370–459, 459–548, … | same |

Everything scrolls together; the nav bar is the only fixed part. The table never has its own vertical scroll.

---

## 2. Components

### 2.1 Toolbar row (app-only controls in web styles)

`Row`, cross-axis centred:

- **Search:** `PaperSearchField`, **320** wide (`max-w-xs`), 38 tall, placeholder `librarySearchHint`. The `×` clear button appears when text is present. There is no leading icon.
- **Filter:** gap 12, then `PaperSegmented.md` with All · Downloaded · Unread (38 tall). "Downloaded" is hidden in local-only builds, as today.
- **Spacer.**
- **Sort:** a `PaperButton.ghost md` trigger with the current sort label + `chevron-down.svg` 16 (36 tall). It opens a `PaperMenu` (components §13) with three radio items; the selected item shows `check.svg` 16 `accent`.

Below 640 the row wraps:

- search on its own row, full width;
- then filter (left) and sort (right), 8 below (`gap-y-2`).

### 2.2 Papers table

`PaperTable` (components §7.1): a `.card` with no padding, radius 8, border `gray800`, fill `gray900`. The table min-width is 704. Below that it scrolls horizontally inside the card, which only happens below about 750 px of window width.

| Column | Header | Width | Cell content |
|---|---|---|---|
| Photo | "PHOTO" | **80** fixed (`w-20` = 16 + 48 + 16) | `PaperThumbnail.row` 48×64. It is dimmed to 0.5 when the paper is unavailable offline. |
| Name | "NAME" | flex, min 200 | Title link `sm 500 gray100`, ellipsis, content capped at **288**. A `ReadBadge` "Read" sits 8 after the title when `paper.isRead`. Below it, `mt-0.5`: meta `xs gray400` = `paperMeta` ("Added 11 Oct 2026" / "Waiting to upload"). |
| Rate | "RATE" | **72** (16 + 40 + 16) | `ReadMeter` 40×16 (read = accent solid, unread = gray-500 dashed). Display only: the app has no "Mark read" action, so the web's button is not added. |
| Status | "STATUS" | **104** | App-only. `PaperSyncChip` / `DownloadStateBadge` / `PaperKeptChip`, restyled as `NeutralChip`/`StatusChip` (components §9.4, §9.7) in a `flex-wrap gap-1`. The column is hidden entirely when no row has a chip (offline-only and guest builds). |
| Opened | "OPENED" | **96** | `xs gray400`, wraps, e.g. "2 days ago" (`formatWhen`). Empty: `—` `xs gray500`. |
| Action | "ACTION" (right-aligned) | **180** | `flex justify-end gap-1`: `PaperButton.ghost xs` "Open" · `PaperButton.ghost xs` "···" (toggles the detail row, `aria-expanded`) · `PaperButton.destructive xs` "Delete". |

**Name column width:** 752 − 532 = **220** at 800 portrait (188 content) and 700 at 1280 (content still capped at 288).

**Header row:**

- **48** tall, `px-4 py-3`.
- Eyebrow labels 12/16 600 uppercase +0.3 `gray400`.
- 1 px `gray800` bottom border.

**Body rows:**

- **88** + 1 divider (`divide-y gray800`).
- Hover fill `#1F1F1F`.
- Tapping the row opens the paper (the existing behaviour, kept). The title link and the buttons are separate focus stops.

**Detail row** ("···" open):

- Fill `#1F1F1F`, `px-4 pb-3`.
- `flex-wrap gap-1` of `PaperButton.ghost xs`: **Rename**, then **Download** or **Remove download** (not in local-only builds).
- This replaces the app's `PaperMenuButton` popup and matches the web's expander.
- Errors and notices appear on a line below: `mt-1.5 xs` `red400` / `gray400`.

**Inline rename** (replaces `_RenameDialog` on ≥ 640):

- The Name cell becomes `flex items-center gap-2`: `PaperTextField.sm` (30 tall, flex) · `PaperButton.primary xs` "Save" (24) · `PaperButton.secondary xs` "Cancel" (26).
- Enter saves and Escape cancels.
- While saving, the label is "Saving…" and all three are disabled.
- **Below 640:** keep the dialog (`PaperDialog` + `PaperTextField.md`), because the 30-tall inline field doesn't fit next to the thumbnail at that width.

**Delete:**

- Immediate, as today, followed by `PaperToast` "Deleted “title”." with the `PaperButton.primary sm` "Undo".
- The button label reads "Removing…" for the in-flight frame only if the delete is async.

---

## 3. Add-paper disclosure

### 3.1 Trigger

- `PaperButton.primary md`. The label is "Add paper" (`importButton`) when closed and "Close" (`commonClose`) when open.
- The chevron rotates 180° when open (150 ms; instant under reduced motion).
- The panel appears **without animation**.
- Focus moves to the first control in the panel, and back to the trigger on close.

### 3.2 Panel

- `mt-4`, then a grid **2 columns at ≥ 768** (`md:grid-cols-2`) with gap **16**. One column below 768.
- The two cards are equal height (row stretch).

| Card | Spec |
|---|---|
| **From a file** (`PaperCard p-5`) | Title `cardTitle` (`importFromFile`). Then `mt-4 flex-col gap-4`: `PaperFilePickerButton` "Choose file" (32 tall) + status text 12 to its right (`sm gray400`, file name or "No file chosen"). Below it, a status line with `min-h-5` (20): `sm` `gray400` "Uploading 40%" / `green400` "Added to your library." / `red400` error. |
| **From a link** (`PaperCard p-5`) | Title `cardTitle` (`importUrlDialogTitle`). Then `mt-4 flex-col gap-4`: label `sm 500 gray300` (`importUrlFieldLabel`) + 6 + `PaperTextField` textarea (1 row, 38; grows to 3 rows when several links are pasted). Then the button row `flex items-center gap-3`: `PaperButton.primary md` "Add" (`importUrlSubmit`) + inline status `sm` (`gray400` / `green400` / `red400`). The clipboard suggestion (`importUrlClipboardSuggestion`) is `xs gray400` with a `PaperLink.accent` "Use", placed between the field and the button row. |

| Size | 1280 | 800 |
|---|---|---|
| Card width | (1232 − 16) / 2 = **608** each | (752 − 16) / 2 = **368** each |
| Card height | **194** (2 + 20 + 20 + 16 + 20 + 6 + 38 + 16 + 36 + 20 + 2, set by the link card) | 194 |

- **Offline:** the link card's controls are @ 0.5, and an `xs gray400` line says `importOfflineUrl`.
- **Offline-only builds:** the link card is absent, and the file card spans one column at 50 % (it is not stretched).
- **Below 640:** the panel stays inline (it does not open a bottom sheet). The `showModalBottomSheet` import chooser is removed.

### 3.3 Import progress (app-only)

Each running or failed import is a `PaperCard p-3`, `mt-4` below the panel or trigger, with gap 8 between cards:

- **Row** `flex items-start gap-2`:
  - `PaperSpinner` 16 (running) or `toast-error.svg` 16 `red400` (failed);
  - then a text column: file or URL name `sm 500 gray100` with ellipsis, and the detail line `xs gray400` ("Uploading 40%") or `xs red400` (error).
- **Running:** `PaperProgressBar.determinate` `mt-2`.
- **Failed:** `mt-2 flex gap-1`, with `PaperButton.secondary xs` "Try again" and `PaperButton.ghost xs` "Dismiss".
- **Height:** 54 while running (12 + 20 + 16 + … ≈ 54 with the bar). Do not reserve space.

---

## 4. States

| State | What renders in place of the add trigger and table |
|---|---|
| **Loading** (first load, no cached list) | The trigger and h2 render as normal. The table card shows the real header + **4 skeleton rows** (88 tall): a 48×64 `PaperSkeleton` (radius 6) thumbnail, two name bars (14×40 % and 12×25 %, gap 6), and a 12×40 bar in Rate/Opened. Action cells are empty. Pulse 2 s. |
| **Empty** (no papers, no query) | The trigger and the "Your papers" section are replaced by one `EmptyStateCard` (`p-8`, full width): title `libraryEmptyTitle`, body `mt-1` `libraryEmptyBody` (or `…FileOnly`), action `mt-4` the add trigger (primary + chevron). Opening it shows the panel **below** the card. The desktop drop hint (`libraryEmptyDropHint`) is `mt-2 xs gray400` inside the card. |
| **No search results** | The toolbar stays. The table is replaced by `EmptyStateCard.compact` `mt-3`: title `librarySearchNoResultsTitle` `sm 600 gray100`, body `mt-1 sm gray400` (`librarySearchNoResultsBody`), action `mt-4 PaperButton.secondary md` "Clear search". |
| **Filter empty** | As above, with body `libraryFilterDownloadedEmpty` / `libraryFilterUnreadEmpty` and action "Show all". |
| **Load error** (no cached list) | `ErrorBanner` `mt-3` in the table slot: first line `font-medium red200` (`libraryLoadFailedTitle`), then `libraryLoadFailedBody` `red300`, then `mt-3 PaperButton.secondary xs` "Try again". |
| **Refresh error with a cached list** | The list stays. `PaperToast` with an error (`toast-error.svg`, `xs red400`). |
| **Offline** | The list stays. Offline-unavailable rows: thumbnail @ 0.5, Status chip "Not downloaded". The "From a link" card is disabled (§3.2). |

---

## 5. Insets and IME (README §4.4, §4.6)

- **Backgrounds:** the scroll viewport is full-bleed `gray950`. The container adds `viewPadding.left/right` to its 24 side padding. The last element gets `viewPadding.bottom` extra bottom padding.
- **Toasts:** `bottom: 24 + viewPadding.bottom`, `right: 24 + viewPadding.right`.
- **Menus and dialogs:** clamp 8 from the inset window edges.
- **IME:** `resizeToAvoidBottomInset: true`. The search field, link textarea and inline rename field scroll into view with `Scrollable.ensureVisible`. The nav bar doesn't move.

---

## 6. Parity checklist

Compare with `library.full.800x1280.png` (rows) and `library.1280x800.png` (header block) at the same window width.

- [ ] Page background `#0A0A0A`; `h1` "Library" Geist 24/32 600, letter-spacing −0.6, `#F5F5F5`, left edge at x = 24 (+ inset), 48 below the app bar.
- [ ] "Add paper" button: fill `#818CF8`, label `#1E1B4B` Geist 14/20 500, 36 tall, radius 6, padding 16×8, 16 px chevron 8 after the label; hover fill `#A5B4FC`.
- [ ] "Your papers" `h2` Geist 18/28 600 −0.45 `#F5F5F5`, 32 below the add button.
- [ ] Table card: fill `#171717`, 1 px `#262626` border, radius 8, no shadow; header row 48 tall with a 1 px `#262626` bottom border.
- [ ] Header labels: Geist 12/16 600, uppercase, letter-spacing +0.3, `#A3A3A3`, 16 px left padding per cell.
- [ ] Body row height 88 + 1 px `#262626` divider; row hover fill `#1F1F1F`.
- [ ] Thumbnail 48×64, radius 6, 1 px `#404040` border, `#262626` placeholder fill, file glyph 20 `#525252`.
- [ ] Title Geist 14/20 500 `#F5F5F5`, ellipsis at 288 px; meta Geist 12/16 400 `#A3A3A3`, 2 px below the title.
- [ ] "Read" badge: 20 tall, radius full, padding 8×2, Geist 11 500, `#C7D2FE` on `#1E1B4B`.
- [ ] Row actions: "Open" and "···" are ghost 24 tall (`#A3A3A3`, hover fill `#262626` + `#F5F5F5`); "Delete" is a 26-tall outline with a 1 px `#7F1D1D` border, `#171717` fill, `#F87171` label; gap 4.
- [ ] ReadMeter 40×16: unread dashed 1.5 `#737373`, read solid 2 `#818CF8`.
- [ ] Search field 320×38: `#171717` fill, 1 px `#404040` border, radius 6, 14/20 text, placeholder `#A3A3A3`; focused, a 2 px `#818CF8` edge and no leading icon.
- [ ] Open disclosure: two `p-5` cards, gap 16, equal height 194, side by side at ≥ 768 wide; "Close" label + chevron rotated 180°; no expand animation.
- [ ] Empty library: a single centred card (`p-8`), title 14/20 600 `#F5F5F5`, body 14/20 `#A3A3A3`, primary button 16 below.
- [ ] No grid/list toggle, no FAB, no Material icons anywhere on the screen.
