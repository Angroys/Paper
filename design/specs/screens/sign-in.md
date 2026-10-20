# Screen — Sign-in

**User goal:** Sign in to my paper.college account (or create one) and land in my library.
Flow: [flows.md › F2](../flows.md#f2-sign-in). Layout rules: [layout-system.md](../layout-system.md).

## Regions
1. **Brand slot**: app mark + wordmark (design-brand asset).
2. **Value line**: one sentence (`signInTagline`).
3. **Primary auth**: `GoogleSignInButton`.
4. **Divider**: "or" (`signInDividerOr`).
5. **EmailSignInForm**: email, password (show/hide), submit, mode switch (sign in / create account), "Forgot password?", "Email me a sign-in link".
6. **Status region**: `AuthErrorBanner` / `OfflineBanner` (above primary auth, live region).
7. **Footer**: Terms + Privacy links (open in browser), version.

## Wireframes

### fallback (<600) and compact (600–839, portrait)
```
┌──────────────────────────────┐
│          [ logo ]            │
│     Paper                    │
│  signInTagline               │
│ ┌──────────────────────────┐ │
│ │ AuthErrorBanner (if any) │ │
│ └──────────────────────────┘ │
│ [ G  Continue with Google  ] │  48dp
│ ───────────  or  ─────────── │
│ Email                        │
│ [__________________________] │
│ Password             [ 👁 ]  │
│ [__________________________] │
│ [        Sign in           ] │  48dp
│ Forgot password?             │
│ Email me a sign-in link      │
│ New here? Create account     │
│                              │
│ Terms · Privacy      v1.0.0  │
└──────────────────────────────┘
```
Form column max width 400dp, centred; scrolls with IME.

### medium (840–1199) / expanded / large
```
┌───────────────────────────────────────────────────────────────┐
│ [traffic lights / caption buttons reserve]          drag area │
│ ┌──────────────────────────┐ ┌──────────────────────────────┐ │
│ │                          │ │  Paper                       │ │
│ │   brand panel            │ │  signInTagline               │ │
│ │   (illustration slot,    │ │  [AuthErrorBanner]           │ │
│ │    design-brand)         │ │  [ G Continue with Google ]  │ │
│ │                          │ │  ──── or ────                │ │
│ │                          │ │  Email  [_______________]    │ │
│ │                          │ │  Password [____________][👁] │ │
│ │                          │ │  [ Sign in ]                 │ │
│ │                          │ │  Forgot? · Email link        │ │
│ │                          │ │  Create account              │ │
│ └──────────────────────────┘ └──────────────────────────────┘ │
│ Terms · Privacy                                     v1.0.0    │
└───────────────────────────────────────────────────────────────┘
```
Two columns 5/7 of 12-col grid on `medium`, 6/6 on `large`. Brand panel hidden when height < 560.

### AuthBrowserWaitState (replaces regions 3–5)
```
│        ( spinner )              │
│  authBrowserWaitTitle           │
│  authBrowserWaitBody            │
│  [ Reopen browser ]  [ Cancel ] │
│  authBrowserReturnHint (after 2s focus w/o callback)
│  authDeepLinkMissingHint (desktop, after 30s) → [Use email instead]
```

### MagicLinkSentState / confirm email
```
│  ✉  authCheckEmailTitle          │
│  authCheckEmailBody ({email})    │
│  [ Resend (60s) ]  [ Use another email ] │
```

## Components
`SignInScreen`, `GoogleSignInButton`, `EmailSignInForm`, `AuthBrowserWaitState`, `MagicLinkSentState`, `AuthErrorBanner`, `OfflineBanner`, `DesktopTitleBar`.

## States
| State | Behaviour |
| --- | --- |
| Default | Google first, email form visible (not hidden behind a toggle). |
| Submitting | Submit button shows spinner, label stays (`authSigningIn`); inputs read-only; Google disabled. |
| Browser wait | See above. Back/Esc = Cancel. |
| Error | Banner with cause + action; field errors inline under field. Values preserved. |
| Offline | `OfflineBanner(authOfflineTitle, authOfflineBody)`; Google + submit disabled with tooltip/semantics hint. Auto-enables on reconnect. |
| Session expired | Banner `authSessionExpired`; email prefilled. |
| Success | Navigate to Library (replace route; back does not return to sign-in). |

## Microcopy keys
`signInScreenHeading`, `signInTagline`, `signInGoogle`, `signInDividerOr`, `signInEmailLabel`, `signInPasswordLabel`, `authShowPassword`, `authHidePassword`, `signInSubmit`, `signUpSubmit`, `authSigningIn`, `signInForgotPassword`, `signInMagicLink`, `signInCreateAccountPrompt`, `signInHaveAccountPrompt`, `signInTerms`, `signInPrivacy`, `authBrowserWaitTitle`, `authBrowserWaitBody`, `authReopenBrowser`, `authCancel`, `authBrowserReturnHint`, `authDeepLinkMissingHint`, `authUseEmailInstead`, `authGoogleCancelled`, `authGoogleFailed`, `authCodeExchangeFailed`, `authTimeout`, `authInvalidCredentials`, `authEmailInvalid`, `authPasswordRequired`, `authNetworkError`, `authRateLimited`, `authConfirmEmailTitle`, `authCheckEmailTitle`, `authCheckEmailBody`, `authResend`, `authResendCooldown`, `authUseAnotherEmail`, `authResetSent`, `authOfflineTitle`, `authOfflineBody`, `authSessionExpired`, `authAlreadySignedIn`, `authRetry`.

## Accessibility
- Heading: wordmark is `header` semantics ("Sign in to Paper", `signInScreenHeading`).
- Focus order: banner (if present, announced) → Google → email → password → show/hide → submit → links.
- Fields have persistent labels (not placeholder-only); autofill hints `email`, `password` / `newPassword`.
- Errors announced via live region and linked to field (`errorText`).
- Browser wait: announce `authBrowserWaitTitle` on enter; spinner has label.
- No CAPTCHA/timeouts on input; Resend cooldown shown as text, not only a progress ring.
