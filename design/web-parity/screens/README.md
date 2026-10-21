# Web-parity screens: inventory, app chrome, layout and full-screen rules

**Scope:** the Flutter app "Paper" restyled to match paper.college (RPR web app) near pixel-for-pixel. This file is the structural layer: which screens exist, how they map to web routes, the app's own navigation chrome, per-orientation layout rules, and Android full-screen behaviour. The per-screen visual specs are written by M3 (see the index in §5). Exact token values live in [`../tokens.md`](../tokens.md); this file names tokens by **role** (`background`, `surface`, `border`, `textPrimary`, `textMuted`, `textSubtle`, `accent`, `accentSoft`, `accentInk`) and by the RPR Tailwind classes they come from.

**User goal (all screens):** "Read and annotate my papers on a tablet with the same look and muscle memory as paper.college, with every pixel of the screen given to the paper."

**Personas:**
- **Web-first researcher.** Uses paper.college on desktop and picks up the tablet app. Expects the same colours, cards, buttons and reader layout.
- **Tablet-only reader.** Reads PDFs in landscape or portrait, often with a stylus. Wants nothing but the paper on screen.

**Hard constraints from the brief:**
- Restyle only, with no new features.
- The web's top nav bar is not replicated.
- The theme is dark only, like the web (`<html class="dark">` in RPR `src/app/layout.tsx`).
- Web sizes are kept, with no forced 48dp touch-target enlargement.
- Android runs in sticky immersive mode on every screen.
- The smoothness rules in `design/specs/motion.md` §1 (60–120 fps) still apply.

### Reference conventions used below
- **px = Flutter logical px.** A CSS px on the web equals one logical px in the app.
- **Tailwind spacing:** 1 unit = 4 px (`px-3` = 12, `py-2` = 8, `gap-8` = 32). `rem` = 16 px.
- **RPR gray ramp is neutral (R=G=B):** gray-50 #fafafa … gray-800 #262626, gray-900 #171717, gray-950 #0a0a0a (`tailwind.config.ts`).
- **Dark accent:** indigo-400 `accent`, indigo-950 `accentSoft`, indigo-200 `accentInk`.
- **Role → class map (dark side of every `dark:` pair):**

| Role | RPR class | Value |
|---|---|---|
| `background` | `bg-gray-950` / `--background` | #0a0a0a |
| `surface` | `bg-gray-900` (`.card`, `.btn-secondary`, popovers) | #171717 |
| `surfaceHover` | `hover:bg-gray-800` | #262626 |
| `surfacePressed` | `active:bg-gray-700` (`.btn-ghost`) | #404040 |
| `border` | `border-gray-800` (`.card`, header, panels) | #262626 |
| `borderStrong` | `border-gray-700` (`.btn-secondary`, `.field-input`, citation popover) | #404040 |
| `textPrimary` | `text-gray-100` | #f5f5f5 |
| `textSecondary` | `text-gray-300` / `text-gray-200` | #d4d4d4 / #e5e5e5 |
| `textMuted` | `text-gray-400` | #a3a3a3 |
| `textSubtle` | `text-gray-500` | #737373 |
| `focusRing` | `ring-2 ring-accent ring-offset-2 ring-offset-gray-950` | — |

**Icons:** RPR ships **no icon package**. Every icon is an inline stroke SVG with `fill="none" stroke="currentColor" strokeLinecap/Join="round"`, in two families:
- **24-viewBox nav glyphs:** `strokeWidth 1.5`, drawn at `h-4 w-4` (16 px). Used in `DashboardSidebar` `NavIcon`.
- **20-viewBox chrome glyphs:** `strokeWidth 1.75`, drawn at `h-5 w-5` (20 px). Used for reader back, sidebar show/hide and close.

The app must render these exact paths as SVG/`CustomPainter` icons and must not use Material Symbols. design-ui owns the icon asset list; this file only says which glyph goes where.

---

## 1. Screen inventory

App routes are from `lib/app/routes.dart` and `lib/app/router.dart` (go_router 18):
- `/` redirects to `/library`.
- `/library` and `/settings` are branches of a `StatefulShellRoute.indexedStack` wrapped by `AppShell`.
- `/reader/:paperId` and `/sign-in` are full-screen routes **outside** the shell.
- `/sign-in` is pushed by `openSignIn()` and pops itself once signed in. It is absent in offline-only builds.

