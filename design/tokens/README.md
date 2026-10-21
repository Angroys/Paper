# Paper design tokens (Flutter)

| File | What |
| --- | --- |
| `paper-tokens.json` | Source of truth. Every value equals what the paper.college web app renders (RPR `tailwind.config.ts`, `src/app/globals.css`, `src/components/**`) |
| `paper_tokens.dart` | Hand-written Flutter theme built from the JSON. Imports only `package:flutter/material.dart`, with no codegen |

If you change a value, change it in both files.

**v2 (web parity, 2026-10).** All values now equal the web. The web is dark-only, so the app is dark-only. The full extraction is in `design/web-parity/tokens.md`: CSS variables, every Tailwind class used by the in-scope components resolved to hex, fonts, type scale, icons and the old→new table. Reference screenshots are in `design/web-parity/reference/`.

## 1. Wire it in

1. Copy `design/tokens/paper_tokens.dart` to `lib/theme/paper_tokens.dart`.
2. Requires **Flutter ≥ 3.35**: it uses `AppBarThemeData`, `InputDecorationThemeData`, `CardThemeData`, `DialogThemeData`, `WidgetStateProperty` and `Color.withValues`. Checked with Flutter 3.47.7 stable: `dart format` reports no changes and `flutter analyze` reports no issues. A widget smoke test pumped the theme on android, windows and macOS and confirmed the web heights: filled button 36, outlined button 38, text field 38, icon button 32.
3. Set up the app. The web is dark-only, so the app is too:

```dart
import 'package:flutter/material.dart';
import 'theme/paper_tokens.dart';

MaterialApp(
  theme: PaperTheme.dark(),
  themeMode: ThemeMode.dark,
  themeAnimationDuration: Duration.zero,
);
```

- Remove the System / Light / Dark setting.
- `PaperTheme.light()` and `PaperColors.light` still exist only as aliases of the dark values, so old call sites compile. Delete them in the same change that removes the toggle.
- Sizes are the web's on every platform: 36 buttons, 38 bordered controls, 32 icon buttons, `MaterialTapTargetSize.shrinkWrap`, `NoSplash`, `VisualDensity.standard`. There is no touch enlargement and no ink ripple.

4. Read the tokens in widgets:

```dart
final colors = Theme.of(context).extension<PaperColors>()!;
final hl = Theme.of(context).extension<PaperHighlightColors>()!;

Container(color: colors.surface);                 // web .card bg (gray-900)
Container(color: PaperWeb.gray800);               // a spec citing dark:bg-gray-800
TextField(style: PaperTypography.input(colors));  // REQUIRED: 14/20 text, 38px tall
Text('Library', style: PaperTypography.pageTitle(colors));
AnimatedContainer(duration: PaperMotion.of(context, PaperMotion.colors), curve: PaperMotion.standard, …);
Padding(padding: EdgeInsets.all(PaperSpacing.tw5));   // web p-5
```

Suggestion: add `extension PaperThemeX on BuildContext { PaperColors get paper => Theme.of(this).extension<PaperColors>()!; }` in the app.

### What is in the Dart file

- **Colours:**
  - `PaperColors`: semantic roles, a ThemeExtension. `light` is an alias of `dark`.
  - `PaperWeb`: new. Exact web colours by Tailwind or CSS-var name, plus pre-composited opacity variants.
  - `PaperHighlightColor`: an enum of 6 hues.
  - `PaperHighlightColors`: alphas and blend mode.
  - `PaperReaderMark`: AI marks.
- **Layout:**
  - `PaperSpacing`, which now includes the Tailwind steps `tw0_5`…`tw24` and `tw(n)`.
  - `PaperRadii`.
  - `PaperElevation`, which now includes the Tailwind `shadowSm`…`shadow2xl`.
  - `PaperIconSize`.
  - `PaperHitTarget`, with the web control sizes.
  - `PaperLayer`.
- **Motion:** `PaperMotion`, which now includes `colors`, `spin`, `pulse` and `progressIndeterminate`.
- **Breakpoints and window classes:**
  - `PaperBreakpoints`, which now includes the Tailwind breakpoints `twSm`…`tw2xl`, `max-w-*` containers and `readerPanelWeb` = 384.
  - `PaperWindowClass`, `PaperSidePanelMode` and `PaperChrome`.
- **Typography:** `PaperTypography`, which now includes the Tailwind `text*` / `leading*` constants and `pageTitle`, `sectionTitle`, `cardTitle`, `eyebrow` and `input`.
- **Theme:** `PaperFadePageTransitionsBuilder` and `PaperTheme`.

## 2. Fonts: bundle the web's exact Geist files

The web loads two **variable** WOFF files with `next/font/local` (`src/app/layout.tsx`):

- `src/app/fonts/GeistVF.woff`: Geist **v1.200**, wght axis 100–900.
- `src/app/fonts/GeistMonoVF.woff`: Geist Mono v1.200.

Each is exposed as `--font-geist-sans` / `--font-geist-mono` and declared with `weight: "100 900"`.

The app used to bundle Geist **v1.801** static TTFs. Those have different vertical metrics:

| Version | hhea ascender / descender / lineGap |
| --- | --- |
| v1.200 (web) | 920 / −220 / 100 |
| v1.801 (old app) | 1005 / −295 / 0 |

They also have different glyph sets (783 vs 975 glyphs). With the old files every line of text sits a pixel or two off the web.

Use the web's own files instead. Static instances cut from those exact VF files (fontTools `instancer`, wght pinned, no other change) are in `design/web-parity/fonts/`:

```
Geist-Regular.ttf  (400)   GeistMono-Regular.ttf  (400)
Geist-Medium.ttf   (500)   GeistMono-Medium.ttf   (500)
Geist-SemiBold.ttf (600)   GeistMono-SemiBold.ttf (600)
Geist-Bold.ttf     (700)
OFL.txt                    GeistVF.woff, GeistMonoVF.woff (the untouched web originals)
```

To adopt them:

1. Replace `assets/fonts/Geist*.ttf` with the files above.
2. Keep the existing `pubspec.yaml` family names (`Geist`, `GeistMono`).
3. Add `GeistMono-SemiBold.ttf` at weight 600.

```yaml
flutter:
  fonts:
    - family: Geist
      fonts:
        - asset: assets/fonts/Geist-Regular.ttf
          weight: 400
        - asset: assets/fonts/Geist-Medium.ttf
          weight: 500
        - asset: assets/fonts/Geist-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Geist-Bold.ttf
          weight: 700
    - family: GeistMono
      fonts:
        - asset: assets/fonts/GeistMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/GeistMono-Medium.ttf
          weight: 500
        - asset: assets/fonts/GeistMono-SemiBold.ttf
          weight: 600
```

Do not use `google_fonts`: it fetches at runtime and serves a newer Geist. Static instances are used rather than the VF because Flutter only drives the `wght` axis through explicit `FontVariation`s, and `FontWeight` alone would not select the weight.

### License notes

- Geist and Geist Mono are licensed under the SIL OFL 1.1 (© The Geist Project Authors, Vercel).
- Ship `OFL.txt` and keep the existing `LicenseRegistry.addLicense` call.
- The instances keep the family names "Geist" / "Geist Mono". Pinning an axis of the same font version is not a modification that requires renaming under the OFL; no glyph or outline was changed.
- Colours come from Tailwind CSS's palette (MIT) with the web's own neutral-gray override.

## 3. Key values (dark-only)

| Role | Value | Web source |
| --- | --- | --- |
| background | `#0A0A0A` | `--background` / `bg-gray-950` |
| surface (cards, inputs, popovers) | `#171717` | `.card` / `.field-input` `dark:bg-gray-900` |
| surfaceVariant (hover, chips) | `#262626` | `dark:bg-gray-800` |
| primary (the one accent) | `#818CF8` | `--accent` (indigo-400) |
| onPrimary | `#1E1B4B` | `.btn-primary dark:text-indigo-950` |
| primarySoft / onPrimarySoft | `#1E1B4B` / `#C7D2FE` | `--accent-soft` / `--accent-ink` |
| textPrimary | `#F5F5F5` | `dark:text-gray-100` |
| textSecondary | `#D4D4D4` | `dark:text-gray-300` |
| textMuted | `#A3A3A3` | `dark:text-gray-400` (the most used text colour) |
| border / divider | `#262626` | `dark:border-gray-800` |
| outline (input / secondary-button border) | `#404040` | `dark:border-gray-700` |
| focus ring | `#818CF8`, 2px, offset 2px on gray-950 | `focus-visible:ring-2 ring-accent ring-offset-2` |
| focus ring on the PDF page | `#4F46E5` | `--mark-focus-ring` |
| error / success / warning | `#F87171` / `#4ADE80` / `#FBBF24` | red-400 / green-400 / amber-400 |

Contrast is checked in `design/web-parity/tokens.md` §12. A few web pairs are below AA and are kept for parity:

- outline: 1.73:1
- gray-500 meta text: 3.78:1

**Breakpoints.** The app's window classes are unchanged: 600, 840, 1200 and 1600. Responsive changes that mirror a web `sm:` / `md:` / `lg:` / `xl:` switch use `PaperBreakpoints.twSm` (640), `twMd` (768), `twLg` (1024) and `twXl` (1280). The reader side panel default is now 384 (the web's `w-96`) in every class.

**Motion:**

- Web durations and easings, all unchanged: instant 80ms, fast 150ms, base 200ms, slow 300ms, emphasis 420ms, hover delay 40ms.
- New: `colors` (150ms + `standard`, Tailwind's `transition-colors` default), `spin` 1s linear, `pulse` 2s and `progressIndeterminate` 1.2s.
- The web has **no route transitions**, because navigation is instant. `page` (300ms fade) is kept for the app shell; see tokens.md §10.

## 4. Performance rules built into the theme

- Shadows are now the web's Tailwind shadows. The web keeps them in dark mode, and on `#0A0A0A` they are faint.
  - Use them only on overlays: popovers (`shadowLg`/`shadowXl`), dialogs (`shadowXl`), toasts (`shadowMd`) and the PDF toolbar (`shadowSm`).
  - Never use them on scrolling lists or PDF pages.
  - Cards use a border only and `Clip.none`.
- `surfaceTint` is transparent.
- `splashFactory` is `NoSplash` everywhere, which matches the web and avoids InkSparkle's first-tap shader compile.
- Every platform uses `PaperFadePageTransitionsBuilder`.

## 5. Highlights on the PDF

- The PDF page stays **white**, so the theme registers `PaperHighlightColors.whitePaper`.
- It paints the opaque wash with `BlendMode.multiply` at the web's resting alpha **0.10** (`--highlight-wash-opacity`; it was 0.40 before).
  - Hover is 0.55 with a 1.5px ring in the hue's 600 shade.
  - Pressed is 0.68.
  - The just-created pending selection is `#FBBF24` at 0.40 (`pending`).
- **No stacking:** draw all rects of one colour on a page inside a single `saveLayer` with the alpha applied once. This matches the web's per-hue wash layer.
- AI marks (`PaperReaderMark`) rest at 0.10, show `full` plus a 1.5px `ring` on hover, and use `focusRingOnPaper` at 2px for keyboard focus.
- PDF text selection is `PaperWeb.pdfSelection` (indigo-600 at 30%).
