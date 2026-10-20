#!/usr/bin/env python3
"""Verify char limits in marketing/*.md and rewrite the `_Chars: N / L_` lines.

Convention: a line `<!-- limit: L -->`, then a ```text fenced block, then a
`_Chars: ... _` line. Count = Python len() of the block content (newlines
between lines included, no trailing newline). Exit 1 if any block is over.
Also checks Mac keywords format and Microsoft search-term word budget.
Usage: python3 marketing/check_limits.py
"""
import pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
PAT = re.compile(r"<!-- limit: (\d+) -->\n```text\n(.*?)\n```\n_Chars: [^\n]*_", re.S)
fail = False
for md in sorted(HERE.glob("*.md")):
    text = md.read_text()
    def sub(m):
        global fail
        limit, body = int(m.group(1)), m.group(2)
        n = len(body)
        ok = n <= limit
        if not ok:
            fail = True
        print(f"{'OK  ' if ok else 'OVER'} {md.name:24} {n:5}/{limit:<5} {body.splitlines()[0][:60]}")
        return f"<!-- limit: {limit} -->\n```text\n{body}\n```\n_Chars: {n} / {limit}_"
    md.write_text(PAT.sub(sub, text))

mac = (HERE / "store-mac-app-store.md").read_text()
kw = re.search(r"## Keywords.*?```text\n(.*?)\n```", mac, re.S).group(1)
if ", " in kw or " " in kw:
    print("OVER mac keywords contain spaces"); fail = True
if "paper" in kw.lower().split(","):
    print("OVER mac keywords repeat app name"); fail = True

ms = (HERE / "store-microsoft.md").read_text()
sec = re.search(r"## Search terms.*?(?=\n## )", ms, re.S).group(0)
terms = re.findall(r"```text\n(.*?)\n```", sec)
words = sum(len(t.split()) for t in terms)
print(f"{'OK  ' if len(terms) <= 7 and words <= 21 else 'OVER'} MS search terms: {len(terms)} terms, {words} words")
fail |= len(terms) > 7 or words > 21
sys.exit(1 if fail else 0)
