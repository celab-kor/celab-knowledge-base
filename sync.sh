#!/bin/bash
# CELab Knowledge Base 자동 동기화 스크립트
# 변경사항이 있으면 자동으로 git add + commit + push

KB_PATH="$HOME/Documents/celab-knowledge-base"
LOG="$KB_PATH/.sync.log"

cd "$KB_PATH" || exit 1

# 변경사항 확인
CHANGES=$(git status --porcelain 2>/dev/null)

if [ -n "$CHANGES" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')

  git add -A >> "$LOG" 2>&1
  git commit -m "Auto sync: $COUNT file(s) updated at $TIMESTAMP" >> "$LOG" 2>&1
  git push origin main >> "$LOG" 2>&1

  echo "[$TIMESTAMP] ✅ $COUNT 파일 동기화 완료" >> "$LOG"
  osascript -e "display notification \"$COUNT개 파일이 GitHub Pages에 반영되었습니다\" with title \"CELab 지식창고 동기화\"" 2>/dev/null
else
  echo "[$(date '+%H:%M:%S')] 변경사항 없음" >> "$LOG"
fi

# 로그 최근 200줄만 유지
tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
