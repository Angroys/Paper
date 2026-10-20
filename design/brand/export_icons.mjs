// Paper app icon + splash exporter (single source of truth for every icon file).
//
// Usage (from any scratch dir that has @resvg/resvg-js@2.6.2 installed):
//   NODE_PATH=<scratch>/node_modules node design/brand/export_icons.mjs
// Writes SVG masters + all PNG/ICO exports next to this script.
// No dependency is added to the repo; resvg is a scratch-only tool.

import { createRequire } from "node:module";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
let Resvg;
try {
  ({ Resvg } = require("@resvg/resvg-js"));
} catch {
  ({ Resvg } = require(join(process.env.NODE_PATH ?? "", "@resvg/resvg-js")));
}

const OUT = dirname(fileURLToPath(import.meta.url));

// ---- Palette (from paper.college: globals.css / tailwind.config.ts) ----
const C = {
  canvasDark: "#0A0A0A", // --background (dark) neutral-950
  plate: "#171717", // neutral-900, gradient top of the icon plate
  canvasLight: "#FAFAFA", // --background (light) neutral-50
  sheet: "#FAFAFA", // paper sheet
  fold: "#D4D4D4", // neutral-300 folded corner
  title: "#404040", // neutral-700
  line: "#A3A3A3", // neutral-400
  highlight: "#818CF8", // --accent (dark) indigo-400 = citation wash
  highlightInk: "#312E81", // --accent-ink (light) indigo-900
  outline: "#262626", // neutral-800 (light-bg splash outline)
};

// ---- The mark, drawn on the 108x108 adaptive-icon grid ----
// Sheet bbox 36..72 x 31..77 (half-diagonal 29.2 < 33 safe radius).
const SHEET =
  "M39 31H62L72 41V74A3 3 0 0 1 69 77H39A3 3 0 0 1 36 74V34A3 3 0 0 1 39 31Z";
const FOLD = "M62 31V38A3 3 0 0 0 65 41H72Z";

function markColor({ simple = false, outline = false } = {}) {
  const o = outline
    ? `<path d="${SHEET}" fill="none" stroke="${C.outline}" stroke-width="1" stroke-linejoin="round"/>`
    : "";
  const body = simple
    ? `<rect x="42" y="45" width="16" height="4" rx="2" fill="${C.title}"/>
    <rect x="40" y="55" width="28" height="9" rx="2.5" fill="${C.highlight}"/>`
    : `<rect x="42" y="45" width="16" height="3.2" rx="1.6" fill="${C.title}"/>
    <rect x="42" y="51.6" width="24" height="2.4" rx="1.2" fill="${C.line}"/>
    <rect x="40.5" y="56.6" width="27" height="7" rx="2" fill="${C.highlight}"/>
    <rect x="42" y="58.9" width="24" height="2.4" rx="1.2" fill="${C.highlightInk}"/>
    <rect x="42" y="67" width="18" height="2.4" rx="1.2" fill="${C.line}"/>`;
  return `<g id="paper-mark">
    <path d="${SHEET}" fill="${C.sheet}"/>${o}
    <path d="${FOLD}" fill="${C.fold}"/>
    ${body}
  </g>`;
}

// Single-colour mark (Android 13 themed icon / monochrome): alpha only.
function markMono(color = "#FFFFFF") {
  return `<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="108" height="108">
      <path d="${SHEET}" fill="#fff"/>
      <path d="M62 31V38A3 3 0 0 0 65 41H72" fill="none" stroke="#000" stroke-width="2" stroke-linejoin="round"/>
      <rect x="42" y="45" width="16" height="3.2" rx="1.6" fill="#000"/>
      <rect x="42" y="51.6" width="24" height="2.4" rx="1.2" fill="#000"/>
      <rect x="40.5" y="56.6" width="27" height="7" rx="2" fill="#000"/>
      <rect x="42" y="58.9" width="24" height="2.4" rx="1.2" fill="#fff"/>
      <rect x="42" y="67" width="18" height="2.4" rx="1.2" fill="#000"/>
    </mask></defs>
    <rect width="108" height="108" fill="${color}" mask="url(#m)"/>`;
}

