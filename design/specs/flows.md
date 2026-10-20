# Paper app — Key user flows (UX spec)

**Fidelity:** flow diagrams (ASCII) + step tables. Structure only. Copy slots are camelCase ARB keys (design-copy fills strings).
Layout per window class: [layout-system.md](./layout-system.md). Screens: [screens/](./screens/).

Each flow states **one user goal** up front, then entry → steps → exit, every branch and failure path, and the states the user sees.

---

## F1. First run / onboarding

**Goal:** A new install understands in < 20s what Paper does (read, highlight, explain, works offline) and reaches sign-in without being forced through slides.

```
[Launch] → [Splash (native, ≤ 1 frame budget beyond engine init)]
   │
   ├─ session in secure storage & valid ─────────────► [Library]   (skip onboarding)
   ├─ session present but expired, online ──refresh──► [Library]
   │                                   └─ refresh fails ─► [Sign-in] + AuthErrorBanner(authSessionExpired)
   ├─ session present, OFFLINE ─────────────────────► [Library, offline] (cached data; SyncBadge=offline)
   └─ no session
        ├─ onboardingSeen = false → [OnboardingCarousel 3 pages] ──Skip/Done──► [Sign-in]
        └─ onboardingSeen = true  → [Sign-in]
```

| Step | Screen | Notes |
| --- | --- | --- |
| 1 | OnboardingPage 1 — "Read" | `onboardingReadTitle`, `onboardingReadBody` |
| 2 | OnboardingPage 2 — "Highlight & explain" (pen on tablets, mouse on desktop — illustration slot varies by `lastInputKind`) | `onboardingExplainTitle`, `onboardingExplainBody` |
| 3 | OnboardingPage 3 — "Works offline" | `onboardingOfflineTitle`, `onboardingOfflineBody` |
| CTA | Persistent "Skip" on every page; "Get started" on page 3 | `onboardingSkip`, `onboardingNext`, `onboardingGetStarted` |

- Swipe / arrow keys / PageDown advance; page indicator is a semantics `"Page {n} of 3"` (`onboardingPageIndicator`).
- On `expanded+` the carousel is a single centred card (max 560dp), not full-bleed.
- **Offline on first run with no session:** carousel works; Sign-in shows OfflineBanner (`authOfflineTitle`) and disables buttons with reason (not hidden).
- After first successful sign-in, a single CoachMark on the Import button (`coachImportPaper`) — dismissible, never repeats.
- No permissions are requested during onboarding (file picker permission is just-in-time at import).

---

## F2. Sign-in

**Goal:** Get into my existing paper.college account (or create one) in as few steps as possible, and always know what to do if it fails.

### F2a. Google via system browser + deep link

```
[Sign-in] ─tap "Continue with Google"─► [AuthBrowserWaitState]
     │                                     │ app opens system browser (Custom Tab on Android,
     │                                     │ default browser on Win/macOS) to Supabase OAuth URL
     │                                     │ with PKCE + redirect paper://auth-callback
     │                                     ▼
     │                            user completes Google consent in browser
     │                                     │
     │          ┌──────────────────────────┼──────────────────────────────┐
     │          ▼                          ▼                              ▼
     │  deep link paper://auth-callback   user closes browser /          deep link with ?error=
     │  ?code=… received                  returns to app w/o completing   (access_denied etc.)
     │          │                          │                              │
     │  exchange code → session            wait state stays; after        [Sign-in] + AuthErrorBanner
     │          │                          app regains focus 2s with no   (authGoogleCancelled /
     │   ┌──────┴──────┐                   callback → show "Didn't finish? authGoogleFailed) + Retry
     │   ▼             ▼                   Try again / Use email"
     │ success     exchange fails          (authBrowserReturnHint)
     │   │         (network / stale code)
     │   ▼             ▼
     │ [Library]  [Sign-in] + AuthErrorBanner(authCodeExchangeFailed) + Retry
     │ (initial sync starts; library skeleton until first page arrives)
```

AuthBrowserWaitState content: spinner, `authBrowserWaitTitle` ("Finish signing in in your browser"), `authBrowserWaitBody`, buttons **Reopen browser** (`authReopenBrowser`) and **Cancel** (`authCancel`). Cancel returns to Sign-in with no error.

