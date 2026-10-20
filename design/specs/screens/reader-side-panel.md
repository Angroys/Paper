# Screen — Reader side panel (Notes · Glossary · Explanation)

**User goal:** Keep my notes, this paper's glossary and AI explanations beside the PDF so I can refer back without losing my reading position.
Flows: [F5](../flows.md#f5-ask-ai-explanation--glossary--citations--visuals-with-offline-fallback), [F6](../flows.md#f6-offline-edit--reconnect--sync-last-write-wins). Split/overlay rules: [layout-system.md §4](../layout-system.md#4-reader--side-panel-behaviour). Anchor: RPR `ExplanationSidebar.tsx` + `lib/reader/sidebar.ts` (newest-first stack; pending → complete | error; re-explaining keeps previous text; dedup moves existing card to top; ratings; tags; visual aid).

## Regions
1. **Panel header**: `PanelTabBar` (Notes · Glossary · Explanation), close button, overflow (Sort, Export notes – v1.1 placeholder hidden).
2. **Tab body** (independent scroll; scroll position kept per tab while panel open).
3. **Tab footer** (Notes only): "New note" composer.
4. **Offline/AI-unavailable strip** (Glossary + Explanation tabs, when applicable).

Container per class: bottom sheet (fallback) · overlay side sheet (compact) · split with `SplitDragHandle` (medium+).

## Wireframes

### Split (medium+), Explanation tab active
```
╫─┬───────────────────────────────────┐
║ │ [Notes] [Glossary] [Explanation•]  ✕ │  • = new unread result badge
║ ├───────────────────────────────────┤
║ │ ┌ ExplanationCard (pending) ──────┐ │
║ │ │ "self-attention"                │ │
║ │ │ ━━━━━━━━━━━━  explaining…       │ │
║ │ └─────────────────────────────────┘ │
║ │ ┌ ExplanationCard (complete) ─────┐ │
║ │ │ "positional encoding"   p.6 ↗   │ │ ↗ = jump to highlight
║ │ │ [tag][tag]                      │ │
║ │ │ Analogy paragraph…              │ │
║ │ │ Formal definition…              │ │
║ │ │ ▶ VisualAidPlayer (online)      │ │
║ │ │ Rate ☆☆☆☆☆   Re-explain for this paper │
║ │ └─────────────────────────────────┘ │
║ │ ┌ ExplanationCard (error) ────────┐ │
║ │ │ "softmax"  aiExplainFailed [Retry]│
║ │ └─────────────────────────────────┘ │
╨─┴───────────────────────────────────┘
```

### Bottom sheet (fallback)
```
┌──────────────────────────────┐
│ (page, dimmed above 40%)     │
├────────── ═══ ───────────────┤ drag handle (snap 40% / 90%)
│ [Notes][Glossary][Explanation]│
│ card …                       │
└──────────────────────────────┘
```

### Notes tab
```
│ [Notes•] [Glossary] [Explanation]  ✕ │
│ Sort: Page order ▾                   │
│ ┌ NoteCard ───────────────────────┐  │
│ │ p.3  ▒ "quoted highlight text…" │  │ tap quote → jump to highlight
│ │ My note text (editable inline)  │  │
│ │ edited 2 min ago · ⟳ pending    │  │ per-note sync glyph only when pending/failed
│ └─────────────────────────────────┘  │
│ ┌ NoteCard (figure) ──────────────┐  │
│ │ p.7 [figure thumb] Fig. 2       │  │
│ │ note…                           │  │
│ └─────────────────────────────────┘  │
├──────────────────────────────────────┤
│ [ + New note on page 12 _________ ]  │ paper-level note composer
```
Sort: Page order (default) · Recently edited. Notes = (a) notes attached to highlights/figure highlights, (b) free notes anchored to a page.

### Glossary tab
```
│ [🔍 Filter terms         ]           │
│ ┌ GlossaryTermTile ───────────────┐  │
│ │ positional encoding    p.6  ›   │  │ › expands to cached explanation
│ │ [tag]  1-line summary…          │  │
│ └─────────────────────────────────┘  │
│ …                                     │
```
Scoped to the open paper. Expanding a term shows its stored explanation (works offline once fetched). "Explain again" routes to Explanation tab.

## States
| Tab | Empty | Loading | Error | Success | Partial | Offline |
| --- | --- | --- | --- | --- | --- | --- |
| Notes | `notesEmptyTitle` / `notesEmptyBody` (input-aware: "Select text and tap Note") | local DB read: instant; skeleton only if > 150ms | `notesLoadFailed` [Retry] | list | some notes pending sync (per-card glyph) | fully functional; edits queue |
| Glossary | `glossaryEmptyTitle` / `glossaryEmptyBody` | skeleton tiles | `glossaryLoadFailed` [Retry] | list | terms with no cached explanation show `glossaryNoCachedExplanation` | list from local cache; strip `aiOfflineStrip`; expanding uncached term shows `glossaryOfflineUncached` |
| Explanation | `explanationEmptyTitle` / `explanationEmptyBody` ("Select a term and tap Explain") | pending card | error card [Retry]; re-explain failure keeps old text + inline `aiReexplainFailed` | complete card | stack mixes states | queued card `aiOfflineCardTitle`/`aiOfflineCardBody` + toggle `aiExplainWhenOnline`; cached explanations shown with `aiCachedExplanation`; visual aid → `aiVisualOffline`; rating & re-explain disabled with reason |
| Any (AI unavailable while online) | — | — | `AiOfflineState` variant `aiUnavailableTitle` / `aiUnavailableBody` | — | — | — |

Panel-level: when online returns, queued cards transition to pending automatically; tab label shows a dot badge when a background result arrives on a non-active tab (`panelTabNewResult`).

## Interactions
- Open panel: toolbar ▤, Mod+\, or Explain/Note action (auto-opens to relevant tab). Close: ✕, Esc (when focus inside), drag below min (split), swipe down (sheet).
- Tab switching: tap, Ctrl/Cmd+Alt+1/2/3, ←/→ when tab bar focused.
- Jump from card to highlight: scrolls PDF, flashes highlight outline (reduced motion: static outline 1s), shows "Back to page N" pill.
- Hovering a card (pointer) outlines its highlight in the PDF; hovering a highlight scrolls nothing (no surprise scroll).
- Rating: 1–5 stars, single tap; changeable; offline → disabled + tooltip `aiNeedsConnection`.
- Overlay modes: PDF is inert under scrim; tapping scrim closes.

## Components
`ReaderSidePanel`, `SplitDragHandle`, `PanelTabBar`, `NotesList`, `NoteCard`, `NoteEditor`, `GlossaryList`, `GlossaryTermTile`, `ExplanationStack`, `ExplanationCard`, `VisualAidPlayer`, `AiOfflineState`, `OfflineBanner` (strip variant), `EmptyState`, `SkeletonRow`, `InlineError`.

## Microcopy keys
`panelTabNotes`, `panelTabGlossary`, `panelTabExplanation`, `panelClose`, `panelTabNewResult`, `notesEmptyTitle`, `notesEmptyBody`, `notesEmptyBodyPen`, `notesLoadFailed`, `notesSortPageOrder`, `notesSortRecent`, `notesComposerPlaceholder`, `notesEditedAgo`, `notesPendingSync`, `notesSyncFailed`, `noteDelete`, `noteDeletedUndo`, `noteJumpToHighlight`, `glossaryFilterHint`, `glossaryEmptyTitle`, `glossaryEmptyBody`, `glossaryLoadFailed`, `glossaryNoCachedExplanation`, `glossaryOfflineUncached`, `glossaryExplainAgain`, `explanationEmptyTitle`, `explanationEmptyBody`, `explanationPending`, `explanationReexplain`, `explanationReexplaining`, `explanationRateLabel`, `explanationRated`, `explanationJumpToPage`, `explanationAnalogyHeading`, `explanationFormalHeading`, `aiExplainFailed`, `aiReexplainFailed`, `aiRetry`, `aiOfflineStrip`, `aiOfflineCardTitle`, `aiOfflineCardBody`, `aiExplainWhenOnline`, `aiCachedExplanation`, `aiVisualOffline`, `aiVisualPlay`, `aiVisualPause`, `aiVisualSeek`, `aiNeedsConnection`, `aiUnavailableTitle`, `aiUnavailableBody`.

## Accessibility
- Panel is a `complementary` region labelled by the active tab; tab bar uses tab semantics with selected state.
- Explanation cards: pending card has `busy` + label `explanationPending` ("Explaining {term}"); completion announced politely ("Explanation ready: {term}") — matches RPR's distinct aria-labels per state.
- Error and offline strips announced once on appearance, not repeatedly.
- Focus: opening via Explain does **not** steal focus from the PDF selection on pointer/touch (announcement only); opening via keyboard shortcut moves focus to the active tab.
- Split handle keyboard operable (see layout-system §4).
- Video visual aid: controls labelled (`aiVisualPlay` etc.), no autoplay with reduced motion; the text explanation is always the primary content (video is supplemental).
