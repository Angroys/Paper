// Minimal in-memory Supabase stand-in for capturing signed-in screens of
// the RPR web app WITHOUT a real Supabase project or a real user.
//
//   PDF_PATH=/path/to/paper.pdf node mock-supabase.mjs        # listens on :54399
//
// Then build and start RPR against it (no file in RPR is edited; RPR's .env
// has no Supabase keys, and the blank AI keys keep every AI call local):
//
//   NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54399 \
//   NEXT_PUBLIC_SUPABASE_ANON_KEY=mock-anon-key \
//   SUPABASE_SERVICE_ROLE_KEY=mock-service-key \
//   AZURE_API_KEY= MANIM_RENDER_URL= MANIM_RENDER_TOKEN= \
//   npx next build && npx next start -p 3000
//
// (`next dev` cannot render the reader: pdfjs-dist 5 crashes under the dev
// webpack runtime.)
//
// Serves just enough of GoTrue (/auth/v1/user), PostgREST (/rest/v1/<table>
// with eq filters, order, HEAD counts, single-object Accept) and Storage
// (signed URLs + object download) for /library, /settings and the reader.
// Anonymous sign-up (/auth/v1/signup) is refused with 403: no user is ever
// created, real or mock.

import http from "node:http";
import fs from "node:fs";
import { fileURLToPath } from "node:url";

export const PORT = Number(process.env.MOCK_PORT ?? 54399);
const USER_ID = "00000000-0000-4000-8000-000000000001";
const NOW = Date.parse("2026-10-20T10:00:00Z");
const iso = (daysAgo) => new Date(NOW - daysAgo * 86400000).toISOString();

export const FIXTURE = { paperId: "11111111-1111-4111-8111-000000000001", projectId: "33333333-3333-4333-8333-000000000001" };

const user = {
  id: USER_ID,
  aud: "authenticated",
  role: "authenticated",
  email: "reader@example.com",
  email_confirmed_at: iso(30),
  phone: "",
  app_metadata: { provider: "email", providers: ["email"] },
  user_metadata: {},
  identities: [],
  is_anonymous: false,
  created_at: iso(30),
  updated_at: iso(1),
};

const P = (n) => `11111111-1111-4111-8111-00000000000${n}`;
const papers = [
  ["Lightning-Fast Image Inversion and Editing for Text-to-Image Diffusion Models", 0, null],
  ["Attention Is All You Need", 2, iso(1)],
  ["Denoising Diffusion Probabilistic Models", 4, null],
  ["High-Resolution Image Synthesis with Latent Diffusion Models", 6, iso(3)],
  ["Classifier-Free Diffusion Guidance", 9, null],
  ["Prompt-to-Prompt Image Editing with Cross Attention Control", 12, null],
].map(([title, d, read], i) => ({
  id: P(i + 1),
  user_id: USER_ID,
  title,
  storage_path: `${USER_ID}/${P(i + 1)}.pdf`,
  file_name: `paper-${i + 1}.pdf`,
  uploaded_at: iso(d),
  read_at: read,
  added_from_paper_id: null,
  source_url: null,
  auto_matched: false,
  match_notice_dismissed_at: null,
}));

const term = (id, paper, t, explanation, tags, rating, d) => ({
  id: `22222222-2222-4222-8222-00000000000${id}`,
  user_id: USER_ID,
  paper_id: paper,
  highlight_id: null,
  term: t,
  normalized_term: t.toLowerCase(),
  explanation,
  tags,
  rating,
  created_at: iso(d),
});

