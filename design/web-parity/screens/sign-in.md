# Sign-in (S6): web-parity spec

- **App route:** `/sign-in` (`?expired=1`), pushed over the shell, with **no app nav bar** (README §2.5).
- **App source:** `features/auth/sign_in_screen.dart` (`SignInScreen`, `_StatusBanner`, `_BrandPanel`, `_Footer`, `_Label`) and `sign_in_prompt.dart`.
- **Web route:** `/sign-in` (`app/sign-in/page.tsx` `mx-auto max-w-sm px-6 py-16 sm:py-24`, and `auth/SignInForm.tsx`).
- **Components:** [`../components.md`](../components.md).

**References:**

| Shot | Use |
|---|---|
| [`sign-in.1280x800.png`](../reference/sign-in.1280x800.png), [`sign-in.800x1280.png`](../reference/sign-in.800x1280.png) | column, title, fields, buttons, toggle line |
| [`sign-in.focus-email.1280x800.png`](../reference/sign-in.focus-email.1280x800.png), [`sign-in.focus-email.800x1280.png`](../reference/sign-in.focus-email.800x1280.png) | focused input (2 px accent edge) |

The web shots include the 61-px web header. The app has none, so **every web y value is 61 lower than the app's**. Compare x positions, sizes and the gaps between elements, not absolute y.

**Decisions applied (CMO):**

- **`_BrandPanel` is removed** at every width. The app tagline (`signInTagline`) goes with it.
- **One `max-w-sm` column**, top-aligned, in the web's element order: title → email → password → submit → Google → toggle line.
- **No "or" divider.** The Google button's "G" icon is dropped (the web button is text-only).
- The app's extra entry points (forgot password, magic link, browser-wait, check-email, paste-link) are **kept and restyled**, not removed.

---

## 1. Layout

| | 1280×800 | 800×1280 | < 640 |
|---|---|---|---|
| Column box | `max-w-sm` **384**, centred: x 448–832 | 384 centred: x 208–592 | full width |
| Column content (`px-6`) | **336**: x 472–808 (identical to web) | **336**: x 232–568 | window − 48 |
| Top padding | **96** (`sm:py-24`) | **96** | **64** (`py-16`) |
| Bottom padding | 96 + `viewPadding.bottom` | same | 64 + `viewPadding.bottom` |
| Field height | 38 (`sm:text-sm`) | 38 | **42** (`text-base` 16/24 below `sm`) |

**Back button** (README §2.5):

- `PaperIconButton` 32 with `reader-back.svg` 20 `gray400`.
- Position: `left: 16 + viewPadding.left`, `top: 16 + viewPadding.top`.
- Hover `gray800` + `gray100`. Tooltip `signInCloseTooltip`. It pops the route.
- It stays at the screen corner and does not scroll.

**Scroll:** the whole column scrolls when the IME is open or the window is short. The background is full-bleed `gray950`.

### 1.1 Vertical stack (sign-in mode, no messages)

| # | Element | Spacing | Height | App y @ 1280 and 800 | Web y (−61 for app) |
|---|---|---|---|---|---|
| 1 | `h1`: `pageTitle` 24/32 600 −0.6 `gray100`, text "Sign in" (`signInSubmit` string; see deviations) | pt 96 | 32 | 96–128 | 157–189 |
| 2 | Form (`flex-col gap-5`) | `mt-8` 32 | — | 160 → | 221 → |
| 2a | Email label `sm 500 gray300` (`signInEmailLabel`) | | 20 | 160–180 | 221–241 |
| 2b | Email field `PaperTextField.md` | gap 6 | 38 | 186–224 | 247–285 |
| 2c | Password label | gap 20 | 20 | 244–264 | 305–325 |
| 2d | Password field + show/hide toggle | gap 6 | 38 | 270–308 | 331–369 |
| 2e | Error (`role=alert`) `sm red400`, or notice `sm gray300` | gap 20 | 20+ | only when present | |
| 2f | Submit `PaperButton.primary md`, full width, "Sign in" / "Create account" | gap 20 | 36 | 328–364 | 389–425 |
| 2g | App-only link row: "Forgot password?" (left) · "Email me a sign-in link" (right), `sm 400 gray400`, hover `gray100` + underline (offset 2), `flex justify-between`. Sign-in mode only. | gap 20 | 20 | 384–404 | — |
| 3 | Google `PaperButton.secondary md` full width, "Continue with Google" | `mt-4` 16 | 38 | 420–458 | 441–479 (after 2f) |
| 4 | Toggle line, centred: `sm gray400` prompt + `PaperLink.strong` (`gray100` 500, hover underline) | `mt-6` 24 | 20 | 482–502 | 503–523 |
| 5 | App-only legal footer: "Terms · Privacy Policy" (`signInTerms`, `signInPrivacy`) `xs gray400`, hover `gray100`, centred, gap 8 | `mt-6` 24 | 16 | 526–542 | — |

**Show/hide password** (app feature):

- A `PaperIconButton` 24 inside the field's right edge, 8 inset.
- Glyph: Lucide `eye` / `eye-off` 16 at stroke 1.5, `gray400`, hover `gray100`.
- Tooltip `authShowPassword` / `authHidePassword`.
- The field's right padding becomes 12 + 24 + 8 = 44.

**Toggle line:** the web splits "New here?" (gray-400) from "Create an account" (gray-100 link). The app has one string per mode (`signInCreateAccountPrompt`, `signInHaveAccountPrompt`).

