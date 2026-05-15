#!/usr/bin/env python3
"""Register one or more pages/*.html files into index.html's PAGES array.

Usage:
    python3 register_page.py pages/2026-05-16_foo.html [pages/2026-05-16_bar.html ...]

Behavior:
- Extracts <title> from each HTML file.
- Inserts a new entry at the head of the PAGES array.
- Skips files whose url already appears in PAGES (idempotent).
- Preserves the existing JSON shape so the Rev.3 app's regex keeps working.

Defaults for new entries (user may edit afterwards):
- desc: ""
- category: "기타"
- tags: []
- emoji: "📄"
- date: today (YYYY-MM-DD)
- id: time-based int (matches Rev.3 app convention of Date.now())
"""
from __future__ import annotations

import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path

KB_PATH = Path(__file__).resolve().parent.parent
INDEX_HTML = KB_PATH / "index.html"
PAGES_DATA = KB_PATH / "pages-data.json"

PAGES_RE = re.compile(r"const\s+PAGES\s*=\s*(\[[\s\S]*?\n\]);")
TITLE_RE = re.compile(r"<title>([^<]+)</title>", re.IGNORECASE)


def extract_title(html_path: Path) -> str:
    try:
        text = html_path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return html_path.stem
    m = TITLE_RE.search(text)
    if m:
        title = m.group(1).strip()
        if title:
            return title
    return html_path.stem


def load_pages(index_text: str) -> tuple[list[dict], re.Match]:
    m = PAGES_RE.search(index_text)
    if not m:
        raise RuntimeError("PAGES array not found in index.html")
    pages = json.loads(m.group(1))
    return pages, m


def render_pages(pages: list[dict]) -> str:
    return f"const PAGES = {json.dumps(pages, ensure_ascii=False, indent=2)};"


def make_entry(page_rel_url: str, html_path: Path) -> dict:
    return {
        "id": int(time.time() * 1000),
        "title": extract_title(html_path),
        "desc": "",
        "category": "기타",
        "tags": [],
        "date": datetime.now().strftime("%Y-%m-%d"),
        "emoji": "📄",
        "url": page_rel_url,
    }


def normalize(arg: str) -> str:
    p = arg.replace("\\", "/").lstrip("./")
    if p.startswith("pages/"):
        return p
    return f"pages/{Path(p).name}"


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: register_page.py <pages/xxx.html> [more...]", file=sys.stderr)
        return 1

    targets = [normalize(a) for a in argv[1:]]

    index_text = INDEX_HTML.read_text(encoding="utf-8")
    pages, match = load_pages(index_text)
    existing_urls = {p.get("url") for p in pages}

    added: list[str] = []
    skipped: list[str] = []
    missing: list[str] = []

    base_ts = int(time.time() * 1000)
    for i, rel in enumerate(targets):
        if rel in existing_urls:
            skipped.append(rel)
            continue
        html_path = KB_PATH / rel
        if not html_path.exists():
            missing.append(rel)
            continue
        entry = make_entry(rel, html_path)
        entry["id"] = base_ts + i
        pages.insert(0, entry)
        existing_urls.add(rel)
        added.append(rel)

    if added:
        new_index = index_text.replace(match.group(0), render_pages(pages))
        INDEX_HTML.write_text(new_index, encoding="utf-8")
        # Mirror to pages-data.json so the Rev.3 app stays in sync
        # (the app reads pages-data.json and reconstructs the inline PAGES array).
        PAGES_DATA.write_text(
            json.dumps(pages, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    for rel in added:
        print(f"[register] + {rel}")
    for rel in skipped:
        print(f"[register] = {rel} (already registered)")
    for rel in missing:
        print(f"[register] ! {rel} (file not found)", file=sys.stderr)

    return 0 if not missing else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
