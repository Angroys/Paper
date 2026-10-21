// Reference-screenshot capture for the web-parity restyle (M1).
//
// Captures the paper.college web app with headless Chromium (Playwright),
// at a landscape-tablet (1280x800) and a portrait (800x1280) viewport.
//
//   node capture.mjs live  [outDir]   signed-out screens from https://www.paper.college
//   node capture.mjs local [outDir]   signed-in screens from a local `next build && next start`
//                                     of RPR wired to mock-supabase.mjs (see README)
//
// Playwright is not a dependency of this repo. It is loaded from the RPR
// checkout's node_modules (RPR_DIR, default /home/minimax/research-paper-helper),
// so nothing is installed here and nothing in RPR is modified.
//
// Safety: every request to Supabase's anonymous sign-up endpoint
// (`/auth/v1/signup`) is aborted and logged, so a capture can never create
// a Supabase user on the live project.

import { createRequire } from "node:module";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const RPR_DIR = process.env.RPR_DIR ?? "/home/minimax/research-paper-helper";
const require = createRequire(path.join(RPR_DIR, "package.json"));
const { chromium } = require("@playwright/test");

const mode = process.argv[2] ?? "live";
const outDir = path.resolve(process.argv[3] ?? here);
const LIVE = process.env.LIVE_URL ?? "https://www.paper.college";
const LOCAL = process.env.LOCAL_URL ?? "http://localhost:3000";
const MOCK = process.env.MOCK_URL ?? "http://127.0.0.1:54399";

const VIEWPORTS = [
  { name: "1280x800", width: 1280, height: 800 },
  { name: "800x1280", width: 800, height: 1280 },
];

const launchArgs = [
  // The signed-out hero is WebGL (react-three-fiber); SwiftShader renders it headless.
  "--use-gl=swiftshader",
  "--enable-unsafe-swiftshader",
  "--font-render-hinting=none",
];

async function newPage(browser, vp, extra = {}) {
  const ctx = await browser.newContext({
    viewport: { width: vp.width, height: vp.height },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "reduce", // freezes idle float / pulses so frames are stable
    ...extra,
  });
  await ctx.route("**/auth/v1/signup**", (route) => {
    console.warn("[blocked] anonymous sign-up request:", route.request().url());
    return route.abort();
  });
  return { ctx, page: await ctx.newPage() };
}

async function settle(page, ms = 1500) {
  await page.waitForLoadState("networkidle").catch(() => {});
  await page.evaluate(() => document.fonts?.ready).catch(() => {});
  await page.waitForTimeout(ms);
}

async function shot(page, file, opts = {}) {
  const p = path.join(outDir, file);
  await page.screenshot({ path: p, ...opts });
  console.log("wrote", path.relative(process.cwd(), p));
}

// ---------------------------------------------------------------- live
async function live(browser) {
  for (const vp of VIEWPORTS) {
    const { ctx, page } = await newPage(browser, vp);
    await page.goto(`${LIVE}/`, { waitUntil: "domcontentloaded" });
    await settle(page, 4000);
    await shot(page, `landing.${vp.name}.png`);
    await shot(page, `landing.full.${vp.name}.png`, { fullPage: true });

    await page.goto(`${LIVE}/sign-in`, { waitUntil: "domcontentloaded" });
    await settle(page);
    await shot(page, `sign-in.${vp.name}.png`);

    // Focus state of the email field + primary button (keyboard focus ring).
    const email = page.locator('input[type="email"]').first();
    if (await email.count()) {
      await email.focus();
      await page.waitForTimeout(250);
      await shot(page, `sign-in.focus-email.${vp.name}.png`);
    }
    await ctx.close();
  }
}

// ---------------------------------------------------------------- local
// Signed-in screens, served by a production build of RPR (`next build` +
// `next start`) pointed at mock-supabase.mjs. The session cookie is minted
// by mock-supabase.mjs (`sessionCookie()`), so no real account exists anywhere.
// `next dev` is NOT used: pdfjs-dist 5 crashes under the dev webpack runtime
// ("Object.defineProperty called on non-object"), so the reader never renders.
const ANDROID_TABLET_UA =
  "Mozilla/5.0 (Linux; Android 14; SM-X710) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