- **Until the copy is split:** render the whole string as `PaperLink.strong`, centred.
- **Exact parity:** add two keys, prompt + action (see integration notes).

---

## 2. States

| State | Spec |
|---|---|
| **Field error** | Invalid email or empty password: the field border turns `red500` (2 px when focused). The message goes in the alert row (2e) `sm red400`, not under the field, as on the web. |
| **Submitting** | The submit label becomes `authSigningIn` ("Signing in…") and the button is disabled @ .5. The fields stay enabled (web). There is no spinner in the button; the app's `CircularProgressIndicator` is removed. |
| **Session expired** (`?expired=1`) | An `mt-2 sm gray400` line under the h1 (`authSessionExpired`), styled like the web's lede. `mt-8` to the form stays. |
| **Offline** | `PlaceholderCard` at `mt-8` (in place of the form, Google and toggle): `rounded-lg border gray800 bg gray900 p-6`, title `font-medium gray100` (`authOfflineTitle`), body `mt-1 sm gray300` (`authOfflineBody`), action `mt-4 PaperButton.secondary md` "Try again". |
| **Not configured** | The same `PlaceholderCard` with only `authNotConfigured`. No form. |
| **Browser wait** (Google started) | It replaces the form, Google and toggle. `PaperCard p-5` at `mt-8`:<br>· row `flex items-center gap-2`: `PaperSpinner` 16 + title `sm 600 gray100` (`authBrowserWaitTitle`);<br>· body `mt-2 sm gray400` (`authBrowserWaitBody`);<br>· actions `mt-4 flex gap-3`: `PaperButton.secondary md` "Reopen browser" · `PaperButton.ghost md` "Cancel";<br>· hint `mt-3 xs gray400` (`authBrowserReturnHint`, later `authDeepLinkMissingHint`) + `PaperLink.accent xs` "Use email instead".<br>**Desktop paste link:** `mt-4` label `sm 500 gray300` (`authPasteLinkLabel`) + gap 6 + `PaperTextField.md` + `mt-3 PaperButton.primary md` "Continue". The error is `mt-1.5 xs red400` (`authPasteLinkInvalid`). |
| **Check email** (magic link / sign-up confirm / reset) | `PaperCard p-5` at `mt-8`:<br>· title `sm 600 gray100` (`authCheckEmailTitle` / `authConfirmEmailTitle`);<br>· body `mt-2 sm gray400` (`authCheckEmailBody`, `authResetSent`);<br>· actions `mt-4 flex gap-3`: `PaperButton.secondary md` "Send again" (cooldown label `authResendCooldown`, disabled @ .5) · `PaperButton.ghost md` "Use another email". |
| **Already signed in** | As the web: `mt-2 sm gray400` "Signed in as **email**" (the email in `gray100` 500, `authAlreadySignedIn` copy), then `mt-8 PaperButton.secondary md` full width "Sign out". |

All state swaps are instant (the web has none). design-motion may keep the existing ≤ 150 ms `AnimatedSwitcher` cross-fades under `PaperMotion.of`.

---

## 3. Insets and IME

- **Background:** full-bleed `gray950` under cutouts and bars.
- **Column:** inset on all sides by `viewPadding`, in addition to the padding above. The back button is at `16 + left/top`.
- **IME:** `resizeToAvoidBottomInset: true`. The column scrolls, and the focused field is brought into view with 24 clearance above the keyboard. Nothing is pinned to the bottom.
- **Focus:** opening the screen does not autofocus the email field on touch devices. On desktop it does, and the focus shows the 2 px accent edge, as in `sign-in.focus-email.*`.

---

## 4. Parity checklist

Compare with `sign-in.1280x800.png` and `sign-in.focus-email.1280x800.png` (subtract 61 from the web y values).

- [ ] No brand panel and no app bar; a single column whose content is exactly 336 wide (x 472–808 at 1280, x 232–568 at 800), with the page background `#0A0A0A`.
- [ ] `h1` "Sign in" Geist 24/32 600 −0.6 `#F5F5F5`, 96 below the top (+ inset).
- [ ] 32 from the h1 to the Email label; labels Geist 14/20 500 `#D4D4D4`, 6 above their field.
- [ ] Fields 38 tall (42 below 640 wide), `#171717` fill, 1 px `#404040` border, radius 6, text 14/20 `#F5F5F5`, padding 12×8.
- [ ] Focused field: 2 px `#818CF8` edge and no glow; the field size doesn't change.
- [ ] 20 between field groups and between the password field and the submit button.
- [ ] Submit: full width, 36 tall, `#818CF8` fill, label "Sign in" `#1E1B4B` 14/20 500 centred; hover `#A5B4FC`.
- [ ] "Continue with Google": full width, 38 tall, `#171717` fill, 1 px `#404040` border, `#E5E5E5` 14/20 500 label, **no G icon**, 16 below the form.
- [ ] No "or" divider anywhere.
- [ ] Toggle line centred, 24 below the Google button, Geist 14/20; the link part is `#F5F5F5` 500 and underlines on hover.
- [ ] Error text 14/20 `#F87171` sits between the password field and the submit button (not under the email field).
- [ ] While submitting, the label reads "Signing in…" at 50 % opacity, with no spinner.
- [ ] Back button 32×32 at 16/16 from the top-left, 20 px chevron `#A3A3A3`.
