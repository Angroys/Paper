# Web reference screenshots (M1)

These are pixel references of the paper.college web app for the Flutter restyle. They were all taken with headless Chromium (Playwright 1.61.1, `chromium-1228`) at `deviceScaleFactor: 1`, `colorScheme: "dark"`, `reducedMotion: "reduce"`. The landing hero is WebGL, so the flags are `--use-gl=swiftshader --enable-unsafe-swiftshader`.

There are two viewports:

- **1280×800**: landscape tablet / laptop.
- **800×1280**: portrait tablet.

The file naming is `<screen>[.<state>].<width>x<height>.png`. A `.full.` file is the whole scrollable page, not just the viewport.

Captured 2026-10-21 with `capture.mjs` in this folder.

## How each screen was captured

| Screen | Files | Source | URL / route |
|---|---|---|---|
| Landing (signed-out) | `landing.*`, `landing.full.*` | **live** | https://www.paper.college/ |
| Sign in | `sign-in.*`, `sign-in.focus-email.*` (keyboard focus on the email field) | **live** | https://www.paper.college/sign-in |
| Library (dashboard) | `library.*`, `library.full.*`, `library.add-paper-open.*` | **local** | `/library` |
| Project page | `project.*`, `project.full.*` | **local** | `/projects/<id>` |
| Glossary | `glossary.*` (search field + tag filters + entry list), `glossary.entry-expanded.*`, `glossary.search.*` ("diff" typed) | **local** | `/projects/<id>`, glossary section. The web has no standalone glossary page: `/glossary` redirects to `/library`. The glossary lives on project pages and in the reader side panel. |
| Settings | `settings.*` | **local** | `/settings` |
| Reader, desktop UA (docked explanation side panel, 384px) | `reader.*` (default), `reader.selection-popover.*`, `reader.highlight-rest.*`, `reader.highlight-hover.*`, `reader.mention-hover.*` (teal in-doc link), `reader.term-hover.*` (blue cached term), `reader.panel-hidden.*`, `reader.term-click-focus-lock.*` | **local** | `/library/<paperId>` |
| Reader, Android-tablet UA (mobile OS: no docked panel, floating explanation popover) | `reader-android.*`, the same states | **local** | `/library/<paperId>` with `userAgent` = Android 14 tablet Chrome, `hasTouch` |

Live and local mean:

- **live:** the production site, signed out. Every request to Supabase `/auth/v1/signup` is aborted by the script, and no session is created: the landing and sign-in pages only *read* the session.
- **local:** RPR built and served on this machine (`next build` + `next start`, no file edits). It runs against `mock-supabase.mjs`, an in-memory stand-in for Supabase Auth, PostgREST and Storage.
  - The signed-in user, papers, projects and glossary terms are fixtures in that file.
  - The session cookie is minted locally.
  - **No Supabase user, real or anonymous, was created**, and the real project was never contacted.
  - `AZURE_API_KEY` / `MANIM_*` were blanked for the run, so no AI call can leave the machine.
  - The cached-term explanations shown are fixture text.
  - The PDF is arXiv 2312.12540v5 ("Lightning-Fast Image Inversion and Editing…", ICLR 2025). It is read from a local path and is not committed.

### Not capturable

These are derived from component source; see `design/web-parity/tokens.md`:

| What | Why |
|---|---|
| **Citation popover** (`CitationPopover.tsx`) | RPR's production build minifies the author-year citation regex into an invalid unicode escape, so `/library/[paperId]` SSR throws and the reader renders without citation hotspots (tokens.md §14). `next dev` cannot be used instead because pdfjs-dist 5 crashes under the dev webpack runtime. Its box: `w-80 max-h-80 rounded-lg border-gray-700 bg-gray-900 p-4 shadow-xl`, z-30. |
| **Figure highlights panel**, **cite-add toast**, **match notice**, **Obsidian connect / disconnect dialog**, **beta toggle** | They need data or flags (saved figure crops, an in-flight "add to library", an auto-matched paper, a connected vault, `is_beta`) that the fixtures do not include. Their classes are in the source and resolved in tokens.md §2–§3. |

### Web-only feature in the captures

`*.term-click-focus-lock.*` shows the web's **Focus time** lock: clicking a cached term starts a 3-minute focus lock (blurred backdrop, lifted paragraph card, HUD pill). The app does not have this feature. These shots are references for the explanation card and floating popover only. In the Android shots the floating explanation popover is drawn over the focus card. In the desktop shots the new card appears at the top of the side panel.

## Reproduce

Prerequisites:

- RPR checkout at `/home/minimax/research-paper-helper` (override with `RPR_DIR`), with `node_modules` installed.
- `npx playwright install chromium` done.
- Nothing is installed into this repo: `capture.mjs` loads Playwright from RPR's `node_modules`.

```bash
cd design/web-parity/reference

# 1. Live, signed-out screens
node capture.mjs live .

# 2. Local, signed-in screens
PDF_PATH=/path/to/any-paper.pdf node mock-supabase.mjs &          # :54399

cd "$RPR_DIR"
export NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54399 \
       NEXT_PUBLIC_SUPABASE_ANON_KEY=mock-anon-key \
       SUPABASE_SERVICE_ROLE_KEY=mock-service-key \
       AZURE_API_KEY= MANIM_RENDER_URL= MANIM_RENDER_TOKEN= \
       NEXT_TELEMETRY_DISABLED=1
npx next build && npx next start -p 3000 &                         # writes only RPR's gitignored .next/

cd -
node capture.mjs local .
# then stop next-server and mock-supabase
```

How it works:

- `mock-supabase.mjs` serves:
  - `/auth/v1/user` (the fixture user) and `/auth/v1/token`.
  - `/auth/v1/signup`, which always returns **403**.
  - PostgREST GET/HEAD/POST/PATCH with `eq` / `in` / `is` filters, `order`, `limit` and single-object `Accept`.
  - Storage signed URLs and the object download, which returns the `PDF_PATH` file.
  - `POST /__reset`, which restores the seed data. `capture.mjs` calls it before each viewport pass so every pass starts from the same state.
- The session cookie is `sb-127-auth-token` = `base64-` + base64url(JSON session) with an unsigned JWT, the `@supabase/ssr` format for a project URL on `127.0.0.1`.
- RPR's git status was checked before and after the runs: no tracked file changed.

## Token extraction (feeds `tokens.md` §3)

`token-extraction/` holds three scripts. Run them from an empty directory, in this order:

```bash
node .../extract-classes.cjs /home/minimax/research-paper-helper .   # files.txt, generated.css, classes.json
node .../dead-light-classes.cjs /home/minimax/research-paper-helper  # live.json
node .../colour-table.cjs                                            # colors.md = tokens.md §3
```

- `extract-classes.cjs` tokenises every string literal in the 63 in-scope `.tsx` files. It then compiles the tokens with RPR's own `tailwindcss` 3.4.19 and `tailwind.config.ts`, so every resolved value is Tailwind's real output.
- `dead-light-classes.cjs` marks light classes that a `dark:` sibling in the same literal always overrides.
- `colour-table.cjs` resolves the CSS vars to their `.dark` values and composites opacity variants over `#0a0a0a` and `#171717`.

Re-running them on the 2026-10-21 RPR checkout reproduces `tokens.md` §3 byte for byte.