| # | App screen / surface | App route | App source (read-only) | Web route | Web source (RPR) | Notes |
|---|---|---|---|---|---|---|
| S1 | **Library** | `/library` | `features/library/library_screen.dart`, `library_widgets.dart` | `/library` | `app/(app)/library/page.tsx` → `LibraryCentrePapers`, `PapersTable`/`PaperTableRow`, `AddPaperDisclosure`, `ImportPaperForm`/`UploadPaperForm` (plus `DashboardSidebar`, `FeaturedPapersRow` and the Projects rail, which have no app equivalent; see §3.3) | The web also shows `/` (landing with dropzone) to first-time visitors. The app has no landing: an empty library uses the `_EmptyLibrary` state styled like the web's add-a-paper card. |
| S2 | **Reader**: header strip + view toolbar | `/reader/:paperId` | `features/reader/reader_screen.dart`, `widgets/reader_chrome.dart` (`ReaderToolbar`, `PageNavigator`, `ZoomControl`, `ToolModeSegmented`, `FindBar`, `ReturnPill`) | `/library/[paperId]` | `app/(app)/library/[paperId]/page.tsx` (header: back chevron, title, delete), `reader/PdfReaderLoader.tsx` (split layout), `reader/PdfReader.tsx` (sticky `role="toolbar"` zoom pill, PDF pages) | The web hides its global header here (`lib/nav/chrome.ts` `hidesAppHeader`), and so does the app (§2.5). |
| S2a | Reader › **highlight / selection popover** | (overlay) | `widgets/selection_popovers.dart` (`SelectionPopover`, `HighlightPicker`), `widgets/popover.dart` (`AnchoredPopover`, `PopoverSurface`, `PopoverBar`, `PopoverAction`, `HighlightSwatches`) | (overlay) | `PdfReader.tsx` `[data-selection-popover]` `role="dialog" aria-label="Highlight actions"`, anchored 8 px above the selection and clamped to ≥ 40 px from top | The web has one amber highlight. The app's extra hue swatches stay (existing feature) but are styled as web buttons. |
| S2b | Reader › **citation popover** | (overlay) | `widgets/citation_popover.dart` | (overlay) | `reader/CitationPopover.tsx` (`w-80 max-h-80 rounded-lg border-gray-700 bg-gray-900 p-4 shadow-xl`) | |
| S2c | Reader › **figure popover** | (overlay) | `widgets/figure_popover.dart` | (overlay) | `reader/FigureOverlay.tsx`, `FigureHighlightsPanel.tsx` | |
| S2d | Reader › **explanation popover** (compact only) | (overlay) | panel `explanation_tab.dart` cards inside the compact bottom sheet | (overlay) | `reader/FloatingExplanationPopover.tsx` (`w-[min(20rem,100vw-1rem)] max-h-[70vh] rounded-lg border-gray-800 bg-gray-950 shadow-xl`), shown on mobile OS only | On tablets (≥ 640 px wide) the app uses the docked panel like web desktop. Below 640 px the newest explanation card shows in this 320 px floating popover style. |
| S3 | Reader › **side panel**: tabs Notes · Highlights · Glossary · Explanation | (inside reader) | `features/panel/reader_side_panel.dart` (`ReaderSidePanel`, `PanelTabBar`), `notes_tab.dart`, `highlights_tab.dart`, `glossary_tab.dart`, `explanation_tab.dart`, `ai_states.dart`, `split_view.dart`, `panel_layout.dart` | (inside reader) | `PdfReaderLoader.tsx` `<aside aria-label="Explanations" class="w-96 border-l border-gray-800 bg-gray-950">` with a sticky `px-3 py-2` header and a hide button; body: `FigureHighlightsPanel` + `ExplanationSidebar` (newest-first `.card p-4` stack, `gap-3 p-4`) | **The web panel has no tabs**: it is one explanation stack, with figure highlights above it. The app's four tabs are an existing feature. They stay, restyled with the web's segmented/ghost-button language (M3, side-panel.md). Tab bodies reuse web components: Explanation = `ExplanationSidebar` cards; Highlights = `FigureHighlightsPanel` rows; Glossary = `GlossaryEntryCard`; Notes = `.card` + `.field-input`. |
| S4 | **Glossary** | none (only the panel tab, S3) | `features/panel/glossary_tab.dart` | `/projects/[projectId]` (glossary section). `/glossary` redirects to `/library`. | `glossary/GlossarySearch.tsx` (`field-input w-full`, tag chips `rounded-full px-2.5 py-1 text-xs`), `GlossaryEntryCard.tsx`, `TagChip.tsx`, `TermRating.tsx` | There is no standalone glossary screen in either product. glossary.md specs the glossary tab body using the web project-page glossary components. |
| S5 | **Settings** | `/settings` | `features/settings/settings_screen.dart` (Account, Appearance, Reader, Storage, Sync, About), `sign_out_dialog.dart`, `features/sync/sync_sheet.dart` | `/settings` | `app/(app)/settings/page.tsx` (`mx-auto max-w-3xl px-6 py-12 sm:py-16`, h1 `text-2xl font-semibold tracking-tight`, lede `text-sm text-gray-400`, sections `mt-6`), `settings/ProfileSettingsForm.tsx`, `BetaFeaturesToggle.tsx`, `ObsidianSettingsSection.tsx` | **Drop the Appearance › theme selector** (`ThemeSelector`): the web is dark-only. App-only sections (Reader, Storage, Sync, About) are restyled as web `.card` sections in the same column. |
| S6 | **Sign-in** | `/sign-in` (`?expired=1`) | `features/auth/sign_in_screen.dart`, `sign_in_prompt.dart` | `/sign-in` | `app/sign-in/page.tsx` (`mx-auto max-w-sm px-6 py-16 sm:py-24`), `auth/SignInForm.tsx` | The app's `_BrandPanel` (two-pane on wide screens) has no web counterpart. M3 decides in sign-in.md whether to hide it for parity; this file recommends hiding it (single `max-w-sm` column). |
| — | **Projects** | **none**: the app has no projects feature | — | `/projects/[projectId]` (`/projects` redirects to `/library`) | `projects/*`, library page right rail | Out of scope: restyle only, no new features. Not in the app chrome. |
| — | Sync status sheet / badge | (sheet) | `features/sync/sync_badge.dart`, `sync_sheet.dart` | none | — | Restyled as web chrome: the badge sits in the nav bar (§2) and the sheet is a `.card`-style dialog. No web counterpart. |

