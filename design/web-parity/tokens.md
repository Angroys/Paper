# Web-parity tokens (M1)

Every visual token that the paper.college web app paints on the in-scope screens, extracted from RPR. The Flutter values that now match them are listed alongside.

- **Source (read-only):** `/home/minimax/research-paper-helper`
  - `tailwind.config.ts`
  - `src/app/globals.css`
  - `src/app/layout.tsx`
  - `src/app/fonts/*`
  - `src/components/{library,reader,glossary,settings,auth,layout,projects,landing}`
  - `src/app/**/page.tsx`
- **Method:**
  1. Every string literal in those 63 `.tsx` files was tokenised (1,249 distinct tokens).
  2. The tokens were fed back through RPR's own Tailwind 3.4.19 with RPR's own config, so each class below is what Tailwind actually generates, not a hand lookup. This produced 537 real utility classes.
  3. A per-literal pass marks which light-mode classes are dead because a `dark:` sibling overrides them.
  4. The script is `design/web-parity/reference/README.md` § "Token extraction".
- **Flutter files:**
  - `design/tokens/paper_tokens.dart`
  - `design/tokens/paper-tokens.json`
  - `design/tokens/README.md`
- **Screenshots:** `design/web-parity/reference/`

## 1. Theme: dark-only

- `src/app/layout.tsx` renders `<html lang="en" className="dark" style={{ colorScheme: "dark" }}>`. `dark` is a server-rendered prop, and nothing ever removes it.
- `globals.css` says: "The app is dark only … the `.dark` token overrides below always apply."
- There is no theme toggle anywhere in the web UI.
- `tailwind.config.ts` still declares `darkMode: "class"`. Its comment about a localStorage theme script is stale.

**Decision:** the app becomes dark-only.

- Remove the Settings "Theme: System / Light / Dark" control and its persisted preference.
- `MaterialApp(theme: PaperTheme.dark(), themeMode: ThemeMode.dark)`.
- `PaperTheme.light()` / `PaperColors.light` are kept as aliases of dark so the code compiles until the toggle is removed. Delete them in that change.
- Native splash: the dark background `#0A0A0A` only. The light splash entries in `pubspec.yaml` (`color: "#FAFAFA"`) become dead; set both to `#0A0A0A`.
- `colorScheme: "dark"` on the web also makes native widgets dark: scrollbars, checkbox and file-input chrome, date pickers. Theme the Flutter equivalents dark (already the case).

**Light-mode classes are dead code.** Almost every web class list pairs a light class with a `dark:` override, for example `text-gray-900 dark:text-gray-100`. Only the `dark:` value ever paints. §3 marks each light class `dead` or `live`. A light class is **live** only when nothing overrides it, as with `bg-accent`, `text-white` on thumbnails, and the always-white PDF chrome.

## 2. CSS variables (`.dark` values = the only values that paint)

| Variable | Dark (painted) | Light (dead) | Used for | Dart |
|---|---|---|---|---|
| `--background` | `#0a0a0a` | `#fafafa` | `body` background, `bg-background` | `PaperColors.background`, `PaperWeb.background` |
| `--foreground` | `#f5f5f5` | `#171717` | `body` text colour (default ink) | `PaperColors.textPrimary`, `PaperWeb.foreground` |
| `--accent` | `#818cf8` (indigo-400) | `#4f46e5` | `bg-/text-/ring-/border-/stroke-/outline-/accent-accent` | `PaperColors.primary`, `PaperWeb.accent` |
| `--accent-hover` | `#a5b4fc` (indigo-300) | `#4338ca` | primary hover/active, link hover | `primaryHover` |
| `--accent-soft` | `#1e1b4b` (indigo-950) | `#eef2ff` | selected nav item, tag chips, avatar disc | `primarySoft` |
| `--accent-ink` | `#c7d2fe` (indigo-200) | `#312e81` | text on accent-soft | `onPrimarySoft` |
| `--mark-focus-ring` | `#4f46e5` (pinned) | `#4f46e5` | keyboard focus on PDF marks, figure outline | `focusRingOnPaper`, `PaperWeb.markFocusRing` |
| `--term-wash-color` / `-opacity` | `#60a5fa` / 0.10 | same | blue cached-term rest wash | `PaperReaderMark.term.wash`, `restAlpha` |
| `--term-mark-full` / `-active` / `-ring` | `rgba(59,130,246,.55)` / `.68` / `#2563eb` | same | term hover / press / ring | `PaperReaderMark.term` |
| `--highlight-wash-color` / `-opacity` | `#fbbf24` / 0.10 | same | user highlight rest wash | `PaperHighlightColor.yellow.wash`, `whitePaper.restAlpha` |
| `--highlight-mark-full` / `-active` / `-ring` | `rgba(245,158,11,.55)` / `.68` / `#d97706` | same | highlight hover / press / ring | `hoverAlpha` / `activeAlpha` / `.ring` |
| `--highlight-mark-pending` | `rgba(251,191,36,.40)` | same | just-made selection overlay | `PaperHighlightColors.pending` |
| `--citation-*` | wash `#818cf8`, full `rgba(99,102,241,.55)`, ring `#4f46e5` | same | citation hotspots | `PaperReaderMark.citation` |
| `--appendix-*` | wash `#2dd4bf`, full `rgba(20,184,166,.55)`, ring `#0d9488` | same | in-document jumps ("Figure 1", "Section 3") | `PaperReaderMark.appendix` |
| `--mention-*` | wash `#a3a3a3`, full `rgba(115,115,115,.55)`, ring `#525252` | same | external mentions | `PaperReaderMark.mention` |
| `--mark-reveal-duration` / `-settle-` / `-press-` / `-reveal-delay` | 150 / 200 / 80 / 40 ms | same | every mark state change | `PaperMotion.fast/base/instant/hoverDelay` |
| `--mark-ease-reveal` / `-settle` | `cubic-bezier(0,0,.2,1)` / `(.4,0,.2,1)` | same | | `PaperMotion.decelerate` / `standard` |
| `--mark-grow-highlight` / `-term` | 1.02 / 1.04 | same | hover scale | `PaperMotion.markHoverScale` / `termHoverScale` |
| `--popover-bg` / `-border` / `-text` / `-accent` | `#111827` / `#374151` / `#d1d5db` / `#818cf8` | `#fff` / `#e5e7eb` / `#374151` / `#4f46e5` | **landing hero card only** (cool gray, not the neutral ramp) | `PaperWeb` not needed (landing is out of the app) |
| `--focus-lock-*` | tint `rgba(10,10,10,.55)`, blur 6px, saturate .7, card glow `rgba(129,140,248,.45)` | | focus-lock overlay (web-only feature, see §14) | — |
| `--hero-*`, `--paper-*`, `--graph-*`, `--mindmap-*` | | | landing hero, Paper Scenes, removed mindmap | out of scope |

**The gray ramp is hue-free.** `tailwind.config.ts` replaces Tailwind's cool gray with a neutral (R=G=B) ramp, so every `gray-*` class resolves to these values:

| gray | 50 | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 | 950 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hex | `#fafafa` | `#f5f5f5` | `#e5e5e5` | `#d4d4d4` | `#a3a3a3` | `#737373` | `#525252` | `#404040` | `#262626` | `#171717` | `#0a0a0a` |

Other hues come from Tailwind's default palette. Only `indigo` (via the `--accent*` vars, plus `dark:text-indigo-950` = `#1e1b4b`), `red`, `green`, `amber`, `yellow` and `teal`/`blue` (marks) appear.

### 2.1 Component classes (`globals.css @layer components`), resolved for dark

