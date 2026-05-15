#!/bin/bash
# 발행대기 인박스 처리 스크립트 (공개/비공개 공용)
#
# 환경변수로 동작 분기:
#   INBOX             — 데스크탑 인박스 경로 (기본: ~/Desktop/🌐_지식창고_발행대기)
#   KB_PATH           — 대상 저장소 로컬 경로 (기본: ~/Documents/celab-knowledge-base)
#   KB_LABEL          — 로그/알림 라벨 (기본: "지식창고")
#   KB_VISIBILITY     — "public" 또는 "private" (기본: "public")
#   KB_BASE_URL       — 슬랙 알림 URL prefix (sync.sh로 전달)
#   KB_REGISTER_INDEX — "true"/"false" — index.html PAGES 배열 자동 등록 여부 (기본 true)
#
# 두 인박스(.command) 파일이 이 스크립트를 호출하며, 각자 env 값을 다르게 설정한다.

INBOX="${INBOX:-$HOME/Desktop/🌐_지식창고_발행대기}"
KB_PATH="${KB_PATH:-$HOME/Documents/celab-knowledge-base}"
KB_LABEL="${KB_LABEL:-지식창고}"
KB_VISIBILITY="${KB_VISIBILITY:-public}"
KB_REGISTER_INDEX="${KB_REGISTER_INDEX:-true}"

PAGES="$KB_PATH/pages"
LOG="$KB_PATH/.sync.log"
REGISTER_HELPER="$HOME/Documents/celab-knowledge-base/scripts/register_page.py"
SYNC_SH="$HOME/Documents/celab-knowledge-base/sync.sh"
TS=$(date '+%Y-%m-%d %H:%M:%S')

if [ ! -d "$INBOX" ]; then
  mkdir -p "$INBOX"
fi
if [ ! -d "$PAGES" ]; then
  mkdir -p "$PAGES"
fi

shopt -s nullglob
HTML_FILES=("$INBOX"/*.html)
shopt -u nullglob

COUNT=${#HTML_FILES[@]}

if [ "$COUNT" -eq 0 ]; then
  echo "📭 [${KB_LABEL}] 인박스가 비었습니다. ($INBOX)"
  osascript -e "display notification \"인박스가 비어있습니다\" with title \"${KB_LABEL} 발행대기 처리\"" 2>/dev/null
  exit 0
fi

echo "📦 [${KB_LABEL} / ${KB_VISIBILITY}] ${COUNT}개 HTML — pages/로 이동 시작"
MOVED=0
NEW_RELS=()

for src in "${HTML_FILES[@]}"; do
  base=$(basename "$src")
  safe_name=$(python3 -c "
import re, sys, unicodedata
name = sys.argv[1]
name = unicodedata.normalize('NFC', name)
name = re.sub(r'\s+', '_', name)
name = re.sub(r'[\\\\/:*?\"<>|]', '_', name)
print(name)
" "$base")
  if ! [[ "$safe_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_ ]]; then
    date_prefix=$(date '+%Y-%m-%d')
    safe_name="${date_prefix}_${safe_name}"
  fi
  dest="$PAGES/$safe_name"
  if mv -f "$src" "$dest"; then
    echo "  ✅ $base → pages/$(basename "$dest")"
    MOVED=$((MOVED + 1))
    NEW_RELS+=("pages/$(basename "$dest")")
    echo "[$TS] 📥 [${KB_LABEL}] inbox→pages: $(basename "$dest")" >> "$LOG"
  else
    echo "  ❌ 이동 실패: $base"
  fi
done

if [ "$MOVED" -eq 0 ]; then
  echo "이동된 파일이 없습니다."
  exit 1
fi

# index.html PAGES 배열 등록 — public(지식창고)만 적용
if [ "$KB_REGISTER_INDEX" = "true" ] && [ -f "$REGISTER_HELPER" ] && [ "${#NEW_RELS[@]}" -gt 0 ]; then
  echo ""
  echo "📝 [${KB_LABEL}] 갤러리 인덱스(index.html PAGES) 등록"
  CELAB_KB_PATH="$KB_PATH" python3 "$REGISTER_HELPER" "${NEW_RELS[@]}" | tee -a "$LOG"
fi

echo ""
echo "🔄 [${KB_LABEL}] 자동 동기화 실행"
KB_PATH="$KB_PATH" KB_LABEL="$KB_LABEL" KB_VISIBILITY="$KB_VISIBILITY" KB_BASE_URL="$KB_BASE_URL" \
  bash "$SYNC_SH"

osascript -e "display notification \"${MOVED}개 페이지가 ${KB_LABEL}에 발행되었습니다\" with title \"${KB_LABEL} 발행 완료\"" 2>/dev/null
echo ""
echo "✨ 완료. ${MOVED}개 페이지 발행됨. (${KB_LABEL} / ${KB_VISIBILITY})"