---

## 2. App navigation chrome

### 2.1 Decision: one slim **top bar** in both orientations, with no rail and no bottom bar

The bar is 48 px tall. It is a **different component** from the web header: the content is app destinations plus the sync badge, it uses sidebar-item styling, and it is shorter than the web header's ~61 px. It replaces today's `AppShell`:
- the compact `NavigationBar`;
- the 72 dp `NavigationRail`;
- the 240/256 dp sidebar.

**Why a top bar and not a left rail in landscape:**
1. **Width parity drives breakpoint parity.** The web's layout switches on **viewport width** (Tailwind min-width media queries). On a 1280×800 landscape tablet the web renders its `xl` layout, and the library grid is `13rem | 1fr | 18rem`.
   - A 56 px rail would leave 1224 px of content. Columns would then be 56 px narrower than the same web page at 1280 px, so they could not match pixel-for-pixel.
   - A top bar keeps the full 1280 px, so every column width and wrap point matches the web at the same width.
2. **Same eye path as the web.** The web's only chrome is a top header above a scrolling `<main>`, and the reader drops it entirely. A slim top bar keeps the page's first pixel row where the web user expects it, and it vanishes in the reader the same way.
3. **One component, two orientations.** A single bar needs no orientation-switching relayout, avoids the old hysteresis logic, and has nothing to animate on rotate. That fits the motion.md rule of no layout animation.
4. **The vertical cost is small and only on browse screens.** The bar takes 48 px out of 800 (6%) in landscape and 48 out of 1280 (3.75%) in portrait. Library and Settings scroll anyway, and the reader, where vertical space is the product, has no bar.

**Rejected alternatives:**
- A **landscape left rail** breaks width parity (point 1).
- A **portrait bottom bar** adds a second chrome position, puts nav where swipe-up reveals the system nav bar in immersive mode (gesture conflict), and does not exist on the web.

### 2.2 Anatomy (`AppNavBar`)

```
┌──────────────────────────────────────────────────────────────────────────────┐ ← viewPadding.top (cutout, portrait) — background only
│ [24] Paper   [16] [▦ Library] [4] [◯ Settings]               (sync)  Sign in [24] │  48 px
└──────────────────────────────────────────────────────────────────────────────┘ ← 1 px `border` (border-b border-gray-800)
```

| Part | Spec (logical px) | RPR source of the style |
|---|---|---|
| Bar | Height **48** + `viewPadding.top`. Background `background` (gray-950). Bottom hairline **1 px** `border` (gray-800). Row padding: left `24 + viewPadding.left`, right `24 + viewPadding.right` (`px-6`). Children vertically centred. Full window width, with no max-width container. | `header.border-b … dark:border-gray-800 dark:bg-gray-950`; `nav.px-6` |
| Wordmark | Text "Paper": `text-sm` (14/20), weight 600, `tracking-tight` (−0.025em = −0.35 px), `textPrimary` (gray-100), Geist. Tap goes to `/library` (same as the Library item). Focus ring: radius 6, 2 px `accent` ring. | root layout `Link href="/"` classes |
| Gap to items | **16** | — |
| Destination item | Height **36** (`py-2` 8 + 20 line). Padding **12** horizontal (`px-3`). Icon **16×16** + gap **12** (`gap-3`) + label `text-sm` (14/20) weight 500. Radius **6** (`rounded-md`). Gap between items **4** (`gap-1`). | `DashboardSidebar` item: `btn-ghost justify-start gap-3 px-3 py-2` + `NavIcon h-4 w-4` |
| Destinations | (1) **Library**: `papers` glyph (24-viewBox, path `M7 3h7l4 4v14H7z` + `M14 3v4h4`). (2) **Settings**: `profile` glyph (circle cx12 cy12 r3.5 at y8 + `M5 20a7 7 0 0 1 14 0`), the glyph the web uses for its "Profile" → `/settings` item. Offline-only builds show the same two items. | `NavIcon` paths |
| Spacer | Flexible. | — |
| Sync badge | Existing `SyncBadge` in icon form: **32×32** hit box, 16 px glyph, `textMuted`. Absent in offline-only builds. Restyled as a `btn-ghost` icon button (radius 6). | reader hide-panel button pattern `h-8 w-8 rounded-md` |
| Account slot | **Guest:** text link "Sign in" (`commonSignIn`) calling the existing `openSignIn()`. Style `navLinkClass`: padding 8 h / 4 v (`px-2 py-1`), `text-sm` weight 400, `textMuted` → hover `textPrimary`, radius 6, no background. **Signed in:** nothing, because Settings already holds the account. This relocates an existing entry point that is already in Settings and the sync sheet. It is not a new feature. | root layout `navLinkClass`, `HeaderAccount` |
| Gap badge ↔ account | **8** (`sm:gap-2`) | — |