| Class | Fill | Border | Label | Hover | Active | Focus-visible | Disabled | Box |
|---|---|---|---|---|---|---|---|---|
| `.btn-primary` | `#818cf8` | none | `#1e1b4b` (indigo-950), text-sm/500 | fill `#a5b4fc` | fill `#a5b4fc` | ring 2px `#818cf8` + 2px offset `#0a0a0a` | opacity .5, no pointer | `rounded-md` 6, `px-4 py-2` → 36 tall |
| `.btn-secondary` | `#171717` | 1px `#404040` | `#e5e5e5`, text-sm/500 | fill `#262626` | fill `#262626` | same ring | opacity .5 | 6, `px-4 py-2` + border → 38 tall |
| `.btn-ghost` | transparent | none | `#a3a3a3`, text-sm/500 | fill `#262626`, label `#f5f5f5` | fill `#404040` | same ring | opacity .5 | 6, `px-4 py-2` → 36 |
| `.field-input` | `#171717` | 1px `#404040` | `#f5f5f5` text-sm; placeholder `#a3a3a3` | — | — | border `#818cf8` + ring 1px `#818cf8` (2px accent edge, no offset) | opacity .5 | 6, `px-3 py-2` → 38 |
| `.card` | `#171717` | 1px `#262626` | — | — | — | — | — | `rounded-lg` 8, no shadow |

Flutter mapping:

| Web | Flutter |
|---|---|
| `.btn-primary` | `FilledButton` |
| `.btn-secondary` | `OutlinedButton` |
| `.btn-ghost` | `TextButton` |
| `.field-input` | `TextField(style: PaperTypography.input(c))` |
| `.card` | `Card` |

All five are themed in `PaperTheme`. The web ring has a 2px offset, which Flutter's `BorderSide` cannot draw. M3 should spec a `PaperFocusRing` wrapper: an outer 2px `#818cf8` stroke separated by a 2px gap of the surrounding surface colour, which is `#0a0a0a` on the page and `#171717` inside cards and popovers (`dark:ring-offset-gray-900`).

**Destructive outline** ("Remove" / "Delete" in rows and the reader header):

- Base: `border-red-200 bg-white text-red-700` overridden by `dark:border-red-900 dark:bg-gray-900 dark:text-red-400`.
- Hover: `dark:hover:bg-red-950`.
- Focus: `focus-visible:ring-red-500`.
- Box: `rounded-md px-2.5 py-1 text-xs font-medium`, 26 tall.
- Dart: `PaperWeb.red900` / `red400` / `red950`, `PaperHitTarget.smallButtonHeight`.


**Thumbnail overlay button** (`DeletePaperButton variant="overlay"`, on featured cards):

- Fill `bg-gray-950/70` = `#0a0a0a` at .70, over the thumbnail.
- Border `border-white/30`.
- Label white, `shadow-sm`, `backdrop-blur-sm` (4px).
- Hover: fill `#0a0a0a` at .90.
- Focus: ring white.

## 3. Every colour class in the in-scope components, resolved

This table is generated. Columns:

- **Uses:** occurrences across the 63 files.
- **Resolved value:** the hex value. An opacity variant shows as `hex @ alpha`.
- **Over #0a0a0a / #171717:** an opacity variant composited over the page and over a card.
- **Dark-only status:**
  - `dead`: the class never paints, because the same literal always carries a `dark:` override for the same property and state.
  - `live`: the class paints.

`dark:` classes always paint. To build a screen, read the `dark:` variant when there is one, and the base class when it is `live`.

Classes that generate **nothing**, so do not replicate them:

- `bg-accent-soft/60` and `dark:bg-accent-soft/40`: Tailwind 3 cannot apply `/N` to a `var()` colour, so both render transparent.
- `bg-white/92`: 92 is not on the opacity scale. The `dark:bg-gray-900/90` sibling paints.
- `motion-safe:animate-expand-in`: no such animation is configured, so the "Add a paper" panel just appears.

