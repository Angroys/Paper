# Paper

Paper is the native app for [paper.college](https://paper.college). It runs on
**Android tablets, Windows and macOS** from one Flutter codebase. You can read
research PDFs with a native pdfium renderer (no webview), highlight text and
figures, take notes, look up citations and ask the paper.college AI for
explanations, glossaries and visual aids. The app is local-first: papers you
have downloaded work offline, and your edits sync to the same Supabase backend
as the web app when you are back online.

iOS/iPhone and Linux are not v1 targets.

## Architecture map

| Path | What lives there |
| --- | --- |
| `lib/main.dart` | Entry point: window setup, `ProviderScope`, boot |
| `lib/app/` | `App`, `go_router` router and routes, `AppShell` (adaptive nav), app-level shortcuts and commands, persisted settings, deep-link listener |
| `lib/core/` | `Env` (compile-time config), paper.college API client, `@supabase/ssr` cookie encoder, connectivity, deep-link service, window classes, desktop window |
| `lib/theme/` | Design tokens (`paper_tokens.dart`, generated from `design/tokens`), theme extensions, motion |
| `lib/l10n/` | `app_en.arb`. `flutter gen-l10n` writes `app_localizations*.dart` from it |
| `lib/domain/` | Models, repository/service interfaces, errors. Pure Dart |
| `lib/data/` | drift SQLite database (`db/`), local-first repositories, file store, Supabase remote and the "unconfigured" remote (`remote/`) |
| `lib/auth/` | Supabase auth repository (PKCE OAuth through the system browser, email/password, magic link), unconfigured repository, Windows `paper://` registration |
| `lib/sync/` | Outbox `SyncEngine` and its providers |
| `lib/ai/` | `HttpAiService` (paper.college AI routes), glossary remote, unavailable fallback |
| `lib/features/auth` | Sign-in screen |
| `lib/features/library` | Library screen and controller |
| `lib/features/reader` | pdfrx reader: controller, state, viewport, geometry, stylus, citations, shortcuts, widgets |
| `lib/features/panel` | Side panel and split view: Notes, Glossary, Explanation and Highlights tabs |
| `lib/features/settings` | Settings screen and the sign-out dialog |
| `lib/features/sync` | `SyncBadge` and `SyncSheet` |

Main packages: **Riverpod 3** (`flutter_riverpod`) for state and DI,
**go_router** for navigation, **drift** for SQLite, **pdfrx** for PDF
rendering and **supabase_flutter** for the backend.

The specs the app implements are in `design/specs/`: `layout-system.md`,
`flows.md`, `components.md`, `motion.md` and `screens/`.

## Setup

1. Install **Flutter 3.47.7** (stable channel). CI pins the same version.
2. **Linux hosts need `clang`.** pdfrx's `pdfium_dart` native-assets hook
   compiles with it, and `flutter test`, `flutter analyze` builds and
   `flutter build apk` all fail without it. On Debian/Ubuntu run
   `sudo apt-get install clang libsqlite3-dev`. `libsqlite3-dev` is needed by
   the drift tests.
3. **Android:** JDK 17, Android SDK with **compileSdk 36** and **NDK
   28.2.13676358**. These are the Flutter defaults that
   `android/app/build.gradle.kts` uses. minSdk is 24. Gradle installs CMake
   3.22.1 on the first build if it is missing.
   `android/gradlew` and the wrapper jar are not committed. Flutter
   regenerates them on the first `flutter build apk` or `flutter run`.
4. Generate code. Always run these steps in this order, after every pull:

   ```sh
   flutter pub get
   flutter gen-l10n
   dart run build_runner build --delete-conflicting-outputs
   ```

   Generated files (`lib/l10n/app_localizations*.dart`, `*.g.dart`) are
   **never committed**. They are gitignored, and CI generates them itself.

## Environment

Configuration is compiled in with `--dart-define` (see `lib/core/env.dart`):

| Define | Required | Default |
| --- | --- | --- |
| `SUPABASE_URL` | for online features | — |
| `SUPABASE_ANON_KEY` | for online features | — |
| `PAPER_API_BASE_URL` | no | `https://paper.college` |

The easiest way to set them is a local env file:

```sh
cp env/example.json env/dev.json   # then fill in the real values
flutter run --dart-define-from-file=env/dev.json
```

`env/*.json` is gitignored. Only `env/example.json` is tracked. **Never
commit real values.**

If `SUPABASE_URL` or `SUPABASE_ANON_KEY` is missing, the app runs in
**"not configured" mode**. It creates no Supabase client, auth stays
signed out, and every network feature reports that it is unavailable. Tests
and plain `flutter run` use this mode.

Supabase dashboard setup (Authentication):

- Add `paper://auth-callback` to the **redirect URL allow-list**.
- Enable the **Google** provider.

## Run and build

```sh
# Run (pick a device from `flutter devices`)
flutter run -d <android-device-id> --dart-define-from-file=env/dev.json
flutter run -d windows             --dart-define-from-file=env/dev.json
flutter run -d macos               --dart-define-from-file=env/dev.json

# Build
flutter build apk --debug   --dart-define-from-file=env/dev.json  # build/app/outputs/flutter-apk/app-debug.apk
flutter build windows       --dart-define-from-file=env/dev.json  # build/windows/x64/runner/Release/
flutter build macos --debug --dart-define-from-file=env/dev.json  # build/macos/Build/Products/Debug/Paper.app
```

You can only build Windows on a Windows host (Visual Studio with the "Desktop
development with C++" workload) and macOS on a macOS host (Xcode). From Linux
you can build only the Android APK. CI builds all three.

## Deep links

The app registers the `paper://` scheme:

- `paper://auth-callback?...` is the OAuth **PKCE** redirect. Google sign-in
  (and the email confirmation, magic-link and recovery links) open in the
  **system browser**, and Supabase then redirects back to the app.
- `paper://paper/<id>` opens a paper in the reader.

How each platform registers the scheme:

- **Android:** `<intent-filter>` entries in
  `android/app/src/main/AndroidManifest.xml`.
- **macOS:** `CFBundleURLTypes` in `macos/Runner/Info.plist`.
- **Windows:** the app registers itself under `HKCU\Software\Classes\paper`
  on every launch (`lib/auth/windows_protocol_registration.dart`, no admin
  rights needed). This covers the portable zip and `flutter run`. The Inno
  Setup installer (`installer/windows/paper.iss`) writes the same keys and
  removes them on uninstall. `windows/runner/main.cpp` forwards a link to an
  instance that is already running.
- **Desktop fallback:** if the browser cannot hand the link back, the sign-in
  screen offers a **"paste the link"** field. Copy the `paper://auth-callback`
  URL from the browser and paste it there.

## Offline and sync

- **Local-first.** All library metadata, highlights and notes live in SQLite
  (drift). Downloaded PDFs are cached on disk. Reading, highlighting and
  note-taking work offline.
- **Sync** uses an outbox. Each synced write queues an op, which is pushed
  oldest first, and then the server state is pulled and merged. Sync runs on
  start, on reconnect, every 5 minutes, on app resume, 2 s after a local
  write, and from "Sync now".
- **Conflict rules, in summary:**
  - Highlights are immutable rows (create/delete only), so they cannot
    conflict.
  - Papers have no server `updated_at`. While a paper has queued ops the
    local row wins, so the last push wins.
  - Figure notes use **last-write-wins per row on `updated_at`**. When the
    server wins, the losing local text is kept for 30 days under "Restore
    mine".
  - On 401 the outbox is kept. Other 4xx errors mark the op as failed, with
    Retry and Discard in the SyncSheet.
  - Signing in as a different user wipes the local data first.

  The full rules are in the doc block at the top of
  [`lib/sync/sync_engine.dart`](lib/sync/sync_engine.dart).
- **Device-only data (data-model gap, option A).** The RPR schema has no
  columns for **highlight colour, notes on text highlights, free page notes,
  and reading position / last opened**. v1 makes no schema changes, so these
  stay **on this device** and never sync. Figure notes do sync. See
  `design/specs/flows.md` ("Data-model gap").

## AI features

Explain, re-explain, glossary, glossary rating and visual aids call the
existing paper.college (RPR) Next.js routes (`lib/ai/http_ai_service.dart`).
They are online only, and the app has no on-device model.

- **Auth coupling.** These routes accept **cookies only**, with no
  `Authorization: Bearer` support. The app sends its Supabase session the way
  a browser would, as the `@supabase/ssr` auth cookie
  (`lib/core/ssr_auth_cookie.dart`):
  - The cookie is named `sb-<project-ref>-auth-token`.
  - The value is `base64-` plus the base64url (unpadded) of the session JSON.
  - Values longer than 3180 characters are chunked into `<name>.0`,
    `<name>.1` and so on.
  - The app refreshes the session first and **blanks the refresh token**, so
    the server can never rotate it. Any `Set-Cookie` in the response is
    ignored.
- **Risk.** This depends on RPR's internal cookie format. If
  `@supabase/ssr` changes it, AI calls start failing with "AI unavailable".
  The planned follow-up is to add Bearer-token support to the RPR routes.
- **Visual aids** open **externally** in the browser or system player. v1
  has no in-app player.
- **Offline vs unavailable.** The UI tells these two states apart:
  - **offline:** no connection. Cached explanations are still shown.
  - **aiUnavailable:** online, but AI cannot run because the build is not
    configured, the user is signed out, or the API rejected the session
    (401/403).

## Keyboard shortcuts

`Mod` is **Cmd** on macOS and **Ctrl** on Windows and Android. The tables come
from `design/specs/layout-system.md` §9, as implemented in
`lib/app/app_shortcuts.dart` (app-wide) and
`lib/features/reader/reader_shortcuts.dart` (reader). Inside the reader, the
reader's shortcuts win any overlap. Single-key shortcuts are disabled while a
text field has focus, and you can turn them off in Settings › Reader ›
"Single-key shortcuts".

**App-wide**

| Action | Windows / Android | macOS |
| --- | --- | --- |
| Search library (in Library) | Ctrl+F | Cmd+F |
| Focus library search (anywhere) | Ctrl+K | Cmd+K |
| Import file | Ctrl+O | Cmd+O |
| Import from link | Ctrl+Shift+O | Cmd+Shift+O |
| Settings | Ctrl+, | Cmd+, |
| Sync now | Ctrl+Shift+S | Cmd+Shift+S |

**Reader**

| Action | Windows / Android | macOS |
| --- | --- | --- |
| Tool: select / pen / figure | V / P / F | V / P / F |
| Highlight selection (last colour); no selection: Highlight tool | H | H |
| Highlight colour 1–6 (Yellow, Green, Blue, Pink, Purple, Orange) | 1 … 6 | 1 … 6 |
| Explain selection (AI) | E | E |
| Add note to selection | N | N |
| Copy selection | Ctrl+C | Cmd+C |
| Next / previous page | PageDown / PageUp · → / ← | same |
| First / last page | Home / End | Home / End · Cmd+↑ / Cmd+↓ |
| Go to page… | Ctrl+G | Cmd+Option+G |
| Zoom in / out | Ctrl+= (or Ctrl+Shift+=, numpad +) / Ctrl+- | Cmd+= / Cmd+- |
| Actual size / fit width / fit page | Ctrl+0 / Ctrl+1 / Ctrl+2 | Cmd+0 / Cmd+1 / Cmd+2 |
| Find in paper | Ctrl+F | Cmd+F |
| Next / previous match | F3 / Shift+F3 · Enter / Shift+Enter in find | Cmd+G / Cmd+Shift+G |
| Toggle side panel | Ctrl+\ | Cmd+\ |
| Side panel tab 1 / 2 / 3 | Ctrl+Alt+1 / 2 / 3 | Cmd+Option+1 / 2 / 3 |
| Close popover / clear selection | Esc | Esc |
| Close paper | Ctrl+W · Alt+← | Cmd+W · Cmd+[ |

Some §9 shortcuts are not implemented in v1: Enter/F2/Delete on library
cards, Undo/Redo, the shortcuts help (Mod+/), and full screen (F11 /
Ctrl+Cmd+F).

## Testing

```sh
flutter pub get && flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed $(git ls-files 'lib/*.dart' 'test/*.dart')
flutter analyze          # must report "No issues found"
flutter test             # unit + widget tests (sync, repositories, auth deep links, reader, screens)
flutter build apk --debug
```

On Linux, `flutter test` needs `clang` (the pdfium_dart hook) and
`libsqlite3-dev` (drift tests run against a real in-memory SQLite). Tests run
in "not configured" mode with fakes. They need no network and no secrets.

## CI

`.github/workflows/ci.yml` runs on **every branch push, every `v*` tag, pull
requests, and manual dispatch** (`workflow_dispatch`). Newer runs on the
same ref cancel older ones. The shared setup action
(`.github/actions/setup-paper`) installs Flutter 3.47.7 and runs pub get,
gen-l10n and build_runner.

| Job | Runner | What it does | Artifact |
| --- | --- | --- | --- |
| Analyze & test | ubuntu | format check, `flutter analyze`, `flutter test` | — |
| Build Android (debug APK) | ubuntu | `flutter build apk --debug` | `paper-android-debug-apk-<ver>` → `Paper-<ver>-android.apk` |
| Build Windows (zip + installer) | windows | `flutter build windows`, zip, Inno Setup installer | `paper-windows-<mode>-<ver>` → `Paper-<ver>-windows.zip`, `Paper-<ver>-windows-setup.exe` |
| Build macOS (debug DMG) | macos | `flutter build macos --debug`, `hdiutil` DMG | `paper-macos-debug-<ver>` → `Paper-<ver>-macos.dmg` |
| GitHub prerelease | ubuntu | only on `v*` tags, after all builds | release assets |

- `<ver>` is the tag without its leading `v` (`v1.2.3` → `1.2.3`), or the
  7-character commit SHA otherwise (`scripts/ci/version.sh`).
- **Optional repository secrets:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `PAPER_API_BASE_URL`. They are passed as `--dart-define`. Without them,
  the builds boot in "not configured" mode.
- **Releases:** pushing a `v*` tag creates a **GitHub prerelease** with
  auto-generated notes and these assets: `Paper-<ver>-android.apk`,
  `Paper-<ver>-windows-setup.exe` (Inno Setup), `Paper-<ver>-windows.zip`
  and `Paper-<ver>-macos.dmg`.
- **Windows build mode:** tag builds are **release mode** (unsigned).
  Branch and PR Windows artifacts are **debug** builds, which only start on
  PCs that have the Visual Studio debug runtime (`vcruntime140d.dll` etc.).
- **macOS** builds are always debug, and the debug `.app` is **arm64-only**
  (Apple Silicon).
- Per-push artifacts are kept for **14 days**.

## Installing test builds

All builds are **unsigned**, so each OS warns before running them.

- **Android:**
  1. Allow your browser or file manager to install apps (Settings → Apps →
     Special app access → Install unknown apps).
  2. Open `Paper-<ver>-android.apk`.
- **Windows:**
  - **Installer:** run `Paper-<ver>-windows-setup.exe`. On SmartScreen's
    "Windows protected your PC", choose **More info → Run anyway**.
  - **Portable:** unzip `Paper-<ver>-windows.zip` and run `paper.exe`.
- **macOS:**
  1. Open the DMG and drag **Paper** to **Applications**.
  2. The first time, right-click Paper → **Open** (then confirm), or run
     `xattr -dr com.apple.quarantine /Applications/Paper.app`.

## Known limitations / v1 deviations

- No in-app video player. Visual aids open externally.
- No PDF thumbnails in the library.
- Pen strokes snap to the text they cross and become highlights. Strokes that
  cross no text (freeform ink) are **not saved**.
- Password reset sends the email, but there is no in-app
  "set new password" screen.
- Imports are limited to **20 MB** per PDF, the same cap as RPR.
- Highlight colour, notes on text highlights, page notes and reading position
  are device-only (see [Offline and sync](#offline-and-sync)).
- AI depends on RPR's `@supabase/ssr` cookie format (see
  [AI features](#ai-features)).
- The performance checklist **P1–P14** (`design/specs/motion.md`) still
  needs profiling on real devices. It is not covered by automated tests.