### 2.3 Item states (destination items, sync button, wordmark, "Sign in")

| State | Destination item | Notes |
|---|---|---|
| Rest | Transparent background. Icon and label `textMuted` (gray-400). | `.btn-ghost` |
| Hover (mouse/stylus hover) | Background `surfaceHover` (gray-800). Text `textPrimary` (gray-100). | `dark:hover:bg-gray-800 dark:hover:text-gray-100` |
| Pressed | Background `surfacePressed` (gray-700). Text `textPrimary`. | `dark:active:bg-gray-700` |
| Focus-visible (keyboard) | 2 px `accent` ring, offset 2 px in `background` (draw as a 2 px gap then a 2 px ring), radius 6 + offset. Shown only for keyboard focus (`FocusHighlightMode.traditional`), never on touch. | `focus-visible:ring-2 ring-accent ring-offset-2 ring-offset-gray-950` |
| **Active (current branch)** | Background `accentSoft` (indigo-950). Icon and label `accentInk` (indigo-200). Hover and pressed keep the same colours. Semantics `selected: true`. | `bg-accent-soft text-accent-ink hover:bg-accent-soft` (`aria-current="page"`) |
| Disabled | Opacity 0.5 and no pointer. Not used today. | `disabled:opacity-50` |

- **Transitions:** colour only, **150 ms** `Curves.easeInOut` (Tailwind `transition-colors` default: 150 ms, cubic-bezier(0.4,0,0.2,1)). Use `PaperMotion.of(context, …)` so reduced motion means 0 ms. Nothing animates size, position or opacity.
- **No ripple/ink splash:** set `splashFactory: NoSplash.splashFactory`. The web has none.
- **No touch-target enlargement:** items stay 36 px tall, and the sync and account controls stay 32 / 28 px. Set `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap` and `visualDensity: VisualDensity.standard`, and use no `kMinInteractiveDimension` padding.

### 2.4 Narrow widths (< 640 px, e.g. split-screen multi-window or a phone)
- Below the Tailwind `sm` breakpoint, item labels hide. Items become **36×36** icon-only buttons with a tooltip and semantics label, which mirrors the web's `hidden … sm:flex` pattern.
- The wordmark and "Sign in" stay.
- The side padding stays 24, as the web keeps `px-6` at every width.

### 2.5 Behaviour per route
- **`/library`, `/settings`:** the bar is shown. Selecting the current item scrolls that branch to the top and resets it, as today (`goBranch(initialLocation: true)`).
- **`/reader/:paperId`:** **no app bar**, the same as the web's `hidesAppHeader`. The reader is already a route outside the shell; keep it that way.
  - The reader's own header strip is the only way out: back chevron (20 px glyph in a 28 px box `-m-1 p-1`), title `text-lg` weight 600 truncated, and delete. It is 1 px `border` bottom, `px-4 py-3`, `background`; full spec in reader.md.
  - On entry the bar is not animated away. The reader page transition (motion.md §2.1 fade-through curtain) covers it.
  - Reader "focus/immersive" UI hiding is out of scope.
- **`/sign-in`:** pushed over the shell **without** the bar (the bar lives in the shell). Top-left back button: 32×32 ghost icon button with the 20 px back-chevron glyph, at 16 px inset (+ cutout inset). It pops to the previous route.
- **Dialogs, sheets and popovers** sit above the bar. The bar is never dimmed separately: the modal barrier covers the whole window.
- **Keyboard:** the bar never moves with the IME. Only the body resizes (§4.6).
- **Semantics:** wrap the bar in `Semantics(container: true, explicitChildNodes: true)` named "App navigation" (role nav). Traversal order: wordmark → Library → Settings → sync → Sign in → page content.