| Class | Uses | Property | Resolved value | Over #0a0a0a | Over #171717 | Dark-only status |
|---|---|---|---|---|---|---|
| `accent-accent` | 4 | accent-color | #818cf8 (--accent) |  |  | **live** |
| `bg-[var(--popover-accent)]` | 1 | background-color | #818cf8 (--popover-accent) |  |  | **live** (no dark: override) |
| `bg-accent` | 8 | background-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `active:bg-accent-hover` | 1 | background-color | #a5b4fc (--accent-hover) |  |  | **live** (no dark: override) |
| `hover:bg-accent-hover` | 3 | background-color | #a5b4fc (--accent-hover) |  |  | **live** (no dark: override) |
| `bg-accent-soft` | 13 | background-color | #1e1b4b (--accent-soft) |  |  | **live** (no dark: override) |
| `dark:hover:bg-accent-soft` | 2 | background-color | #1e1b4b (--accent-soft) |  |  | **live** |
| `hover:bg-accent-soft` | 2 | background-color | #1e1b4b (--accent-soft) |  |  | **live** in 1, dead in 1 |
| `bg-background` | 1 | background-color | #0a0a0a (--background) |  |  | **live** (no dark: override) |
| `bg-black` | 1 | background-color | #000000 |  |  | **live** (no dark: override) |
| `dark:hover:bg-black/20` | 1 | background-color | #000000 @ 0.2 | #080808 | #121212 | **live** |
| `bg-gray-100` | 11 | background-color | #f5f5f5 |  |  | **live** in 1, dead in 10 |
| `file:bg-gray-100` | 2 | background-color | #f5f5f5 |  |  | dead (always paired with a dark: override) |
| `hover:bg-gray-100` | 9 | background-color | #f5f5f5 |  |  | **live** in 1, dead in 8 |
| `bg-gray-200` | 7 | background-color | #e5e5e5 |  |  | dead (always paired with a dark: override) |
| `hover:bg-gray-200` | 2 | background-color | #e5e5e5 |  |  | dead (always paired with a dark: override) |
| `hover:file:bg-gray-200` | 2 | background-color | #e5e5e5 |  |  | dead (always paired with a dark: override) |
| `bg-gray-50` | 9 | background-color | #fafafa |  |  | **live** in 1, dead in 8 |
| `hover:bg-gray-50` | 2 | background-color | #fafafa |  |  | dead (always paired with a dark: override) |
| `dark:bg-gray-700` | 1 | background-color | #404040 |  |  | **live** |
| `dark:hover:bg-gray-700` | 1 | background-color | #404040 |  |  | **live** |
| `dark:hover:file:bg-gray-700` | 2 | background-color | #404040 |  |  | **live** |
| `dark:bg-gray-800` | 17 | background-color | #262626 |  |  | **live** |
| `dark:file:bg-gray-800` | 2 | background-color | #262626 |  |  | **live** |
| `dark:hover:bg-gray-800` | 10 | background-color | #262626 |  |  | **live** |
| `dark:bg-gray-800/50` | 1 | background-color | #262626 @ 0.5 | #181818 | #1f1f1f | **live** |
| `dark:hover:bg-gray-800/50` | 1 | background-color | #262626 @ 0.5 | #181818 | #1f1f1f | **live** |
| `dark:bg-gray-900` | 20 | background-color | #171717 |  |  | **live** |
| `dark:bg-gray-900/90` | 1 | background-color | #171717 @ 0.9 | #161616 | #171717 | **live** |
| `dark:bg-gray-950` | 7 | background-color | #0a0a0a |  |  | **live** |
| `bg-gray-950/70` | 1 | background-color | #0a0a0a @ 0.7 | #0a0a0a | #0e0e0e | **live** (no dark: override) |
| `hover:bg-gray-950/90` | 1 | background-color | #0a0a0a @ 0.9 | #0a0a0a | #0b0b0b | **live** (no dark: override) |
| `hover:bg-red-100` | 1 | background-color | #fee2e2 |  |  | dead (always paired with a dark: override) |
| `active:bg-red-50` | 4 | background-color | #fef2f2 |  |  | dead (always paired with a dark: override) |
| `bg-red-50` | 7 | background-color | #fef2f2 |  |  | dead (always paired with a dark: override) |
| `hover:bg-red-50` | 5 | background-color | #fef2f2 |  |  | dead (always paired with a dark: override) |
| `dark:hover:bg-red-900` | 1 | background-color | #7f1d1d |  |  | **live** |
| `dark:active:bg-red-950` | 4 | background-color | #450a0a |  |  | **live** |
| `dark:bg-red-950` | 7 | background-color | #450a0a |  |  | **live** |
| `dark:hover:bg-red-950` | 5 | background-color | #450a0a |  |  | **live** |
| `bg-white` | 25 | background-color | #ffffff |  |  | **live** in 5, dead in 20 |
| `hover:bg-white/60` | 1 | background-color | #ffffff @ 0.6 | #9d9d9d | #a2a2a2 | dead (always paired with a dark: override) |
| `bg-white/70` | 1 | background-color | #ffffff @ 0.7 | #b6b6b6 | #b9b9b9 | **live** (no dark: override) |
| `bg-white/90` | 1 | background-color | #ffffff @ 0.9 | #e7e7e7 | #e8e8e8 | **live** (no dark: override) |
| `hover:bg-yellow-100` | 1 | background-color | #fef9c3 |  |  | dead (always paired with a dark: override) |
| `dark:hover:bg-yellow-900/40` | 1 | background-color | #713f12 @ 0.4 | #331f0d | #3b2715 | **live** |
| `border-accent` | 1 | border-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `dark:hover:border-accent` | 1 | border-color | #818cf8 (--accent) |  |  | **live** |
| `focus:border-accent` | 1 | border-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `hover:border-accent` | 1 | border-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `border-gray-100` | 4 | border-color | #f5f5f5 |  |  | dead (always paired with a dark: override) |
| `border-gray-200` | 33 | border-color | #e5e5e5 |  |  | dead (always paired with a dark: override) |
| `lg:border-gray-200` | 1 | border-color | #e5e5e5 |  |  | dead (always paired with a dark: override) |
| `border-gray-300` | 6 | border-color | #d4d4d4 |  |  | dead (always paired with a dark: override) |
| `hover:border-gray-300` | 1 | border-color | #d4d4d4 |  |  | dead (always paired with a dark: override) |
| `border-gray-400` | 1 | border-color | #a3a3a3 |  |  | **live** (no dark: override) |
| `dark:border-gray-600` | 3 | border-color | #525252 |  |  | **live** |
| `dark:border-gray-700` | 19 | border-color | #404040 |  |  | **live** |
| `dark:hover:border-gray-700` | 1 | border-color | #404040 |  |  | **live** |
| `dark:border-gray-800` | 22 | border-color | #262626 |  |  | **live** |
| `dark:lg:border-gray-800` | 1 | border-color | #262626 |  |  | **live** |
| `border-red-200` | 11 | border-color | #fecaca |  |  | dead (always paired with a dark: override) |
| `dark:border-red-500` | 1 | border-color | #ef4444 |  |  | **live** |
| `dark:focus:border-red-500` | 1 | border-color | #ef4444 |  |  | **live** |
| `border-red-600` | 1 | border-color | #dc2626 |  |  | dead (always paired with a dark: override) |
| `focus:border-red-600` | 1 | border-color | #dc2626 |  |  | dead (always paired with a dark: override) |
| `dark:border-red-900` | 11 | border-color | #7f1d1d |  |  | **live** |
| `border-transparent` | 2 | border-color | #000000 @ 0 |  |  | **live** (no dark: override) |
| `border-white/30` | 1 | border-color | #ffffff @ 0.3 | #545454 | #5d5d5d | **live** (no dark: override) |
| `border-white/60` | 1 | border-color | #ffffff @ 0.6 | #9d9d9d | #a2a2a2 | **live** (no dark: override) |
| `dark` | 3 | border-color | #262626 |  |  | **live** |
| `dark` | 3 | background-color | #0a0a0a @ 0.6 | #0a0a0a | #0f0f0f | **live** |
| `dark` | 3 | stroke | #404040 |  |  | **live** |
| `dark` | 3 | color | #c7d2fe (--accent-ink) |  |  | **live** |
| `dark` | 3 | ring-color | #fca5a5 @ 0.3 | #533939 | #5c4242 | **live** |
| `dark` | 3 | ring-offset-color | #171717 |  |  | **live** |
| `divide-gray-200` | 2 | border-color | #e5e5e5 |  |  | dead (always paired with a dark: override) |
| `dark:divide-gray-800` | 2 | border-color | #262626 |  |  | **live** |
| `from-gray-950/90` | 1 | gradient-from | #0a0a0a @ 0.9 | #0a0a0a | #0b0b0b | **live** (no dark: override) |
| `from-gray-950/90` | 1 | gradient-to | #0a0a0a @ 0 |  |  | **live** (no dark: override) |
| `from-gray-950/90` | 1 | gradient-stops | `var(--tw-gradient-from), var(--tw-gradient-to)` |  |  | **live** (no dark: override) |
| `focus-visible:outline-accent` | 5 | outline-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `focus-visible:ring-[color:var(--mark-focus-ring)]` | 1 | ring-color | #4f46e5 (--mark-focus-ring) |  |  | **live** (no dark: override) |
| `focus-visible:ring-accent` | 34 | ring-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `focus-within:ring-accent` | 1 | ring-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `focus:ring-accent` | 4 | ring-color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `hover:ring-gray-300` | 1 | ring-color | #d4d4d4 |  |  | dead (always paired with a dark: override) |
| `dark:hover:ring-gray-600` | 1 | ring-color | #525252 |  |  | **live** |
| `ring-gray-950/10` | 3 | ring-color | #0a0a0a @ 0.1 | #0a0a0a | #161616 | **live** in 1, dead in 2 |
| `ring-gray-950/15` | 1 | ring-color | #0a0a0a @ 0.15 | #0a0a0a | #151515 | **live** (no dark: override) |
| `dark:focus-visible:ring-offset-gray-900` | 4 | ring-offset-color | #171717 |  |  | **live** |
| `dark:focus:ring-offset-gray-900` | 3 | ring-offset-color | #171717 |  |  | **live** |
| `dark:focus-visible:ring-offset-gray-950` | 11 | ring-offset-color | #0a0a0a |  |  | **live** |
| `focus-visible:ring-offset-transparent` | 1 | ring-offset-color | #000000 @ 0 |  |  | **live** (no dark: override) |
| `focus-visible:ring-offset-white` | 1 | ring-offset-color | #ffffff |  |  | **live** (no dark: override) |
| `dark:ring-red-300/30` | 1 | ring-color | #fca5a5 @ 0.3 | #533939 | #5c4242 | **live** |
| `dark:focus:ring-red-500` | 1 | ring-color | #ef4444 |  |  | **live** |
| `focus-visible:ring-red-500` | 5 | ring-color | #ef4444 |  |  | **live** (no dark: override) |
| `focus:ring-red-600` | 1 | ring-color | #dc2626 |  |  | dead (always paired with a dark: override) |
| `ring-red-700/20` | 1 | ring-color | #b91c1c @ 0.2 | #2d0e0e | #371818 | **live** (no dark: override) |
| `ring-red-700/30` | 1 | ring-color | #b91c1c @ 0.3 | #3f0f0f | #481919 | dead (always paired with a dark: override) |
| `focus-visible:ring-white` | 1 | ring-color | #ffffff |  |  | **live** (no dark: override) |
| `dark:ring-white/10` | 2 | ring-color | #ffffff @ 0.1 | #232323 | #2e2e2e | **live** |
| `stroke-accent` | 2 | stroke | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `stroke-gray-200` | 1 | stroke | #e5e5e5 |  |  | dead (always paired with a dark: override) |
| `stroke-gray-500` | 2 | stroke | #737373 |  |  | **live** (no dark: override) |
| `dark:stroke-gray-700` | 1 | stroke | #404040 |  |  | **live** |
| `text-[var(--popover-accent)]` | 1 | color | #818cf8 (--popover-accent) |  |  | **live** (no dark: override) |
| `hover:text-accent` | 3 | color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `text-accent` | 17 | color | #818cf8 (--accent) |  |  | **live** (no dark: override) |
| `hover:text-accent-hover` | 4 | color | #a5b4fc (--accent-hover) |  |  | **live** (no dark: override) |
| `dark:hover:text-accent-ink` | 1 | color | #c7d2fe (--accent-ink) |  |  | **live** |
| `dark:text-accent-ink` | 1 | color | #c7d2fe (--accent-ink) |  |  | **live** |
| `hover:text-accent-ink` | 1 | color | #c7d2fe (--accent-ink) |  |  | dead (always paired with a dark: override) |
| `text-accent-ink` | 15 | color | #c7d2fe (--accent-ink) |  |  | **live** in 14, dead in 1 |
| `dark:text-amber-400` | 1 | color | #fbbf24 |  |  | **live** |
| `text-amber-700` | 1 | color | #b45309 |  |  | dead (always paired with a dark: override) |
| `text-current` | 1 | color | `currentColor` |  |  | **live** (no dark: override) |
| `dark:hover:text-gray-100` | 8 | color | #f5f5f5 |  |  | **live** |
| `dark:text-gray-100` | 46 | color | #f5f5f5 |  |  | **live** |
| `dark:file:text-gray-200` | 2 | color | #e5e5e5 |  |  | **live** |
| `dark:text-gray-200` | 4 | color | #e5e5e5 |  |  | **live** |
| `text-gray-200` | 1 | color | #e5e5e5 |  |  | **live** (no dark: override) |
| `dark:text-gray-300` | 26 | color | #d4d4d4 |  |  | **live** |
| `dark:placeholder:text-gray-400` | 1 | color | #a3a3a3 |  |  | **live** |
| `dark:text-gray-400` | 91 | color | #a3a3a3 |  |  | **live** |
| `text-gray-400` | 3 | color | #a3a3a3 |  |  | dead (always paired with a dark: override) |
| `dark:text-gray-500` | 2 | color | #737373 |  |  | **live** |
| `placeholder:text-gray-500` | 1 | color | #737373 |  |  | dead (always paired with a dark: override) |
| `text-gray-500` | 47 | color | #737373 |  |  | dead (always paired with a dark: override) |
| `dark:text-gray-600` | 1 | color | #525252 |  |  | **live** |
| `disabled:text-gray-600` | 1 | color | #525252 |  |  | **live** (no dark: override) |
| `text-gray-600` | 47 | color | #525252 |  |  | dead (always paired with a dark: override) |
| `file:text-gray-700` | 2 | color | #404040 |  |  | dead (always paired with a dark: override) |
| `text-gray-700` | 27 | color | #404040 |  |  | dead (always paired with a dark: override) |
| `text-gray-800` | 5 | color | #262626 |  |  | **live** in 1, dead in 4 |
| `hover:text-gray-900` | 8 | color | #171717 |  |  | dead (always paired with a dark: override) |
| `text-gray-900` | 46 | color | #171717 |  |  | **live** in 2, dead in 44 |
| `dark:text-green-400` | 10 | color | #4ade80 |  |  | **live** |
| `text-green-700` | 10 | color | #15803d |  |  | dead (always paired with a dark: override) |
| `dark:text-indigo-950` | 4 | color | #1e1b4b |  |  | **live** |
| `dark:hover:text-red-100` | 1 | color | #fee2e2 |  |  | **live** |
| `dark:text-red-200` | 1 | color | #fecaca |  |  | **live** |
| `dark:text-red-300` | 9 | color | #fca5a5 |  |  | **live** |
| `dark:text-red-400` | 32 | color | #f87171 |  |  | **live** |
| `dark:text-red-400/80` | 1 | color | #f87171 @ 0.8 | #c85c5c | #cb5f5f | **live** |
| `text-red-600` | 4 | color | #dc2626 |  |  | dead (always paired with a dark: override) |
| `text-red-600/80` | 1 | color | #dc2626 @ 0.8 | #b22020 | #b52323 | dead (always paired with a dark: override) |
| `text-red-700` | 38 | color | #b91c1c |  |  | **live** in 1, dead in 37 |
| `text-red-800` | 1 | color | #991b1b |  |  | dead (always paired with a dark: override) |
| `hover:text-red-900` | 1 | color | #7f1d1d |  |  | dead (always paired with a dark: override) |
| `text-white` | 6 | color | #ffffff |  |  | **live** in 2, dead in 5 |
| `via-gray-950/75` | 1 | gradient-to | #0a0a0a @ 0 |  |  | **live** (no dark: override) |
| `via-gray-950/75` | 1 | gradient-stops | `var(--tw-gradient-from), rgb(10 10 10 / 0.75) var(--tw-gradient-via-position), var(--tw-gradient-to)` |  |  | **live** (no dark: override) |