async function local(browser) {
  const { sessionCookie, FIXTURE } = await import(path.join(here, "mock-supabase.mjs"));
  const cookie = sessionCookie();
  const url = new URL(LOCAL);
  const resetMock = () => fetch(`${MOCK}/__reset`, { method: "POST" });
  for (const vp of VIEWPORTS) {
    await resetMock();
    const { ctx, page } = await newPage(browser, vp);
    await ctx.addCookies([{ ...cookie, domain: url.hostname, path: "/" }]);

    // Library (dashboard).
    await page.goto(`${LOCAL}/library`, { waitUntil: "domcontentloaded" });
    await settle(page, 2500);
    await shot(page, `library.${vp.name}.png`);
    await shot(page, `library.full.${vp.name}.png`, { fullPage: true });
    // "Add a paper" disclosure open (upload + import forms).
    await optional("add-paper", async () => {
      const add = page.locator('[aria-controls="library-add-panel"]').first();
      await add.evaluate((el) => el.scrollIntoView({ block: "start" }));
      await add.click({ timeout: 5000 });
      await page.waitForTimeout(600);
      await shot(page, `library.add-paper-open.${vp.name}.png`);
    });

    // Glossary: lives on the project page (GlossarySearch over the project's terms).
    await page.goto(`${LOCAL}/projects/${FIXTURE.projectId}`, { waitUntil: "domcontentloaded" });
    await settle(page, 2000);
    await shot(page, `project.${vp.name}.png`);
    await shot(page, `project.full.${vp.name}.png`, { fullPage: true });
    const search = page.locator('input[type="search"], input[placeholder*="earch"]').first();
    if (await search.count()) await optional("glossary", async () => {
      await search.scrollIntoViewIfNeeded();
      await page.evaluate(() => window.scrollBy(0, 0));
      await search.evaluate((el) => el.scrollIntoView({ block: "start" }));
      await page.waitForTimeout(300);
      await shot(page, `glossary.${vp.name}.png`);
      // Expand the first entry card.
      const expander = page.locator("button[aria-expanded]").filter({ hasText: "Newton-Raphson" }).first();
      if (await expander.count()) {
        await expander.click({ timeout: 5000 });
        await page.waitForTimeout(400);
        await expander.evaluate((el) => el.scrollIntoView({ block: "center" }));
        await shot(page, `glossary.entry-expanded.${vp.name}.png`);
      }
      await search.fill("diff");
      await page.waitForTimeout(600);
      await shot(page, `glossary.search.${vp.name}.png`);
    });

    // Settings.
    await page.goto(`${LOCAL}/settings`, { waitUntil: "domcontentloaded" });
    await settle(page, 1500);
    await shot(page, `settings.${vp.name}.png`);

    // Reader (desktop UA: docked explanation side panel).
    await openReader(page, FIXTURE);
    await shot(page, `reader.${vp.name}.png`);
    await optional("reader interactions", () => readerInteractions(page, vp, "reader"));
    await ctx.close();

    // Reader as an Android tablet sees it (mobile OS: no docked panel, the
    // explanation floats as a popover anchored to the term).
    await resetMock();
    const android = await newPage(browser, vp, { userAgent: ANDROID_TABLET_UA, hasTouch: true });
    await android.ctx.addCookies([{ ...cookie, domain: url.hostname, path: "/" }]);
    await openReader(android.page, FIXTURE);
    await shot(android.page, `reader-android.${vp.name}.png`);
    await optional("android reader interactions", () => readerInteractions(android.page, vp, "reader-android"));
    await android.ctx.close();
  }
}

async function optional(label, fn) {
  try {
    await fn();
  } catch (err) {
    console.warn(`[skip] ${label}: ${String(err.message ?? err).split("\n")[0]}`);
  }
}

