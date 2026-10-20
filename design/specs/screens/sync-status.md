# Component screen — Sync status (SyncBadge + SyncSheet)

**User goal:** At a glance, know whether my work is safely saved to my account, and fix it in one step if it isn't.
Flow: [F6](../flows.md#f6-offline-edit--reconnect--sync-last-write-wins).

## Placement per window class
| Class | SyncBadge placement | Form | Opens |
| --- | --- | --- | --- |
| compact | Top app bar trailing (Library/Settings); reader overflow row | icon only (+ count dot) | `SyncSheet` as modal bottom sheet |
| medium / expanded | Rail bottom; reader toolbar (icon) | icon + count dot | `SyncSheet` as anchored popover (expanded) / bottom sheet (medium) |
| large / extraLarge | Sidebar row above account chip; reader toolbar (icon + short text) | icon + text "Synced · 2 min ago" | anchored popover (360dp) |

## States
| State | Icon slot | Short text key | Long text key | Live announce? | Action |
| --- | --- | --- | --- | --- | --- |
| `synced` | check-cloud | `syncStateSynced` | `syncLastSynced` ("Synced · {relativeTime}") | No (silent) | Open sheet |
| `syncing` | rotating arrows (static with reduced motion) | `syncStateSyncing` | `syncProgress` ("Syncing {done} of {total}") | Only if user triggered it | — |
| `pending` (online, waiting debounce) | cloud + count | `syncStatePending` | `syncPendingCount` ("{n} changes waiting to sync") | No | Sync now |
| `offline` | cloud-off (+ count when n>0) | `syncStateOffline` | `syncPendingOffline` ("Offline · {n} changes saved on this device") / `syncOfflineNoChanges` | Once on transition | — |
| `error` | warning | `syncStateError` | `syncErrorSummary` ("{n} changes couldn't sync") / `syncAuthExpired` | Yes (polite, once) | Retry · Details · (Sign in again) |

Priority when multiple apply: error > offline > syncing > pending > synced.
Transitions debounced: don't flash `syncing` for syncs < 400ms (stay on previous state then go to synced).

## SyncSheet wireframe
```
┌────────────────────────────────────────┐
│ ◎ Synced · 2 min ago            [Sync now]│
├────────────────────────────────────────┤
│ (pending/offline) 4 changes on this device│
│   • 2 highlights · Attention Is All…    │
│   • 1 note · Diffusion Models…          │
│   • 1 rename                             │
├────────────────────────────────────────┤
│ (error) 1 change couldn't sync           │
│   ⚠ Note on "softmax" — paper was deleted│
│     on another device  [Discard] [Retry] │
├────────────────────────────────────────┤
│ Replaced versions (2)                  › │
│ How syncing works                      › │
│ Sync settings                          › │
└────────────────────────────────────────┘
```
Pending list groups by type per paper; collapses beyond 5 rows ("and {n} more", `syncAndMore`).

## ConflictNotice (LWW)
- Trigger: after a sync where ≥ 1 local change lost to a newer server write.
- Snackbar (not modal): `syncConflictSummary` ("{n} of your offline edits were replaced by newer edits from another device") [Review].
- Review → "Replaced versions" list:
```
│ Note · Attention Is All You Need · p.4              │
│ Yours (offline): "key insight is…"   edited 10:02   │
│ Kept (newer):    "the key idea…"     edited 10:15   │
│ [ Restore mine ]  [ Dismiss ]                       │
```
- Restore mine creates a new write (now newest). Kept 30 days, then auto-purged (`syncReplacedExpiry`).
- Deleted-vs-edited: if the server deleted a row the user edited offline → item in error list with [Discard] or [Keep as new note] (for notes) — never auto-resurrect.

## Edge cases
- Clock skew: LWW uses server-assigned `updated_at` on accept, not device clock, for ordering final state; device time only orders the local outbox.
- Device-local data (highlight colours, text-highlight notes, free page notes, reading position — see [flows.md › Data-model gap](../flows.md#data-model-gap-highlight-colour-notes-edit-timestamps-needs-cto-decision)) never enters the outbox and never counts as pending.
- Very large outbox (> 500 ops): progress shown; app remains usable; sync runs in background isolate.
- Sign-out with pending: see settings.md `SignOutDialog`.
- Auth expired: error state with [Sign in again]; outbox retained across re-auth for the same user id only.

## Components
`SyncBadge`, `SyncSheet`, `ConflictNotice`, `AppSnackbar`, `OfflineBanner`.

## Microcopy keys
`syncStateSynced`, `syncStateSyncing`, `syncStatePending`, `syncStateOffline`, `syncStateError`, `syncLastSynced`, `syncNeverSynced`, `syncProgress`, `syncPendingCount`, `syncPendingOffline`, `syncOfflineNoChanges`, `syncErrorSummary`, `syncAuthExpired`, `syncSignInAgain`, `syncNow`, `syncRetry`, `syncDetails`, `syncDiscard`, `syncKeepAsNewNote`, `syncItemPaperDeleted`, `syncItemRejected`, `syncAndMore`, `syncChangeHighlights`, `syncChangeNotes`, `syncChangeRename`, `syncChangeDelete`, `syncChangeReadingPosition`, `syncChangeUpload`, `syncConflictSummary`, `syncReview`, `syncReplacedVersions`, `syncReplacedYours`, `syncReplacedKept`, `syncRestoreMine`, `syncDismiss`, `syncReplacedExpiry`, `syncHowItWorksTitle`, `syncHowItWorksBody`, `syncSettingsLink`, `syncBadgeSemantics`, `syncLocalOnlyBadge`, `syncLocalOnlyExplainer`.

## Accessibility
- SyncBadge is a button with full long-form label in semantics (`syncBadgeSemantics`: "Sync status: {long text}. Opens details"), even when visually icon-only.
- State is never colour-only: distinct icon shape per state + text.
- Announcements: offline transition (once), error (once), user-triggered sync completion. Background success is silent to avoid chatter.
- Sheet: focus moves to the header; Esc closes and returns focus to badge.
