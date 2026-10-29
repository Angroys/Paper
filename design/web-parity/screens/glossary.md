# Glossary (S4): web-parity spec

**Where it appears:**

- **App:** the **Glossary tab** of the reader side panel (`features/panel/glossary_tab.dart`: `GlossaryTab`, `GlossaryTermTile`, `_TagChip`, `_SkeletonRows`). The app has no standalone glossary route.
- **Web:** the glossary section of `/projects/[projectId]`:
  - `glossary/GlossarySearch.tsx`
  - `glossary/GlossaryEntryCard.tsx`
  - `glossary/TagChip.tsx`
  - `glossary/TermRating.tsx`

  `/glossary` redirects to `/library` on the web.
- **Components:** [`../components.md`](../components.md).
- **Panel frame, header and AI states:** [`side-panel.md`](side-panel.md).

**References:**

| Shot | Use |
|---|---|
| [`glossary.1280x800.png`](../reference/glossary.1280x800.png), [`glossary.800x1280.png`](../reference/glossary.800x1280.png) | search field, tag filter pills, collapsed entry cards |
| [`glossary.entry-expanded.1280x800.png`](../reference/glossary.entry-expanded.1280x800.png), [`glossary.entry-expanded.800x1280.png`](../reference/glossary.entry-expanded.800x1280.png) | expanded entry: chevron rotated, prose, rating row, "From …" line |
| [`glossary.search.1280x800.png`](../reference/glossary.search.1280x800.png), [`glossary.search.800x1280.png`](../reference/glossary.search.800x1280.png) | filtered list while typing |

**Compare styles, not widths.** The references are a full-width page section (752 / 1232 wide). The app renders the same components inside the 384 panel, where cards are **352** wide.

**Not added (web-only):**

- The **recommended-tag filter pills** row (`GlossarySearch` `aria-label="Recommended tags"`): the app has no tag filtering.
- The "Showing N of M terms · Clear filters" line.
- The "From ‹paper›" link: the tab is already scoped to the open paper.

The pill style is still specified (components §9.6) in case tag filtering is ever added.

---

## 1. Layout (inside the panel body)

| | Docked (≥ 1024) / overlay (640–1023) | Sheet (< 640) |
|---|---|---|
| Body padding | 16 (`p-4`) | 16 |
| Content width | **352** | window − 32 |
| Card content width (`p-5`) | **312** | window − 72 |

The body is one vertical scroll region under the 41-tall panel header:

| # | Element | Spacing | Height |
|---|---|---|---|
| 1 | Search: `PaperSearchField` w-full, placeholder `glossaryFilterHint`, no leading icon, `×` clear when it has text | top 16 | 38 |
| 2 | Entry list: `flex-col`, gap **16** (`space-y-4`) | `mt-6` 24 | — |
| 3 | Bottom padding | 16 + `viewPadding.bottom` | — |

The search field scrolls with the list. It is not pinned, as on the web.

---

## 2. Entry card (`GlossaryEntryCard`)

The box is `PaperCard p-5` (fill `gray900`, border 1 `gray800`, radius 8, padding **20**).

| Part | Spec |
|---|---|
| Header row | `flex flex-wrap items-baseline justify-between gap-2` |
| Term button | `flex items-center gap-1.5`: `chevron-right-small.svg` **14** `gray500`, rotated 0° collapsed / **90°** expanded (150 ms; instant under reduced motion), then the term `sm 600 gray100` with `break-words`. Hover: term text `accent`. Focus: ring 2 accent, no offset, radius 6. Semantics: button, `expanded`. The whole header row is tappable. |
| Date | `xs gray400`, `createdAt` formatted `MMM d, yyyy` (`DateFormat.yMMMd`), e.g. "Oct 20, 2026". Baseline-aligned with the term. |
| Tags (app data) | `mt-2 flex-wrap gap-1`: `TagChip.type` / `TagChip.topic` (components §9.2–9.3). At most 2, as today. Shown in both collapsed and expanded states. |
| **Expanded panel** | Appears instantly (the web uses `hidden`). design-motion may keep a ≤ 150 ms size change under `PaperMotion.of`. |
| · Prose | `mt-2`, `explanationBody` 14/22.75 `gray300`, pre-wrap. Inline code is `code` on `gray800`, radius 4, `px-1`. |
| · Rating | `mt-3`, `PaperRating` (components §18.2). This replaces `StarRating`. |
| · Explain again | `mt-3`, `PaperButton.secondary xs` "Explain again" (`glossaryExplainAgain`). While running, the label is `explanationReexplaining` and the button is disabled. It is hidden when offline; then `xs gray400` `aiNeedsConnection` takes its place. |
| · Re-explain error | `mt-1.5 xs red400` (`aiReexplainFailed`) |
| · No cached text | instead of the prose: `mt-2 sm italic gray400` (`glossaryNoCachedExplanation`, or `glossaryOfflineUncached` when offline) |

