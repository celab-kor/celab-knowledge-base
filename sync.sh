#!/bin/bash
# 발행 동기화 스크립트 (공개/비공개 공용)
#
# 환경변수:
#   KB_PATH       — 대상 저장소 경로 (기본: ~/Documents/celab-knowledge-base)
#   KB_LABEL      — 로그/알림용 라벨 (기본: "지식창고")
#   KB_VISIBILITY — "public" 또는 "private" (기본: "public")
#   KB_BASE_URL   — 슬랙 메시지 링크 prefix
#                   public 기본: https://celab-knowledge-base.pages.dev (Cloudflare Pages)
#                   private 기본: https://github.com/celab-kor/celab-wiki/blob/main

KB_PATH="${KB_PATH:-$HOME/Documents/celab-knowledge-base}"
KB_LABEL="${KB_LABEL:-지식창고}"
KB_VISIBILITY="${KB_VISIBILITY:-public}"

if [ -z "$KB_BASE_URL" ]; then
  if [ "$KB_VISIBILITY" = "private" ]; then
    KB_BASE_URL="https://github.com/celab-kor/celab-wiki/blob/main"
  else
    KB_BASE_URL="https://celab-knowledge-base.pages.dev"
  fi
fi

LOG="$KB_PATH/.sync.log"
SLACK_HELPER="$HOME/Documents/celab-knowledge-base/scripts/notify_slack.py"

cd "$KB_PATH" || exit 1

CHANGES=$(git status --porcelain 2>/dev/null)

if [ -n "$CHANGES" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')

  NEW_PAGES=$(echo "$CHANGES" | awk '($1 == "??" || $1 == "A") && $2 ~ /^pages\/.*\.html$/ { print $2 }')

  git add -A >> "$LOG" 2>&1
  git commit -m "Auto sync [${KB_LABEL}]: $COUNT file(s) updated at $TIMESTAMP" >> "$LOG" 2>&1
  git push origin main >> "$LOG" 2>&1

  echo "[$TIMESTAMP] ✅ [${KB_LABEL}] $COUNT 파일 동기화 완료" >> "$LOG"
  osascript -e "display notification \"$COUNT개 파일이 반영되었습니다\" with title \"${KB_LABEL} 동기화\"" 2>/dev/null

  if [ -n "$NEW_PAGES" ] && [ -f "$SLACK_HELPER" ]; then
    while IFS= read -r page; do
      [ -z "$page" ] && continue
      echo "[$TIMESTAMP] 💬 [${KB_LABEL}] Slack 알림: $page" >> "$LOG"
      CELAB_KB_BASE_URL="$KB_BASE_URL" \
      CELAB_KB_LABEL="$KB_LABEL" \
      CELAB_KB_VISIBILITY="$KB_VISIBILITY" \
      CELAB_KB_PATH="$KB_PATH" \
        python3 "$SLACK_HELPER" "$page" >> "$LOG" 2>&1
    done <<< "$NEW_PAGES"
  fi
else
  echo "[$(date '+%H:%M:%S')] [${KB_LABEL}] 변경사항 없음" >> "$LOG"
fi

tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