const BG_DEFS = `<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${C.plate}"/><stop offset="1" stop-color="${C.canvasDark}"/>
    </linearGradient>`;

const svg108 = (inner, defs = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="0 0 108 108">${defs ? `<defs>${defs}</defs>` : ""}\n  ${inner}\n</svg>\n`;

// Composite icon: a plate shape inside an S x S canvas, showing the
// 72-unit visible viewport (18..90) of the adaptive layers, like a launcher.
function composite(S, { shape = "square", margin = 0, radius = 0, shadow = false, simple = false } = {}) {
  const x = S * margin;
  const w = S - 2 * x;
  const r = shape === "circle" ? w / 2 : w * radius;
  const plate = `<rect x="${x}" y="${x}" width="${w}" height="${w}" rx="${r}" ry="${r}"/>`;
  const filt = shadow
    ? `<filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="${S * 0.012}"/></filter>`
    : "";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">
  <defs>${BG_DEFS}<clipPath id="clip">${plate}</clipPath>${filt}</defs>
  ${shadow ? `<g filter="url(#sh)" transform="translate(0 ${S * 0.012})" fill="#000" fill-opacity="0.35">${plate}</g>` : ""}
  <g><g clip-path="url(#clip)">
    <svg x="${x}" y="${x}" width="${w}" height="${w}" viewBox="18 18 72 72">
      <rect x="0" y="0" width="108" height="108" fill="url(#bg)"/>
      ${markColor({ simple })}
    </svg>
  </g></g>
</svg>\n`;
}

// Mark-only canvas (transparent), mark scaled so the 108 grid fills S.
const markCanvas = (S, opts) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 108 108">\n  ${markColor(opts)}\n</svg>\n`;
// Tight splash logo: crop to the sheet bbox with even padding (viewBox 26..82).
const splashLogo = (opts) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="288" height="288" viewBox="26 26 56 56">\n  ${markColor(opts)}\n</svg>\n`;

function png(svg, size) {
  return new Resvg(svg, { fitTo: { mode: "width", value: size }, background: "rgba(0,0,0,0)" })
    .render()
    .asPng();
}
function write(rel, data) {
  const p = join(OUT, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, data);
}

// PNG-compressed ICO (Vista+); each entry is an exact render, not a resample.
function ico(pngs) {
  const head = Buffer.alloc(6 + 16 * pngs.length);
  head.writeUInt16LE(0, 0);
  head.writeUInt16LE(1, 2);
  head.writeUInt16LE(pngs.length, 4);
  let off = head.length;
  pngs.forEach(({ size, data }, i) => {
    const e = 6 + 16 * i;
    head.writeUInt8(size >= 256 ? 0 : size, e);
    head.writeUInt8(size >= 256 ? 0 : size, e + 1);
    head.writeUInt16LE(1, e + 4); // planes
    head.writeUInt16LE(32, e + 6); // bpp
    head.writeUInt32LE(data.length, e + 8);
    head.writeUInt32LE(off, e + 12);
    off += data.length;
  });
  return Buffer.concat([head, ...pngs.map((p) => p.data)]);
}

// ---------------- Masters ----------------
const ANDROID_SQ = { shape: "square", margin: 4 / 48, radius: 0.2 };
const ANDROID_RD = { shape: "circle", margin: 2 / 48 };
const MAC = { shape: "square", margin: 100 / 1024, radius: 185.4 / 824, shadow: true };
const WIN = { shape: "square", margin: 1 / 32, radius: 0.2 };
const PLAY = { shape: "square", margin: 0, radius: 0 };

const master = composite(1024, { shape: "square", margin: 0, radius: 0.2 });
write("icon/paper-icon.svg", master);
write("icon/paper-icon-foreground.svg", svg108(markColor()));
write("icon/paper-icon-background.svg", svg108(`<rect width="108" height="108" fill="url(#bg)"/>`, BG_DEFS));
write("icon/paper-icon-monochrome.svg", svg108(markMono()));
write("icon/paper-icon-macos.svg", composite(1024, MAC));
write("icon/paper-icon-1024.png", png(master, 1024));

// ---------------- Android ----------------
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
const fg = svg108(markColor());
const bg = svg108(`<rect width="108" height="108" fill="url(#bg)"/>`, BG_DEFS);
const mono = svg108(markMono());
for (const [d, k] of Object.entries(densities)) {
  const L = 48 * k;
  const A = 108 * k;
  write(`android/mipmap-${d}/ic_launcher.png`, png(composite(L, ANDROID_SQ), L));
  write(`android/mipmap-${d}/ic_launcher_round.png`, png(composite(L, ANDROID_RD), L));
  write(`android/mipmap-${d}/ic_launcher_foreground.png`, png(fg, A));
  write(`android/mipmap-${d}/ic_launcher_background.png`, png(bg, A));
  write(`android/mipmap-${d}/ic_launcher_monochrome.png`, png(mono, A));
}
write("android/mipmap-anydpi-v26/ic_launcher.xml", adaptiveXml());
write("android/mipmap-anydpi-v26/ic_launcher_round.xml", adaptiveXml());
write("android/playstore-icon.png", png(composite(512, PLAY), 512));

function adaptiveXml() {
  return `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
