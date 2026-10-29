# Settings (S5): web-parity spec

- **App route:** `/settings`, inside the shell, with the app nav bar.
- **App source:** `features/settings/settings_screen.dart`, `sign_out_dialog.dart`, `features/sync/sync_sheet.dart`.
- **Web route:** `/settings`:
  - `app/(app)/settings/page.tsx`
  - `settings/ProfileSettingsForm.tsx`
  - `settings/BetaFeaturesToggle.tsx`
  - `settings/ObsidianSettingsSection.tsx`
  - `settings/ObsidianDisconnectDialog.tsx`
- **Components:** [`../components.md`](../components.md).
- **Chrome and insets:** [README §2, §3.3, §4.4](README.md).

**References:**

| Shot | Use |
|---|---|
| [`settings.1280x800.png`](../reference/settings.1280x800.png) | column width, title block, section cards (Profile, Obsidian), footer line |
| [`settings.800x1280.png`](../reference/settings.800x1280.png) | the same at portrait, column 720 centred |
| *(none)* | beta checkbox, Obsidian rows and the disconnect dialog: not captured; build them from source (components §5.1, §7.4, §14) |

**Decisions applied:**

- **Single centred column at every width,** as on the web. The app's wide-screen master/detail layout (section `ListTile` list + `VerticalDivider` + 720 detail) is **removed**. All sections stack.
- **Drop the theme selector:** the web is dark-only. Appearance keeps "Reduce motion".
- **No web-only features:** the display-name/avatar editor, the Obsidian section and the beta toggle are not added. Each app section is drawn as a web `.card p-5` section.
- **Every `SwitchListTile`** becomes a row with a 20×20 `PaperCheckbox` (the web "switch", tokens.md §14).
- **Every `ListTile`** becomes a `PaperListRow` (components §7.4).

---

## 1. Layout

| | 1280×800 | 800×1280 | < 640 |
|---|---|---|---|
| Container | `mx-auto max-w-3xl px-6`: box 768 (padding included), centred | box 768, centred (16 margin each side) | full width, `px-6` |
| Content column | **720**, x 280–1000 | **720**, x 40–760 (sampled) | window − 48 |
| Top padding below the app bar | **64** (`sm:py-16`) | **64** | **48** (`py-12`) |
| Bottom padding | 64 + `viewPadding.bottom` | same | 48 + `viewPadding.bottom` |

Side padding gets + `viewPadding.left/right`. README §3.3 is corrected to 720 for portrait.

Vertical stack, with y measured from the window top (app bar 0–48):

| # | Element | Spacing | Height | y (1280 and 800) |
|---|---|---|---|---|
| 1 | `h1` "Settings": `pageTitle` 24/32 600 −0.6 `gray100` | pt 64 | 32 | 112–144 |
| 2 | First section card | `mt-8` 32 | content | 176 → |
| 3 | Each next section card | `mt-6` 24 | content | — |

- **One scroll region;** the nav bar is fixed.
- **No footer line:** the web's "Signed in as …" footer (`mt-4 xs gray400`) is not repeated, because the app shows the email in the Account identity block.
- **No lede:** the web lede ("How you appear on Paper…") has no app string, so it is omitted (copy gap, see integration notes). If design-copy adds one, place it `mt-2 sm gray400` under the h1 and keep `mt-8` below it.

---

## 2. Section card anatomy

Each section is a `PaperCard p-5` (fill `gray900`, border 1 `gray800`, radius 8, padding 20, no shadow).

| Part | Spec |
|---|---|
| Heading | `cardTitle` 14/20 600 `gray100` (`settingsSection*`) |
| Intro (optional) | `mt-2 sm gray400` |
| Rows | a `PaperListRow` list at `mt-3`. Each row is `py-3` with a 1 px `gray800` bottom border except the last, no horizontal padding, hover `#1F1F1F`, `focus-within` inset ring. |
| Row, left | label `sm 500 gray300`; description below, gap 4, `xs gray400` |
| Row, right | the control, vertically centred. Top-aligned with `mt-0.5` when it is a checkbox (`BetaFeaturesToggle` `items-start`). Gap 16 (`gap-4`) to the label. |
| Below 640 | a row with a wide control (segmented, buttons) stacks: control under the label, gap 12 (`flex-col gap-3`) |
| Footer actions (optional) | `mt-4 flex flex-wrap items-center gap-3` of `md` buttons |

**Row heights:**

- text-only row with a description: 12 + 20 + 4 + 16 + 12 = **64** + 1;
- row with a 38 control and a one-line label: 12 + 38 + 12 = **62** + 1.

---

## 3. Sections (app content → web components)

