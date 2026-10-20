# Paper design tokens (Flutter)

| File | What |
| --- | --- |
| `paper-tokens.json` | Source of truth. Every value is mapped from the paper.college web app (RPR `tailwind.config.ts`, `src/app/globals.css`, `design/tokens/*.json`) |
| `paper_tokens.dart` | Hand-written Flutter theme built from the JSON. Imports only `package:flutter/material.dart`, with no codegen |

If you change a value, change it in both files.

## 1. Wire it in

1. Copy `design/tokens/paper_tokens.dart` to `lib/theme/paper_tokens.dart`.
2. Requires **Flutter ≥ 3.35**: it uses `AppBarThemeData`, `InputDecorationThemeData`, `CardThemeData`, `DialogThemeData`, `WidgetStateProperty` and `Color.withValues`. Checked with Flutter 3.47.7 stable: `dart format` reports no changes, `flutter analyze` reports no issues, and a widget smoke test pumps every themed component in light and dark on android and windows.
3. Set up the app:

```dart
import 'package:flutter/material.dart';
import 'theme/paper_tokens.dart';

MaterialApp(
  theme: PaperTheme.light(),
  darkTheme: PaperTheme.dark(),
  // The web app is dark-only today (layout.tsx renders class="dark").
  // Default to dark for brand parity and let Settings switch to system or light.
  themeMode: ThemeMode.dark,
);
```

`PaperTheme.light({TargetPlatform? platform})` uses touch density on Android (48dp targets, `InkRipple`) and pointer density on Windows and macOS (compact `VisualDensity`, 32 to 36dp controls, `NoSplash`). Tests can pass `platform:` to pick one.

4. Read the tokens in widgets:

```dart
final colors = Theme.of(context).extension<PaperColors>()!;
final hl = Theme.of(context).extension<PaperHighlightColors>()!;

Container(color: colors.surface);
Text('Offline', style: TextStyle(color: colors.statusOffline));
final windowClass = PaperWindowClass.ofContext(context); // compact … extraLarge
AnimatedOpacity(duration: PaperMotion.of(context, PaperMotion.fast), curve: PaperMotion.decelerate, …);
Padding(padding: const EdgeInsets.all(PaperSpacing.lg));
```

Suggestion: add `extension PaperThemeX on BuildContext { PaperColors get paper => Theme.of(this).extension<PaperColors>()!; }` in the app.

### What is in the Dart file

`PaperColors` (a ThemeExtension with light and dark), `PaperHighlightColor` (an enum of 6 hues), `PaperHighlightColors` (a ThemeExtension for alphas and blend mode: `whitePaper` / `darkPaper`), `PaperReaderMark` (AI marks: term, citation, appendix, mention), `PaperSpacing`, `PaperRadii`, `PaperElevation`, `PaperIconSize`, `PaperHitTarget`, `PaperLayer`, `PaperMotion`, `PaperBreakpoints`, `PaperWindowClass`, `PaperSidePanelMode`, `PaperChrome`, `PaperTypography`, `PaperFadePageTransitionsBuilder` and `PaperTheme`.

## 2. Fonts: bundle Geist (no runtime fetching)

The web app uses **Geist** and **Geist Mono** by Vercel (`src/app/fonts/GeistVF.woff`, `GeistMonoVF.woff`). Both are **SIL Open Font License 1.1**, so you can bundle them as-is and no substitute font is needed. Bundle static TTFs. Do **not** use the `google_fonts` package: it downloads fonts at runtime, which breaks offline use and causes a font swap on first launch. Static weights also render more reliably than variable fonts across Skia and Impeller.

Download the static TTFs from https://github.com/vercel/geist-font/releases (`fonts/Geist/ttf/`, `fonts/GeistMono/ttf/`) or from Google Fonts ("Geist", "Geist Mono"). Put them in `fonts/` at the project root:

```
fonts/Geist-Regular.ttf      fonts/GeistMono-Regular.ttf
fonts/Geist-Medium.ttf       fonts/GeistMono-Medium.ttf
fonts/Geist-SemiBold.ttf
fonts/Geist-Bold.ttf
fonts/OFL.txt                (Geist license text, from the release zip)
```

`pubspec.yaml`. The family names must match `PaperTypography.sans` and `PaperTypography.mono` exactly:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: Geist
      fonts:
        - asset: fonts/Geist-Regular.ttf
          weight: 400
        - asset: fonts/Geist-Medium.ttf
          weight: 500
        - asset: fonts/Geist-SemiBold.ttf
          weight: 600
        - asset: fonts/Geist-Bold.ttf
          weight: 700
    - family: GeistMono
      fonts:
        - asset: fonts/GeistMono-Regular.ttf
          weight: 400
        - asset: fonts/GeistMono-Medium.ttf
          weight: 500
