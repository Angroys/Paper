# Screen — Settings

**User goal:** Adjust how Paper looks and reads, control disk use and offline downloads, check sync, and manage my account — without hunting.
Anchor: RPR `settings/page.tsx` (profile display name/avatar, beta toggle, Obsidian pairing). Native v1 keeps Account; drops beta/Obsidian/pointer-tracking (web-only).

## Sections (order)
1. **Account** — avatar, display name, email (read-only), "Manage account on paper.college ↗", Sign out.
2. **Appearance** — Theme: System · Light · Dark · Sepia (`ThemeSelector`; app-wide — Sepia tints chrome warm-neutral and applies a page tint in the reader); "Keep notifications until dismissed" toggle.
3. **Reader** — Default zoom (Fit width · Fit page · Last used); Scroll direction (Vertical continuous · Horizontal paged); Panel style on tablets landscape (Split · Overlay); Auto-switch to Pen when stylus detected; Single-key shortcuts; Default highlight colour; Keep screen awake while reading (Android).
4. **Storage & offline** — `StorageUsageBar` (Paper downloads / cache / free); Auto-download new papers (Off · Wi-Fi only · Always); `DownloadedPapersList` (title, size, [Remove]); "Remove all downloads"; "Clear cache" (thumbnails & render cache, not user data).
5. **Sync** — status row (embeds `SyncBadge` long form + last synced time) [Sync now]; Sync on mobile data toggle; "Replaced versions" (count) → list; "How syncing works" (LWW explanation, `syncHowItWorksBody`).
6. **About** — version + build, What's new, Terms, Privacy, Open-source licences (Flutter `LicensePage`), Send feedback (mailto/web), Keyboard shortcuts (desktop).

## Wireframes

### fallback / compact — single column, sections as grouped lists; sub-pages push
```
┌──────────────────────────────┐
│ Settings                     │
│ ACCOUNT                      │
│ (A) Ana Popescu            › │
│ APPEARANCE                   │
│ Theme              System  › │
│ READER                       │
│ Default zoom     Fit width › │
│ Auto-switch to pen     [on]  │
│ STORAGE & OFFLINE            │
│ ▓▓▓▓▓░░░ 1.2 GB used       › │
│ SYNC                         │
│ ◎ Synced · 2 min ago  [Sync] │
│ ABOUT                        │
│ Version 1.0.0 (42)         › │
├──────────────────────────────┤
│   [Library]     [Settings]   │
└──────────────────────────────┘
```

### medium / expanded / large — master-detail
```
┌────┬───────────────────┬─────────────────────────────────────────────┐
│rail│ Settings          │ Storage & offline                           │
│/   │ ▸ Account         │ ▓▓▓▓▓▓░░░░░░  1.2 GB of 64 GB               │
│side│ ▸ Appearance      │   Downloads 1.0 GB · Cache 0.2 GB           │
│bar │ ▸ Reader          │ Auto-download new papers   [Wi-Fi only ▾]   │
│    │ ● Storage&offline │ Downloaded papers (12)                      │
│    │ ▸ Sync      ◎     │  Attention Is All You Need  2.1 MB [Remove] │
│    │ ▸ About           │  …                                          │
│    │                   │ [ Remove all downloads ]  [ Clear cache ]   │
└────┴───────────────────┴─────────────────────────────────────────────┘
```
Section list 280dp; detail max width 720dp. Selected section persisted. Deep-linkable (`/settings/sync` opened from SyncSheet "Settings").

## States
| Area | State | Behaviour |
| --- | --- | --- |
| Account | Offline | Name edit disabled with reason `settingsNeedsConnection`; sign-out still allowed (see below). |
| Account | Avatar load fail | Initials placeholder. |
| Sign out | Pending changes > 0 | `SignOutDialog` warns: `signOutPendingTitle` / `signOutPendingBody` ("{n} changes haven't synced and will be lost") → [Sync now and sign out] (primary when online) · [Sign out anyway] (destructive) · [Cancel]. No pending → simple confirm `signOutConfirmTitle`. Sign-out clears local DB + downloads for that account. |
| Storage | Computing size | Bar skeleton; values fill in. |
| Storage | No downloads | `storageNoDownloads` + hint how to download from library. |
| Storage | Remove all | Confirm `storageRemoveAllTitle` (non-destructive to library — states that papers stay in library). |
| Storage | Low disk (< 500 MB free) | Inline warning `storageLowDisk`; auto-download paused (`storageAutoDownloadPaused`). |
| Sync | All states | Mirror `sync-status.md`. [Sync now] disabled while syncing / offline (reason shown). |
| Replaced versions | Empty | `syncReplacedEmpty`. |
| Any toggle | Save | Applied instantly, persisted locally; no Save button. Preferences that sync across devices: theme? **No** — device-local in v1 (all settings are device-local except display name). |

## Components
`SettingsScreen`, `SettingsSection`, `SettingsTile`, `AccountChip`, `ThemeSelector`, `StorageUsageBar`, `DownloadedPapersList`, `SignOutDialog`, `SyncBadge`, `SyncSheet` (replaced versions list reused), `InlineError`, `ShortcutsDialog`.

## Microcopy keys
`settingsTitle`, `settingsSectionAccount`, `settingsSectionAppearance`, `settingsSectionReader`, `settingsSectionStorage`, `settingsSectionSync`, `settingsSectionAbout`, `settingsDisplayName`, `settingsEmail`, `settingsManageAccount`, `settingsSignOut`, `settingsNeedsConnection`, `signOutConfirmTitle`, `signOutConfirmBody`, `signOutPendingTitle`, `signOutPendingBody`, `signOutSyncFirst`, `signOutAnyway`, `settingsTheme`, `themeSystem`, `themeLight`, `themeDark`, `themeSepia`, `settingsPersistentNotifications`, `settingsDefaultZoom`, `zoomFitWidth`, `zoomFitPage`, `zoomLastUsed`, `settingsScrollDirection`, `scrollVertical`, `scrollHorizontal`, `settingsPanelStyle`, `panelStyleSplit`, `panelStyleOverlay`, `settingsAutoPen`, `settingsSingleKeyShortcuts`, `settingsDefaultHighlightColor`, `settingsKeepAwake`, `storageUsageLabel`, `storageDownloads`, `storageCache`, `storageFree`, `settingsAutoDownload`, `autoDownloadOff`, `autoDownloadWifi`, `autoDownloadAlways`, `storageDownloadedPapers`, `storageRemove`, `storageRemoveAll`, `storageRemoveAllTitle`, `storageRemoveAllBody`, `storageClearCache`, `storageCacheCleared`, `storageNoDownloads`, `storageLowDisk`, `storageAutoDownloadPaused`, `settingsSyncNow`, `settingsSyncMobileData`, `syncReplacedVersions`, `syncReplacedEmpty`, `syncHowItWorksTitle`, `syncHowItWorksBody`, `aboutVersion`, `aboutWhatsNew`, `aboutTerms`, `aboutPrivacy`, `aboutLicenses`, `aboutFeedback`, `aboutShortcuts`.

## Accessibility
- Each section heading = semantics header; master list is a navigation list with selected state.
- Toggles use switch semantics with the tile title as label; value changes announced.
- Destructive buttons (Sign out anyway, Remove all) never default-focused; dialogs focus Cancel first.
- Storage bar has text equivalents (not bar-only).
- Theme preview tiles labelled by name, not swatch.
