# Paper — splash spec

The splash is the app icon's mark (the paper sheet with one indigo-highlighted line) centred on the brand canvas. There is no wordmark, tagline, spinner or animation. The splash covers start-up only and is never used as a loading screen.

## Colours

| Theme | Screen background | Logo asset | Android 12 icon disc |
| --- | --- | --- | --- |
| Light | `#FAFAFA` (neutral-50, web `--background` light) | `splash-logo-light.png` (sheet with a 1-unit `#262626` outline, so it doesn't disappear into the canvas) | `#0A0A0A` |
| Dark (default; the web app is dark-only) | `#0A0A0A` (neutral-950, web `--background` dark) | `splash-logo.png` (no outline) | `#171717` |

## Size

- `splash-logo*.svg` uses viewBox `26 26 56 56` on the 108-unit icon grid. The sheet takes up about 64% × 82% of the logo box.
- The logo is drawn at **144 dp** square. `splash-logo.png` is 576 px, which flutter_native_splash treats as xxxhdpi (4×), so it comes out at 144 dp.
- Other renders are provided as `-288`, `-576` and `-1152` (the 1152 px file is for desktop / 4K or for scaling down).
- Android 12+: use `splash-android12.png` (1152 × 1152). The mark stays inside the central 768 px circle that the system masks to (it actually stays inside 704 px, the 66/108 safe zone). It is the same art as the adaptive-icon foreground, so the splash-to-launcher transition matches.

## Timing

- **No artificial delay.** Call `FlutterNativeSplash.preserve()` in `main()`, then `FlutterNativeSplash.remove()` once the first frame is ready **and** the Supabase session has been restored from local storage. Do not wait on the network for this.
- **Hard cap: 2 s.** If the session restore takes longer, remove the splash anyway and show the library skeleton.
- **Exit:** a 200 ms opacity fade with standard easing `cubic-bezier(0.4, 0, 0.2, 1)`. These match the web tokens `--mark-settle-duration` and `--mark-ease-settle`. Android 12 uses the system exit animation; don't override it.
- **Reduced motion** (Android "Remove animations" / OS reduce-motion): cut straight to the app with no fade.

## Desktop (Windows / macOS)

flutter_native_splash only supports Android, iOS and web. On desktop:

- Set the native window background to `#0A0A0A` before Flutter attaches, so there is no white flash:
  - **macOS:** in `MainFlutterWindow.swift`, set `backgroundColor = NSColor(red: 0.039, green: 0.039, blue: 0.039, alpha: 1)`.
  - **Windows:** in `win32_window.cpp`, have `WM_ERASEBKGND` paint `#0A0A0A`.
- On top of that, an optional in-app `SplashGate` widget can paint the same canvas with `splash-logo.svg` (flutter_svg) or `splash-logo-1152.png` at 144 logical px, following the same timing rules.

## flutter_native_splash config (pubspec.yaml or flutter_native_splash.yaml)

Copy `design/brand/splash/*.png` to `assets/brand/splash/` first.

```yaml
flutter_native_splash:
  color: "#FAFAFA"
  image: assets/brand/splash/splash-logo-light.png
  color_dark: "#0A0A0A"
  image_dark: assets/brand/splash/splash-logo.png

  android_12:
    color: "#FAFAFA"
    image: assets/brand/splash/splash-android12.png
    icon_background_color: "#0A0A0A"
    color_dark: "#0A0A0A"
    image_dark: assets/brand/splash/splash-android12.png
    icon_background_color_dark: "#171717"

  android: true
  ios: false
  web: false
  fullscreen: false
  android_gravity: center
```

Regenerate with `dart run flutter_native_splash:create`.