async function openReader(page, FIXTURE) {
  await page.goto(`${LOCAL}/library/${FIXTURE.paperId}`, { waitUntil: "domcontentloaded" });
  await page.locator(".textLayer span").first().waitFor({ timeout: 60000 });
  await settle(page, 3000);
}

/** Scroll the element into the middle of its scroll container and return its box. */
async function reveal(locator) {
  await locator.evaluate((el) => el.scrollIntoView({ block: "center" }));
  await locator.page().waitForTimeout(500);
  return locator.boundingBox();
}

async function readerInteractions(page, vp, prefix) {
  const park = () => page.mouse.move(2, vp.height - 2);

  // 1. Text selection → selection popover (Explain & save / Highlight / Copy),
  //    then "Highlight" (mark only: never starts a focus lock, never calls AI).
  await optional(`${prefix} selection`, async () => {
    const spans = page.locator(".textLayer span");
    const n = await spans.count();
    for (let i = 30; i < Math.min(n, 160); i++) {
      const s = spans.nth(i);
      const text = (await s.textContent()) ?? "";
      if (text.trim().length < 30) continue;
      const box = await reveal(s);
      if (!box || box.width < 120) continue;
      const y = box.y + box.height / 2;
      await page.mouse.move(box.x + 1, y);
      await page.mouse.down();
      await page.mouse.move(box.x + Math.min(box.width - 2, 180), y, { steps: 12 });
      await page.mouse.up();
      await page.waitForTimeout(900);
      if (!(await page.locator("[data-selection-popover]").count())) continue;
      await shot(page, `${prefix}.selection-popover.${vp.name}.png`);
      const hl = page.locator("[data-selection-highlight]");
      if (await hl.count()) {
        await hl.click();
        await page.waitForTimeout(1200);
        await park();
        await page.waitForTimeout(400);
        await shot(page, `${prefix}.highlight-rest.${vp.name}.png`);
        const b = await page.locator('[data-mark-type="highlight"]').first().boundingBox();
        if (b) {
          await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
          await page.waitForTimeout(600);
          await shot(page, `${prefix}.highlight-hover.${vp.name}.png`);
          await park();
        }
      }
      return;
    }
    throw new Error("no selectable line produced a popover");
  });

  // 2. In-document mention link (teal appendix-mark): hover reveal.
  await optional(`${prefix} mention`, async () => {
    const box = await reveal(page.locator('[data-mark-type="mention"]').first());
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.waitForTimeout(600);
    await shot(page, `${prefix}.mention-hover.${vp.name}.png`);
    await park();
  });

  // 3. Docked side panel hidden, then shown again (desktop only).
  const hide = page.getByRole("button", { name: "Hide explanations" });
  if (await hide.count()) {
    await optional(`${prefix} panel toggle`, async () => {
      await hide.click({ timeout: 5000 });
      await page.waitForTimeout(600);
      await shot(page, `${prefix}.panel-hidden.${vp.name}.png`);
      await page.getByRole("button", { name: "Show explanations" }).click({ timeout: 5000 });
      await page.waitForTimeout(600);
    });
  }

  // 4. Cached-term mark (blue): hover reveal, then click → explanation card.
  //    LAST on purpose: a term click starts the web's 3-minute "Focus time"
  //    lock, which blocks every other interaction on the page.
  await optional(`${prefix} term`, async () => {
    const box = await reveal(page.locator('[data-mark-type="term"]').first());
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.waitForTimeout(600);
    await shot(page, `${prefix}.term-hover.${vp.name}.png`);
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    await page.waitForTimeout(1800);
    await shot(page, `${prefix}.term-click-focus-lock.${vp.name}.png`);
  });
}

const browser = await chromium.launch({ args: launchArgs });
fs.mkdirSync(outDir, { recursive: true });
try {
  if (mode === "live") await live(browser);
  else if (mode === "local") await local(browser);
  else throw new Error(`unknown mode ${mode}`);
} finally {
  await browser.close();
}