### 2.6 What `AppShell` loses
- The `NavigationBar`, `NavigationRail` and extended sidebar.
- The `_SidebarHeader`.
- `ShellSyncBadge`, because the badge now always lives in the bar.

`_NotConfiguredStrip` (dev-only) stays, directly **below** the bar. Window-class hysteresis is no longer needed for the chrome. It may still be used by the reader panel.

---

## 3. Layout rules per orientation

### 3.1 Breakpoints: mirror Tailwind on window width

RPR uses Tailwind's default `screens` (the config doesn't override them). They are min-width and inclusive:

| Tailwind | min width | App rule |
|---|---|---|
| (base) | 0 | `width < 640` |
| `sm` | 640 | `640 ≤ width < 768` |
| `md` | 768 | `768 ≤ width < 1024` |
| `lg` | 1024 | `1024 ≤ width < 1280` |
| `xl` | 1280 | `1280 ≤ width < 1536` |
| `2xl` | 1536 | `width ≥ 1536` |

- **`width` is `MediaQuery.sizeOf(context).width`, the full window width.** Do not subtract `viewPadding` (cutout) or the chrome, because that is how CSS media queries behave.
- Compute it once per screen. With no hysteresis the result is deterministic and matches the web: the web flips at exactly these widths.
- Pick it up through a `WebBreakpoint.of(context)` helper. **design-ui/CTO** to name it; the existing `PaperWindowClass` (600/840/1200/1600) **must not** drive web-parity layouts, because its thresholds differ from Tailwind's.
- Container max-widths are Tailwind's: `max-w-sm` 384, `max-w-3xl` 768, `max-w-5xl` 1024, `max-w-7xl` 1280.

### 3.2 Target devices

| Orientation | Reference window | Breakpoint it mirrors | Content top |
|---|---|---|---|
| **Landscape** | ~1280×800 | **`xl`** (exactly at the threshold) | `48 + viewPadding.top` (usually 0 in landscape) |
| **Portrait** | ~800×1280 | **`md`** (768 ≤ 800 < 1024) | `48 + viewPadding.top` (cutout height if the device has one) |

**Caveat:** landscape tablets narrower than 1280 (for example 1194, 1180 or 1138) get the `lg` layout, exactly as the web would at that width. This is intended and gives parity per width, not per device. Screenshot comparisons must use the same viewport width on both sides.

### 3.3 Per-screen mapping

**S1 Library.** Web container: `mx-auto max-w-7xl px-6 py-10 sm:py-12`. Then h1 `text-2xl` and lede `mt-2 text-sm`. Then the grid `mt-8 gap-8`:
- base/sm/md: 1 column;
- `lg`: `13rem | minmax(0,1fr)`;
- `xl`: `13rem | 1fr | 18rem`.

The app has **no** dashboard sidebar (profile tile, Dashboard/Statistics/Profile items, progress donut), **no** featured-papers row and **no** projects rail. These are absent features, and the brief forbids adding them. The rule:

| | Landscape 1280 (`xl`) | Portrait 800 (`md`) |
|---|---|---|
| Container | width min(1280, window) − 48 side padding = **1232** content; top padding **48** (`sm:py-12`) | **752** content (800 − 48); top padding **48** |
| Grid | Only the **centre column** has app content, so it spans the full container: no empty 13rem/18rem columns and no fake placeholders. Search/sort (`_FilterRow`), import, and the papers list sit in this column in web order: add-a-paper card, then the table. | Single column, as on the web at `md`. |
| Papers list | Web `PapersTable`: `.card` containing a table, `min-w-[44rem]` (704). It fits both orientations, so there is no horizontal scroll. The app's `PaperRow` takes the table-row style; `PaperCard` grid mode is dropped (M3 decides in library.md). | 752 ≥ 704, so the full table fits. |

> Parity gap (flag to CEO/CMO, not decided here): at `lg`/`xl` the web library has a left sidebar and a right projects rail. Without them the app's centre column is wider than the web's (1232 vs ~672 px at 1280). Pixel parity of the library page is only possible for the header, the add-paper card and the table **styles**, not the column geometry, unless the brief is widened.

**S2 Reader** (no app bar). Web structure: header strip (`px-4 py-3 border-b`), then `flex` row: PDF pane `flex-1 overflow-y-auto bg-gray-950 px-6 py-6` | `aside w-96` (384) side panel `border-l`. The zoom toolbar is a `sticky top-0` centred pill (`rounded-md border px-2 py-1 gap-1.5 shadow-sm bg-gray-900`, `mb-4`).