```

The theme only uses weights 400, 500 and 600. Bold (700) is for user emphasis. Fallbacks are set in code (`Segoe UI`, `SF Pro Text`, `Roboto` / `Consolas`, `Menlo`), so missing glyphs such as CJK or math still render.

### License notes

- Geist and Geist Mono: SIL OFL 1.1. Ship `fonts/OFL.txt`, and register it so the in-app licenses page lists it:

```dart
LicenseRegistry.addLicense(() async* {
  final text = await rootBundle.loadString('fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(<String>['Geist', 'Geist Mono'], text);
});
```

  (This needs `fonts/OFL.txt` listed under `flutter: assets:`, and the `services` import in `main.dart`.) Do not sell the font files on their own, and do not ship modified copies under the name "Geist". Embedding them in an app is fine.
- Colors come from Tailwind CSS's default palette (MIT), the same values the web app uses.

## 3. Key values

| Role | Light | Dark |
| --- | --- | --- |
| background | `#FAFAFA` | `#0A0A0A` |
| surface (cards/panels) | `#FFFFFF` | `#171717` |
| surfaceVariant | `#F5F5F5` | `#262626` |
| primary (the one accent) | `#4F46E5` indigo-600 | `#818CF8` indigo-400 |
| onPrimary | `#FFFFFF` (6.29:1) | `#1E1B4B` (5.36:1) |
| textPrimary | `#171717` (17.2:1) | `#F5F5F5` (18.2:1) |
| textSecondary | `#525252` (7.5:1) | `#D4D4D4` (12.1:1) |
| textMuted | `#737373` (4.54:1) | `#A3A3A3` (7.1:1) |
| border | `#E5E5E5` | `#262626` |
| outline (controls, ≥3:1) | `#737373` | `#737373` |
| focus ring | `#4F46E5` | `#818CF8` (on the PDF page: always `#4F46E5`) |
| success / warning / error / info | `#15803D` / `#B45309` / `#B91C1C` / `#1D4ED8` | `#4ADE80` / `#FBBF24` / `#F87171` / `#60A5FA` |
| offline / syncing / pending / sync error | gray / primary / warning / error | same roles |

All contrast ratios are listed in the JSON next to each token.

**Breakpoints** (logical width, `PaperWindowClass`). `design/specs/layout-system.md` uses these same names and ranges. Component specs: `design/specs/components.md`.

| Class | Width | Nav (`navigationWidth`) | Columns / margin / gutter | Side panel (`sidePanelMode`, default / min / max) | Reader toolbar |
| --- | --- | --- | --- | --- | --- |
| `compact` | < 600 | bottom bar (0) | 4 / 16 / 8 | bottom sheet, full width (snap 40% / 90%) | 56 |
| `medium` | 600–839 | rail 72 | 8 / 24 / 16 | overlay 360 / 320 / 85% | 64 |
| `expanded` | 840–1199 | rail 72 | 12 / 24 / 24 | split 360 / 300 / 50% | 64 touch · 48 pointer |
| `large` | 1200–1599 | sidebar 240 | 12 / 32 / 24 | split 380 / 300 / 50% | 64 touch · 48 pointer |
| `extraLarge` | ≥ 1600 | sidebar 256 | 12 / 40 / 24 (content max 1440) | split 420 / 320 / 45% | 64 touch · 48 pointer |

- **PDF viewport minimum 480dp** (720dp on `extraLarge`). `windowClass.sidePanelMaxWidth(windowWidth)` returns the smaller of the fraction cap and `windowWidth − pdfMin`; `splitFallsBackToOverlay(windowWidth)` is true when that max drops under the class minimum, so show the panel as an overlay instead.
- Class changes commit only 8dp past a boundary (`PaperBreakpoints.hysteresis`).
- `PaperChrome`: `readerToolbarHeight(windowClass, pointer:)`, split handle (1dp divider, 24×48 grabber, hit 24 touch / 16 pointer, key step 16 / 64, snap closed 48dp below min via `PaperBreakpoints.sidePanelCloseSnap`), macOS title row 52 with a 78×52 traffic-light reserve, Windows title bar 40 (48 merged) with 46×32 caption buttons in a 138 reserve, window min 480×560, default 1280×800.
- `PaperTheme` also themes `ListTile` (SettingsTile) and `Switch` (on: primary track; off: surfaceVariant track with a 1.5dp outline border).
- `PaperSpacing.gutter/margin/columns(windowClass)` give the layout grid. `gutter` is the space between columns; use `margin` for the outer page inset.

**Motion:** instant 80ms, fast 150ms, base 200ms, slow 300ms, page 300ms (fade only), emphasis 420ms, hover delay 40ms. Curves: standard `Cubic(0.4,0,0.2,1)`, decelerate `Cubic(0,0,0.2,1)`, accelerate `Cubic(0.4,0,1,1)`. Use `PaperMotion.of(context, d)` to respect the OS reduced-motion setting.

## 4. Performance rules built into the theme

- **No shadows on scrolling content.** Cards, app bars, nav and PDF pages use tonal surfaces and 1dp borders, with elevation 0. Only dialogs (light theme) get a shadow. Cards use `Clip.none`.
- `surfaceTint` is transparent, so M3 tint overlays are never computed.
- `splashFactory` is `InkRipple` (touch) or `NoSplash` (desktop). This avoids InkSparkle's shader compile on the first tap.
- Every platform uses `PaperFadePageTransitionsBuilder`: one `FadeTransition`, with no zoom, slide or shadow. This replaces the default `ZoomPageTransitionsBuilder` on Android and `CupertinoPageTransitionsBuilder` on macOS.

## 5. Highlights on the PDF

- The PDF page stays **white in both app themes** (web parity), so both themes register `PaperHighlightColors.whitePaper`. It paints with `BlendMode.multiply` at a resting alpha of 0.40, so the glyphs stay dark under the highlight.
- **No stacking:** draw all rects of one color on a page inside a single `canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0,0,0,alpha)..blendMode = hl.blendMode)`. Inside that layer, draw the opaque `PaperHighlightColor.wash`. Overlapping rects then never get darker. This matches the web's per-hue wash-layer contract.
- If you add an inverted "night paper" mode, use `PaperHighlightColors.darkPaper` (srcOver blending, lower alpha). Multiply over a dark page turns black.
- AI marks (`PaperReaderMark`) rest at 0.10 alpha, show the `full` fill and a 1.5dp `ring` on hover, and use `focusRingOnPaper` at 2dp for keyboard focus.
- Stylus highlighter strokes: `hl.ink(color)`, with one layer per color per page.