Edge cases
- Deep link arrives when app was killed: cold start parses the initial link before routing; splash holds until exchange resolves (max 10s, then error state `authTimeout`).
- Deep link arrives for an already signed-in user: ignored, toast `authAlreadySignedIn`.
- Windows/macOS: protocol `paper://` registered at install; if registration missing (portable zip), wait state shows fallback after 30s: `authDeepLinkMissingHint` with "Use email instead".
- Offline: button disabled, inline reason `authOfflineBody`.

### F2b. Email

Default: **email + password** (matches RPR web) with tab/toggle to **magic link**.

```
[Sign-in] → EmailSignInForm (email, password) ─Submit─►
    ├─ valid → [Library]
    ├─ invalid credentials → inline field error authInvalidCredentials (focus to password, value kept)
    ├─ email not confirmed → MagicLinkSentState variant authConfirmEmailTitle + Resend (cooldown 60s)
    ├─ network error → AuthErrorBanner authNetworkError + Retry
    └─ rate limited → authRateLimited (shows wait seconds)

"Create account" → same form, mode=signUp → authCheckEmailTitle (confirmation link opens paper://auth-callback)
"Forgot password?" → email only → authResetSent (reset done on web; link to paper.college)
"Email me a sign-in link" → MagicLinkSentState → deep link → [Library]
```

Validation: client-side email format on blur, not per keystroke; Submit enabled when both non-empty. Password field has show/hide toggle (`authShowPassword`/`authHidePassword`). Enter submits.

---

## F3. Import paper (URL / file)

**Goal:** Get a paper into my library from a link or a file on this device, and know when it's ready to read.

```
[Library] ─Import (button / Mod+O / Mod+Shift+O / drag-drop file on desktop)─► ImportMenu
     ├─ "From URL"  → ImportUrlDialog
     │      ├─ paste URL (auto-filled if clipboard holds an http(s) URL — shown as suggestion chip, never auto-submitted)
     │      ├─ invalid URL → inline importUrlInvalid
     │      └─ Submit → dialog closes → ImportProgressTile at top of list ("Importing…")
     │              ├─ success → tile becomes PaperCard; snackbar importSuccess [Open]
     │              ├─ not a PDF / paywalled / 404 → tile error importUrlNotPdf / importUrlFetchFailed [Retry] [Dismiss]
     │              └─ duplicate (same source already in library) → snackbar importDuplicate [Open existing]
     └─ "From file" → native file picker (filter .pdf)
            ├─ cancel → nothing
            ├─ > size limit → importFileTooLarge
            ├─ not a PDF / corrupted → importFileInvalid
            └─ ok → ImportProgressTile ("Uploading 43%") → success as above
                                      └─ upload fails → importUploadFailed [Retry]
```

Offline branch
- URL import offline: dialog submit disabled with `importOfflineUrl` ("Needs a connection").
- File import offline: **allowed** — the file is copied to local cache, appears in library immediately as *local only* (DownloadStateBadge = `availableOffline` + SyncBadge pending +1). Upload is queued; ImportProgressTile is not shown; card shows `paperPendingUpload` caption until sync completes.
- Multiple files (desktop drag-drop / multi-select): one tile per file, processed sequentially; summary snackbar `importBatchSummary` ("3 added, 1 failed").

Imported papers are **downloaded for offline by default** when imported from file (bytes are already local); URL imports are cloud-only until the user downloads (setting: Settings › Storage › "Auto-download new papers").

---

## F4. Open + read + highlight

**Goal:** Open a paper and mark the passages that matter with the input I have in hand, without losing my place.

### Open

```
[Library] tap/click/Enter PaperCard
   ├─ available offline → ReaderScreen, restores last page + zoom (instant; first page from cache)
   ├─ cloud only, online → ReaderScreen loading (progress "Downloading 2.1 / 4.8 MB") → reads as pages stream
   │       └─ download fails → ReaderErrorState readerDownloadFailed [Retry] [Back]
   ├─ cloud only, OFFLINE → no navigation; snackbar readerUnavailableOffline [Learn more → Settings › Storage]
   │       (card shows disabled-look + cloud-off badge in library so this is predictable)
   └─ corrupted / can't render → ReaderErrorState readerRenderFailed [Re-download] [Back]
```