| | Landscape 1280 (`xl`) | Portrait 800 (`md`) |
|---|---|---|
| Panel | **Docked split**, panel **384** wide (web `w-96`), left border 1 px `border`. PDF pane = 1280 − 384 − 1 = **895** minus 24+24 padding = 847 page width. The existing split drag handle may still resize (existing feature); default and reset width = 384. | **Docked split** like web desktop (the web docks at every desktop width and only floats on a mobile OS). Panel 384, PDF pane 415 − 48 = 367 page width, which is too narrow to read. **Rule:** at `< lg` (< 1024) the panel opens as an **overlay** sheet (384 wide, right-anchored, `background` fill, `border-l`, `shadow-xl`) over the PDF instead of splitting. The PDF viewport is never resized (motion.md P-rules). This is the app's existing overlay mode, restyled. |
| Panel hidden | The PDF pane takes the full width. A show-panel button sits at `top 12 right 12` (`absolute right-3 top-3`), **36×36**, `rounded-md border-gray-700 bg-gray-900 shadow-sm`, 20 px glyph. | Same. |
| Toolbar | One header strip row: back, title, then the app's `ToolModeSegmented`, `PageNavigator`, `ZoomControl` and panel toggle, in web control styles (`btn-secondary border-transparent px-2 py-1`, zoom % `text-xs tabular-nums min-w-12`). M3 decides whether zoom stays as the web's sticky pill (preferred for parity) or moves into the strip. | Same strip. If controls overflow at 800 (title truncates first, min title width 120), the overflow controls move into a `…` menu. |
| Popovers | Anchored. Citation popover 320×≤320. Selection popover 8 px above the selection, ≥ 40 px from the pane top. | Same. Popovers clamp to the PDF pane and keep **8** from its edges, plus the cutout inset (§4.4). |

**S3 Side panel.** The internal layout is the same in both orientations because the panel is always 384 wide:
- sticky header `px-3 py-2 border-b` holding the tab bar and the hide button (32×32);
- body `flex-col gap-3 p-4`;
- cards `.card p-4` (`rounded-lg`, 1 px `border`, `surface`).

Below 640 width (split-screen or phone), the panel becomes the existing bottom sheet, full width, with web card styles.

**S4 Glossary** (tab body). Search `field-input w-full`, then a tag-chip row `mt-3 gap-1.5` (chips `rounded-full px-2.5 py-1 text-xs`), then the entry cards stack. It is the same at any panel width.

**S5 Settings.** Web `mx-auto max-w-3xl px-6 py-12 sm:py-16`:

| | Landscape 1280 | Portrait 800 |
|---|---|---|
| Column | 768 max-width, centred (256 each side) | 752 (800 − 48 padding; under 768 + 48, so the padding governs) |
| Top padding | 64 (`sm:py-16`) | 64 |
| Sections | h1 `text-2xl`, lede `mt-2`, first section `mt-8`, then each section `mt-6` as a `.card` | Same |

**S6 Sign-in.** Web `mx-auto max-w-sm px-6 py-16 sm:py-24`. Single centred column **384** wide at both orientations, top padding **96** (`sm:py-24`), h1 `text-2xl`, form below. The column is not vertically centred; it top-aligns like the web. With the IME open, the column scrolls (§4.6).

---

## 4. Android full screen: sticky immersive, edge-to-edge, cutouts

The goals:
- The app owns every pixel.
- The status bar and navigation bar are hidden on **every** screen. An edge swipe shows them transiently, and they auto-hide.
- No interactive element or text is ever under a display cutout.

### 4.1 System UI mode

| Item | Spec |
|---|---|
| Mode | `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`. On Android this hides both bars, and a swipe from a bar edge shows them **transiently** (semi-transparent, overlaid). They auto-hide after ~3 s or on the next interaction. A swipe never exits immersive mode. |
| When to apply | (a) In `main()` after `WidgetsFlutterBinding.ensureInitialized()`, before `runApp`. (b) On every `AppLifecycleState.resumed` (an `AppLifecycleListener` at app root). (c) From `SystemChrome.setSystemUIChangeCallback`: if `systemOverlaysAreVisible == true` while the app is not transient-revealing (e.g. after an external activity), re-apply after **1 s** so a deliberate peek isn't cut short. (d) After the IME closes (§4.6). (e) After returning from platform UIs (file picker, OAuth Custom Tab/browser, share sheet, permission dialog), which is covered by (b). |
| Native backstop | In `MainActivity.onWindowFocusChanged(hasFocus = true)`, call `WindowCompat.getInsetsController(window, window.decorView)` with `.hide(WindowInsetsCompat.Type.systemBars())` and `.systemBarsBehavior = BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE`. This covers focus changes Flutter doesn't see (system dialogs, multi-window). It is idempotent with the Dart call. |
| Flutter in-app dialogs, sheets, menus | These stay in the same window, so the mode is unaffected and nothing needs to be done. Never use a platform `AlertDialog`. |
| Desktop (Windows/macOS) | No-op. Guard all calls with `defaultTargetPlatform == TargetPlatform.android`. |

### 4.2 Edge-to-edge and transparent bars

