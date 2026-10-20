# Screen — Library

**User goal:** Find the paper I want to read (or add a new one) in seconds, and know which papers I can open offline.
Flows: [F3 Import](../flows.md#f3-import-paper-url--file), [F4 Open](../flows.md#f4-open--read--highlight), [F7 Delete](../flows.md#f7-delete-with-undo). Anchor: RPR `library/page.tsx` (PapersTable, PaperThumbnail, DeletePaperButton, ImportPaperForm, UploadPaperForm, ReadMeter).

## Regions
1. **Nav** (per class: bottom bar / rail / sidebar) with `SyncBadge`.
2. **LibraryHeader**: title "Library", `LibrarySearchField`, `ImportButton` (→ `ImportMenu`), sort menu (Recently opened · Recently added · Title A–Z), view toggle (grid / list; list is default on `expanded+` with pointer, grid on touch).
3. **Filter chips** (single row, scrollable): All · Downloaded · Unread. (`libraryFilterAll`, `libraryFilterDownloaded`, `libraryFilterUnread`)
4. **Import progress zone**: `ImportProgressTile`s pinned above the list.
5. **Content**: `PaperGrid` of `PaperCard` or `PaperList` of `PaperRow`.
6. **Transient**: `AppSnackbar` / `DeleteUndoSnackbar` bottom (above bottom bar on fallback).

## PaperCard anatomy
```
┌─────────────────────┐
│                     │  PaperThumbnail (first page, 3:4; placeholder = title initials block)
│     thumbnail       │
│                [⬇]  │  DownloadStateBadge (bottom-right of thumb)
├─────────────────────┤
│ Title, 2 lines max… │
│ Added 12 Oct · 34 pp│  meta (paperMetaAdded, paperMetaPages)
│ ▓▓▓▓░░░ 40%     [⋮] │  read-progress bar (from last page) + overflow
└─────────────────────┘
```
PaperRow (list): `[thumb 40×52] Title · meta | progress | DownloadStateBadge | updated | [⋮]`.

### DownloadStateBadge states
| State | Icon slot | Text (semantics) | Tap behaviour |
| --- | --- | --- | --- |
| `cloudOnly` | cloud outline | `downloadStateCloudOnly` | Opens reader if online; badge tap = download |
| `queued` | clock | `downloadStateQueued` | Tap = cancel |
| `downloading` | ring progress | `downloadStateDownloading` ({percent}) | Tap = cancel |
| `availableOffline` | check-in-circle | `downloadStateAvailable` | Context menu has "Remove download" |
| `failed` | warning | `downloadStateFailed` | Tap = retry |
| `pendingUpload` | arrow-up | `downloadStatePendingUpload` (offline-imported file not yet uploaded) | Opens SyncSheet |

When offline, `cloudOnly` cards render dimmed (structure: reduced emphasis, not hidden) with badge `cloud-off` and `downloadStateUnavailableOffline`; open → snackbar `readerUnavailableOffline`.

## Wireframes

### fallback (<600)
```
┌──────────────────────────────┐
│ Library              [◎ Sync]│ top app bar
│ [🔍 Search papers        ] │
│ (All)(Downloaded)(Unread)    │
│ ┌──────────┐ ┌──────────┐    │ 2-col grid
│ │ card     │ │ card     │    │
│ └──────────┘ └──────────┘    │
│ ┌──────────┐ ┌──────────┐    │
│                         [＋] │ FAB = Import
├──────────────────────────────┤
│   [Library]     [Settings]   │ bottom bar
└──────────────────────────────┘
```

### compact (600–839) / medium (840–1199)
```
┌────┬───────────────────────────────────────────────┐
│ ▣  │ Library                    [🔍 Search ⌘K ] [＋ Import ▾] │
│Lib │ (All)(Downloaded)(Unread)      Sort ▾  [▦|☰] │
│    │ ┌ ImportProgressTile: Importing arxiv.org/… ━━━━  [×] ┐ │
│ ⚙  │ ┌──────┐ ┌──────┐ ┌──────┐ (┌──────┐ medium)   │
│Set │ │ card │ │ card │ │ card │  │ card │          │
│    │ └──────┘ └──────┘ └──────┘  └──────┘          │
│    │                                               │
│ ◎  │                                               │ ← SyncBadge at rail bottom
└────┴───────────────────────────────────────────────┘
```
Grid: compact 3 columns (card min 168dp), medium 4–5 (card min 180dp). Auto-fill by min width.

### expanded / large (sidebar + list default)
```
┌─────────────┬──────────────────────────────────────────────────────────────┐
│ ●●●  Paper  │ Library                      [🔍 Search papers    ⌘K] [＋ Import ▾]│
│             │ (All)(Downloaded)(Unread)                 Sort ▾   [▦|☰]   │
│ ▣ Library   │ ┌──────────────────────────────────────────────────────────┐ │
│ ⚙ Settings  │ │ ▢ Title                    Pages  Progress  Offline  Opened │ │
│             │ ├──────────────────────────────────────────────────────────┤ │
│ ─────────── │ │ [t] Attention Is All You…   15    ▓▓░ 40%    ✓        2h  ⋮ │ │
│ ◎ Synced    │ │ [t] Diffusion Models …      34    ░░░ 0%     ☁        —   ⋮ │ │
│   2 min ago │ │ …                                                         │ │
│             │ └──────────────────────────────────────────────────────────┘ │
│ (A) Ana  ▾  │                                                              │
└─────────────┴──────────────────────────────────────────────────────────────┘
```
`large`: content max width 1440 centred; grid 6 columns if grid view.

## States

### Loading (first load, no cache)
Skeleton matching current view: 6–12 `SkeletonCard`/`SkeletonRow`; header is real and interactive (Import works). Static (no shimmer) when reduced motion. Subsequent loads render from local DB instantly; remote refresh is silent (SyncBadge shows syncing).

### Empty (no papers)
```
│            [ illustration slot ]           │
│            libraryEmptyTitle               │
│            libraryEmptyBody                │
│   [ Import from file ]  [ Paste a link ]   │
│   (desktop) libraryEmptyDropHint           │
```

### Search no-results
```
│  🔍  librarySearchNoResultsTitle ("No papers match '{query}'") │
│      librarySearchNoResultsBody                                │
│      [ Clear search ]                                          │
```
Search is local (title + filename + authors if available), as-you-type with 150ms debounce, result count announced (`librarySearchResultCount`).

### Filter empty
"Downloaded" with none: `libraryFilterDownloadedEmpty` + [Show all]. "Unread" none: `libraryFilterUnreadEmpty`.

### Offline
SyncBadge offline; OfflineBanner **not** shown at top (library fully works); Import menu "From URL" disabled with reason; cloud-only cards dimmed per above.

### Error
Initial remote fetch fails with no cache: `InlineError(libraryLoadFailedTitle, libraryLoadFailedBody)` [Retry]. With cache: show cache + SyncBadge error.

### Import in progress / failed
ImportProgressTile: `[icon] source label · status · progress · [Cancel]`; failure: reason + [Retry] [Dismiss].

### Rename
Inline edit on card title (list) or `RenameDialog` (grid / touch). Enter saves, Esc cancels. Empty title → `renameEmptyError`. Saved offline → pending sync.

### Selection mode (multi)
Tablet: long-press enters selection; desktop: Mod/Shift+click or checkbox column. Top bar becomes contextual: "{n} selected" (`librarySelectedCount`) · Download · Remove download · Delete · [×].

## Components
`AppShell`, `AppNavigationBar`/`AppNavigationRail`/`AppSidebar`, `SyncBadge`, `LibraryHeader`, `LibrarySearchField`, `ImportButton`, `ImportMenu`, `ImportUrlDialog`, `ImportProgressTile`, `PaperGrid`, `PaperList`, `PaperCard`, `PaperRow`, `PaperThumbnail`, `DownloadStateBadge`, `PaperContextMenu`, `RenameDialog`, `DeleteUndoSnackbar`, `EmptyState`, `SkeletonCard`, `SkeletonRow`, `NoResults`, `InlineError`, `AppSnackbar`, `CoachMark`.

## Microcopy keys
`libraryTitle`, `librarySearchHint`, `librarySearchClear`, `librarySearchResultCount`, `librarySearchNoResultsTitle`, `librarySearchNoResultsBody`, `libraryFilterAll`, `libraryFilterDownloaded`, `libraryFilterUnread`, `libraryFilterDownloadedEmpty`, `libraryFilterUnreadEmpty`, `libraryShowAll`, `librarySortLabel`, `librarySortRecentlyOpened`, `librarySortRecentlyAdded`, `librarySortTitle`, `libraryViewGrid`, `libraryViewList`, `libraryEmptyTitle`, `libraryEmptyBody`, `libraryEmptyDropHint`, `libraryLoadFailedTitle`, `libraryLoadFailedBody`, `librarySelectedCount`, `importButton`, `importFromUrl`, `importFromFile`, `importUrlDialogTitle`, `importUrlFieldLabel`, `importUrlClipboardSuggestion`, `importUrlSubmit`, `importUrlInvalid`, `importOfflineUrl`, `importInProgress`, `importUploading`, `importSuccess`, `importDuplicate`, `importOpenExisting`, `importUrlNotPdf`, `importUrlFetchFailed`, `importFileTooLarge`, `importFileInvalid`, `importUploadFailed`, `importBatchSummary`, `importCancel`, `importRetry`, `importDismiss`, `paperMetaAdded`, `paperMetaPages`, `paperReadProgress`, `paperPendingUpload`, `paperMenuOpen`, `paperMenuRename`, `paperMenuDownload`, `paperMenuRemoveDownload`, `paperMenuDelete`, `renameDialogTitle`, `renameSave`, `renameCancel`, `renameEmptyError`, `downloadStateCloudOnly`, `downloadStateQueued`, `downloadStateDownloading`, `downloadStateAvailable`, `downloadStateFailed`, `downloadStatePendingUpload`, `downloadStateUnavailableOffline`, `readerUnavailableOffline`, `libraryDeletedUndo`, `libraryDeletedManyUndo`, `libraryDeleteManyTitle`, `libraryDeleteManyBody`, `libraryDeleteConfirm`, `libraryDeleteFailed`, `undo`, `coachImportPaper`.

## Accessibility
- Landmarks: nav, header (`libraryTitle` heading level 1), main list.
- Grid is a semantics list; each card is one focusable node: "{title}, {pages} pages, {progress} read, {download state}". Overflow reachable via Tab within card and via context-menu key / Shift+F10.
- Arrow keys move focus within the grid (roving focus); Enter opens; F2/Return rename; Delete deletes.
- Download badge state change announced politely (only on completion/failure, not each percent).
- Undo snackbar: stays while focused/hovered; reachable by keyboard (`F6` cycles to snackbar region); duration ≥ 8s (WCAG 2.2.1 adjustable via "Keep notifications until dismissed" in Settings › Appearance).
- Dimmed offline cards keep full text contrast for the title; only the thumbnail is de-emphasised.