const seed = () => ({
  papers: structuredClone(papers),
  projects: [
    { id: "33333333-3333-4333-8333-000000000001", user_id: USER_ID, name: "Diffusion editing", created_at: iso(5) },
    { id: "33333333-3333-4333-8333-000000000002", user_id: USER_ID, name: "Thesis reading list", created_at: iso(8) },
  ],
  project_papers: [
    { project_id: "33333333-3333-4333-8333-000000000001", paper_id: P(1), user_id: USER_ID, added_at: iso(1) },
    { project_id: "33333333-3333-4333-8333-000000000001", paper_id: P(3), user_id: USER_ID, added_at: iso(1) },
    { project_id: "33333333-3333-4333-8333-000000000002", paper_id: P(2), user_id: USER_ID, added_at: iso(2) },
  ],
  glossary_terms: [
    term(1, P(1), "Diffusion inversion", "Running a diffusion model backwards: given a finished image (and its prompt), find the starting noise that would generate that exact image again.", ["method", "computer vision"], 5, 0),
    term(2, P(1), "Newton-Raphson", "A classic way to solve an equation by repeatedly guessing, measuring how wrong the guess is, and jumping along the slope towards the answer.", ["method"], 4, 0),
    term(3, P(1), "Noise latent", "The random starting point a diffusion model turns into an image; changing it changes the picture.", ["concept"], null, 1),
    term(4, P(2), "Self-attention", "Each word looks at every other word in the sentence and decides how much each one matters to its own meaning.", ["method", "nlp"], 5, 2),
    term(5, P(3), "Denoising", "Removing a little noise at each step until a clean sample remains.", ["concept"], 3, 4),
  ],
  highlights: [],
  term_explanations: [
    { term: "deterministic", normalized_term: "deterministic", explanation: "Always gives the same output for the same input, with no randomness.", field: "other", image_url: null, image_prompt: null, created_at: iso(3) },
    { term: "schedulers", normalized_term: "schedulers", explanation: "The rule that decides how much noise is removed at each step of a diffusion model.", field: "other", image_url: null, image_prompt: null, created_at: iso(3) },
  ],
  profiles: [
    { id: USER_ID, display_name: "Ada Reader", avatar_path: null, is_beta: false, beta_features_enabled: false, pointer_tracking_consent: false, role: "user", updated_at: iso(1) },
  ],
  figure_highlights: [],
});
let tables = seed();
const reset = () => {
  tables = seed();
};

// ------------------------------------------------------------- session
const b64url = (s) => Buffer.from(s).toString("base64url");
export function accessToken() {
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(
    JSON.stringify({ sub: USER_ID, aud: "authenticated", role: "authenticated", email: user.email, exp: 4102444800, iat: 1760000000, is_anonymous: false, session_id: "mock" }),
  );
  return `${header}.${payload}.${b64url("mock-signature")}`;
}
export function session() {
  return { access_token: accessToken(), token_type: "bearer", expires_in: 3600, expires_at: 4102444800, refresh_token: "mock-refresh", user };
}
/** @supabase/ssr cookie for project URL http://127.0.0.1:<port> → storage key `sb-127-auth-token`. */
export function sessionCookie() {
  return { name: "sb-127-auth-token", value: "base64-" + b64url(JSON.stringify(session())) };
}

// ------------------------------------------------------------- server
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "*",
  "access-control-allow-methods": "GET,POST,PATCH,PUT,DELETE,HEAD,OPTIONS",
  "access-control-expose-headers": "content-range, x-total-count",
};

function send(res, status, body, headers = {}) {
  const isBuf = Buffer.isBuffer(body);
  res.writeHead(status, { ...cors, "content-type": isBuf ? "application/pdf" : "application/json", ...headers });
  res.end(isBuf ? body : body === undefined ? "" : JSON.stringify(body));
}

function readBody(req) {
  return new Promise((r) => {
    let d = "";
    req.on("data", (c) => (d += c));
    req.on("end", () => r(d));
  });
}

function query(table, params) {
  let rows = [...(tables[table] ?? [])];
  for (const [k, v] of params) {
    if (["select", "order", "limit", "offset", "on_conflict", "columns"].includes(k)) continue;
    const m = /^(eq|neq|in|is)\.(.*)$/.exec(v);
    if (!m) continue;
    const [, op, raw] = m;
    if (op === "eq") rows = rows.filter((r) => String(r[k]) === raw);
    if (op === "neq") rows = rows.filter((r) => String(r[k]) !== raw);
    if (op === "is") rows = rows.filter((r) => (raw === "null" ? r[k] == null : String(r[k]) === raw));
    if (op === "in") {
      const set = new Set(raw.replace(/^\(|\)$/g, "").split(",").map((s) => s.replace(/^"|"$/g, "")));
      rows = rows.filter((r) => set.has(String(r[k])));
    }
  }
  const order = params.get("order");
  if (order) {
    const [col, dir] = order.split(",")[0].split(".");
    rows.sort((a, b) => (String(a[col]) < String(b[col]) ? -1 : 1) * (dir === "desc" ? -1 : 1));
  }
  const limit = params.get("limit");
  if (limit) rows = rows.slice(0, Number(limit));
  return rows;
}