## 4. Fonts

| | Web | App before | App now |
|---|---|---|---|
| Sans | `src/app/fonts/GeistVF.woff`: Geist **v1.200** (Glyphs 3.2 build 3249), variable `wght` 100–900, 783 glyphs | Geist v1.801 static TTFs (975 glyphs) | static instances of the web VF: `design/web-parity/fonts/Geist-{Regular,Medium,SemiBold,Bold}.ttf` |
| Mono | `GeistMonoVF.woff`: Geist Mono v1.200, `wght` 100–900 | Geist Mono v1.801 Regular/Medium | `GeistMono-{Regular,Medium,SemiBold}.ttf` from the web VF |
| Vertical metrics (UPM 1000) | ascender 920, descender −220, lineGap 100 (hhea = typo; win 976/262) | 1005 / −295 / 0 | same as web |
| Loading | `next/font/local` in `layout.tsx`, CSS vars `--font-geist-sans` / `--font-geist-mono`, `weight: "100 900"`; `body` = `font-sans antialiased` | | `pubspec.yaml` `fonts:` block (see `design/tokens/README.md` §2) |
| Fallback stack | `ui-sans-serif, system-ui, sans-serif` / `ui-monospace, monospace` | | `PaperTypography.sansFallback` / `monoFallback` |

Notes on the fonts:

- **Weights used by the components:** 400 (`font-normal`, 10 uses, and the default), 500 (`font-medium`, 57), 600 (`font-semibold`, 48). There is no `font-bold`. 700 is still bundled for `<strong>` in explanation prose. Mono appears only in `font-mono text-[0.7rem]` (the animation time label) and in inline `code` (0.9em).
- **How the instances were made:**
  - Tool: fontTools 4.67 `varLib.instancer.instantiateVariableFont(font, {"wght": W}, updateFontNames=False)`.
  - Names: name IDs 1/2/4/6/16/17 were set to "Geist" / "Geist Mono" plus the style name.
  - `OS/2.usWeightClass` = W.
  - No outlines, metrics or glyphs changed.
  - `design/web-parity/fonts/` also keeps the untouched web WOFFs and `OFL.txt`.
  - SHA-256:
    - Regular `5346da75…`
    - Medium `6973b197…`
    - SemiBold `630f0cd7…`
    - Bold `d7b79fb1…`
- **License:** SIL OFL 1.1 (Vercel, "The Geist Project Authors"). Bundling in an app is allowed. Ship `OFL.txt` and keep the `LicenseRegistry` entry.
- **Why static and not the VF:** Flutter applies the `wght` axis only through explicit `FontVariation('wght', …)`. A `FontWeight` alone would render the 400 default, so static instances keep `FontWeight` working.
- **Rendering:** the web sets `-webkit-font-smoothing: antialiased`, which is grayscale AA on macOS. Flutter's default text rendering is already grayscale; nothing to set.
- **Line-height model:** Tailwind always sets an explicit `line-height`. In Flutter use `height: lineHeight / fontSize` with `TextLeadingDistribution.even`, which is what `PaperTypography._s` does. With these exact fonts, that reproduces CSS half-leading.

