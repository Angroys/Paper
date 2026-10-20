# Paper — native app brand notes (v1)

**Stage:** Evolution. This document extends the existing paper.college identity and invents no new hues or typefaces.
**Source of truth (read-only):** `research-paper-helper` → `src/app/globals.css`, `tailwind.config.ts`, `src/app/layout.tsx`, `design/brand/graph-lib-visual-language.md`.
**Register:** warm-technical, airy, neutral grays plus **one** indigo accent. The web app is dark-only, so the native app defaults to dark and also ships a light theme.

> **Note on the favicon.** The current web favicon (`src/app/favicon.ico`) is the default Next.js/Vercel triangle. It is not a Paper mark, so nothing was derived from it. The mark below is new, built only from existing brand elements: the white PDF "paper" canvas and the indigo reader highlight. Follow-up for the web team: replace the favicon with `icon/paper-icon.svg` (out of scope here; RPR is read-only).

---

## 1. Palette

Every value is an existing web token. Contrast figures are WCAG 2.x ratios, computed.

| Role | Light | Dark | Web token |
| --- | --- | --- | --- |
| Canvas | `#FAFAFA` | `#0A0A0A` | `--background` |
| Surface / icon plate top | `#FFFFFF` | `#171717` | neutral-0 / neutral-900 |
| Ink | `#171717` (17.2:1 on canvas) | `#F5F5F5` (18.2:1) | `--foreground` |
| Muted ink | `#525252` (7.5:1) | `#A3A3A3` (7.9:1) | gray-600 / gray-400 |
| Quiet ink (captions, ≥ UI 3:1) | `#737373` (4.5:1) | `#A3A3A3` | gray-500 |
| Accent | `#4F46E5` (6.0:1 on `#FAFAFA`, 6.3:1 on white) | `#818CF8` (6.6:1 on `#0A0A0A`) | `--accent` |
| Accent hover | `#4338CA` | `#A5B4FC` | `--accent-hover` |
| Accent soft (fills) | `#EEF2FF` | `#1E1B4B` | `--accent-soft` |
| Accent ink on soft | `#312E81` (10.2:1) | `#C7D2FE` (10.7:1) | `--accent-ink` |
| On-accent text | `#FFFFFF` on `#4F46E5` (6.3:1) | `#0A0A0A` on `#818CF8` (6.6:1) | — |

Reader mark families (unchanged from web; they always sit on the white PDF page): highlight amber `#FBBF24` / ring `#D97706`, term blue `#60A5FA` / ring `#2563EB`, citation indigo `#818CF8` / ring `#4F46E5`, appendix teal `#2DD4BF` / ring `#0D9488`, mention gray `#A3A3A3` / ring `#525252`.

**Icon-only colours:** sheet `#FAFAFA`, fold `#D4D4D4`, title bar `#404040`, text lines `#A3A3A3`, highlight band `#818CF8`, highlighted line `#312E81` (3.8:1 on the band, which clears the 3:1 graphical bar), plate gradient `#171717 → #0A0A0A`.

## 2. Typography

| Use | Family | License | Bundle |
| --- | --- | --- | --- |
| UI + display (wordmark "Paper" = Geist SemiBold, tracking −0.01em) | **Geist** (variable 100–900) | SIL Open Font License 1.1 (Vercel) | Bundle the TTFs from `github.com/vercel/geist-font` under `assets/fonts/`. Don't fetch at runtime, because the app must work offline. |
| Mono (DOIs, code, shortcuts) | **Geist Mono** | SIL OFL 1.1 | Same as above |

- **Fallbacks** (declare as `fontFamilyFallback`): Android `Roboto`; Windows `Segoe UI Variable`, `Segoe UI`; macOS `.AppleSystemUIFont` (SF Pro). Mono falls back to `Roboto Mono`, `Cascadia Mono` or `Menlo`.
- Weights: 400 body, 500 labels, 600 titles and wordmark. Line-height 1.5 for body, 1.25 for titles. Letter-spacing −0.01em at ≥ 20 px, otherwise 0.
- PDF page content is rendered by pdfium in the paper's own fonts. The brand type applies to app chrome only.
- Include the OFL text in the app's licenses page by calling `LicenseRegistry.addLicense` with `OFL.txt`.

## 3. Icon construction

- **Grid:** the Android adaptive canvas is 108 × 108 units. The visible launcher viewport is 72 units (18..90), and the **safe zone is a circle of diameter 66**.
- **Mark ("Paper sheet"):** a portrait sheet at x 36–72, y 31–77 (36 × 46 units, corner radius 3) with a 10-unit dog-ear fold at the top right. It is centred at (54, 54), and its half-diagonal is 29.2, inside the safe radius of 33.
- **Content of the sheet:**
  - A dark title bar.
  - Two gray text lines.
  - **One line highlighted in indigo.** The indigo band behind a dark line is the brand idea: "the line you didn't understand, explained". It is the reader's citation/highlight mark.
- **Plate:** a vertical gradient `#171717 → #0A0A0A`.
- **Platform shapes** (all rendered from the same 72-unit viewport):
  - Android legacy square: 4/48 margin, 20% radius.
  - Android round: 2/48 margin.
  - Play Store: full-bleed square; Google applies its own mask.
  - Windows: 1/32 margin, 20% radius.
  - macOS: Apple Big Sur grid, an 824 px plate in 1024 (100 px margin, ≈ 9.8%), radius 185.4, with a soft drop shadow of 1.2% offset and 1.2% blur at 35% black.