export function start(pdfPath = process.env.PDF_PATH) {
  const pdf = pdfPath ? fs.readFileSync(pdfPath) : null;
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
    const p = url.pathname;
    if (req.method === "OPTIONS") return send(res, 204);
    const body = await readBody(req);

    // Test hook: restore the seed data so every viewport pass starts clean.
    if (p === "/__reset") {
      reset();
      return send(res, 204);
    }

    // ---- GoTrue
    if (p === "/auth/v1/signup") {
      console.warn("[mock] refused sign-up");
      return send(res, 403, { code: 403, msg: "sign-ups disabled in mock" });
    }
    if (p === "/auth/v1/user") return send(res, 200, user);
    if (p === "/auth/v1/token") return send(res, 200, session());
    if (p === "/auth/v1/logout") return send(res, 204);
    if (p.startsWith("/auth/v1/")) return send(res, 200, {});

    // ---- Storage
    if (p.startsWith("/storage/v1/object/sign/")) {
      if (req.method === "POST") {
        const rest = p.slice("/storage/v1/object/sign/".length);
        let parsed = {};
        try {
          parsed = JSON.parse(body || "{}");
        } catch {}
        if (Array.isArray(parsed.paths)) {
          return send(res, 200, parsed.paths.map((path) => ({ path, signedURL: `/object/sign/${rest}/${path}?token=mock`, error: null })));
        }
        return send(res, 200, { signedURL: `/object/sign/${rest}?token=mock` });
      }
      if (pdf) return send(res, 200, pdf, { "content-length": String(pdf.length) });
      return send(res, 404, { error: "no PDF_PATH" });
    }
    if (p.startsWith("/storage/v1/")) return send(res, 200, []);

    // ---- PostgREST
    if (p.startsWith("/rest/v1/rpc/")) return send(res, 200, null);
    if (p.startsWith("/rest/v1/")) {
      const table = p.slice("/rest/v1/".length);
      if (req.method === "GET" || req.method === "HEAD") {
        const rows = query(table, url.searchParams);
        const range = { "content-range": rows.length ? `0-${rows.length - 1}/${rows.length}` : `*/0` };
        if (req.method === "HEAD") return send(res, 200, undefined, range);
        if ((req.headers.accept ?? "").includes("vnd.pgrst.object")) {
          if (rows.length === 1) return send(res, 200, rows[0], range);
          return send(res, 406, { code: "PGRST116", details: `The result contains ${rows.length} rows`, hint: null, message: "JSON object requested, multiple (or no) rows returned" });
        }
        return send(res, 200, rows, range);
      }
      if (req.method === "POST") {
        let rows = [];
        try {
          rows = [].concat(JSON.parse(body || "[]"));
        } catch {}
        rows = rows.map((r, i) => ({ id: `99999999-9999-4999-8999-${String(Date.now() + i).slice(-12)}`, user_id: USER_ID, created_at: new Date().toISOString(), ...r }));
        (tables[table] ??= []).push(...rows);
        const single = (req.headers.accept ?? "").includes("vnd.pgrst.object");
        return send(res, 201, single ? rows[0] : rows);
      }
      if (req.method === "PATCH") {
        const rows = query(table, url.searchParams);
        let patch = {};
        try {
          patch = JSON.parse(body || "{}");
        } catch {}
        rows.forEach((r) => Object.assign(r, patch));
        return send(res, 200, rows);
      }
      if (req.method === "DELETE") return send(res, 204);
    }
    send(res, 404, { error: `mock: unhandled ${req.method} ${p}` });
  });
  server.listen(PORT, "127.0.0.1", () => console.log(`[mock-supabase] http://127.0.0.1:${PORT}`));
  return server;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) start();
