# Paper app: voice and microcopy guide

Source strings: `design/copy/app_en.arb` (English, Flutter gen-l10n template).
Voice comes from paper.college: the landing page ("Read any paper without getting stuck."), the import and auth messages, the explain flow (an everyday analogy first, then the precise definition), and `design/copy/*.md` in the web repo. The app sounds like the website, written for a tablet or desktop.

## Who we write for

Students and researchers who read papers and get stuck on terms. They are smart and short on time. Reading level is about Grade 8: short words, short sentences, no jargon in the interface itself. The papers are hard enough.

## Voice dials

| Dimension | Position | Why |
| --- | --- | --- |
| funny ↔ serious | Slightly serious, warm | People open Paper to study. Never make a joke in an error. |
| formal ↔ casual | Casual and clear | "Paste a link", not "Provide a URL". Contractions in body text are fine ("Couldn’t", "You’re"). |
| respectful ↔ irreverent | Respectful | Treat the reader as a smart adult. No baby talk, no blaming the user. |
| enthusiastic ↔ matter-of-fact | Matter-of-fact | Say what happened and what to do next. At most one bright line per screen (for example, onboarding). No exclamation marks. |

## Rules

1. **Say what happened, then what to do.** "That file is over 20 MB. Try a smaller PDF." Every error gives a next step or a button.
2. **Active voice, subject then verb.** "We sent a sign-in link to {email}", not "A link has been sent".
3. **Sentence case everywhere**: titles, buttons, tabs, menu items, settings rows. Capitalize only the first word and proper nouns ("Google", "Wi-Fi", "PDF", "arXiv", "Paper"). Feature names stay lowercase in running text ("your glossary"). They are capitalized only when they are tab or screen labels ("Glossary").
4. **Punctuation.** Full sentences (body text, snackbars, errors) end with a period. Labels, buttons, titles, tabs and tooltips have no final period. Use the ellipsis character `…` for work in progress ("Syncing…"). Use curly apostrophes and quotes (’ “ ”). Straight `'` is an escape character in ICU/gen-l10n and must not appear in strings.
5. **Plain words only.** Do not use "leverage", "seamless", "robust", "unlock", "delight", "synergize", "oops", "uh-oh", or "please" in anything other than the generic error.
6. **No blame.** "That doesn’t look like a link", not "You entered an invalid URL".
7. **Translatable.** No idioms, puns or wordplay. Do not build sentences from fragments. Keep whole sentences in one key with placeholders. Plurals always use ICU `{count, plural, =1{…} other{…}}` (add `=0` when zero reads differently).
8. **Offline is normal, not an error.** Tell people what still works ("Your highlights and notes still work") before what does not.
9. **AI honesty.** Explanations are written by AI. Never promise accuracy. `aiPoweredNote` stays under explanations.

## Character budgets

Every key's `@key.description` gives its slot and maximum length. The limits count rendered English, with the sample placeholder values and the longest plural branch. The generator checks them. Keep them when you edit strings.

| Slot | Max chars |
| --- | --- |
| Nav / tab label, status chip | 12 |
| Button, menu item, tooltip | 18 (hard limit 24) |
| Field label / placeholder, short status | 24–32 |
| Screen / dialog / empty-state title | 32 |
| Snackbar | 40–80 (one line on phone width ≈ 40) |
| Empty-state / dialog body | 100–120 |
| Help paragraph (sync conflict) | 160 |

Plan for about 35% growth in translation (German, French). Buttons must wrap or ellipsize. They must never clip. Variable text (titles, emails, queries) does not count toward the budget. The UI truncates it.

## Terminology

Use one word per idea. Do not use the synonyms in the last column.

| Term | Meaning | Use | Avoid |
| --- | --- | --- | --- |
| **Paper** | The app, and also one document in the library | "Add paper", "Open the paper" | document, file (except for errors about the file itself), article |
| **Library** | All of the user's papers | "Added to your library" | collection, shelf, workspace |
| **Highlight** | A colored mark on text, a figure box, or a pen stroke. Verb and noun. | "Highlight figure", "Delete highlight" | annotation, markup |
| **Pen** | Stylus mode | "Pen mode on" | stylus (in UI), pencil, ink |
| **Note** | Free text the user writes, usually attached to a highlight | "Add note" | comment, memo, annotation |
| **Glossary** | Saved terms and their explanations, for one paper or all papers | "Save to glossary" | dictionary, vocabulary, flashcards |
| **Explanation** | AI output for a selected term or sentence: analogy, then precise definition, then an optional visual | "Explain", "Re-explain for this paper" | answer, summary, AI response, definition (alone) |
| **Side panel** | The split-view pane with Notes / Glossary / Explanation tabs | "Show side panel" | drawer, sidebar, inspector |
| **Download** | Keep a PDF on this device for offline reading | "Download for offline", "Available offline" | save, cache, pin |
| **Sync** | Send local changes to the account and get remote ones | "All changes synced", "3 changes waiting to sync" | upload, backup, save to cloud |
| **Sign in / Sign out** | Auth | "Sign in", "Sign out" | log in, login, log out |
| **Offline** | No connection | "You’re offline" | disconnected, no internet |

## Sync conflict (last-write-wins), user-facing

`syncConflictBody`: "If you change the same highlight or note on two devices, the most recent change wins. Edits to different items are all kept." Do not use the words "conflict", "row" or "timestamp" in UI text.

## Variants (pick one; ARB ships the first)

- `appTagline`: **"Read any paper without getting stuck."** / "Research papers, explained as you read." / "Highlight it. Understand it. Keep it."
- `libraryEmptyTitle`: **"No papers yet"** / "Your library is empty" / "Start with one paper"
- `aiOfflineTitle`: **"You’re offline"** / "Explanations need a connection" / "Connect to explain"