| Item | Spec |
|---|---|
| Overlay style | `SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent, systemNavigationBarDividerColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark, systemNavigationBarIconBrightness: Brightness.light, systemNavigationBarContrastEnforced: false, systemStatusBarContrastEnforced: false))`. Light icons suit the dark-only `background` when bars are transiently shown. Set this once at startup and also via `AppBarTheme.systemOverlayStyle` / `AnnotatedRegion` on each `Scaffold` so routes don't reset it. |
| Native | `MainActivity.onCreate` (before `super.onCreate`): `WindowCompat.setDecorFitsSystemWindows(window, false)`. This is the `enableEdgeToEdge` equivalent. `FlutterActivity` is not a `ComponentActivity`, so `androidx.activity.enableEdgeToEdge()` is unavailable unless the activity base changes. targetSdk 35 already forces edge-to-edge on Android 15+, and this makes API 24–34 match. |
| styles.xml (`values`, `values-night`, `values-v31`, `values-night-v31`) | **NormalTheme** (the running theme, which today lacks these): `android:windowLayoutInDisplayCutoutMode` = `shortEdges`, `android:windowDrawsSystemBarBackgrounds` = `true`, `android:statusBarColor` and `android:navigationBarColor` = `@android:color/transparent`, `android:enforceNavigationBarContrast` and `android:enforceStatusBarContrast` = `false` (API 29+, in `values-v29`/v31 variants). Add a **`values-v30`** (and `values-night-v30`) override with `windowLayoutInDisplayCutoutMode` = **`always`**, so long-edge cutouts in landscape don't letterbox. LaunchTheme already has `shortEdges`; mirror `always` there on v30+. |
| Window background | `NormalTheme` `windowBackground` = #0a0a0a (`background`) so any frame before Flutter paints is not white. |

### 4.3 Insets vocabulary (Flutter)
- **`MediaQuery.viewPaddingOf(context)`** is used for layout. In immersive mode its bar components are 0, and it **still contains the display-cutout** rectangle on the cutout's edge. It doesn't change when bars are transiently revealed: transient bars overlay and do not dispatch insets. So layout never jumps on a peek. Use it for all cutout-avoidance padding.
- **`MediaQuery.paddingOf`** is the same minus the IME. It is not used for chrome.
- **`MediaQuery.viewInsetsOf(context).bottom`** is the IME height (§4.6).
- **`MediaQuery.systemGestureInsetsOf(context)`** is the system back-gesture zones (left/right ~24–32 px). No app drag gesture may start inside these zones.
- Breakpoints use `MediaQuery.sizeOf` (§3.1), never the inset-reduced size.

### 4.4 Per-screen surface rules

**Rule of thumb:** *backgrounds bleed, content insets.*
- Fills, hairlines, the PDF backdrop and panel backgrounds extend under cutouts and bar areas.
- Text, icons, controls, popovers and the PDF page itself are inset by `viewPadding`.
- Do **not** wrap whole screens in `SafeArea`. That would leave unpainted or wrongly coloured strips; the current `SafeArea(...)` wrappers in `app_shell.dart`, `reader_screen.dart` and `sign_in_screen.dart` are replaced by explicit padding.

| Surface | Extends under cutout/bars | Inset by `viewPadding` |
|---|---|---|
| `Scaffold` background (all screens) | yes (`background` full-bleed) | — |
| App nav bar (§2) | Background + bottom hairline extend to top/left/right edges | Row content: top (bar is `48 + top`), left, right |
| Library / Settings scroll body | Scroll viewport full-bleed | Container gets `+left/+right` added to its `px-6`; last item gets `+bottom` padding (`viewPadding.bottom`, ≥ 0) so it can scroll clear of a bottom cutout or gesture handle |
| Reader header strip | Background + hairline full-bleed | Content: top, left, right |
| Reader PDF pane | `background` backdrop full-bleed | PDF page layer: left/right/bottom by viewPadding, in addition to the web `px-6 py-6`. Pages are **never** drawn under a cutout. Scrolling pages pass under the header strip only. |
| Reader zoom pill / `ReturnPill` / show-panel button / toasts | — | Positioned from the inset edge (e.g. show-panel `right: 12 + viewPadding.right`, `ReturnPill` `bottom: 32 + viewPadding.bottom`) |
| Side panel (split or overlay) | Background + `border-l` extend to top/right/bottom edges | Header and body content: top, right, bottom |
| Bottom sheet (< 640) | Fill to bottom/left/right edges | Content: left/right/bottom |
| Popovers (selection, citation, figure, explanation) | — | Clamp rect = PDF pane rect deflated by viewPadding + 8 px margin |
| Sign-in | Background full-bleed | Column: all sides; back button `16 + left/top` |
| Modal dialogs | Barrier full-bleed | Dialog box: `insetPadding` = web `p-4`-ish 16 + viewPadding |