## 5. Type scale (Tailwind classes actually used)

| Class | px size / line-height | Uses | Typical web role | Dart |
|---|---|---|---|---|
| `text-[0.65rem]` | 10.4 / inherit | 2 | donut caption, counter chip | `PaperTypography.text0_65rem` |
| `text-[11px]` | 11 / inherit (16 inside text-xs, 20 inside text-sm parents; `leading-none` in 2) | 7 | tag/badge chips (500), eyebrow in popover / focus card (600 uppercase tracking-wide), card meta | `labelSmall` (11/16/500), `popoverTitle` |
| `text-[0.7rem]` | 11.2 / inherit | 1 | mono animation time label | `text0_7rem` |
| `text-xs` | 12 / 16 | 98 | meta, captions, small buttons, eyebrows | `bodySmall`, `caption`, `eyebrow`, `labelMedium` |
| `text-sm` | 14 / 20 | 118 | body, buttons, card titles, inputs | `bodyMedium`, `labelLarge`, `titleSmall`, `cardTitle`, `input` |
| `text-sm leading-relaxed` | 14 / 22.75 | 12 | explanation prose, popover body | `explanationBody`, `explanationBodyCompact` |
| `text-base` | 16 / 24 | 14 | featured-card title, zoom ± glyphs, × close glyphs (with `leading-none`) | `bodyLarge` |
| `text-lg` | 18 / 28 | 5 (+2 responsive) | section titles ("Projects", "Your papers"), reader header title | `titleLarge`, `sectionTitle` |
| `text-xl` | 20 / 28 | 1 | settings avatar initial | `headlineMedium` |
| `text-2xl` | 24 / 32 | 5 | page titles ("Library", "Settings", "Sign in", project name) | `headlineLarge`, `pageTitle` |
| `text-3xl` | 30 / 36 | 2 | donut percentage (tabular) | `displayMedium` |
| `text-4xl` → `sm:text-5xl` → `lg:text-6xl` | 36/40 → 48/48 → 60/60 | 1 | landing hero h1 (out of app scope) | `displayLarge` (36/40) |

- **Letter spacing:**
  - `tracking-tight`: −0.025em, 15 uses, on page and section titles and sidebar names. In Dart that is `size × −0.025`, e.g. −0.6 at 24px.
  - `tracking-wide`: +0.025em, 5 uses, on uppercase eyebrows. That is +0.3 at 12px and +0.275 at 11px.
- **Line-height modifiers:**
  - `leading-none`: 1, 5 uses.
  - `leading-tight`: 1.25, 1 use.
  - `leading-snug`: 1.375, 2 uses.
  - `leading-relaxed`: 1.625, 12 uses.
  - `leading-4`: 16px, 1 use.
- **Tabular numerals:** `tabular-nums` is used for the zoom %, donut and counters. In Flutter that is `FontFeature.tabularFigures()`.
- **Truncation and wrapping:**
  - `truncate` = single line with ellipsis.
  - `line-clamp-2` = `maxLines: 2` with ellipsis.
  - `break-words`.
  - `whitespace-pre-wrap` on explanations: keep newlines.
  - `text-balance` on the landing h1 only.

## 6. Spacing, sizes, layout

Tailwind unit = 4px (`PaperSpacing.tw(n)`). Steps used, with occurrence counts:

| Utility | Values (×4 px) |
|---|---|
| `gap` | 2 (45), 3 (19), 1 (18), 1.5 (14), 4 (10), 5, 6, 8, 10, 12 |
| `p` | 4 (13), 5 (10), 6 (9), 8 (9), 3 (6), 1, 2, 1.5 |
| `px` | 2.5 (26), 4 (22), 2 (19), 3 (12), 6 (11), 5, 1, 8, 1.5 |
| `py` | 1 (33), 3 (13), 2 (9), 0.5 (9), 1.5 (8), 10, 4, 12, 16, 24, 6, 8, 20, 2.5 |
| `mt` | 2 (29), 4 (29), 3 (21), 1 (17), 8 (11), 0.5 (7), 6, 1.5, 5 |
| `w` / `h` (fixed) | 4 (16px icons), 5 (20), 8 (32 icon buttons), 9 (36), 16 (64 thumbnails), 6 (24), 7, 10, 12, 20, 24, 28, 32, 40, 52, 56, 64, 80 (320 popovers), 96 (384 reader panel) |
| `max-w` | xs 320, sm 384 (sign-in column), md 448 (dialog), lg 512, 2xl 672 (focus card), 3xl 768, 5xl 1024 (header nav), 6xl 1152, 7xl 1280, `[20rem]` 320, `[calc(100vw-32px)]` |

Recurring compositions to reuse:

| Pattern | Spacing | Size |
|---|---|---|
| Card padding | `p-5` (20) default; `p-4` (16) for explanation and figure cards; `p-6`/`p-8` for empty states | |
| Page shell | `px-6` (24) horizontal, `py-16 sm:py-24` on sign-in; library/project use a 3-column grid (see M2/M3 screen specs) | |
| Reader header | `px-4 py-3`, gap 2 | 52 + 1px border |
| Reader explanation panel | `w-96`, sticky header `px-3 py-2` with border-b; cards gap 3 inside `p-4` | 384 |
| PDF pane | `px-6 py-6` around pages; pages are white with no border | |
| PDF view toolbar | `px-2 py-1 gap-1.5 rounded-md border shadow-sm`, sticky top, z-20 | |
| Selection popover | `p-1 gap-1 rounded-md shadow-lg`; buttons `px-3 py-1.5 rounded text-sm font-medium` | |
| Citation popover | `w-80 max-h-80 p-4 rounded-lg border gray-700 bg gray-900 shadow-xl` | |
| Floating explanation (mobile OS) | `w-[min(20rem,100vw-1rem)] max-h-[70vh] rounded-lg border gray-800 bg gray-950 shadow-xl`, z-40 | |
| Chips/badges | `rounded-full px-2 py-0.5 text-[11px] font-medium` | |
| Small action | `rounded-md px-2.5 py-1 text-xs font-medium` (+1px border) | 26 tall |

- **Breakpoints** are Tailwind's: sm 640, md 768, lg 1024, xl 1280, 2xl 1536 (`PaperBreakpoints.tw*`). The app keeps its own window classes (600/840/1200/1600) for nav chrome. Where a screen spec says "at `lg:` the sidebar becomes a column", switch at 1024.
- **Mobile-OS behaviour** (it matters for the Android build):
  - The web reader detects a mobile OS (`isMobileOs()`, user agent). There it **removes** the docked panel and shows `FloatingExplanationPopover` anchored to the explained term instead.
  - The `reader-android.*` screenshots show that path at tablet sizes.
  - The desktop UA shows the docked 384px panel (`reader.*`).
  - Which one the app mirrors on Android tablets is an M2/M3 decision; both are captured.

## 7. Radii

| Class | px | Uses | Where | Dart |
|---|---|---|---|---|
| (marks) | 2 | — | every PDF mark rect, highlight wash | `PaperRadii.xs`, `PaperHighlightColors.cornerRadius` |
| `rounded` | 4 | 17 | selection-popover buttons, small chips, figure crops | `PaperRadii.sm` |
| `rounded-md` | 6 | 28 + all `.btn-*` / `.field-input` | buttons, inputs, icon buttons, toolbar, selection popover | `PaperRadii.md` |
| `rounded-lg` | 8 | 21 + `.card` | cards, popovers, dialog, toasts, sidebar avatar | `PaperRadii.lg` |
| `rounded-xl` | 12 | 4 | featured paper cards, focus card | `PaperRadii.xl` |
| `rounded-2xl` | 16 | 1 | landing upload card | `PaperRadii.xxl` |
| `rounded-full` | 9999 | 27 | chips, avatars, pills, donut | `PaperRadii.full` |