### Highlight — three modalities

| Modality | Gesture | Result |
| --- | --- | --- |
| **Finger** (select mode, default on touch) | Long-press word → selection handles → adjust → SelectionPopover appears above selection | Tap colour → highlight created; or Explain / Note / Copy |
| **Finger** (highlight mode) | Drag across text → snaps to text runs → highlight created on lift with last colour | HighlightPicker floats briefly (2s) to change colour |
| **Stylus** (pen mode, auto-enabled when a stylus first touches the page; toggle in toolbar) | Stroke over text → stroke snaps to underlying text lines → text highlight. Stroke over non-text (figure) → ink highlight kept as freeform | Finger still scrolls; palm rejected. Eraser end / barrel button erases highlight under stroke |
| **Mouse / trackpad** | Click-drag select → SelectionPopover; or press **H** for last colour | Hover over existing highlight shows outline; click opens HighlightPicker (change colour, add note, delete) |
| **Figure** (figure mode, all inputs) | Drag a rectangle | FigureSelectionBox → Save as figure highlight (+ optional note) |

States: created highlight is written to local DB immediately (optimistic, never waits for network) → SyncBadge pending count +1 → synced in background.
Undo: snackbar `highlightCreatedUndo` for 5s (+ Mod+Z) after create/delete.
Failure: local write failure (disk full) → `highlightSaveFailed` with Retry; highlight not shown as saved.

Reading position: last page + zoom saved on page change (debounced 1s) and synced (LWW).

---

## F5. Ask AI (explanation / glossary / citations / visuals) with offline fallback

**Goal:** Understand a confusing term or passage in plain language without leaving the page.

```
[Reader] select text → SelectionPopover "Explain" (or E)
   ├─ ONLINE
   │    → side panel opens on Explanation tab (split classes) / sheet (overlay classes)
   │    → ExplanationCard pending (term + indeterminate progress) prepended to stack
   │       ├─ success → card complete (analogy → formal definition; tags; rating; "Re-explain for this paper")
   │       │             term also added to Glossary tab (dedup: existing card moves to top — same rule as RPR sidebar.ts)
   │       ├─ error (5xx / timeout 30s) → card error aiExplainFailed [Retry] — highlight is still saved
   │       └─ connection drops mid-request → card becomes queued-offline state (below)
   └─ OFFLINE
        → highlight is saved normally
        → ExplanationCard in "waiting for connection" state: aiOfflineCardTitle / aiOfflineCardBody
           [Explain when online] toggle (default ON) — queued request auto-runs on reconnect,
           card updates in place; user is notified via panel badge, not a modal
        → if a cached explanation exists for the term (previously fetched, stored locally) → show it with caption aiCachedExplanation
```

Citation popover: tap a citation marker → CitationPopover. Online: reference metadata + "Import into library". Offline: shows the raw reference text parsed locally from the PDF + `citationOfflineHint`; Import disabled with reason.

Visual aid (Manim video): online only. Offline: VisualAidPlayer replaced by `aiVisualOffline` line; never a broken player.

AI unavailable for non-offline reasons (API rejects bearer token → known risk in CEO brief): panel shows `aiUnavailableTitle` / `aiUnavailableBody` once; Explain action stays visible but routes to this state. Do not show "you're offline" when the user is online.

---

## F6. Offline edit → reconnect → sync (last-write-wins)

**Goal:** Keep working with no connection and trust that nothing I did is lost — and if something was overwritten, know what and why.

