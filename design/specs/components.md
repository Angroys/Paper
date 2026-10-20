# Paper app: component specs (hi-fi)

**Product:** Paper (paper.college) native client for Android tablets, Windows and macOS.
**Owner:** design-ui. **Consumes:** `design/tokens/*` (values), `layout-system.md` (component inventory, behaviour), `screens/*.md` (structure), `design/copy/app_en.arb` (strings).
**Mockups:** [`mockups/`](./mockups/README.md) shows these components in context.
**Motion authority:** [`motion.md`](./motion.md). This file never defines durations, curves or reduced-motion fallbacks; each component cites the motion.md §2.0 catalog row ("motion #n") that governs it.

Component names match the inventory in [`layout-system.md` §11](./layout-system.md#11-component-inventory) exactly. Window classes use the token names (`PaperWindowClass.*`). The spec files use the same names and ranges:

| `PaperWindowClass` | Width (dp) |
| --- | --- |
| `compact` | < 600 |
| `medium` | 600–839 |
| `expanded` | 840–1199 |
| `large` | 1200–1599 |
| `extraLarge` | ≥ 1600 |

---

## 0. Conventions

### 0.1 Notation

| Written as | Means (Dart) |
| --- | --- |
| `c.surface` | `Theme.of(context).extension<PaperColors>()!.surface` |
| `hl.fill(PaperHighlightColor.yellow)` | `PaperHighlightColors` extension (whitePaper in both app themes) |
| `sp.lg` | `PaperSpacing.lg` (4dp grid: xxs 2, xs 4, sm 8, md 12, lg 16, xl 24, xxl 32, xxxl 48, huge 64) |
| `r.md` | `PaperRadii.md` / `PaperRadii.borderMd` (xs 2, sm 4, md 6, lg 8, xl 12, xxl 16, full) |
| `t.titleSmall` | `Theme.of(context).textTheme.titleSmall` (Geist, see JSON `typography.scale`) |
| `PaperTypography.noteBody(c)` | Reader-specific styles (`explanationBody`, `explanationBodyCompact`, `popoverTitle`, `glossaryTerm`, `noteBody`, `pageIndicator`, `code`, `caption`) |
| `icon.md` | `PaperIconSize.md` (xs 14, sm 16, md 20, lg 24, xl 32) |
| `PaperChrome.*`, `PaperBreakpoints.*` | Fixed chrome and layout sizes added in this pass (see tokens README §3) |

### 0.2 Density

Density keys off **window class + last input kind** (`layout-system.md` §6), not platform.

| | Touch / stylus | Pointer + keyboard |
| --- | --- | --- |
| Min hit target | 48 × 48 (`PaperHitTarget.touchMin`) | 32 × 32 (`PaperHitTarget.pointerMin`) |
| Button / input height | 48 | 36 (32 in dense toolbars and popovers) |
| Icon button | 48 box, 20 icon | 32 box, 20 icon (18 in list rows) |
| List row | 56 (64 with subtitle) | 40 (52 with subtitle) |
| Reader toolbar | 64 (`compact`: 56) | 48 on `expanded`+ (`PaperChrome.readerToolbarHeight`) |
| Hover | none; never hide actions behind hover | required on every interactive element |
| Ripple | `InkRipple` | `NoSplash` (state fills only) |

### 0.3 Shared state recipe

Every interactive component resolves these states with `WidgetStateProperty`. Rows below are the defaults unless a component says otherwise.

| State | Visual | Motion |
| --- | --- | --- |
| default | as specified | — |
| hover (pointer) | fill → `c.surfaceVariant` (on a `surfaceVariant` base: `c.border` in light, `c.outlineVariant` in dark). Filled buttons → `c.primaryHover`. | motion #35 |
| pressed | touch: `InkRipple` in `c.textPrimary` @ 10%; pointer: background deepens to `c.border` (light) / `c.outlineVariant` (dark). Colour only, no scale | motion #37 |
| focus (keyboard only, focus-visible) | 2dp ring `c.focusRing`, 2dp offset, radius = component radius + 2. On the white PDF page use `c.focusRingOnPaper`. | motion #36 (none) |
| selected | fill `c.primarySoft`, content `c.onPrimarySoft`; plus a non-colour cue (check glyph, underline, weight 600) | motion #38 |
| disabled | 50% opacity on the whole control (`component.button.disabledOpacity`), no hover, cursor `basic`; keep a tooltip or semantics hint with the reason | — |
| loading | label stays, spinner (16dp, 2dp stroke, `currentColor`) replaces the leading icon; control is inert | looping indicator: motion.md §3.2 "Loops" |
| error | border / text `c.error`, helper text with `error` icon (16dp) under the field, on `errorSurface` when it is a block | — |
| offline | the control stays visible, is disabled with reason `aiNeedsConnection` / `settingsNeedsConnection` ("Needs a connection") in tooltip + semantics, and gets a 14dp `cloud_off` glyph where space allows | — |

Reduced motion: follow motion.md §3 (mapping rules and the per-row fallback column). That includes the in-app override Settings › Appearance › `settingsReduceMotion` (System / On).

### 0.4 Elevation

Flat by default (`elevation.level0/1`: border only). Only transient overlays get a shadow, and only in light: `PaperElevation.shadow2(brightness)` for menus, popovers and tooltips, `shadow3` for dialogs, sheets and snackbars. Dark uses the tonal step `c.surfaceRaised` (#262626) plus `c.border`. Never put a blurred shadow on a scrolling list item or a PDF page.

### 0.5 Icon set

**Recommendation: Material Symbols Rounded**, bundled with the [`material_symbols_icons`](https://pub.dev/packages/material_symbols_icons) package.

- **License:** Apache 2.0 (Google). The package ships the font as an asset, so nothing is fetched at runtime and icons work offline. Register the license through `LicenseRegistry` the same way as Geist (README §2).
- **Axes:** weight 400, grade 0, optical size 20 (pointer) / 24 (touch), fill 0. Use fill 1 only for the selected nav destination and filled rating stars.
- **Why not Lucide:** Lucide (ISC) has a good stroke style, but its Flutter ports lag the upstream set and have no fill axis for selected states. Material Symbols already covers every glyph below, including the cloud family that SyncBadge depends on.
- Use `Symbols.*_rounded` everywhere. Do not mix in Material Icons (`Icons.*`).

| Role | Symbol | Role | Symbol |
| --- | --- | --- | --- |
| Library | `library_books` | Settings | `settings` |
| Search | `search` | Add / import | `add` |
| Back | `arrow_back` | Close | `close` |
| Overflow | `more_vert` / `more_horiz` | Sort | `sort` |
| Grid / list view | `grid_view` / `view_list` | Panel toggle | `right_panel_open` / `right_panel_close` |
| Tool: select | `arrow_selector_tool` | Tool: highlight | `ink_highlighter` |
| Tool: pen | `stylus` | Tool: figure | `crop_free` (or `image_search`) |
| Eraser | `ink_eraser` | Explain | `auto_awesome` |
| Note | `sticky_note_2` | Copy | `content_copy` |
| Delete | `delete` | Open external | `open_in_new` |
| Zoom in / out | `add` / `remove` | Page prev / next | `chevron_left` / `chevron_right` |
| Synced | `cloud_done` | Syncing | `sync` (rotating) |
| Pending | `cloud_upload` | Offline | `cloud_off` |
| Sync error | `warning` | Download failed | `error` |
| Cloud only | `cloud` | Queued | `schedule` |
| Available offline | `check_circle` | Pending upload | `arrow_upward` |
| Device-local note | `devices` | Retry | `refresh` |
| Show password | `visibility` / `visibility_off` | Email link | `mail` |
| Account | `person` | Theme | `contrast` |
| Reader settings | `menu_book` | Storage | `download` |
| About | `info` | Shortcuts | `keyboard` |

The mockups draw simplified stand-ins for these glyphs, so match the symbol names, not the mockup paths. The Google "G" in `GoogleSignInButton` is Google's official asset, not an icon from this set.

---

## 1. Shell and navigation

### AppShell
- **Anatomy:** navigation (bar / rail / sidebar per class) + body. `extraLarge` caps Library/Settings content at `PaperBreakpoints.contentMaxWidth` (1440), centred.
- **Layout grid:** `PaperSpacing.columns / margin / gutter(windowClass)` = compact 4/16/8, medium 8/24/16, expanded 12/24/24, large 12/32/24, extraLarge 12/40/24.
- **Tokens:** body `c.background`; nav `c.surface` (rail) or `c.surfaceVariant` light / `c.surface` dark (sidebar).
- **Flutter:** `LayoutBuilder` → `PaperWindowClass.of(width)` with `PaperBreakpoints.hysteresis` (8dp); `Scaffold` + `Row`. Do not use `NavigationRail.extended`, because the sidebar has rows that the rail cannot draw (the SyncBadge long form and the AccountChip).

### WindowClass
Enum `PaperWindowClass` (in the tokens file). Helpers: `navigationWidth`, `usesNavigationRail`, `usesSidebar`, `sidePanelMode`, `sidePanelWidth`, `sidePanelMinWidth`, `sidePanelMaxFraction`, `sidePanelMaxWidth(w)`, `splitFallsBackToOverlay(w)`. Height rule (< 480dp → overlay panel, auto-hide toolbar) is app logic.

### AppNavigationBar (`compact`)
- **Size:** 64 high + `viewPadding.bottom`; 2 destinations; indicator 64×32 `r.full`.
- **Tokens:** bg `c.surface`, top border `c.border`; indicator `c.primarySoft`; icon `icon.lg` `c.onPrimarySoft` (selected, fill 1) / `c.textSecondary`; label `t.labelMedium` (selected 600 `c.textPrimary`).
- **States:** default, pressed (ripple), focus ring on the indicator, selected. No hover (touch class).
- **Flutter:** `NavigationBar` (themed by `PaperTheme`).

### AppNavigationRail (`medium`, `expanded`)
- **Anatomy:** brand mark 40 (top, 16 inset) · destinations (Library, Settings) · flexible space · `SyncBadge` (icon form, 48 box) pinned 16 from the bottom.
- **Size:** width 72 (`PaperBreakpoints.navRailWidth`); indicator 56×32 `r.full`; destination pitch 72; label `t.labelMedium` 12/16 below the icon.
- **Tokens:** bg `c.surface`, right border 1dp `c.border`; selected indicator `c.primarySoft` + icon `c.onPrimarySoft` + label weight 600 `c.textPrimary`; unselected icon and label `c.textSecondary`.
- **States:** default · hover (indicator area `c.surfaceVariant`) · pressed · focus (ring around the indicator) · selected. Disabled is not used.
- **Dark:** same roles; the mark's plate (#171717) blends into `c.surface`, which is intended (brand.md: dark plate by default).
- **Flutter:** `NavigationRail(labelType: NavigationRailLabelType.all, minWidth: 72)` with `leading:` mark and `trailing:` `Expanded(Align(bottom) SyncBadge)`.
- **Mockups:** library-expanded-*, library-empty-medium-light.

### AppSidebar (`large` 240, `extraLarge` 256)
- **Anatomy:** destination rows · divider · `SyncBadge` long form · flexible space · top border + `AccountChip` (64 high). On macOS the top 52dp is the title-bar row (the traffic lights sit over it); on Windows it sits under the 40dp custom title bar. Collapse toggle (`navCollapseSidebar`) in the header row → rail.
- **Size:** row 40 high, inset 12, radius `r.md`, icon `icon.md` at x 24, label x 56.
- **Tokens:** bg `c.surfaceVariant` (light) / `c.surface` (dark); right border `c.border`; selected row `c.primarySoft` + `c.onPrimarySoft` (label 600); unselected label `t.labelLarge` `c.textPrimary`, icon `c.textSecondary`. Secondary text on the light sidebar must be `c.textSecondary`, never `c.textMuted`: muted gray on `surfaceVariant` is 4.35:1, which fails AA for body text.
- **States:** default · hover (`c.border` fill in light, `c.surfaceVariant` in dark) · pressed · focus · selected.
- **Flutter:** custom `Column` of `ListTile`-like `InkWell` rows (a `NavigationDrawer` is modal-oriented; avoid it).
- **Mockup:** settings-large-light.

### DesktopTitleBar / CaptionButtons
- **macOS:** unified transparent title bar. 52dp row (`PaperChrome.macosTitleBarHeight`); keep 78×52 top-left clear for the traffic lights (inset 20, 18). In the reader the ReaderToolbar *is* this row and the back button starts at x 86 (`macosReaderBackX`). The mockup draws the traffic lights as neutral placeholders because the OS draws them.
- **Windows:** 40dp bar (48 when merged with the reader toolbar); app icon 20 + "Paper" `t.labelMedium` at left; `CaptionButtons` 46×32 each in a 138dp right reserve.
  - Caption buttons: icon strokes 1dp `c.textSecondary`, glyph 10dp. Hover fill `c.surfaceVariant`; close hover is the system red (`#C42B1C`, an OS convention, not a brand token) with a white glyph; pressed is 90% of the hover fill.
- **Tokens:** bg `c.surfaceVariant` (light Library/Settings) / `c.background` (dark, reader).
- **States:** drag region (no visual); double-click maximises (Windows) or zooms (macOS); caption hover, pressed and focus (focus via Alt+Space only).
- **Flutter:** `window_manager` (`TitleBarStyle.hidden`) + `DragToMoveArea`; macOS `macos_window_utils` for the full-size content view. Expose maximise as a native caption region for Snap Layouts.

### ShortcutsDialog
Dialog max width 560, padding `sp.xl`, radius `r.xl`. Search field (36 pointer) at top, then grouped two-column table: action `t.bodyMedium`, keys as `kbd` chips. Each chip is 20 high, radius `r.sm`, border `c.border`, fill `c.surfaceVariant`, `PaperTypography.code` 11/600 `c.textSecondary`. Esc closes. Flutter: `Dialog` + `ListView`.

### AccountChip
Avatar 32 (`r.full`, `c.primarySoft` with initials `t.labelMedium` 600 `c.onPrimarySoft`, or a network image with an initials fallback) + name `t.labelLarge` + email `t.bodySmall` `c.textSecondary` + `chevron_down`. Row 64; hover, pressed, focus as in §0.3. Opens a menu (Account settings, Sign out). Flutter: `MenuAnchor`.

---

## 2. Sync and connectivity

### SyncBadge (5 states, 3 forms)

Every state has its **own icon shape** and a text label, so state is never colour-only.

| State | Icon (Symbols) | Shape cue | Colour token | Short text (ARB) | Long text (ARB) | Count dot |
| --- | --- | --- | --- | --- | --- | --- |
| `synced` | `cloud_done` | cloud + check | `c.statusSynced` | `syncStateSynced` "Synced" | `syncLastSynced` "Synced · {relativeTime}" (`syncNeverSynced` before the first sync) | — |
| `syncing` | `sync` | two circular arrows (spin: motion #24) | `c.statusSyncing` | `syncStateSyncing` "Syncing…" | `syncProgress` "Syncing {done} of {total}" | — |
| `pending` | `cloud_upload` | cloud + up arrow | `c.statusSyncPending` | `syncStatePending` "Pending" | `syncPendingCount` "{n} changes waiting to sync" | yes |
| `offline` | `cloud_off` | cloud + slash | `c.statusOffline` (neutral, **not** an error) | `syncStateOffline` "Offline" | `syncPendingOffline` / `syncOfflineNoChanges` | yes when n > 0 |
| `error` | `warning` | triangle + ! | `c.statusSyncError` | `syncStateError` "Sync error" | `syncErrorSummary` / `syncAuthExpired` | yes (failed items) |

Priority when several states apply: error > offline > syncing > pending > synced. State changes crossfade (motion #23) after the 400ms `kSyncingMinVisible` debounce from motion.md §0.1.

**Forms**

| Form | Where | Anatomy | Size touch / pointer |
| --- | --- | --- | --- |
| **icon** | rail bottom, reader toolbar (64), `compact` app bar | icon `icon.md` in the state colour; count dot top-right | box 48 / 32 |
| **short** | reader toolbar on `large`+ with pointer (48) | pill: icon 18 + short text `t.labelMedium` (+ inline count for pending/offline/error) | h 28, padding 10/12, `r.full` |
| **long** | sidebar row, Settings › Sync row, SyncSheet header | icon 20 + long text `t.labelLarge` 13/500 `c.textPrimary`, wrapping to 2 lines max | row 56 / 48 |

- **Count dot:** 16 high pill (min width 16, padding 4), fill = state colour, text `t.labelSmall` 10/600 `c.onSecondary` (white in light, #171717 in dark), with a 2dp `c.surface` halo. Contrast 4.74–10.7:1 in both themes.
- **Pill fills:** `c.surfaceVariant` with text `c.textPrimary`. Error uses `c.errorSurface` + 1dp `c.errorBorder` + text `c.onErrorSurface`.
- **States:** default · hover (pill/box `c.surfaceVariant` → `c.border` in light) · pressed · focus ring · loading = `syncing` · error = `error` · offline = `offline`. Disabled is not used: the badge always opens `SyncSheet`.
- **Semantics:** button, label `syncBadgeSemantics` with the long text ("Sync status: Offline · 3 changes saved on this device. Opens details."). Announce politely only on the offline and error transitions and on user-triggered completion.
- **Dark:** status colours flip to the -400 hues (`#4ADE80`, `#818CF8`, `#FBBF24`, `#A3A3A3`, `#F87171`). All are ≥ 6:1 on `c.surface`.
- **Flutter:** `IconButton` / `TextButton.icon` wrapped in `Badge` (count), `Tooltip` with the long text on pointer. The rotation uses a `RotationTransition` on the icon only, inside a `RepaintBoundary`.
- **Mockups:** sync-offline-states-board (every state × form, light and dark).

### SyncSheet
- **Container:** anchored popover 360 wide on `large`+ (`r.xl`, `c.surfaceRaised`, `shadow2`); bottom sheet on `compact`/`medium` (top radius `r.xxl`, drag handle 32×4 `c.outlineVariant`).
- **Anatomy:** header row (SyncBadge long form + `syncNow` button, 32 pointer / 40 touch) · divider · pending list grouped by paper (rows 40 / 56, `t.bodyMedium`, type icon 16 `c.textSecondary`) · error block on `c.errorSurface` with Discard / Retry text buttons · nav rows "Replaced versions (n) ›", "How syncing works ›", "Sync settings ›".
- **States:** synced (no list), syncing (header progress text, `syncNow` loading), pending, offline (`syncNow` disabled with reason), error, auth expired (`syncAuthExpired` + primary button `syncSignInAgain`). Rows use `syncChangeHighlights` / `syncChangeNotes` / `syncChangeRename` / `syncChangeDelete` / `syncChangeReadingPosition` / `syncChangeUpload`, `syncAndMore`; error items `syncItemPaperDeleted` / `syncItemRejected` with `syncDiscard` / `syncKeepAsNewNote` / `syncRetry`; nav rows `syncReplacedVersions`, `syncHowItWorksTitle`, `syncSettingsLink`. Opens with motion #13 (popover) or #3 (sheet).
- **Flutter:** `MenuAnchor`-positioned `Material` (popover) / `showModalBottomSheet`.

### OfflineBanner
Two variants, both non-blocking and never modal:

| Variant | Use | Anatomy | Tokens |
| --- | --- | --- | --- |
| **banner** | sign-in status region (`authOfflineTitle` + `authOfflineBody`), scanned-PDF notice (`readerNoTextLayer`), any context that needs the network | 44 high (title 600 + body, wraps to 3 lines max), `r.lg`, icon `cloud_off` 20 + `t.bodyMedium` text; optional trailing text button | bg `c.surfaceVariant`, border `c.border`, icon `c.textSecondary`, text `c.textPrimary` |
| **strip** | top of the Glossary / Explanation tab bodies (`aiOfflineStrip`) | 36 high, full bleed, bottom border; icon 18 + `t.labelLarge` 13/500 | bg `c.surfaceVariant`, text `c.textSecondary` |

- The Library never shows the banner (it fully works offline); the SyncBadge carries the offline state there. When the connection returns, the banner or strip simply goes away and the SyncBadge shows `syncing`: there is no "back online" banner.
- **States:** shown / hidden only. Motion #25: opacity only, and the space it takes is inserted instantly. In the reader the strip lives inside the side panel, so the PDF viewport never changes size.
- **Semantics:** `liveRegion: true`, announced once.
- **Dark:** `c.surfaceVariant` #262626, text #F5F5F5 (13.9:1).
- **Flutter:** `Material` + `Row`, or `MaterialBanner` restyled. Use `AnimatedSwitcher` with a fade (no `AnimatedSize`, per motion #25).

### ConflictNotice
An `AppSnackbar` with `syncConflictSummary` and action `syncReview`. The Replaced versions list uses `SettingsTile`-style rows with two quoted versions (`syncReplacedYours` / `syncReplacedKept`) on `c.surfaceVariant` blocks (radius `r.md`) and buttons `syncRestoreMine` (outlined) / `syncDismiss` (text); footer `syncReplacedExpiry`; empty `syncReplacedEmpty`.

---

## 3. Library

### LibraryHeader
Title `libraryTitle` `t.headlineLarge` 24/32 (−0.6 tracking) · `LibrarySearchField` (340 wide on `expanded`+, full row on `compact`/`medium`) · `ImportButton`. The second row has filter chips `libraryFilterAll` · `libraryFilterDownloaded` · `libraryFilterUnread` (`FilterChip` h 32, `r.full`; selected `c.primarySoft` + check + 1dp `c.primary` border in light), the sort menu (`librarySortLabel`; options `librarySortRecentlyOpened` / `librarySortRecentlyAdded` / `librarySortTitle`; text button + `sort` icon + `chevron_down`) and the grid/list `SegmentedButton` (40 / 32 high, icons only, tooltips `libraryViewGrid` / `libraryViewList`). Grid ↔ list crossfades (motion #21); filter, sort and search results change instantly.

### LibrarySearchField
- **Size:** 48 touch / 36 pointer, radius `r.md`, padding 12, leading `search` 20 `c.textMuted`, trailing clear (`a11yClearText`) when it has text, and a shortcut hint chip "Ctrl K" / "⌘K" (pointer only; `kbd` chip style from ShortcutsDialog, text `c.textSecondary`).
- **Tokens:** fill `c.surface` (light) / `c.surfaceVariant` (dark); border 1dp `c.outlineVariant`; focus border 1.5dp `c.primary` + focus ring; hint `t.bodyLarge` `c.textMuted`.
- **States:** default · hover (border `c.outline`) · focus · disabled (empty library: enabled, but it returns `NoResults`) · loading (none: search is local).
- **Flutter:** `SearchBar` is too opinionated, so use `TextField` with the theme's `InputDecorationThemeData`.

### ImportButton / ImportMenu
Filled button "Add paper" (`importButton`) with `add` leading icon and `chevron_down` trailing, 48 / 36. The menu (`MenuAnchor`, `c.surfaceRaised`, `r.lg`, `shadow2`; motion #13) has two items: "From a file" (`importFromFile`, `file`) and "From a link" (`importFromUrl`, `link`), rows 48 / 36. Offline: the link item is disabled with `importOfflineUrl` as its subtitle. `compact` uses a FAB (56, `r.xl`, `c.primary`). First run: `CoachMark` with `coachImportPaper`.

### ImportUrlDialog
Dialog (max 560, `r.xl`, padding `sp.xl`, motion #15): title `importUrlDialogTitle` `t.headlineMedium`; URL field (label `importUrlFieldLabel`); clipboard suggestion chip (`importUrlClipboardSuggestion`); actions Cancel (`importCancel`, text) + Add (`importUrlSubmit`, filled; loading label `importInProgress`). Errors use the field error style (`importUrlInvalid`, `importUrlNotPdf`, `importUrlFetchFailed`, `importDuplicate` with action `importOpenExisting`).

### ImportProgressTile
- **Anatomy:** card (h 56, `r.lg`, `c.surface`, border) · leading 32 square `r.md` (`c.primarySoft` + `link`/`file` icon `c.onPrimarySoft`) · source `t.labelLarge` 14/500 · status `t.bodySmall` `c.textMuted` (`importInProgress` / `importUploading`) · progress 4dp (determinate when bytes are known, otherwise indeterminate, `c.primary` on `c.outlineVariant`) · Cancel text button.
- **States:** in progress · failed (leading `c.errorSurface` + `error` icon `c.error`, status = error string (`importUrlFetchFailed`, `importUploadFailed`, `importFileTooLarge`, `importFileInvalid`), actions `importRetry` (outlined) + `importDismiss` (text)) · offline (as failed, `importOfflineUrl`, Try again disabled until reconnect) · success (`importSuccess`; the tile crossfades into the new card, motion #20). Batch imports summarise with `importBatchSummary`.
- **Flutter:** `Card` + `ListTile` + `LinearProgressIndicator(minHeight: 4)`.
- **Mockups:** library-expanded-light (in progress), library-expanded-dark (offline failure).

### PaperGrid / PaperList
Grid: auto-fill by min card width (`medium` 168, `expanded` 180+, `extraLarge` 6 columns), gutter `PaperSpacing.gutter(class)`, row gap 24. List: `PaperRow`s in one bordered container. Use `SliverGrid` / `SliverList` with fixed item extents so scrolling never measures rows.

### PaperCard
- **Anatomy (top → bottom):**
  1. Card padding 8.
  2. Thumbnail bed (3:4, radius `r.sm`, `c.readerBackdrop` in light / `c.surfaceVariant` in dark) holding the `PaperThumbnail` sheet inset 6.
  3. `DownloadStateBadge` 28 at the bed's bottom-right, inset 6.
  4. Title, 2 lines max with an ellipsis, `t.titleSmall` 14/20 600. Always reserves 2 lines so the grid aligns.
  5. Meta `t.bodySmall` `c.textMuted`: "Added 12 Oct · 15 pages" (`paperMetaAdded` · `paperMetaPages`). A paper imported offline shows `paperPendingUpload` here instead.
  6. Progress row: 4dp bar (`c.primary`, `c.success` at 100%) + percent in `PaperTypography.pageIndicator` `c.textSecondary` (semantics `paperReadProgress`) + overflow `more_vert` (32 box; 48 hit on touch).
- **Size:** width from the grid (≈168–200); height ≈ 372 at 196 wide. Radius `r.lg`, border 1dp `c.border`, fill `c.surface`, no shadow.
- **States:**

| State | Visual |
| --- | --- |
| default | as above |
| hover (pointer) | fill `c.surfaceVariant` (motion #35); the overflow button is always visible |
| pressed | ripple (touch) / background deepen (pointer), motion #37 |
| focus | 2dp `c.focusRing` ring, offset 2, radius 10; overflow reachable with Tab |
| selected (multi-select) | 2dp `c.primary` border + 24dp check disc top-left (`c.primary` / `c.onPrimary`) |
| disabled | not used |
| loading | `SkeletonCard`; the real thumbnail fades in only if it wasn't cached (motion #22) |
| error | `DownloadStateBadge.failed`; title row unchanged |
| deleted | card fades and shrinks out, the grid reflows instantly (motion #19); Undo restores it in place (motion #20) |
| offline + cloud-only | thumbnail dimmed (sheet overlaid with `c.surface` @ 55%), badge `cloud_off`; **title and meta keep full contrast** (library.md a11y) |

- **Dark:** card `c.surface` #171717 on `c.background` #0A0A0A; the thumbnail page stays white (pdfPage), and the bed `c.surfaceVariant` frames it.
- **Semantics:** one node, `a11yPaperCard` ("{title}, {pages} pages, {progress}% read, {status}"); overflow labelled `a11yPaperMenu`.
- **Flutter:** `Card(clipBehavior: Clip.none)` + `InkWell` + `Column`. Wrap the thumbnail in a `RepaintBoundary`.
- **Mockups:** library-expanded-light / -dark.

### PaperRow (list, default on `large`+ with pointer)
- **Anatomy:** 28×36 thumbnail (`r.xs`, border) · title `t.labelLarge` 14/500 (1 line, ellipsis) · pages · progress bar 64 + % · `DownloadStateBadge` (20dp glyph, no disc) · opened (relative time) `t.bodySmall` `c.textMuted` · overflow.
- **Size:** 56 high (touch) / 44 (pointer); columns align with a sticky header row (`t.labelMedium` `c.textMuted`, 36 high).
- **States:** hover row `c.surfaceVariant` · focus ring inset 2 (radius `r.md`) · selected `c.primarySoft` row + checkbox column · pressed · offline dim as on PaperCard (thumbnail only).
- **Flutter:** `InkWell` + `Row` inside a `SliverFixedExtentList`.

### PaperThumbnail
First-page raster cached on disk (rendered once, ~2× display size). Placeholder while rendering or on failure: a `c.pdfPage` sheet with title initials (`t.titleLarge`, `c.textMuted`) and no spinner. Never re-rasterise on scroll.

### DownloadStateBadge
- **Anatomy:** 28dp disc (`c.surface` fill + 1dp `c.border`, so it reads on both the white thumbnail and dark beds) with an 18dp glyph. In `PaperRow` the glyph is used alone at 20dp.

| State | Glyph | Colour | Semantics (ARB) | Tap |
| --- | --- | --- | --- | --- |
| `cloudOnly` | `cloud` | `c.textSecondary` | `downloadStateCloudOnly` (action `paperMenuDownload`) | download |
| `queued` | `schedule` | `c.textSecondary` | `downloadStateQueued` | cancel |
| `downloading` | ring progress 2.5dp (`c.primary` on `c.outlineVariant`, determinate; value set directly, motion #46) | `c.primary` | `downloadStateDownloading` ("Downloading {percent}%") | cancel |
| `availableOffline` | `check_circle` | `c.success` | `downloadStateAvailable` | context menu (`paperMenuRemoveDownload`) |
| `failed` | `error` | `c.error` | `downloadStateFailed` | retry (`commonRetry`) |
| `pendingUpload` | `arrow_upward` | `c.warning` | `downloadStatePendingUpload` | opens SyncSheet |
| `unavailableOffline` | `cloud_off` | `c.textMuted` | `downloadStateUnavailableOffline` | snackbar `readerUnavailableOffline` |

- **States:** hover (disc → `c.surfaceVariant`), pressed, focus ring (radius full). It announces only completion and failure.
- **Dark:** disc `c.surface` #171717 with glyph colours from the dark roles; it reads as a dark puck on the white page.
- **Flutter:** `IconButton` with `CustomPaint` for the ring (`CircularProgressIndicator(value:, strokeWidth: 2.5)` also works).
- **Mockups:** sync-offline-states-board, library-expanded-*.

### PaperContextMenu
`MenuAnchor` (right-click / long-press / overflow). Items 48 / 36: `paperMenuOpen`, `paperMenuRename`, `paperMenuDownload` ↔ `paperMenuRemoveDownload`, divider, `paperMenuDelete` (text and icon `c.error`). Opens with motion #13. Container `c.surfaceRaised`, `r.lg`, padding 4, `shadow2` (light). Item hover `c.surfaceVariant`, radius `r.sm`; focus = hover fill + ring.

### RenameDialog
Dialog (motion #15) with a title field, prefilled and selected, title `renameDialogTitle`, actions `renameCancel` / `renameSave`. Empty → field error `renameEmptyError`, Save disabled. In list view on pointer, rename happens inline: the title cell becomes a 32-high field.

### DeleteUndoSnackbar
See `AppSnackbar` (§7). Message `libraryDeletedUndo` ("Deleted “{title}”.") / `libraryDeletedManyUndo`, action `undo`. Duration `kUndoSnackbarDuration` (8s for library deletes) from motion.md §0.1; it does not dismiss while hovered or focused. Multi-delete confirms first with `libraryDeleteManyTitle` / `libraryDeleteManyBody` / `libraryDeleteConfirm`; failure shows `libraryDeleteFailed`.

### EmptyState
- **Anatomy:** illustration slot (max 240×180; Library uses the brand motif: a white sheet with one indigo-highlighted line next to a dashed "drop" sheet) · title `t.headlineMedium` 20/28 `c.textPrimary`, centred · body `t.bodyLarge` `c.textSecondary`, max 400 wide · up to 2 actions (primary filled + secondary outlined, 48 / 36, gap 12).
- **Variants:** library (`libraryEmptyTitle` / `libraryEmptyBody`, actions `importFromFile` (filled) + `importFromUrl` (outlined), desktop hint `libraryEmptyDropHint`) · filter empty (`libraryFilterDownloadedEmpty` / `libraryFilterUnreadEmpty` + `libraryShowAll`) · notes (`notesEmptyTitle` / `notesEmptyBody`, pen variant `notesEmptyBodyPen`), glossary (`glossaryEmptyTitle` / `glossaryEmptyBody`) and explanation (`explanationEmptyTitle` / `explanationEmptyBody`) tabs, which have no illustration, just an icon 32 `c.textMuted` · load failure is `InlineError` (`libraryLoadFailedTitle` / `libraryLoadFailedBody`).
- **Drop target (desktop):** while dragging a PDF over the window, the dashed sheet becomes 2dp `c.primary` dashed and the whole content area gets a `c.primarySoft` wash.
- **Flutter:** `Center` + `ConstrainedBox(maxWidth: 400)` + `Column`.
- **Mockup:** library-empty-medium-light.

### SkeletonCard / SkeletonRow
- Same box geometry as PaperCard / PaperRow. Blocks are `c.surfaceVariant` (light) / `c.surfaceVariant` #262626 on `c.surface` (dark), radius `r.sm`: thumbnail block, two title bars (90% / 60%), meta bar 50%, progress bar.
- **Motion (motion #42):** **static**: no shimmer and no pulse. The skeleton appears only when the load takes longer than `kSkeletonDelay` (150ms). When content arrives it fades in over the skeleton's removal at `base` 200 (decelerate); under reduced motion it is an instant swap.
- **Semantics:** a single `a11yLoading` node for the list.
- **Flutter:** plain `ColoredBox` blocks in `c.surfaceVariant`; `AnimatedSwitcher` (fade, stack layout) keyed by loaded / not loaded.

### NoResults
`EmptyState` variant: `search` icon 32 `c.textMuted`, `librarySearchNoResultsTitle`, `librarySearchNoResultsBody` with the query, action text button `librarySearchClear`.

---

## 4. Reader

### ReaderScreen
Stack order follows `PaperLayer`: pdfPage 0 · highlightWash 2 · markInteractive 5 · citationHotspot 10 · selectionHandles 15 · readerChrome 20 · popover 30 · sidePanelOverlay 40 · toast 46 · dialog 50 · tooltip 60. On `expanded`+ the toolbar sits **above** the viewport. On `compact` / `medium` (auto-hide classes) it overlays the PDF, which keeps a constant top inset (motion #26). Either way the PDF rectangle never changes size because of chrome.

### ReaderToolbar
- **Anatomy (L → R):** back (`readerBack`) · title (`t.titleMedium` 16/600, 1 line, ellipsis; on `large`+ a breadcrumb "Library › {title}" with the "Library" link in `c.textSecondary`) · `ToolModeSegmented` · `PageNavigator` · `ZoomControl` · find (`readerFind`) · `SyncBadge` · panel toggle (`readerTogglePanel`, selected state when open) · overflow (`readerMore`: `paperMenuDownload` / `paperMenuRemoveDownload`, `paperMenuRename`, `readerPaperInfo`, `menuShortcuts`).
- **Height:** `PaperChrome.readerToolbarHeight(windowClass, pointer:)`: compact 56 · touch 64 · pointer 48 (`expanded`+). On macOS `large`+ it merges with the 52dp title-bar row and starts at x 86; on Windows it is the 48dp merged bar with caption buttons in the 138 right reserve.
- **Per class:** compact = back, title, overflow (tools move to `ToolDock`) · medium = adds segmented (icons), panel toggle; auto-hides · expanded = everything inline, persistent · large/extraLarge = pointer density, SyncBadge short form, segmented with labels on `extraLarge`.
- **Tokens:** bg `c.surface` (light) / `c.background` (dark), bottom border `c.border`, icons `icon.md` `c.textSecondary`, buttons 48 (touch) / 32 (pointer). Gap 8 between clusters, 16 around the segmented control.
- **States:** each control follows §0.3. Auto-hide (`compact`/`medium`) is motion #26: transform only, never a size change. At 200% text scale, controls overflow into the overflow menu from the right in this order: find, zoom, page navigator.
- **Dark:** toolbar `c.background` #0A0A0A matches the reader backdrop, so the white page is the only bright surface.
- **Flutter:** custom `Material` + `Row` (not `AppBar`; it needs a draggable title area and per-class content). Add `PreferredSize` for the Scaffold.
- **Mockups:** reader-expanded-light (64, touch), reader-split-large-dark (52, macOS pointer), reader-overlay-medium-light.

### ToolModeSegmented
- **Anatomy:** container `c.surfaceVariant`, `r.lg`, padding 2; 4 segments (Select / Highlight / Pen / Figure: `readerToolSelect`, `readerToolHighlight`, `readerToolPen`, `readerToolFigure`; `readerToolEraser` appears in the ToolDock and while a stylus is in use). The selected segment is a `c.surface` thumb with `r.md`, 1dp `c.border`, icon `c.primary` and label `c.textPrimary` 600.
- **Size:** 40 high (touch, 44-wide icon segments; the 48 hit target is met by the container padding plus toolbar height) / 32 high (pointer); labels (icon + 13/500 text) only on `extraLarge`.
- **States:** default · hover (unselected segment `c.border` fill in light / `c.outlineVariant` in dark) · pressed · focus (ring around the segment; arrow keys move within the radio group) · selected · disabled (Highlight on scanned PDFs: 50% + tooltip `readerNoTextLayer`).
- **Motion:** motion #38 (selected fill and thumb).
- **Semantics:** radio group; selected mode announced. Tooltips show the shortcut (V / H / P / F).
- **Flutter:** `SegmentedButton<ToolMode>(showSelectedIcon: false)` restyled, or a custom `Row` with an `AnimatedAlign` thumb.

### ToolDock (`compact`)
Floating pill 56 high, `r.full`, `c.surfaceRaised`, border, `shadow2` (light); centred 16 above `viewPadding.bottom`. Contents: the 4 tools + eraser + panel button, 48 boxes; selected tool = `c.primarySoft` circle 40. It hides with the toolbar on scroll (motion #26, same controller).

### PdfViewport
Backdrop `c.readerBackdrop` (#E5E5E5 light / #0A0A0A dark). Pages `c.pdfPage` (white in both themes) with a 1dp border `elevation.pdfPage.border`, no shadow, 16 gap between pages, centred. Text selection fill `LIGHT.selection.text` (indigo @ 30%) in **both** themes, because it always sits on white paper. Cursors: I-beam (select), crosshair (figure), custom pen cursor (pen).

### PageNavigator
`chevron_left` · page button "4 / 15" (visual form of `readerPageIndicator`, `PaperTypography.pageIndicator` 12/500 mono tabular, chip 72×28, `c.surfaceVariant`, `r.md`) · `chevron_right`. Button boxes 40 (touch) / 32 (pointer). Chevrons are disabled at the first and last page. On `compact`/`medium` it is a floating pill (`c.inverseSurface`, text `c.onInverseSurface`, 40 high, `r.full`, bottom-right 24 inset). Semantics `readerPageIndicator`; chevrons `readerPrevPage` / `readerNextPage`; tap → `readerGoToPage`. Page changes scroll per motion #32.

### PageJumpDialog
Small dialog (max 320, motion #15): title `readerPageJumpTitle`, numeric field (`readerPageJumpField`), error `readerPageOutOfRange`, actions `commonCancel` / `readerGoToPage`.

### ZoomControl
`remove` (`readerZoomOut`) · "125%" (`readerZoomLevel`, mono 13/500, 60 wide, tap → fit menu: `readerFitWidth`, `readerFitPage`, steps) · `add` (`readerZoomIn`). Boxes 40 / 32. The value is announced politely.

### FindBar
A 48 / 40 high bar that slides down from under the toolbar as an overlay (motion #27). It holds: field (`readerFind`) · count "3 of 17" (`readerFindResultCount`, mono, `c.textMuted`) · up/down · match-case toggle (`readerFindMatchCase`, selected = `c.primarySoft`) · close. Hint under the bar: `readerFindActOnMatch`. Matches use the `term` mark family wash; the current match uses the `active` alpha plus a ring. No results: count text `readerFindNoResults` in `c.error`.

### SelectionPopover
- **Anatomy:** container `c.surfaceRaised`, `r.xl`, 1dp `c.border`, `shadow2` (light) · 6 colour swatches in token order Yellow, Green, Blue, Pink, Purple, Orange (`PaperHighlightColor`, names `highlightColorYellow` … `highlightColorOrange`) · 1dp divider · Explain (`selectionExplain`, `auto_awesome` in `c.primary`, label `c.primary`) · Note (`selectionNote`) · Copy (`selectionCopy`, confirms with `selectionCopied`) · More (`selectionMore` → `selectionSearchWeb`, `selectionLookUpGlossary`).
- **Swatches:** disc 22 (touch) / 18 (pointer), fill = hue `wash`, 1.5dp ring = hue `ring` (≥ 3:1 on white). Hit box 36 wide inside a 48-high bar (touch) / 30 inside 40 (pointer). The last-used hue (the `H` default) shows a 16dp check in #171717.
- **Size:** 48 high touch / 40 pointer; action segments: padding 12, icon 20, gap 6, label 13/500.
- **Placement:** 16dp above the selection (it clears the touch handle knob), flips below when there is less than 56dp above, and is clamped 16dp inside the viewport. It never covers the selection.
- **States:** default · hover (segment `c.surfaceVariant`, `r.md`) · pressed · focus (ring per segment; Tab cycles; Esc closes and returns focus) · offline (Explain keeps working: it queues a card and shows a 14dp `cloud_off` glyph after the label, with tooltip `selectionExplainOffline`) · disabled (no text layer: Explain, Copy and swatches disabled) · loading (none: actions are optimistic).
- **Motion:** motion #9 (enter/exit) and #12 (hides while a handle is dragged and reappears on lift).
- **Dark:** container `c.surfaceRaised` #262626 + `c.border`, no shadow. Swatches are unchanged because they preview the multiply-on-white result.
- **Flutter:** `CompositedTransformFollower` in an `OverlayPortal` at layer 30; `Material(type: transparency)` + `Row` of `InkWell`s.
- **Mockup:** reader-expanded-light.

### HighlightPicker (on an existing highlight)
Same container and swatches as SelectionPopover. The **current colour shows a check glyph** (not just a ring); semantics `a11yColorSwatch` + `a11yColorSelected`. Actions: Note (`selectionNote`) · Explain (`selectionExplain`) · Delete (`highlightDelete`, `delete` + label in `c.error`; undo snackbar `highlightDeletedUndo`). Keys 1–6 pick colours in token order. Motion #11; colour change and delete repaint immediately (motion #30).

### HighlightMark
- **Text highlight:** per page and per hue, one `saveLayer` at the hue alpha (rest 0.40, hover 0.55, active 0.68), wash opaque inside, `BlendMode.multiply` (no stacking; tokens README §5). Corner radius 2 (`PaperHighlightColors.cornerRadius`).
- **States:** hover = 1.5dp ring (hue `ring`) on the overlay + note preview tooltip (motion #34; the wash alpha itself is never animated, motion.md §1.7) · pressed / selected (picker open) = ring · focus = 2dp `c.focusRingOnPaper` · created = appears in the commit frame (motion #29) · jumped-to = ring flash (motion #31). Semantics `a11yHighlight` (+ `a11yHighlightHasNote`), announcement `highlightAnnouncement`; save failure `highlightSaveFailed`.
- **AI marks** (`PaperReaderMark` term / citation / appendix / mention): rest wash 0.10; hover `full`; active `active` + 1.5dp ring; terms also get a 1dp dashed underline in `term.underline`.
- Dark theme: identical, because the page is white. The optional "night paper" mode switches to `PaperHighlightColors.darkPaper` (srcOver).

### InkLayer
Live stroke on its own layer (`RepaintBoundary`) at the pen input rate, `hl.ink(color)` at `stylusInk` alpha 0.45, width 14dp at 100% zoom (a constant height, pressure ignored). On lift it snaps to text runs in the next frame (motion #39). Semantics `a11yInkStroke`. The eraser cursor is a 16dp circle outline `c.textPrimary`.

### FigureSelectionBox
Dragged rectangle: 1.5dp dashed `c.focusRingOnPaper` (4/3 dash) + 8dp corner handles (white fill, 1.5dp indigo-600 stroke), outside area dimmed `c.scrim`. After release, a mini popover (SelectionPopover style) offers swatches, `figureSaveHighlight`, `figureAddNote`, `figureCancel` (box: motion #40). Semantics `a11yFigureHighlight`. A saved figure highlight is a 2dp hue `ring` border + hue wash at 0.10.

### CitationPopover
- **Anatomy:** container as SelectionPopover but **max width 360**, padding 12 / 14 / 12 / 18, and a 3dp `c.primary` accent bar on the left (`component.popover.accentBarWidth`) · overline "REFERENCE [3]" `PaperTypography.popoverTitle` (11/600, +0.44, `c.primary`) · title `t.titleSmall` (2–3 lines) · authors, year and venue `t.bodySmall` `c.textMuted` (paper metadata, not copy) · status line (16 icon + 12/500, when there is a status) · actions row (buttons 32 pointer / 40 touch): Add to library (filled, `citationImport`) + Open link (outlined, `open_in_new`, `citationOpenLink`) · divider · "Go to reference" row (`citationGoToReference`, target page in mono `c.textMuted`; shows the `readerBackToPage` pill after the jump, motion #28). Marker semantics `a11yCitationMarker`.
- **States:**

| State | Content |
| --- | --- |
| loading | overline + 3 static skeleton bars (`citationLoading` for semantics), no actions; swaps to content instantly (motion #10) |
| resolved (online) | as above |
| adding | Add button loading, label `importInProgress` |
| added / in library | status `citationImported` / `citationInLibrary` with `check_circle` `c.success`; primary action becomes `citationOpen` |
| error | `citationImportFailed` `c.error` + `commonRetry` |
| not found | raw reference text `t.bodySmall` + `citationNotFound`; only Go to reference |
| offline | `citationOfflineHint` with `cloud_off`; only Go to reference |

- **Marker:** the in-text marker shows the citation family `active` wash + 1.5dp ring while its popover is open.
- **Dark:** `c.surfaceRaised` #262626; overline `c.primary` #818CF8 (5.07:1); filled button `c.primary` / `c.onPrimary`.
- **Flutter:** `OverlayPortal` + `CompositedTransformFollower`, layer `popover`; semantics `dialog` labelled by the title; Esc returns focus to the marker.
- **Mockup:** reader-split-large-dark.

### NoteEditorInline
A popover (max 360) anchored to the highlight: multi-line field (`noteInlinePlaceholder`), `PaperTypography.noteBody` 15/24, min 3 lines, max 8 then scroll. Autosave status in the footer: `noteSaved`, or `syncLocalOnlyBadge` for device-local notes. Motion #13. There is no Save button; Esc or a tap outside commits.

### ReaderLoadingState / ReaderErrorState
- **Loading:** centred on the backdrop: title `t.titleMedium`, 4dp determinate bar 280 wide (motion #46), text `readerDownloading`, `commonCancel` text button. When cached, the first page appears instantly with no loader.
- **Error:** `EmptyState` layout on the backdrop with `error` icon 32 `c.error`, message `readerRenderFailed` (action `readerRedownload`) / `readerDownloadFailed` (action `commonRetry`) / `readerPaperDeleted` (action `readerBack`), secondary action `commonBack` (outlined).

### StylusModeHint
A `CoachMark` (§7) anchored to the Pen segment: `readerStylusHint`, actions `readerGotIt` / `readerStylusAutoSwitchOff`. First-highlight hints (`readerFirstHighlightHint`, `readerFirstHighlightHintPen`) use the same component. It is shown once.

---

## 5. Side panel

### ReaderSidePanel

| Class | Mode | Default / min / max | Container |
| --- | --- | --- | --- |
| `compact` | bottom sheet | full width; snaps 40% / 90% height | top radius `r.xxl`, drag handle 32×4 `c.outlineVariant`, scrim `c.scrim` |
| `medium` | overlay side sheet | 360 / 320 / 85% | full height from the right, `c.surface`, left border `c.border`, `shadow3` (light), scrim `c.scrim` over the PDF (PDF inert, does not resize) |
| `expanded` | split | 360 / 300 / 50% | `c.surface`, separated by `SplitDragHandle` |
| `large` | split | 380 / 300 / 50% | same |
| `extraLarge` | split | 420 / 320 / 45% (PDF ≥ 720) | same |

Values: `windowClass.sidePanelWidth / sidePanelMinWidth / sidePanelMaxWidth(windowWidth)`. If `splitFallsBackToOverlay(windowWidth)` is true, use the overlay container and show the hint `readerPanelOverlayHint` once (CoachMark, motion #47).

- **Anatomy:** `PanelTabBar` (48) · tab body (own scroll, padding 16, card gap 12) · Notes-only composer footer · optional `OfflineBanner.strip` under the tab bar on Glossary/Explanation.
- **Motion:** bottom sheet motion #3; overlay motion #4; split motion #5 (the panel slides in as an overlay, *then* the PDF commits to the narrower width in one frame; the reverse on close; detail in motion.md §2.3). Never tween the panel width.
- **Dark:** panel `c.surface` #171717 beside the #0A0A0A backdrop; cards inside use `c.surface` + `c.border`, or `c.surfaceVariant` blocks for emphasis.
- **Flutter:** split = `Row(Expanded(PdfViewport), SplitDragHandle, SizedBox(width: w, child: panel))`; overlay = `OverlayPortal` + `SlideTransition`; sheet = `DraggableScrollableSheet` in `showModalBottomSheet`.
- **Mockups:** reader-split-large-dark, reader-overlay-medium-light.

### PanelTabBar
- **Anatomy:** 3 text tabs (Notes / Glossary / Explanation: `panelTabNotes`, `panelTabGlossary`, `panelTabExplanation`) left-aligned with 12 horizontal padding, + close (`panelClose`) at the right (48 touch / 32 pointer).
- **Tokens:** label `t.labelLarge` 14 (selected 600 `c.textPrimary`, unselected 500 `c.textSecondary`); indicator 3dp `c.primary`, rounded, inset 8 under the label; bottom border `c.border`; new-result dot 7dp `c.primary` top-right of the label (semantics `panelTabNewResult`; motion #8).
- **States:** default · hover (label `c.textPrimary` + `c.surfaceVariant` pill behind the label) · pressed · focus (ring around the tab; ←/→ move) · selected (weight + indicator, not colour only) · disabled (not used).
- **Motion:** motion #7 (body fade + indicator slide).
- **Flutter:** `TabBar(isScrollable: true, tabAlignment: TabAlignment.start)` themed, or a custom `Row` (for the dot).

### SplitDragHandle
- **Visual:** 1dp divider `c.border` for the full height + grabber **24×48** centred vertically (`PaperChrome.splitGrabberWidth/Height`), `r.full`, fill `c.surfaceVariant`, 1dp `c.outlineVariant`, two 16dp grip lines 1.5dp `c.textMuted` 6dp apart.
- **Hit area:** 16 wide (pointer) / 24 wide (touch) over the divider (`splitHitWidthPointer/Touch`), extending into both panes.
- **States:**

| State | Visual |
| --- | --- |
| default | as above |
| hover (pointer) | grabber `c.primarySoft` + border `c.primary`, grips `c.onPrimarySoft`; cursor `SystemMouseCursors.resizeColumn`; divider becomes 2dp `c.primary` |
| pressed / dragging | as hover; divider 2dp `c.primary`; haptic tick on touch when snapping |
| focus | 2dp `c.focusRing` ring around the grabber; ←/→ 16dp, Shift 64dp, Home/End min/max |
| disabled | hidden when the panel is closed or in overlay mode |
| snap closed | dragging below `min − 48` (`PaperBreakpoints.sidePanelCloseSnap`) collapses the panel |

- **Semantics:** slider, label `readerPanelResizeLabel`, value = width %.
- **Flutter:** `MouseRegion` + `GestureDetector(onHorizontalDrag…)` + `Focus` with `Shortcuts`. The drag follows motion #6 and motion.md §1.5 (scale the live raster, re-rasterise on drag end); persist the width on drag end. Double-click resets to the class default.

### NoteCard / NotesList
- **Anatomy:** card (`c.surface`, border, `r.lg`, padding 16, gap 12) · header: page label `t.bodySmall` `c.textMuted` ("p. 3", mono, page metadata) + overflow (`commonEdit` / `noteJumpToHighlight` / `noteDelete`; undo `noteDeletedUndo`) · anchor: quote with a 3dp left bar in the **hue wash** colour, `t.bodyMedium` 13/20 `c.textSecondary`, max 2 lines (tap = jump), or for figure notes a 96×64 thumbnail with a 2dp hue ring + figure label · body `PaperTypography.noteBody` 15/24 `c.textPrimary` · footer: status glyph 16 + `t.bodySmall` `c.textMuted`.
- **Footer status:**

| Status | Glyph | Text |
| --- | --- | --- |
| synced | `check` `c.textMuted` | `notesEditedAgo` ("Edited 2 min ago"); `noteSaved` right after an edit |
| device-local (v1 text-highlight and free page notes) | `devices` `c.textMuted` | `syncLocalOnlyBadge` + tooltip `syncLocalOnlyExplainer` |
| pending | `cloud_upload` `c.statusSyncPending` | `notesPendingSync` |
| failed | `warning` `c.error` | `notesSyncFailed` + `syncRetry` |

- **States:** default · hover (card `c.surfaceVariant`; matching PDF highlight shows its hover ring) · pressed · focus ring (radius 10) · editing (body becomes an inline field: 1.5dp `c.primary` border, `r.md`, caret `c.primary`, autosave) · selected (jumped-to: the PDF highlight flashes, motion #31; hover outlines it, motion #33) · error (footer failed).
- **List:** `ListView` sorted by `notesSortPageOrder` (default) or `notesSortRecent`; empty → `EmptyState` (`notesEmptyTitle` / `notesEmptyBody`); load failure `notesLoadFailed`. Composer footer: divider, field `notesComposerPlaceholder` ("New note on page {page}") 48 / 36 + square filled add button (48 / 36, `add`).
- **Dark:** card #171717 inside the #171717 panel works through the `c.border` #262626 edge; the quote bar keeps the hue wash, which reads on dark.
- **Flutter:** `Card` + `Column`; inline editing with `TextField(maxLines: null)` and a debounce of 1s.
- **Mockup:** reader-overlay-medium-light.

### NoteEditor
Full-height editor inside the panel tab (split classes): back arrow + "Page n" header, `noteBody` field filling the panel, autosave footer as above, delete in the overflow.

### GlossaryList / GlossaryTermTile
- **GlossaryList:** filter field (`glossaryFilterHint`, 40 / 36). Scoped to the open paper (no cross-paper toggle in v1).
- **GlossaryTermTile anatomy:** row (min 56 touch / 48 pointer, padding 12/16): term `PaperTypography.glossaryTerm` 15/22 600 · page "p. 6" mono 12 `c.textMuted` · chevron (rotates 90° when expanded) · second line: tag chip(s) (22 high, `r.full`, `c.surfaceVariant`, 12/500 `c.textSecondary`) + 1-line summary `t.bodySmall` `c.textSecondary`. Expanded: the stored explanation in `explanationBodyCompact` 14/22 + "Explain again" text button (`glossaryExplainAgain`). A term with no saved explanation shows `glossaryNoCachedExplanation`.
- **States:** default · hover `c.surfaceVariant` · pressed · focus ring · expanded (selected: chevron rotated, bg `c.surfaceVariant`) · offline + uncached (expanded body shows `glossaryOfflineUncached` with `cloud_off`) · error (`glossaryLoadFailed` InlineError) · loading (SkeletonRow ×6, motion #42).
- **Motion:** motion #45: the body snaps open (height is not animated), fades in, and the chevron rotates.
- **Flutter:** `InkWell` + `Column` with `FadeTransition` + `RotationTransition`. Don't use the default `ExpansionTile` animation (it is a `SizeTransition`, which motion.md bans).

### ExplanationCard (mirrors RPR `SidebarEntry`)
- **Anatomy:** card `c.surface`, border `c.border`, `r.lg`, padding 16 · header: term `t.titleSmall` 14/600 + page link "p. 4" mono `c.primary` + `open_in_new` 16 (semantics `explanationJumpToPage`) · tags (22-high chips) · section overline `t.labelSmall` 11/600 +0.44 `c.textMuted` ("IN EVERYDAY TERMS" `explanationAnalogyHeading`, "PRECISE DEFINITION" `explanationFormalHeading`; the visual has no overline) · body `PaperTypography.explanationBody` 16/26 `c.textSecondary`, max 65ch · `VisualAidPlayer` · footer: rating 5 stars (22, filled `HL.yellow.wash` / outline `c.textMuted`) (semantics `explanationRateLabel`, `explanationRated`) + "Re-explain for this paper" text button (`explanationReexplain`, `refresh` icon, `c.primary`).

| State | Visual |
| --- | --- |
| pending | header + 6dp indeterminate bar (`c.primary` segment 1/3 on `c.outlineVariant` light / `c.surfaceVariant` dark, `r.full`) + `explanationPending` ("Explaining “{term}”…") `t.bodySmall` `c.textMuted`; semantics busy. Bar per motion #44 (static under reduced motion) |
| complete | full anatomy |
| re-explaining | previous text stays (opacity 0.6) + bar under the header + `explanationReexplaining`; on failure an inline `aiReexplainFailed` and the text returns to full |
| error | `c.errorSurface` + `c.errorBorder`; term in `c.onErrorSurface`; `error` 18 `c.error` + `aiExplainFailed` 14/500 `c.onErrorSurface` + `aiRetry` (destructive outlined, 32 / 40) |
| offline (queued) | dashed 1dp `c.outlineVariant` border, `cloud_off` + `aiOfflineCardTitle` / `aiOfflineCardBody`, toggle `aiExplainWhenOnline`; becomes pending on reconnect |
| cached while offline | complete card + caption `aiCachedExplanation`; rating and re-explain disabled with tooltip `aiNeedsConnection` |
| hover | border `c.outline`; PDF highlight ring shown (motion #33) |
| focus | 2dp ring radius 10 |
| new (arrived on an inactive tab) | tab dot only (motion #8); no card flash |

- **Motion:** motion #43: a new card fades in at the top and the cards below jump (no slide or size reveal). Pending → complete crossfades inside the card and the height snaps. Dedup moves the existing card to the top instantly.
- **Footer note:** `aiPoweredNote` once at the bottom of the stack, `t.bodySmall` `c.textMuted`.
- **Dark:** body `c.textSecondary` #D4D4D4 (12.1:1); error surface #450A0A with #FCA5A5 text (8.5:1).
- **Flutter:** `Card` + `Column`; the stack is a `SliverList` with a `FadeTransition` on the new item (not `AnimatedList`'s default insert).
- **Mockup:** reader-split-large-dark (pending, complete with visual, error).

### ExplanationStack
Newest-first `SliverList`, padding 16, gap 12; empty → `EmptyState` (`explanationEmptyTitle` / `explanationEmptyBody`). Footer note `aiPoweredNote`.

### VisualAidPlayer
16:9 frame, `r.md`, fill #0A0A0A (`gray.950`) in both themes (video), 1dp border `c.border`; centred play/pause button 44 (white disc, #171717 glyph, `aiVisualPlay` / `aiVisualPause`); 3dp scrubber at the bottom (`aiVisualSeek`; track `gray.700`, progress `c.primary`). States: loading (static frame placeholder, motion #42), error (falls back to the text explanation only; the frame is removed), offline (`aiVisualOffline`, no frame). Playback rules: motion #54.

### AiOfflineState
Panel-level block. Offline: the `aiOfflineStrip` strip (OfflineBanner) at the top of the Glossary / Explanation bodies, plus queued cards (`aiOfflineCardTitle` / `aiOfflineCardBody`). AI unavailable while online: a block that replaces the tab body, with `warning` 24 `c.textSecondary` + `aiUnavailableTitle` `t.titleSmall` + `aiUnavailableBody` `t.bodyMedium` `c.textSecondary` + `aiRetry`, max width 320, padding 16. The offline state has no retry button because it recovers by itself. Semantics: announced once. Mockup: sync-offline-states-board.

---

## 6. Auth and settings

### SignInScreen
`compact`/`medium`: single 400-wide column. `expanded`+: 5/7 columns (6/6 on `extraLarge`). The left brand panel (`c.surface`, `r.xl`, border) holds the brand motif: a white sheet with one indigo-highlighted line plus an explanation popover, and the `appName` mark in the panel corner. The brand panel is hidden when the window height is under 560. Form order: mark + "Paper" wordmark (`appName`, Geist 600, −0.01em) · `signInScreenHeading` `t.headlineLarge` (header semantics) · `signInTagline` `t.bodyMedium` `c.textSecondary` · status region · Google · "or" divider (`signInDividerOr`, `t.labelMedium` `c.textMuted`) · email form · links · footer `signInTerms` · `signInPrivacy` (`t.bodySmall` `c.textSecondary`) + `aboutVersion` (`c.textMuted`). State swaps (form ↔ browser wait ↔ check email) crossfade per motion #49. Mockup: sign-in-expanded-dark.

### GoogleSignInButton
- **Anatomy:** full-width (max 400) **neutral outlined** button: official multicolour Google "G" 20 + `signInGoogle` `t.labelLarge`, centred, gap 12. This follows Google's branding guidelines: the G keeps its own colours (the only non-token colours in the app), with a neutral fill and border.
- **Size:** 48 (touch and pointer: it is a primary auth action), `r.md`.
- **Tokens:** fill `c.surface`; border 1dp `c.outline` (#737373; 3.78:1 on dark surface, 4.74:1 on light); label `c.textPrimary`.
- **States:** default · hover (`c.surfaceVariant`) · pressed · focus ring · disabled (offline: 50%; the reason is the `authOfflineTitle` / `authOfflineBody` banner above) · loading (G replaced by a 16dp spinner, label `authSigningIn`) · error (button unchanged; `AuthErrorBanner` above shows `authGoogleCancelled` / `authGoogleFailed` / `authCodeExchangeFailed` / `authTimeout`).
- **Flutter:** `OutlinedButton.icon` with an `SvgPicture`/`Image` asset for the G (bundle `assets/brand/google_g.svg`).

### EmailSignInForm
- **Fields:** Email (label `signInEmailLabel`, autofill `email`) and Password (label `signInPasswordLabel`, autofill `password` / `newPassword`, trailing visibility toggle `authShowPassword` / `authHidePassword`). There are no placeholder hints; the persistent labels carry the meaning. Labels sit above the fields (persistent), `t.labelLarge` 14/500 `c.textPrimary`, gap 8.
- **Field spec:** 48 high (touch and pointer: the form is a primary action surface), `r.md`, padding 12, fill `c.surface` (light) / `c.surfaceVariant` (dark), border 1dp `c.outlineVariant`, focus 1.5dp `c.primary` + focus ring, text `t.bodyLarge` 15/400, hint `c.textMuted`, caret `c.primary`.
- **Submit:** filled full width 48, `signInSubmit` / `signUpSubmit`; loading `authSigningIn` with spinner; disabled offline.
- **Links:** `signInForgotPassword`, `signInMagicLink`, `signInCreateAccountPrompt` / `signInHaveAccountPrompt`. Text buttons in `c.primary` 14/500, 40 high hit.
- **States per field:** default · hover (border `c.outline`) · focus · filled · error (border 1.5dp `c.error`, helper row `error` 16 + 12/400 `c.error`: `authEmailInvalid`, `authPasswordRequired`; form-level `authInvalidCredentials`, `authNetworkError`, `authRateLimited` go in the AuthErrorBanner) · disabled/read-only while submitting (fill `c.surfaceVariant`, text `c.textSecondary`).
- **Flutter:** `Form` + `TextFormField` (theme `InputDecorationThemeData`), `AutofillGroup`.

### AuthBrowserWaitState / MagicLinkSentState / AuthErrorBanner
- **Wait:** 32dp spinner `c.primary`, `authBrowserWaitTitle` `t.titleLarge`, `authBrowserWaitBody`, actions `authReopenBrowser` (outlined) + `authCancel` (text); later hints `authBrowserReturnHint` and `authDeepLinkMissingHint` with action `authUseEmailInstead`.
- **Magic link:** `mail` 32 `c.primary` in a 56 `c.primarySoft` circle, `authCheckEmailTitle` (or `authConfirmEmailTitle`), `authCheckEmailBody` with the email in 600, `authResend` / `authResendCooldown` (countdown as text, mono digits), `authUseAnotherEmail`. Password reset confirms with `authResetSent`.
- **AuthErrorBanner:** `OfflineBanner` geometry on `c.errorSurface` + `c.errorBorder`, `error` icon `c.error`, text `c.onErrorSurface`, live region (motion #25). Session expiry uses `authSessionExpired`, with the email prefilled.

### SettingsScreen / SettingsSection / SettingsTile
- **Layout:** `compact`/`medium` = single grouped list; `expanded`+ = master list 280 (`c.surface`, right border) + detail max 720, inset 40.
- **Master rows:** 40 high, `r.md`, icon 20 + `t.labelLarge`; selected `c.primarySoft`/`c.onPrimarySoft` 600; hover `c.surfaceVariant`; the Sync row shows the SyncBadge icon form at the trailing edge.
- **SettingsSection:** overline `t.labelSmall` 11/600 +0.44 `c.textMuted` (on `c.background`, 4.54:1), then a group card (`c.surface`, border, `r.lg`) with tiles separated by inset dividers (16).
- **SettingsTile:** 52 (title only) / 64 (with subtitle) touch-and-pointer comfortable (pointer may use 44/56). Title `t.labelLarge` 14/500 `c.textPrimary`; subtitle `t.bodyMedium` 13 `c.textMuted` (on `c.surface`, 4.74:1). Trailing: `Switch` (44×24, on = `c.primary` track + `c.onPrimary` thumb with a check; off = `c.surfaceVariant` track + 1.5dp `c.outline` + `c.outline` thumb), value + chevron, a button, or nothing. Destructive tiles use title `c.error`.
- **States:** default · hover (tile `c.surfaceVariant`, clipped to the group radius) · pressed · focus (ring inset 2) · disabled (50% + subtitle reason `settingsNeedsConnection`) · selected (master list only) · loading (value replaced by a 12×80 skeleton bar).
- **Flutter:** `ListTile` / `SwitchListTile`. `PaperTheme` now ships `listTileTheme` (min height 52 touch / 44 pointer) and `switchTheme` with these colours.
- **Mockup:** settings-large-light.

### ThemeSelector
Three 120×88 preview tiles (`settingsTheme`: `themeSystem`, `themeLight`, `themeDark`). Switching themes is instant (motion #53). Each is a miniature with a `c.background` sample, a white page sliver and an indigo line, `r.lg`, 1dp `c.border`. Selected = 2dp `c.primary` border + a check disc 20 (`c.primary` / `c.onPrimary`) + label 600. Labels sit under the tiles (`t.labelMedium`). Radio-group semantics; arrow keys move.

### StorageUsageBar
Card: headline `storageUsageLabel` ("1.2 GB of 64 GB used") `t.titleMedium` 16/600 · 12dp bar `r.full`: Downloads `c.primary`, Cache `c.outline`, Free `c.outlineVariant` track · legend (`storageDownloads` / `storageCache` / `storageFree` + value; 10dp swatches + `t.bodyMedium` `c.textSecondary`). Text equivalents are always present. Computing → static bar skeleton (motion #42). Low disk → inline warning on `c.warningSurface` with `warning` `c.warning` (`storageLowDisk`, `storageAutoDownloadPaused`). Related tiles: `settingsAutoDownload` (`autoDownloadOff` / `autoDownloadWifi` / `autoDownloadAlways`), `storageRemoveAll` (destructive; confirm `storageRemoveAllTitle` / `storageRemoveAllBody`), `storageClearCache` (→ `storageCacheCleared`).

### DownloadedPapersList
Heading `storageDownloadedPapers`. Grouped card of 56-high rows: 28×36 thumbnail · title `t.labelLarge` ellipsis · size mono 13 `c.textMuted` · `storageRemove` outlined 32 (84 wide). Hover row `c.surfaceVariant`; keyboard focus ring on the button. Empty → `storageNoDownloads`.

### SignOutDialog
Dialog (motion #15): `signOutConfirmTitle` / `signOutConfirmBody`, or with pending changes `signOutPendingTitle` / `signOutPendingBody` (+ `signOutLocalOnlyBody` when device-local notes exist). Actions: `commonCancel` (text, **default focus**) · `signOutSyncFirst` (filled, when online with pending changes) · `signOutAnyway` (destructive outlined: `c.error` text + `c.errorBorder`).

---

## 7. Feedback

### AppSnackbar / DeleteUndoSnackbar
- **Anatomy:** container `c.inverseSurface`, `r.lg`, `shadow3` (light only), min 48 high (single line) / 68 (two lines), padding 16 · message `t.bodyMedium` `c.onInverseSurface` · optional action text button `t.labelLarge` 600 in `c.inversePrimary` (light #A5B4FC on #262626 = 7.6:1; dark #4F46E5 on #E5E5E5 = 5.0:1) · optional close.
- **Placement:** bottom-centre, 420 wide on desktop (`snackBarTheme.width`), full width minus margins on touch, 24 above the bottom (above the bottom bar on `compact`; above the ToolDock in the reader). Floating (`SnackBarBehavior.floating`).
- **Duration:** `kUndoSnackbarDuration` from motion.md §0.1 (5s highlight undo / 8s library delete); messages without an action use the same 5s. It pauses while hovered or focused; with Settings › `settingsPersistentNotifications` it stays until dismissed.
- **States:** default · action hover (`c.onInverseSurface` @ 8% fill) · action pressed · action focus (ring in `c.inversePrimary`) · stacked (a new snackbar replaces the old one; it never queues more than one).
- **DeleteUndoSnackbar:** message `libraryDeletedUndo` / `libraryDeletedManyUndo` / `noteDeletedUndo` / `highlightDeletedUndo` (also `highlightCreatedUndo`), action `undo`; Ctrl/Cmd+Z triggers the same undo. **ConflictNotice:** `syncConflictSummary` + `syncReview`.
- **Motion:** motion #16 (enter/exit), #17 (replace), #18 (no visible countdown).
- **Flutter:** the `SnackbarHost` overlay from motion #16, or `ScaffoldMessenger` with `SnackBarThemeData` from `PaperTheme` (floating) and the `snackBarAnimationStyle` given there. F6 cycles focus to it.
- **Mockup:** library-expanded-light.

### InlineError
Block on `c.errorSurface` + `c.errorBorder`, `r.lg`, padding 12/16: `error` 20 `c.error` · title `t.labelLarge` `c.onErrorSurface` · body `t.bodyMedium` `c.onErrorSurface` · Try again (`commonRetry`, destructive outlined 32 / 40). Field-level errors use the field error style instead.

### OnboardingCarousel / OnboardingPage
Full-screen on `compact`/`medium`; on `expanded`+ a 560-wide dialog. Illustration slot (brand motif), `onboardingReadTitle` / `onboardingExplainTitle` / `onboardingOfflineTitle` `t.headlineLarge` with the matching `*Body` in `t.bodyLarge` `c.textSecondary`, page dots (8dp, active = 24×8 pill `c.primary`, inactive `c.outlineVariant`, `onboardingPageIndicator` semantics), actions `onboardingSkip` (text) / `onboardingNext` → `onboardingGetStarted` (filled). Swipe or arrow keys (motion #48).

### CoachMark
Small popover (max 280) with a 3dp `c.primary` accent bar, body `t.bodyMedium`, 1–2 text actions (`readerGotIt` / `commonDone`), anchored with an 8dp caret to its target. Shown once per hint. Motion #47.

---

## 8. Contrast verification (WCAG 2.x, computed)

Every text-on-background pair used above. Body text ≥ 4.5:1; UI glyphs, focus rings and large text ≥ 3:1.

| Pair | Light | Dark |
| --- | --- | --- |
| textPrimary on background / surface / surfaceVariant | 17.18 / 17.93 / 16.44 | 18.16 / 16.44 / 13.88 |
| textSecondary on surface / surfaceVariant | 7.81 / 7.17 | 12.09 / 10.21 |
| textMuted on background / surface | 4.54 / 4.74 | 7.85 / 7.11 |
| textMuted on surfaceVariant | **4.35, captions/glyphs only** (use textSecondary for body text on the light sidebar and chips) | 6.00 |
| onPrimary on primary | 6.29 | 5.36 |
| primary (links, overlines) on background / surface / surfaceVariant / surfaceRaised | 6.02 / 6.29 / 5.77 / 6.29 | 6.64 / 6.01 / 5.07 / 5.07 |
| onPrimarySoft on primarySoft (selected nav, chips) | 10.22 | 10.72 |
| error on surface | 6.47 | 6.48 |
| onErrorSurface on errorSurface | 5.91 | 8.51 |
| success on surface | 5.02 | 10.29 |
| statusSyncPending glyph on surfaceVariant | 4.61 | 9.07 |
| statusOffline glyph on surface | 4.74 | 7.11 |
| onInverseSurface on inverseSurface (snackbar) | 14.50 | 14.23 |
| inversePrimary on inverseSurface (snackbar action) | 7.59 | 4.99 |
| count dot text (onSecondary) on pending / offline / error | 5.02 / 4.74 / 6.47 | 10.74 / 7.11 / 6.48 |
| focusRing on background / surface | 6.02 / 6.29 | 6.64 / 6.01 |
| outline (control borders) on surface | 4.74 | 3.78 |
| #171717 check on yellow swatch | 10.74 | 10.74 |

Highlight rings on white: yellow 3.19, green 3.30, blue 5.17, pink 4.60, purple 5.70, orange 3.56 (all ≥ 3:1). Verified with the WCAG relative-luminance formula; 0 failures.

---

## 9. Copy keys

Every key cited in this file exists in the committed `design/copy/app_en.arb` (476 keys), and the names match the screen specs (for example the highlight hues are `highlightColorYellow` … `highlightColorOrange`, in `PaperHighlightColor` order). I checked this with a script that extracts every backticked camelCase identifier with an ARB-style prefix from this file and looks it up in the ARB: **0 missing**. The mockups use only the ARB values. Paper titles, explanation prose, note bodies, tags, sizes and dates are sample content, not copy.