- **Small sizes** (≤ 32 px on Windows ICO frames / MSIX 44, ≤ 16 px on macOS) use a simplified mark with only the title bar and the highlight band, so the indigo stays readable.
- **Monochrome / Android 13 themed icon:** a single colour (white plus alpha). The sheet is solid, the lines and fold are knocked out, and the highlighted line stays solid inside a knocked-out band.
- **Clear space** around the mark is at least 25% of the sheet width. **Minimum size** is 16 px for the icon and 24 px for the sheet on its own in UI.

## 4. Do / Don't

**Do**
- Keep exactly one accent hue (indigo). The highlight band is the only colour in the mark.
- Use the dark plate by default.
- In light UI, show the mark either on its dark plate or with the outline variant.
- Regenerate every export from `export_icons.mjs` rather than editing PNGs by hand.

**Don't**
- Rotate or tilt the sheet, or add a drop shadow to the mark itself.
- Add gradients to the sheet.
- Recolour the highlight to amber or blue. In the reader those colours mean user highlights and terms.
- Add the wordmark inside the icon.
- Use the Vercel triangle favicon anywhere in the app.
- Put the sheet without an outline on light canvases below `#E5E5E5`. It disappears.

## 5. Asset inventory → Flutter destinations

Paths on the left are relative to `design/brand/`.

| Asset | Size | Flutter destination |
| --- | --- | --- |
| `icon/paper-icon.svg` | 1024 vector | Master (rounded plate). Source only; also the candidate web favicon. |
| `icon/paper-icon-1024.png` | 1024 | Source / marketing |
| `icon/paper-icon-foreground.svg` | 108 vector | Source for the adaptive foreground (`flutter_launcher_icons: adaptive_icon_foreground`) |
| `icon/paper-icon-background.svg` | 108 vector | Source for the adaptive background (gradient). For a flat colour use `#0A0A0A`. |
| `icon/paper-icon-monochrome.svg` | 108 vector | Source for the themed icon |
| `icon/paper-icon-macos.svg` | 1024 vector | Source for the macOS-shaped icon |
| `android/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` | 48/72/96/144/192 | `android/app/src/main/res/mipmap-<d>/ic_launcher.png` |
| `android/mipmap-<d>/ic_launcher_round.png` | 48–192 | `android/app/src/main/res/mipmap-<d>/ic_launcher_round.png` |
| `android/mipmap-<d>/ic_launcher_foreground.png` | 108/162/216/324/432 | `android/app/src/main/res/mipmap-<d>/ic_launcher_foreground.png` |
| `android/mipmap-<d>/ic_launcher_background.png` | 108–432 | `android/app/src/main/res/mipmap-<d>/ic_launcher_background.png` |
| `android/mipmap-<d>/ic_launcher_monochrome.png` | 108–432 | `android/app/src/main/res/mipmap-<d>/ic_launcher_monochrome.png` |
| `android/mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml` | XML | `android/app/src/main/res/mipmap-anydpi-v26/` (adaptive icon with a `<monochrome>` layer) |
| `android/playstore-icon.png` | 512 | Play Console listing (not bundled). Optionally `android/app/src/main/ic_launcher-playstore.png`. |
| `windows/app_icon.ico` | 16/24/32/48/64/128/256 (PNG frames) | `windows/runner/resources/app_icon.ico` |
| `windows/icon-256.png` | 256 | `msix_config: logo_path` (the msix package generates its tiles from it) |
| `windows/msix/Square{44,150,310}…Logo.png` | 44/150/310 | Optional hand-made MSIX tiles (`Assets/` of the package manifest) |
| `macos/AppIcon.appiconset/app_icon_{16,32,64,128,256,512,1024}.png` + `Contents.json` | Flutter names | `macos/Runner/Assets.xcassets/AppIcon.appiconset/` (replace the folder contents) |
| `macos/AppIcon.iconset/icon_{16,32,128,256,512}x…{,@2x}.png` | Apple iconset | `iconutil -c icns` → `.icns` for the DMG volume icon / CI. Not bundled. |
| `macos/icon-1024.png` | 1024 | Mac App Store listing / DMG background art |
| `splash/splash-logo.png` (576), `-288/-576/-1152` | 4× = 144 dp | `assets/brand/splash/` → `flutter_native_splash.image_dark`, desktop `SplashGate` |
| `splash/splash-logo-light.png` (+ sizes, `.svg`) | 576 | `assets/brand/splash/` → `flutter_native_splash.image` |
| `splash/splash-logo.svg` | vector | `assets/brand/splash/` (flutter_svg, desktop in-app splash) |
| `splash/splash-android12.png` | 1152 (mark inside the 768 circle) | `assets/brand/splash/` → `flutter_native_splash.android_12.image` |
| `splash/splash.md` | — | Splash spec + config snippet |
| `export_icons.mjs` | — | Regenerates everything above |

**Regenerate:** in a scratch dir run `npm i @resvg/resvg-js@2.6.2`, then `NODE_PATH=<scratch>/node_modules node design/brand/export_icons.mjs`. Nothing is added to the app's dependencies.
