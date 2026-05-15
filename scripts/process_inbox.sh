#!/bin/bash
# 지식창고 발행대기 인박스 처리 스크립트
# ~/Desktop/지식창고_발행대기/ 안의 모든 .html 파일을
# celab-knowledge-base/pages/로 이동 후 자동 동기화(슬랙 발송 포함) 트리거

INBOX="$HOME/Desktop/지식창고_발행대기"
KB_PATH="$HOME/Documents/celab-knowledge-base"
PAGES="$KB_PATH/pages"
LOG="$KB_PATH/.sync.log"
TS=$(date '+%Y-%m-%d %H:%M:%S')

if [ ! -d "$INBOX" ]; then
  mkdir -p "$INBOX"
fi

# 인박스에서 .html 파일 찾기 (재귀 없음, 최상위만)
shopt -s nullglob
HTML_FILES=("$INBOX"/*.html)
shopt -u nullglob

COUNT=${#HTML_FILES[@]}

if [ "$COUNT" -eq 0 ]; then
  echo "📭 인박스가 비었습니다. ($INBOX)"
  osascript -e 'display notification "인박스가 비어있습니다" with title "지식창고 발행대기 처리"' 2>/dev/null
  exit 0
fi

echo "📦 인박스에서 ${COUNT}개 HTML 파일 발견 — pages/로 이동 시작"
MOVED=0

for src in "${HTML_FILES[@]}"; do
  base=$(basename "$src")
  # URL-safe 파일명으로 변환 (공백·한글 → 안전 형식). 단순 안전화: 공백을 _로
  safe_name=$(echo "$base" | sed -e 's/[[:space:]]\+/_/g' -e 's/[^A-Za-z0-9가-힣._-]/_/g')
  # 날짜 prefix 없으면 추가
  if ! [[ "$safe_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_ ]]; then
    date_prefix=$(date '+%Y-%m-%d')
    safe_name="${date_prefix}_${safe_name}"
  fi
  dest="$PAGES/$safe_name"
  # 중복 시 -1, -2 ... suffix
  i=1
  while [ -e "$dest" ]; do
    name_no_ext="${safe_name%.html}"
    dest="$PAGES/${name_no_ext}-${i}.html"
    i=$((i + 1))
  done
  if mv "$src" "$dest"; then
    echo "  ✅ $base → pages/$(basename "$dest")"
    MOVED=$((MOVED + 1))
    echo "[$TS] 📥 inbox→pages: $(basename "$dest")" >> "$LOG"
  else
    echo "  ❌ 이동 실패: $base"
  fi
done

if [ "$MOVED" -eq 0 ]; then
  echo "이동된 파일이 없습니다."
  exit 1
fi

echo ""
echo "🔄 자동 동기화 실행 (sync.sh) — 깃 푸시 + 슬랙 알림"
bash "$KB_PATH/sync.sh"

osascript -e "display notification \"${MOVED}개 페이지가 지식창고에 발행되었습니다\" with title \"지식창고 발행 완료\"" 2>/dev/null
echo ""
echo "✨ 완료. ${MOVED}개 페이지 발행됨."