## 8. Borders, rings, focus

| Item | Value |
|---|---|
| Hairline | `border` 1px (41 uses), with `-b` (9), `-t` (3) and `-l` (1). The colour is almost always `dark:border-gray-800` (#262626, structure) or `dark:border-gray-700` (#404040, controls and popovers). |
| Dashed | `border-dashed` 1px: empty figure placeholder, landing drop zone |
| `border-2` | 1 use (landing drop zone) |
| Focus ring | `focus-visible:ring-2 ring-accent ring-offset-2`: 2px `#818cf8` outside a 2px gap. The gap is `ring-offset-gray-950` (#0a0a0a) on the page and `ring-offset-gray-900` (#171717) inside cards. There are 39 uses. Variants: `ring-offset-1` (popover buttons), `focus-visible:outline-2 outline-offset-1/2 outline-accent` (5 uses, same visual), `ring-red-500` (destructive) and `ring-white` (thumbnail overlay). |
| Input focus | `focus:border-accent focus:ring-1 focus:ring-accent`: a 2px accent edge with no offset |
| Mark focus | 2px `#4f46e5` box-shadow ring (`--mark-focus-ring`) |
| Mark hover ring | 1.5px opaque family ring |
| Figure outline | 1.5px dashed `#4f46e5` with offset 2. Hover opacity .7, saved .55, saved+hover 1. Radius 4. |
| `ring-1` hairlines | `dark:ring-white/10` on avatar and thumbnail edges, `ring-gray-950/10` (dead in dark) |

Dart: `PaperElevation.borderWidth` 1, `borderStrong` 1.5, `focusRingWidth` 2, `focusRingOffset` 2.

## 9. Shadows, blur, opacity

| Class | Value | Uses | Where | Dart |
|---|---|---|---|---|
| `shadow-sm` | `0 1px 2px 0 rgb(0 0 0/.05)` | 7 | PDF toolbar, show-panel button, accent buttons | `PaperElevation.shadowSm` |
| `shadow-md` | `0 4px 6px -1px /.1, 0 2px 4px -2px /.1` | 4 | toasts, HUD bubbles | `shadowMd` |
| `shadow-lg` | `0 10px 15px -3px /.1, 0 4px 6px -4px /.1` | 3 | selection popover, back-to-page pill | `shadowLg` |
| `shadow-xl` | `0 20px 25px -5px /.1, 0 8px 10px -6px /.1` | 5 | citation popover, floating explanation, dialog | `shadowXl` |
| `shadow-2xl` | `0 25px 50px -12px rgb(0 0 0/.25)` | 1 | focus card | `shadow2xl` |
| `backdrop-blur-sm` / `-md` | 4px / 12px | 1 / 3 | thumbnail overlay button / toasts and pills | `ImageFilter.blur(sigma ≈ px/2)`; perf: only on small fixed overlays |
| `disabled:opacity-50` / `60` / `70` | .5 / .6 / .7 | 9 / 2 / 1 | disabled controls | `PaperTheme` uses .5 |
| Text opacity | `dark:text-red-400/80` | 1 | error hint | `PaperWeb.red400.withValues(alpha: .8)` |

All shadows keep their black alpha in dark mode. They are barely visible on #0a0a0a, but they are part of the look, so include them on overlays.

## 10. Motion

| Token | Value | Where | Dart |
|---|---|---|---|
| Tailwind `transition-colors` (27), `transition-transform` (3), `transition-shadow` (1) | 150ms `cubic-bezier(.4,0,.2,1)` | every hover/press colour change, chevron rotate | `PaperMotion.colors` + `standard` |
| `duration-150` | 150ms | glossary chevron rotate 90° | `fast` |
| Mark reveal / settle / press / hover delay | 150 / 200 / 80 / 40 ms; reveal `(0,0,.2,1)`, settle `(.4,0,.2,1)` | PDF marks, figure outline | `fast` / `base` / `instant` / `hoverDelay` |
| Mark grow | scale 1.02 (lines), 1.04 (words) | | `markHoverScale` / `termHoverScale` |
| `animate-spin` | 1s linear infinite | spinners (`spinner.svg`) | `spin` |
| `animate-pulse` | 2s `(.4,0,.6,1)`, opacity 1→.5→1 | figure crop skeleton | `pulse`, `pulseCurve` |
| `animate-progress-indeterminate` | 1.2s ease-in-out, translateX −100%→300% | explanation progress bar | `progressIndeterminate` |
| Focus lock | backdrop 300, enter 420, nudge 320, pulse 400, card pulse 600, exit 800 | focus lock only | `backdrop`, `emphasis` |
| Route change | **none** (instant) | Next.js navigation | `page` (300ms fade) kept for the app shell. **Flag for design-motion:** set it to `Duration.zero` for strict parity. |
| Reduced motion | `motion-reduce:transition-none`; marks change instantly with no scale; focus lock goes opacity-only ≤150ms | | `PaperMotion.of` / `fade` |

The disclosure panels ("Add a paper", "Read papers") have **no** open animation: `animate-expand-in` is undefined. Only the chevron rotates 180° over 150ms.

## 11. Z-order (reader contract)

| z | Web layer | Dart `PaperLayer` |
|---|---|---|
| 2 | pdf.js text layer | `highlightWash` |
| 10 | citation / appendix hotspots, selection popover, sticky panel header | `citationHotspot`, `selectionPopover` |
| 20 | PDF view toolbar (sticky), "show explanations" button, back-to-page pill, toasts | `readerChrome` |
| 25 | focus-lock backdrop | `focusBackdrop` |
| 30 | citation popover | `citationPopover` |
| 32 | focus card | `focusCard` |
| 40 | floating explanation popover (mobile OS) | `floatingExplanation` |
| 45 / 46 | focus HUD / focus toast | `hud` / `toast` |
| 50 | dialogs (feedback, Obsidian disconnect) | `dialog` |

## 12. Contrast (dark, WCAG)

| Pair | Ratio | AA? |
|---|---|---|
| gray-100 `#f5f5f5` on `#0a0a0a` / `#171717` | 18.16 / 16.44 | yes |
| gray-200 `#e5e5e5` on `#171717` | 14.23 | yes |
| gray-300 `#d4d4d4` on `#171717` / `#262626` | 12.09 / 10.21 | yes |
| gray-400 `#a3a3a3` on `#0a0a0a` / `#171717` / `#262626` | 7.85 / 7.11 / 6.00 | yes |
| gray-500 `#737373` on `#0a0a0a` / `#171717` | 4.18 / 3.78 | **no** for body text (web parity: chevrons, rare meta) |
| accent `#818cf8` on `#0a0a0a` / `#171717` | 6.64 / 6.01 | yes |
| indigo-950 on accent / accent-hover | 5.36 / 8.02 | yes |
| indigo-950 on accent in the small accent buttons (CitationPopover "Add to library", FigureHighlightsPanel save: `text-white … dark:text-indigo-950`) | 5.36 | yes (the light `text-white` is dead; white only paints on thumbnails, over the dark gradient or `bg-gray-950/70`) |
| accent-ink on accent-soft | 10.72 | yes |
| red-400 on `#0a0a0a` / `#171717`; red-300 on red-950 | 7.16 / 6.48; 8.51 | yes |
| green-400 / amber-400 on `#171717` | 10.29 / 10.74 | yes |
| input / secondary border gray-700 on gray-900 | 1.73 | **no** for UI (3:1); web parity, as the brief says "match the web exactly" |
| focus ring `#818cf8` on `#0a0a0a` | 6.64 | yes |
| mark focus ring `#4f46e5` on white paper | 6.29 | yes |
| disabled gray-600 on `#171717` | 2.29 | exempt |

## 13. Icons

**The web uses no icon library.** `package.json` has no lucide, heroicons or react-icons. Every glyph is an inline SVG path, an outline stroke in `currentColor` with round caps and joins, or a text character. To get pixel parity, ship the **exact SVGs**. They are extracted to `design/web-parity/icons/*.svg`, with `stroke="currentColor"` and the original viewBox and stroke width.

- **Render them** with `flutter_svg` (`SvgPicture.asset(path, width: 16, colorFilter: ColorFilter.mode(color, BlendMode.srcIn))`), or hand-port them to a `CustomPainter`. Both reproduce the stroke widths.
- **Lucide is only a fallback.** The "closest Lucide" column is for a quick prototype with `lucide_icons_flutter`. Lucide glyphs are drawn at stroke 2 in a font, so they cannot match the web's 1.5/1.75 strokes, and several shapes differ (sharp vs rounded file corner, mirrored bar chart).
- **Remove `material_symbols_icons` usage** from the restyled screens.

| SVG asset | viewBox / stroke | Rendered size (Tailwind) | Colour (dark) | Where (web file) | Closest Lucide (fallback) |
|---|---|---|---|---|---|
| `chevron-down.svg` | 24 / 1.5 | 16 (`h-4`); rotates 180° when open, 150ms | inherits button label | AddPaperDisclosure, ReadPapersDisclosure | `chevron-down` (same path) |
| `chevron-right-small.svg` | 16 / 2 | 14 (`h-3.5`); rotates 90° when expanded | gray-500 | GlossaryEntryCard | `chevron-right` |
| `reader-back.svg` | 20 / 1.75 | 20 (`h-5`) | gray-400, hover gray-100 on gray-800 | reader header back (`library/[paperId]/page.tsx`) | `chevron-left` |
| `nav-back.svg` | 24 / 1.5 | 16 | gray-400 / active accent-ink | DashboardSidebar "Library" (project page) | `chevron-left` |
| `nav-dashboard.svg` | 24 / 1.5 | 16 | same | DashboardSidebar "Dashboard" | `layout-dashboard` |
| `nav-statistics.svg` | 24 / 1.5 | 16 | gray-600 (disabled item) | DashboardSidebar "You Statistics" | `chart-no-axes-column` (mirrored) |
| `nav-profile.svg` | 24 / 1.5 | 16 | same | DashboardSidebar "Profile" | `user-round` |
| `nav-papers.svg` | 24 / 1.5 (round caps) | 16 | same | DashboardSidebar "Papers" | `file` |
| `lines.svg` | 24 / 1.5 | 16 (sidebar "Glossary"), 12 (`h-3`, featured-card "N terms") | inherits | DashboardSidebar, FeaturedPaperCard | `text-align-start` |
| `file.svg` | 24 / 1.5 (no caps) | thumbnail placeholder (`row` 20, `hero` 40) | gray-600 | PaperThumbnail | `file` |
| `bookmark.svg` | 24 / 1.5 | 12 | inherits (gray-200 on card) | FeaturedPaperCard "Unread/Read" | `bookmark` |
| `highlighter.svg` | 24 / 1.5 | 12 | same | FeaturedPaperCard "N highlights" | `highlighter` |
| `panel-hide.svg` | 20 / 1.75 | 20 in a 32 button | gray-400 | reader panel header "Hide explanations" | `panel-right-close` (shape differs) |
| `panel-show.svg` | 20 / 1.75 | 20 in a 36 bordered button | gray-300 | "Show explanations" (top-right of PDF pane) | `panel-right-open` (shape differs) |
| `timer.svg` | 24 / 1.75 | 16 (HUD) / 20 (redirect screen) | accent | FocusLockHud, FocusRedirectScreen | `timer` |
| `check.svg` | 24 / 2 | 16 | green-400 | FocusLockHud done | `check` (same path) |
| `alert-circle.svg` | 24 / 1.75 | 16 | red-400 | FocusLockHud error | `circle-alert` |
| `toast-check.svg` | 16 / 1.75 | 16 | green-400 | CiteAddToast success | `check` |
| `toast-error.svg` | 16 / 1.75 + 1.5 circle | 16 | red-400 | CiteAddToast error | `circle-alert` |
| `spinner.svg` | 16 / 2 (track opacity .25) | 16, spins 1s linear | accent | CiteAddToast pending, LandingUpload | `loader-circle` (different arc) |
| `info.svg` | 20 / 1.75 | 16 | inherits (gray-300) | MatchNotice | `info` |
| `info-small.svg` | 16 / 1.5 | 16 | inherits | LandingUpload error | `info` |
| `file-upload.svg` | 24 / 1.5 | 24 | accent | LandingUpload drop zone (landing only) | `file-up` |

Non-icon graphics, to draw with a `CustomPainter`:

- `ReadMeter`: a 40×16 sparkline polyline `1,12 8,5 15,11 22,3 29,10 39,6`.
  - Read: stroke 2 in accent.
  - Unread: stroke 1.5 gray-500, dashed `3 3`.
- `ProgressDonut`: a 36-unit viewBox, r 15.9155, stroke 3.5.
  - Track: gray-700.
  - Arc: accent with round caps, starting at 12 o'clock.

Text glyphs, rendered in Geist and **not** icons:

| Glyph | Where | Style |
|---|---|---|
| `×` | ExplanationSidebar, CitationPopover and CiteAddToast close | `text-base leading-none` in 24/32 buttons |
| `−` / `+` | PDF zoom | `text-base leading-none` |
| `···` | table row overflow | |
| `↗` | external link | |
| `↩` | back-to-page pill | |
| `🖍` | selection popover "Highlight" | emoji |

Keep these as `Text`, not `Icon`, so the glyph shapes match.

## 14. Web-only features and quirks seen while capturing

- **Focus time (focus lock).** Clicking any cached term or explaining a selection starts a 3-minute lock:
  - blurred backdrop (z-25)
  - lifted paragraph card (z-32)
  - "Focus time 2:59" HUD pill (z-45)

  This is captured in `reader*.term-click-focus-lock.*`. The app has no focus lock, and the brief says "no new features", so this is reference only. On a mobile OS the floating explanation popover opens on top of the focus card (`reader-android.term-click-focus-lock.*`).
- **Settings "switch".** The Beta toggle is a native 20×20 `<input type="checkbox" role="switch">`, not a track-and-thumb switch. `text-accent` has no effect on a native checkbox. Map the app's `Switch` usages on restyled screens to a 20px rounded-4 checkbox, accent when checked.
- **Sticky dashboard sidebar overlaps the full-width glossary section** when scrolled at `xl` (visible in earlier capture runs). This is a web layout bug; do not reproduce it.
- **RPR production build bug, out of scope.** `next build` minifies an author-year citation regex into an invalid unicode escape (`\p{Lu}|…)\\\b` with the `u` flag). As a result, `/library/[paperId]` SSR throws `SyntaxError: Invalid regular expression` and the page falls back to client rendering, with **no citation hotspots**. That is why no citation popover could be captured. If it happens on the live site too, it needs an RPR fix.
- No in-scope button paints white text on the dark accent. Every `bg-accent` button carries `dark:text-indigo-950` (#1E1B4B, 5.36:1), including CitationPopover "Add to library" and FigureHighlightsPanel save. `text-white` is live only on thumbnails: the FeaturedPaperCard title and the overlay "Remove" button.

## 15. Token changes (old → new)

App tokens before this change were `design/tokens` v1.0.0. The new values equal the web.

### Theme and colours

| Token | Old | New | Why |
|---|---|---|---|
| Theme mode | light + dark, `ThemeMode.dark` default, Settings toggle | **dark-only**; `PaperTheme.light()` = dark; JSON `color.light` removed | web is dark-only |
| `PaperColors.light.*` (all 46) | light palette (`#FAFAFA` bg, `#4F46E5` primary, …) | alias of `PaperColors.dark` | same |
| `PaperColors.dark.surfaceRaised` | `#262626` | `#171717` | popovers are gray-900 + border + shadow |
| `.secondary` | `#D4D4D4` | `#E5E5E5` | `.btn-secondary dark:text-gray-200` |
| `.outline` | `#737373` (AA deviation) | `#404040` | `.field-input` / `.btn-secondary dark:border-gray-700` |
| `.outlineVariant` | `#404040` | `#525252` | gray-600 HUD / hover rings |
| `.scrim` | `#0A0A0A` @ .55 | `#0A0A0A` @ .60 | dialog backdrop `rgba(10,10,10,.60)` |
| `.inverseSurface` / `.onInverseSurface` / `.inversePrimary` | `#E5E5E5` / `#171717` / `#4F46E5` | `#171717` / `#F5F5F5` / `#818CF8` | web toasts are dark cards, not inverted |
| `.selection` | `#818CF8` @ .35 | `#4F46E5` @ .30 | `.textLayer ::selection` |
| `PaperWeb` | — | new: gray ramp, CSS vars, red/green/amber, composited variants | exact Tailwind names |
| `PaperHighlightColors.whitePaper.restAlpha` | 0.40 | **0.10** | `--highlight-wash-opacity` |
| JSON `color.highlight.precomputed.whitePaper.*` | `#…66` | `#…1a` | follows rest alpha |

### Elevation, sizes and layers

| Token | Old | New | Why |
|---|---|---|---|
| `PaperElevation.shadow2/3(dark)` | none | `shadowLg` / `shadowXl` | web keeps Tailwind shadows in dark |
| `PaperElevation.shadow2Light` / `shadow3Light` | `0 1 3 /.1` / `0 4 6 -1 /.1` | `shadowLg` / `shadowXl` | Tailwind values |
| `PaperElevation.shadowSm…shadow2xl` | — | new | Tailwind shadows |
| `PaperIconSize.navigation` | 24 | 16 | sidebar glyphs `h-4` |
| `PaperIconSize.xxs` | — | 12 | `h-3` card glyphs |
| `PaperHitTarget.touchMin` / `stylusMin` | 48 / 40 | 32 / 32 | brief: web sizes, no enlargement |
| `PaperHitTarget.buttonHeightTouch` | 48 | 36 | `.btn-*` |
| `PaperHitTarget.borderedControlHeight` / `smallButtonHeight` / `iconButton*` | — | 38 / 26 / 32, 36, 24 | web controls |
| `PaperLayer.selectionPopover` / `citationPopover` / `floatingExplanation` | — | 10 / 30 / 40 | web z contract |

### Motion, breakpoints, chrome and spacing

| Token | Old | New | Why |
|---|---|---|---|
| `PaperMotion.colors` / `backdrop` / `spin` / `pulse` (+`pulseCurve`) / `progressIndeterminate` | — | 150 / 300 / 1000 / 2000 / 1200 ms | Tailwind + globals.css |
| `PaperBreakpoints.sidePanelMedium` / `Expanded` / `Large` / `ExtraLarge` | 360 / 360 / 380 / 420 | 384 (all) | web panel `w-96` |
| `PaperBreakpoints.tw*`, `maxW*`, `readerPanelWeb` | — | 640…1536, 320…1280, 384 | Tailwind |
| `PaperChrome.readerToolbarCompact` / `Touch` / `Pointer` | 56 / 64 / 48 | 52 / 52 / 52 | reader header `px-4 py-3` + `text-lg` |
| `PaperSpacing.tw*`, `tw(n)` | — | Tailwind steps | |

### Typography

| Token | Old | New | Why |
|---|---|---|---|
| `PaperTypography.labelSmall` | 11/16 w600 +0.44 | 11/16 w500 0 | badges `text-[11px] font-medium` |
| `.explanationBody` | 16/26 textPrimary | 14/22.75 textSecondary (#D4D4D4) | `text-sm leading-relaxed dark:text-gray-300` |
| `.explanationBodyCompact` | 14/22 textSecondary | 14/22.75 #E5E5E5 | CitationPopover body |
| `.popoverTitle` | letter-spacing 0.44 | 0.275 | `tracking-wide` at 11px |
| `.glossaryTerm` | 15/22 w600 | 14/20 w600 | `text-sm font-semibold` |
| `.noteBody` | 15/24 textPrimary | 14/22.75 textSecondary | same as explanation prose |
| `.pageIndicator` | GeistMono 12/16 w500 | Geist 12/16 w400 tabular | zoom label `text-xs tabular-nums` |
| `.code` | 13/20 mono | 12.6/22.75 mono | `font-mono text-[0.9em]` in prose |
| `PaperTypography.input` / `pageTitle` / `sectionTitle` / `cardTitle` / `eyebrow`, `text*` / `leading*` constants | — | new | web roles |

### PaperTheme

| Token | Old | New | Why |
|---|---|---|---|
| `splashFactory` | InkRipple (android) / NoSplash | NoSplash everywhere; `splashColor` / `focusColor` transparent | web has no ripples |
| `visualDensity` | standard (android) / compact (desktop) | standard everywhere | compact would shave 8px off 36px buttons |
| `materialTapTargetSize` | padded (android) / shrinkWrap | shrinkWrap everywhere | web sizes |
| `iconTheme` | 20, textSecondary | 16, textMuted | `h-4`, gray-400 |
| `appBarTheme` | bg surface/background, 56/48 tall, titleMedium | bg `#0A0A0A`, 52, titleLarge (18/28 −0.45), icons gray-400 | reader header |
| `inputDecorationTheme` | dense on desktop, padding 12×(8 or 12), focus 1.5, error `#F87171` | always dense, 12×9 (38 total with 14/20 text), focus 2px accent, error border `#EF4444`, disabled border 50% | `.field-input` |
| Filled button | min 64×48/36, disabled label .7 | min 0×36, padding 16×8, disabled label .5 | `.btn-primary` |
| Outlined button | min 64×48/36, label textPrimary, border `#737373` | min 0×38, label `#E5E5E5`, border `#404040`, fill `#171717`/hover `#262626` | `.btn-secondary` |
| Text button | label textSecondary, pressed outlineVariant | label `#A3A3A3`, hover `#262626` + `#F5F5F5`, pressed `#404040` | `.btn-ghost` |
| Icon button | 48/32 min, glyph textSecondary | 32 min, padding 0, glyph gray-400, hover gray-800 + gray-100 | web icon buttons |
| `dialogTheme` | radius 12, title titleLarge, body textSecondary | radius 8, border gray-800, title titleSmall (14/600), body gray-400 | dialog card |
| `snackBarTheme` | bg `#E5E5E5`, width 420 desktop | bg `#171717` + 1px `#262626` border, radius 8, width 320 | toasts |
| `tooltipTheme` | inverse surface, radius 4 | `#171717` + `#404040` border, radius 6 | the web has only native tooltips; dark card |
| `listTileTheme.minTileHeight` | 52 / 44 | 44 | |

### Fonts

| Token | Old | New | Why |
|---|---|---|---|
| Geist / Geist Mono files | v1.801 static TTFs (`assets/fonts`) | v1.200 instances of the web VF (`design/web-parity/fonts`), + GeistMono SemiBold | exact web glyphs and metrics |

Unchanged:

- Radii (already Tailwind).
- Mark families and their values.
- Motion durations and curves.
- `PaperWindowClass` thresholds (600/840/1200/1600).
- Status colours (app-only sync UI).
