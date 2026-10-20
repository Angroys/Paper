# Paper app: hi-fi mockups

These are static SVGs drawn at 1× logical size (1 px = 1 dp). Colours come only from `design/tokens/paper-tokens.json`: semantic roles, palette ramps (for illustrations and PDF page content), highlight hues and reader-mark families. The one exception is the official multicolour Google "G" on the sign-in button, which Google's branding rules require. Type is Geist / Geist Mono with the fallback list `Geist, 'Segoe UI', 'SF Pro Text', Roboto, sans-serif`. Component anatomy, sizes and states are specified in [`../components.md`](../components.md).

PNG previews (rendered with resvg 2.6 and the bundled Geist static TTFs) are in [`png/`](./png/), about 1.1 MB in total.

| File | Window class / size | Theme | Shows |
| --- | --- | --- | --- |
| [`sign-in-expanded-dark.svg`](./sign-in-expanded-dark.svg) | `expanded`, 1194×834 (tablet landscape) | dark | Brand panel (5 cols) + form (7 cols, max 400), GoogleSignInButton, EmailSignInForm with the email field focused, links, legal footer |
| [`library-expanded-light.svg`](./library-expanded-light.svg) | `expanded`, 1194×834 | light | AppNavigationRail 72, LibraryHeader, search with shortcut chip, filter chips (All · Downloaded · Unread), sort, ImportProgressTile (adding), PaperCard grid with DownloadStateBadge states (available, downloading, cloud only, failed, pending upload, queued), DeleteUndoSnackbar (“Deleted “{title}”.” + Undo) |
| [`library-expanded-dark.svg`](./library-expanded-dark.svg) | `expanded`, 1194×834 | dark | The same screen **offline**: SyncBadge offline + count, import failed because offline (Try again disabled), cloud-only cards dimmed with `cloud_off`, keyboard focus ring on the first card |
| [`library-empty-medium-light.svg`](./library-empty-medium-light.svg) | `medium`, 800×1280 (tablet portrait) | light | EmptyState with the brand illustration and two import actions |
| [`reader-expanded-light.svg`](./reader-expanded-light.svg) | `expanded`, 1194×834 | light | ReaderToolbar 64 (touch): ToolModeSegmented, PageNavigator, ZoomControl, SyncBadge, panel toggle. PDF on the reader backdrop with yellow/green/blue highlights (multiply), an AI term mark, citation marks, a text selection with handles and the SelectionPopover (6 swatches + Explain / Note / Copy) |
| [`reader-split-large-dark.svg`](./reader-split-large-dark.svg) | `large`, 1440×900 (macOS laptop) | dark | Merged 52dp title row (traffic-light reserve, breadcrumb, SyncBadge short form “Synced”), CitationPopover on an active citation marker, SplitDragHandle, ReaderSidePanel 380 with PanelTabBar (Explanation selected, new-result dot on Glossary) and ExplanationCards: pending, complete (tags, analogy, definition, VisualAidPlayer, rating, re-explain) and error |
| [`reader-overlay-medium-light.svg`](./reader-overlay-medium-light.svg) | `medium`, 800×1280 (tablet portrait) | light | Overlay side sheet 360 over a scrim (the PDF does not resize). Notes tab with NoteCards: synced (“Edited 2 min ago”), device-local (“On this device only”), figure note waiting to sync, inline editing; composer “New note on page 4” |
| [`settings-large-light.svg`](./settings-large-light.svg) | `large`, 1440×900 (Windows laptop) | light | Custom 40dp title bar with caption buttons, AppSidebar 240 (SyncBadge long form, AccountChip), master list 280 (hover + selected), detail “Storage and offline”: StorageUsageBar, SettingsTiles (value + destructive), DownloadedPapersList (hover row, focused Remove button), Clear cache |
| [`sync-offline-states-board.svg`](./sync-offline-states-board.svg) | board, 1440×1040 | light + dark | SyncBadge: 5 states × 3 forms (icon + count, short pill, long row). OfflineBanner (sign-in offline banner, panel strip). AiOfflineState: queued card with “Explain when online”, and AI unavailable while online. DownloadStateBadge: all 7 states |

## Notes

- **System chrome:** Android status and gesture bars are drawn only on the portrait overlay mockup. macOS traffic lights are neutral placeholders because the OS draws them.
- **Copy:** every UI string is a value from the committed `design/copy/app_en.arb` (476 keys), with placeholders filled in; overlines are the uppercase form of their keys. Paper titles, PDF text, explanation prose, note bodies, tags, sizes, the account name and the citation metadata are sample content. Annotations on the states board (column headers, state ids) are not UI.
- **Motion:** the mockups are static. Motion is specified only in `../motion.md`, and `components.md` cites its catalog rows.
- **Highlights:** they are painted the way the app paints them: hue `wash` at the rest alpha 0.40 with `mix-blend-mode: multiply` under the text. The PDF page is white in both themes.
- **Regenerating PNGs:** in a scratch directory, `npm i @resvg/resvg-js@2.6.2`, download the Geist static TTFs (see `design/tokens/README.md` §2), and render each SVG with `new Resvg(svg, { font: { fontFiles, loadSystemFonts: false, defaultFontFamily: 'Geist' } })`.