**Cutout positions to test:**
- **Portrait:** top centre punch-hole/notch, which adds ~24–48 px to top inset. The nav bar and reader strip grow by that amount; the backgrounds fill it.
- **Landscape:** left or right edge (short edge). The cutout adds horizontal inset to whichever side it is on. Content shifts, the background doesn't, and breakpoints don't change (§3.1).
- **Rotation 180°:** the cutout moves sides; insets follow, with no special casing.

### 4.5 Edge gestures vs app gestures
- Sticky-immersive reveal uses the top and bottom edge swipes. Android back uses the left and right edge swipes (`systemGestureInsets`).
- The app must not start drags in those zones:
  - The split drag handle sits at the panel boundary, not the screen edge, so it is fine.
  - The overlay panel has **no** right-edge swipe-to-open. It opens with the toolbar button only.
  - Stylus input is exempt (pen events don't trigger system gestures).
- Do not set `systemGestureExclusionRects`. The user must always be able to reveal the bars and go back.

### 4.6 Keyboard (IME)
- **Screens with text fields resize** (`resizeToAvoidBottomInset: true`): sign-in, settings, the library import/rename dialogs and the library search field. The scroll body gains `viewInsets.bottom` and the focused field is scrolled into view by `Scrollable.ensureVisible`. The bar stays put.
- **The reader never resizes** (`resizeToAvoidBottomInset: false` on the reader `Scaffold`), per motion.md: the PDF viewport is never resized.
  - Fields inside the reader (find bar, notes composer, glossary search, rename) lift **only their own container** with `Padding(bottom: viewInsets.bottom)` inside the side panel or sheet. The find bar is in the header strip, so it doesn't need lifting.
  - This is a layout change of the panel only, so it does not affect the PDF RepaintBoundary.
- **IME and immersive:** opening the IME on Android may reveal the navigation bar while the IME is up. That is allowed. When `viewInsets.bottom` returns to 0 (observe it in a root `didChangeMetrics`), re-apply `immersiveSticky` after **300 ms**, once the IME close animation has finished.
- **IME insets are never added to `viewPadding`-based chrome padding.** Only bodies that hold the focused field consume them.

### 4.7 Edge states for the chrome itself
- **Bars transiently revealed:** nothing relayouts. The bars draw over the 48 px app bar or the reader strip for ~3 s; this is accepted and means no flash.
- **Multi-window or split-screen:** immersive may be ignored by the OS. Layout still uses `viewPadding`, which then contains real bar insets, so content is correctly inset. Breakpoints follow the reduced window width (§2.4, §3.1).
- **Resume from background, the OAuth browser or the file picker:** re-apply the mode (§4.1b), with no visible jump because layout doesn't depend on bar visibility.
- **Rotation:** one frame of relayout from the new size. No animated transition (motion.md).
- **Desktop builds:** no immersive mode, and insets are zero. The bar and layouts are unchanged.

---

## 5. Screens index

M3 writes the per-screen specs below. They don't exist yet. Each must follow the inventory (§1), the chrome (§2), the layout rules (§3), the inset rules (§4.4), and `design/specs/motion.md` §1.

| Screen | Spec file | App route | Web reference | Covers |
|---|---|---|---|---|
| Library | [library.md](library.md) | `/library` | `/library` (`LibraryCentrePapers`, `PapersTable`, `AddPaperDisclosure`) | Header, filter row, add/import, papers table, empty/loading/error/no-results, rename/delete dialogs, the §3.3 parity gap |
| Reader | [reader.md](reader.md) | `/reader/:paperId` | `/library/[paperId]` (`page.tsx` header, `PdfReaderLoader`, `PdfReader`) | Header strip, toolbar/zoom pill, PDF pane, selection/highlight, citation, figure and explanation popovers, loading/error/no-PDF states |
| Side panel | [side-panel.md](side-panel.md) | (in reader) | `PdfReaderLoader` `<aside w-96>`, `ExplanationSidebar`, `FigureHighlightsPanel` | Tab bar in web language, Notes/Highlights/Explanation tab bodies, split vs overlay vs sheet, AI offline/unavailable states |
| Glossary | [glossary.md](glossary.md) | (panel tab) | `GlossarySearch`, `GlossaryEntryCard`, `TagChip`, `TermRating` | Glossary tab body |
| Settings | [settings.md](settings.md) | `/settings` | `/settings` (`ProfileSettingsForm`, `ObsidianSettingsSection`) | Section cards, theme selector removed, sign-out dialog, sync sheet |
| Sign-in | [sign-in.md](sign-in.md) | `/sign-in` | `/sign-in` (`SignInForm`) | Form column, Google/email/magic-link states, expired-session banner, brand panel removal |

The previous app specs in `design/specs/screens/*.md` (old design system) are superseded for **visuals** by these files. Their flows, states and copy keys stay valid unless a web-parity file says otherwise.
