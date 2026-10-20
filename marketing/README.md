# Paper apps — marketing copy

Launch copy for the native Paper apps (Android tablets, Windows, macOS). Source English (en-US) only.

## Files

| File | What it holds |
| --- | --- |
| `landing-download.md` | paper.college/download: SEO/OG, hero, download buttons + requirements, 6 feature blocks, offline, sync, FAQ (8), footer CTA |
| `store-google-play.md` | Play listing: name, short + full description, category/tags, feature graphic headline, 8 tablet screenshot captions, v1.0 notes |
| `store-microsoft.md` | Microsoft Store listing: name, short description, description, 12 features, 7 search terms, 8 captions, v1.0 notes, category |
| `store-mac-app-store.md` | Mac App Store listing: name, subtitle, promo text, description, keywords, category, 8 captions, v1.0 notes |
| `check_limits.py` | Char-limit gate. Run `python3 marketing/check_limits.py` after any edit; it rewrites every `_Chars: N / L_` line and exits 1 on an overrun |

## Primary tagline

**Read any paper without getting stuck.**

This is the live paper.college hero (`LANDING_COPY.hero.headline` in the web app). Reusing it keeps the apps and the web as one product. On the download page it gains a second sentence: *"Read any paper without getting stuck. Now offline too."*

Other options:

| Option | Use when |
| --- | --- |
| Read any paper without getting stuck. **(primary)** | Everywhere: store feature graphic, descriptions, footer |
| Your papers, smooth and offline. | Speed/offline-led ads; apps-only surfaces |
| One library, everywhere you read. | Sync-led messaging (web users who add a device) |
| Read papers. Get unstuck. | Space-tight slots (Mac subtitle, 25 chars) |

## Messaging pillars

1. **Smooth on long PDFs.** Native page rendering keeps scroll and zoom fluid in long, figure-heavy papers. Proof: reader screenshots, short screen recording. Never state an fps number until engineering measures it on target devices.
2. **Mark it your way.** Text, term and figure highlights; stylus on Android tablets; notes in split view; keyboard shortcuts on desktop.
3. **Get unstuck in place (online).** Plain-English explanations (everyday analogy first, then the precise definition), a self-building glossary, citation lookup, short visuals. Always tag as needing internet.
4. **Keep reading offline.** Downloaded papers, highlights and notes work with no connection and sync on reconnect.
5. **One library, everywhere.** Same Google/email account as paper.college; library syncs across app and web.

## Voice

Matches the web app's existing voice ("warm-technical — active, matter-of-fact + one spark", Grade ~8; see RPR `design/copy/cite-add-copy.md` and `landing-copy.ts`).

| Dimension | Position | Why |
| --- | --- | --- |
| Funny ↔ serious | Mostly serious, one light touch per section ("library basement") | Readers are researchers under time pressure |
| Formal ↔ casual | Casual-leaning, plain words, contractions in web copy | Matches paper.college ("No account needed.") |
| Respectful ↔ irreverent | Respectful | Never mock the reader for being stuck |
| Enthusiastic ↔ matter-of-fact | Matter-of-fact | No "!", no superlatives, no ranking claims |

Rules used: sentence case headings, headlines end with a period, "plain-English" (hyphenated), "paper.college" lowercase, AI features always marked as needing internet, no pricing, no user numbers, no ratings, no iOS/Linux, no on-device AI, no privacy claims beyond "your library is tied to your account".

## Claims to verify before publishing

Marked **[VERIFY]** inline. Summary:
1. Minimum OS versions (Android 8.0 / Windows 10–11 64-bit / macOS 10.15, Apple silicon + Intel) — placeholders from Flutter defaults.
2. Store links live at launch vs. direct downloads (CI ships unsigned debug builds only; no store submission in v1 scope).
3. "Smooth on long PDFs" and the "80-page" example on real target hardware.
4. Android phones: excluded from Play device catalog, or installable?
5. Guest → account merge (RPR #82) carries papers, highlights and notes, so the FAQ answer is true.
6. Privacy FAQ line ("Other users can't see your papers, highlights or notes") — confirm with RLS owner.
7. Stylus highlighting is Android-tablet-only in v1 (copy does not claim pen on Windows/Mac).
8. Visual explanations, citation open-access lookup and glossary all reachable from the app (depends on the RPR bearer-token risk in the CEO brief). If AI is stubbed in v1, remove pillar 3 lines from stores and the download page.
9. Importing by link needs internet; offline library browsing works.
10. Play tag names and Microsoft subcategories against the live consoles; Apple support URL exists.

## Localization

Source-only. Translators: "getting stuck" / "get unstuck" means "confused and unable to continue reading" — translate the meaning, not the idiom. "Library basement" may be swapped for any place with no signal.