**Card heights:**

| Card | Height |
|---|---|
| Collapsed, no tags | 20 + 20 + 20 + 2 = **62** (matches `glossary.entry-expanded.800x1280.png`, y 1012–1073) |
| Collapsed, with tags | **90** |
| Expanded | content-driven |

---

## 3. States

| State | Spec |
|---|---|
| **Loading** | The search field is shown but disabled @ .5. Below it, `mt-6`, three skeleton cards (`PaperCard p-5`): a term bar 14×40 % on the left and a date bar 12×64 on the right. Gap 16, pulse 2 s. |
| **Empty** (no terms for this paper) | No search field. `EmptyStateText` (`px-2 py-10 text-center`): title `glossaryEmptyTitle` `sm 600 gray100`, body `mt-1 sm-relaxed gray400` (`glossaryEmptyBody`). |
| **No match** for the query | `EmptyStateCard.compact` `mt-6` (`PaperCard p-8 text-center sm gray400`). The copy needs a new key; until then reuse `librarySearchNoResultsBody`. The search field stays. |
| **Offline, nothing cached** | `NoticeStrip` (side-panel.md §4) + `EmptyStateText` with body `glossaryOfflineUncached` |
| **Offline, cached** | `NoticeStrip` at the top. The list works, and "Explain again" is replaced by the `aiNeedsConnection` line. |
| **Load failed** | `ErrorBanner` (`glossaryLoadFailed`) + `mt-3 PaperButton.secondary xs` "Try again" when retryable |
| **AI unavailable / guest** | side-panel.md §4 |

---

## 4. Insets and IME

- The glossary tab lives inside the side panel, so it uses the panel's inset rules (side-panel.md §5).
- When the search field has focus, the panel body lifts by `viewInsets.bottom`. The PDF does not resize.

---

## 5. Parity checklist

Compare with `glossary.entry-expanded.800x1280.png` and `glossary.800x1280.png`, component by component.

- [ ] Search field 38 tall, `#171717` fill, 1 px `#404040` border, radius 6, padding 12×8, Geist 14/20, placeholder `#A3A3A3`, no leading icon; on focus a 2 px `#818CF8` edge.
- [ ] 24 between the search field and the first card; 16 between cards.
- [ ] Entry card `#171717` fill, 1 px `#262626` border, radius 8, padding 20, no shadow; a collapsed card without tags is 62 tall.
- [ ] Chevron 14 px `#737373`, pointing right when collapsed and down (90°) when expanded, 6 before the term.
- [ ] Term Geist 14/20 600 `#F5F5F5`; turns `#818CF8` on hover; the date is right-aligned on the same baseline, Geist 12/16 `#A3A3A3`, "Oct 20, 2026" format.
- [ ] Expanded prose Geist 14/22.75 `#D4D4D4`, 8 below the header.
- [ ] Rating row 12 below the prose: "Rate this explanation" 12/16 `#A3A3A3`, five 24×24 radius-6 squares with a gap of 4; selected `#818CF8` with a `#1E1B4B` digit; others `#262626` with `#A3A3A3`; trailing "4/5" or "Not rated".
- [ ] "Explain again" is a 26-tall secondary button (`#171717`, 1 px `#404040`, `#E5E5E5` 12/16 500 label).
- [ ] Tag chips (when present) 20 tall, radius full, Geist 11 500: type `#C7D2FE` on `#1E1B4B`, topic `#D4D4D4` on `#262626`.
- [ ] Empty state: centred text, title 14/20 600 `#F5F5F5`, body 14/22.75 `#A3A3A3`, no card, no icon.
- [ ] No Material icons; no `ExpansionTile` divider lines or ink ripple.