| Section | Content |
|---|---|
| **Account** (signed in) | **Identity block** `mt-4 flex items-center gap-4`: avatar 64×64, radius full, `accentSoft` fill + initials `text-xl` 20/28 600 `accentInk`. A photo gets a 1 px `gray700` border instead. Then name `sm 500 gray100` and email `xs gray400`. **Rows:** "Manage account" (`settingsManageAccount`) as a `PaperLink.accent` with a `↗` text glyph (opens the web); "Export notes" (`settingsExportNotes`): the whole row is tappable (hover `#1F1F1F`), as today's `ListTile`. The copied confirmation is an inline `xs green400` "Copied" (`settingsNotesCopied`) for 2 s, not a snackbar. **Footer:** `PaperButton.destructive md` "Sign out" (`settingsSignOut`). |
| **Account** (guest) | Title `guestAccountTitle` `sm 500 gray100` + body `mt-1 sm gray400` (`guestAccountBody`). Footer `PaperButton.primary md` "Sign in" (`commonSignIn`). |
| **Appearance** | One row: "Reduce motion" (`settingsReduceMotion`) + description (`settingsReduceMotionBody`); control `PaperSegmented.md` System · On. **The theme selector is removed.** |
| **Reader** | Rows: "Panel style" with `PaperSegmented.md` Split · Overlay (at ≥ 1024 this picks docked vs overlay; below 1024 the panel is always overlay or sheet, side-panel.md §1). "Auto-switch to pen" and "Single-key shortcuts" with `PaperCheckbox` 20×20 (accent when checked). |
| **Storage** | Intro `mt-2 sm gray400` = usage summary (`storageDownloadedPapers`). **Rows:** one per downloaded paper: title `sm 500 gray100` (ellipsis) + size `xs gray400`; right `PaperButton.secondary xs` "Remove" (`storageRemove`). **Empty:** `mt-3 sm gray400` `storageNoDownloads`. **Footer:** `PaperButton.destructive md` "Remove all" (opens `PaperDialog`) + `PaperButton.secondary md` "Clear cache". Inline result `sm green400` "Cache cleared". |
| **Sync** (not in offline-only builds) | **Status row:** label "Sync" + status `xs`: `green400` synced, `accent` syncing (with a `PaperSpinner` 16), `amber400` pending, `red400` error, `gray400` offline. Right: `PaperButton.secondary md` "Sync now"; disabled @ .5 offline, with the description `settingsNeedsConnection`. **Rows:** "Replaced versions (n)" (`syncReplacedVersions`) with a trailing `PaperButton.ghost xs` "Review" (opens the sync sheet dialog); "How sync works" (`syncHowItWorksTitle`) as a `PaperLink.accent`. |
| **About** | **Rows:** version `sm gray400` (`aboutVersion`, not interactive); Terms · Privacy · Licenses as `PaperLink.accent` rows (`aboutTerms`, `aboutPrivacy`, `aboutLicenses`). Licenses opens the Flutter licence page, dark-themed by `PaperTheme`. |

---

## 4. Dialogs

| Dialog | Spec (`PaperDialog`, components §14) |
|---|---|
| **Sign out** (`sign_out_dialog.dart`) | Title (`signOutConfirmTitle` / `signOutPendingTitle`). Body `mt-2 sm gray400`. Optional local-only paragraph `mt-3`. Checkbox row `mt-4`: `PaperCheckbox` 16 + `sm gray300` (`signOutRemoveLocal`), gap 8; this replaces `CheckboxListTile`. Actions `mt-5 justify-end gap-3`: `secondary md` "Cancel" · (pending) `secondary md` "Sync first" · `destructive md` "Sign out". |
| **Remove all downloads** | Title `storageRemoveAllTitle`, body `storageRemoveAllBody`. Actions: Cancel (`secondary md`) · "Remove all" (`destructive md`). |
| **Sync sheet** (`sync_sheet.dart`) | `PaperDialog` `max-w-md`, `p-5`. Title + status line `xs`. `PaperListRow` list for queued or replaced items: title `sm 500 gray100`, detail `xs gray400`, actions `PaperButton.ghost xs` (Restore mine / Keep as new note / Discard; Discard in `red400`). Footer `secondary md` "Close" + `primary md` "Sync now". Scrolls inside when taller than window − 96. |

---

## 5. States

| State | Spec |
|---|---|
| Loading (prefs or storage sizes) | Values that are not ready show a `PaperSkeleton` 12×64 bar in place of the value or control. Rows keep their height. |
| Error (storage sizes, sync) | inline `xs red400` in the affected row's description slot |
| Offline | "Sync now" @ .5 + description; "Manage account" / Terms / Privacy links stay enabled (the system browser shows its own offline page) |
| Offline-only build | Account and Sync sections are hidden. Storage shows the cache only. |

---

## 6. Insets and IME

- **Backgrounds:** the scroll body is full-bleed `gray950`. The container adds `viewPadding.left/right`. The last card gets `viewPadding.bottom`.
- **IME:** settings has no text fields. Dialogs with fields (none today) follow README §4.6.

---

## 7. Parity checklist

Compare with `settings.1280x800.png` and `settings.800x1280.png`.

- [ ] Content column exactly 720 wide, centred: x 280–1000 at 1280, x 40–760 at 800.
- [ ] `h1` "Settings" Geist 24/32 600 −0.6 `#F5F5F5`, 64 below the app bar.
- [ ] First section card 32 below the title block; 24 between section cards.
- [ ] Section cards: `#171717` fill, 1 px `#262626` border, radius 8, padding 20, no shadow.
- [ ] Section headings Geist 14/20 600 `#F5F5F5`; the rows start 12 below.
- [ ] Row labels 14/20 500 `#D4D4D4`; descriptions 12/16 `#A3A3A3`, 4 below the label; dividers 1 px `#262626` and none after the last row.
- [ ] Toggles are 20×20 checkboxes (`#3B3B3B` fill, 1 px `#858585` border; checked `#818CF8`), not Material switches.
- [ ] Segmented controls are 38 tall: `#171717` container, 1 px `#262626` border, radius 6; selected segment `#C7D2FE` on `#1E1B4B`.
- [ ] Avatar 64 px circle, `#1E1B4B` fill, initials 20/28 600 `#C7D2FE`, 16 before the name.
- [ ] "Sign out" is a 38-tall outline: 1 px `#7F1D1D` border, `#171717` fill, `#F87171` 14/20 500 label; hover fill `#450A0A`.
- [ ] Primary/secondary buttons 36 / 38 tall per components §2; links `#818CF8` 14/20 500 with underline on hover.
- [ ] No section navigation list or vertical divider at any width; no theme selector.
- [ ] Below the last card there are only 64 (+ inset) of bottom padding: no extra footer, no Material `ListTile` chevrons or leading icons.