```
Online ──connection lost──► SyncBadge: offline (icon + "Offline")
   │                           OfflineBanner shown ONLY in contexts that need network
   │                           (import URL, AI, cloud-only paper). Reading/highlighting/notes never blocked.
   ▼
User edits: highlights, notes, renames, deletes, reading position
   → each write: local DB + outbox row (entity, id, op, updated_at local clock, device id)
   → SyncBadge: "Offline · 4 changes pending" (syncPendingOffline)
   ▼
Connection restored (connectivity event + successful lightweight ping)
   → SyncBadge: syncing (progress "Syncing 2 of 4")
   → push outbox (oldest first) → pull remote changes since last cursor
   ├─ all applied → SyncBadge: synced "Synced just now"; snackbar ONLY if > 0 conflicts
   ├─ conflict(s): same row changed on server after our base version
   │     → rule: last write wins per row by updated_at (server timestamp on accept)
   │     → loser's value is NOT silently discarded: kept in local "Replaced versions" (30 days) 
   │     → ConflictNotice snackbar: syncConflictSummary ("2 notes were updated on another device and replaced your offline edits") [Review]
   │     → Review opens SyncSheet › "Replaced versions" list: entity, both timestamps, [Restore mine] [Dismiss]
   │        Restore mine = new write (becomes latest) — explicit, user-initiated
   ├─ partial failure (some rows rejected, e.g. paper deleted on server)
   │     → SyncBadge: error "1 change couldn't sync" [Retry] [Details]
   │     → Details lists item + reason (syncItemPaperDeleted) + [Discard change]
   └─ auth expired → SyncBadge error syncAuthExpired → [Sign in again] (data stays in outbox)
```

LWW explanation shown to users (Settings › Sync › "How syncing works", `syncHowItWorksBody`): "If you edit the same note or highlight on two devices while one is offline, the most recent edit is kept. Older edits are saved under Replaced versions for 30 days so you can restore them."

Background sync triggers: app foreground, connectivity regained, every 5 min while open, after each local write (debounced 2s). Android: WorkManager one-off on connectivity when backgrounded (best effort). Never sync over metered network if Settings › Sync › "Sync on mobile data" is off (downloads only; small metadata always allowed).

---

## F7. Delete with undo

**Goal:** Remove a paper I don't need, and recover instantly if I did it by accident.

```
[Library] PaperCard overflow / right-click / Delete key → "Delete"
   → NO confirm dialog for a single paper (undo is the safety net)
   → card animates out; DeleteUndoSnackbar libraryDeletedUndo ("Deleted '{title}'") [Undo] — 8s, persists while hovered/focused
   ├─ Undo (button or Mod+Z) → card restored at original position; nothing sent to server
   ├─ timeout → delete committed: local row tombstoned + outbox op; PDF cache removed;
   │            highlights/notes for the paper deleted with it (server cascade)
   ├─ offline → same; commits locally, syncs later (SyncBadge pending)
   └─ server delete fails → card restored + snackbar libraryDeleteFailed [Retry]
Multi-select delete (desktop Shift/Mod+click, tablet long-press then tap) → confirm dialog required:
   libraryDeleteManyTitle ("Delete 4 papers?") + body noting highlights & notes are removed → [Delete] [Cancel]
   → then same undo snackbar (libraryDeletedManyUndo)
Delete while paper open in reader (other window/device): reader shows ReaderErrorState readerPaperDeleted [Back to library]
```

"Remove download" (frees disk, keeps paper in library) is a separate, non-destructive action and never shares the Delete affordance position.

---

## Cross-flow state matrix

| Flow | Empty | Loading | Error | Success | Partial | Offline |
| --- | --- | --- | --- | --- | --- | --- |
| F1 Onboarding | — | splash | session refresh fail | Library | — | cached Library / disabled sign-in |
| F2 Sign-in | — | browser wait / submit spinner | cancel, denied, exchange fail, bad creds, rate limit | Library | unconfirmed email | disabled + reason |
| F3 Import | — | progress tile | invalid, not PDF, fetch fail, too large, upload fail | card + snackbar | batch summary | URL blocked, file queued |
| F4 Read/highlight | paper with no highlights (hint) | page streaming | download/render fail | highlight saved | — | offline papers fully usable |
| F5 AI | panel empty state | pending card | error card | complete card | cached explanation | queued card |
| F6 Sync | nothing pending | syncing | auth expired / rejected | synced | some rows failed; conflicts | offline + pending N |
| F7 Delete | library empty after delete → EmptyState | — | server fail → restore | removed | multi: some failed | queued |
