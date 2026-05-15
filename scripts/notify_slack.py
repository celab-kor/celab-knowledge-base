#!/usr/bin/env python3
"""Send a Slack notification for a newly published knowledge-base page.

Usage:
    python3 notify_slack.py <pages/xxx.html>

The webhook URL and message format mirror the Mac app (영상회의록추출기 Rev.3 main.js)
so notifications land in the same Slack channel with a consistent look.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# 환경변수로 공개/비공개 발행 분기 가능. 미지정 시 기본=지식창고(공개) 설정.
KB_BASE_URL = os.environ.get("CELAB_KB_BASE_URL", "https://celab-knowledge-base.pages.dev").rstrip("/")
KB_LABEL = os.environ.get("CELAB_KB_LABEL", "지식창고")
KB_VISIBILITY = os.environ.get("CELAB_KB_VISIBILITY", "public")
KB_PATH = Path(os.environ.get("CELAB_KB_PATH", "")).resolve() if os.environ.get("CELAB_KB_PATH") else Path(__file__).resolve().parent.parent
ENV_LOCAL = Path(__file__).resolve().parent / ".env.local"


def load_webhook() -> str:
    """Read CELAB_SLACK_WEBHOOK from environment or scripts/.env.local (gitignored)."""
    url = os.environ.get("CELAB_SLACK_WEBHOOK", "").strip()
    if url:
        return url
    if ENV_LOCAL.exists():
        for line in ENV_LOCAL.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, value = line.partition("=")
            if key.strip() == "CELAB_SLACK_WEBHOOK":
                return value.strip().strip('"').strip("'")
    raise RuntimeError(
        "CELAB_SLACK_WEBHOOK not set. Define it in env or scripts/.env.local (gitignored)."
    )


def get_meta(page_rel_path: str) -> dict:
    data_file = KB_PATH / "pages-data.json"
    if data_file.exists():
        try:
            data = json.loads(data_file.read_text(encoding="utf-8"))
            for entry in data:
                if entry.get("url") == page_rel_path:
                    return entry
        except Exception:
            pass

    index_html = KB_PATH / "index.html"
    if index_html.exists():
        try:
            text = index_html.read_text(encoding="utf-8", errors="ignore")
            m = re.search(r"const\s+PAGES\s*=\s*(\[.*?\n\];)", text, re.DOTALL)
            if m:
                raw = m.group(1).rstrip(";")
                entries = json.loads(raw)
                for entry in entries:
                    if entry.get("url") == page_rel_path:
                        return entry
        except Exception:
            pass

    html_path = KB_PATH / page_rel_path
    if html_path.exists():
        html = html_path.read_text(encoding="utf-8", errors="ignore")
        t = re.search(r"<title>([^<]+)</title>", html)
        title = t.group(1).strip() if t else page_rel_path
        return {"title": title, "desc": "", "tags": [], "emoji": "📄", "category": "기타"}

    return {"title": page_rel_path, "desc": "", "tags": [], "emoji": "📄", "category": "기타"}


def build_payload(meta: dict, public_url: str) -> dict:
    emoji = meta.get("emoji") or "📄"
    title = meta.get("title") or "새 페이지"
    desc = meta.get("desc") or meta.get("description") or ""
    tags_raw = meta.get("tags") or []
    tags = " ".join(f"#{t}" for t in tags_raw)
    category = meta.get("category") or "일반"
    date_str = datetime.now().strftime("%Y. %m. %d.")

    visibility_icon = "🔒" if KB_VISIBILITY == "private" else "🌐"
    visibility_text = "비공개" if KB_VISIBILITY == "private" else "공개"

    body_lines = [f"{emoji} *<{public_url}|{title}>*"]
    if desc:
        body_lines.append(desc)
    if tags:
        body_lines.append(tags)
    if KB_VISIBILITY == "private":
        body_lines.append("_🔒 비공개 위키 — GitHub 로그인 후 열람 가능_")
    body_text = "\n".join(body_lines)

    return {
        "text": f"{emoji} *새 {KB_LABEL} 페이지 발행* {visibility_icon}",
        "blocks": [
            {"type": "section", "text": {"type": "mrkdwn", "text": body_text}},
            {
                "type": "context",
                "elements": [
                    {"type": "mrkdwn", "text": f"📂 {category} · {date_str} · {visibility_icon} {visibility_text}"}
                ],
            },
        ],
    }


def send(payload: dict) -> int:
    """POST payload to Slack via curl (avoids macOS Python SSL cert issues)."""
    webhook = load_webhook()
    body = json.dumps(payload, ensure_ascii=False)
    result = subprocess.run(
        [
            "curl",
            "-sS",
            "-o", "/dev/null",
            "-w", "%{http_code}",
            "--max-time", "10",
            "-X", "POST",
            "-H", "Content-Type: application/json; charset=utf-8",
            "--data-binary", "@-",
            webhook,
        ],
        input=body.encode("utf-8"),
        capture_output=True,
        timeout=15,
    )
    status = int(result.stdout.decode().strip() or "0")
    if status >= 400 or result.returncode != 0:
        err = result.stderr.decode(errors="ignore").strip()
        raise RuntimeError(f"slack http {status}; curl rc={result.returncode}; {err}")
    return status


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: notify_slack.py <pages/xxx.html>", file=sys.stderr)
        return 1
    page_rel_path = argv[1].lstrip("./")
    public_url = f"{KB_BASE_URL}/{page_rel_path}"
    meta = get_meta(page_rel_path)
    payload = build_payload(meta, public_url)
    try:
        status = send(payload)
        print(f"[slack] {status} {public_url}")
        return 0
    except Exception as e:
        print(f"[slack] error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