`;
}

// ---------------- Windows ----------------
const icoSizes = [16, 24, 32, 48, 64, 128, 256];
write(
  "windows/app_icon.ico",
  ico(icoSizes.map((s) => ({ size: s, data: png(composite(s, { ...WIN, simple: s <= 32 }), s) }))),
);
write("windows/icon-256.png", png(composite(256, WIN), 256));
// MSIX tiles: mark on the plate colour, full bleed (Windows draws the tile).
for (const s of [44, 150, 310]) {
  write(`windows/msix/Square${s}x${s}Logo.png`, png(composite(s, { ...PLAY, simple: s <= 44 }), s));
}

// ---------------- macOS ----------------
write("macos/icon-1024.png", png(composite(1024, MAC), 1024));
for (const b of [16, 32, 128, 256, 512]) {
  write(`macos/AppIcon.iconset/icon_${b}x${b}.png`, png(composite(b, { ...MAC, simple: b <= 16 }), b));
  write(`macos/AppIcon.iconset/icon_${b}x${b}@2x.png`, png(composite(b * 2, { ...MAC, simple: b * 2 <= 16 }), b * 2));
}

// Drop-in for Flutter's macos/Runner/Assets.xcassets/AppIcon.appiconset/
// (same file names as `flutter create`).
const macSlots = [[16, 1, 16], [16, 2, 32], [32, 1, 32], [32, 2, 64], [128, 1, 128], [128, 2, 256], [256, 1, 256], [256, 2, 512], [512, 1, 512], [512, 2, 1024]];
for (const px of [16, 32, 64, 128, 256, 512, 1024]) {
  write(`macos/AppIcon.appiconset/app_icon_${px}.png`, png(composite(px, { ...MAC, simple: px <= 16 }), px));
}
write(
  "macos/AppIcon.appiconset/Contents.json",
  JSON.stringify(
    {
      images: macSlots.map(([pt, sc, px]) => ({ size: `${pt}x${pt}`, idiom: "mac", filename: `app_icon_${px}.png`, scale: `${sc}x` })),
      info: { version: 1, author: "xcode" },
    },
    null,
    2,
  ) + "\n",
);

// ---------------- Splash ----------------
write("splash/splash-logo.svg", splashLogo());
write("splash/splash-logo-light.svg", splashLogo({ outline: true }));
for (const s of [288, 576, 1152]) {
  write(`splash/splash-logo-${s}.png`, png(splashLogo(), s));
  write(`splash/splash-logo-light-${s}.png`, png(splashLogo({ outline: true }), s));
}
write("splash/splash-logo.png", png(splashLogo(), 576));
write("splash/splash-logo-light.png", png(splashLogo({ outline: true }), 576));
// Android 12: 1152 canvas, visible circle 768 (= 72 of 108 units); mark sits
// inside the 66-unit safe circle. Same art as the adaptive foreground.
write("splash/splash-android12.png", png(markCanvas(1152), 1152));

console.log("done");
