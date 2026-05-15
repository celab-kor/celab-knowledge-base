#!/bin/bash
# 지식창고 발행대기 인박스 처리 스크립트
# ~/Desktop/지식창고_발행대기/ 안의 모든 .html 파일을
# celab-knowledge-base/pages/로 이동 후 자동 동기화(슬랙 발송 포함) 트리거

INBOX="$HOME/Desktop/지식창고_발행대기"
KB_PATH="$HOME/Documents/celab-knowledge-base"
PAGES="$KB_PATH/pages"
LOG="$KB_PATH/.sync.log"
REGISTER_HELPER="$KB_PATH/scripts/register_page.py"
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
NEW_RELS=()

for src in "${HTML_FILES[@]}"; do
  base=$(basename "$src")
  # URL-safe 파일명 변환. BSD sed가 UTF-8 범위 [가-힣]를 못 다뤄서 한글이 _로 깨지는 이슈가
  # 있었음. Python으로 처리 — 공백·제어문자만 _로 치환하고 한글·영숫자·._-는 유지.
  safe_name=$(python3 -c "
import re, sys, unicodedata
name = sys.argv[1]
name = unicodedata.normalize('NFC', name)
# 공백/제어 문자만 underscore로
name = re.sub(r'\s+', '_', name)
# URL/파일시스템에서 위험한 문자만 제거 (한글·영숫자·._-는 보존)
name = re.sub(r'[\\\\/:*?\"<>|]', '_', name)
print(name)
" "$base")
  # 날짜 prefix 없으면 추가
  if ! [[ "$safe_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_ ]]; then
    date_prefix=$(date '+%Y-%m-%d')
    safe_name="${date_prefix}_${safe_name}"
  fi
  dest="$PAGES/$safe_name"
  # 동일 stem 파일이 이미 있으면 덮어쓰기 (사용자가 수정본을 다시 발행하는 케이스)
  if mv -f "$src" "$dest"; then
    echo "  ✅ $base → pages/$(basename "$dest")"
    MOVED=$((MOVED + 1))
    NEW_RELS+=("pages/$(basename "$dest")")
    echo "[$TS] 📥 inbox→pages: $(basename "$dest")" >> "$LOG"
  else
    echo "  ❌ 이동 실패: $base"
  fi
done

if [ "$MOVED" -eq 0 ]; then
  echo "이동된 파일이 없습니다."
  exit 1
fi

# index.html PAGES 배열에 신규 entry 등록 (이미 있으면 skip)
if [ -f "$REGISTER_HELPER" ] && [ "${#NEW_RELS[@]}" -gt 0 ]; then
  echo ""
  echo "📝 갤러리 인덱스(index.html PAGES) 등록"
  python3 "$REGISTER_HELPER" "${NEW_RELS[@]}" | tee -a "$LOG"
fi

echo ""
echo "🔄 자동 동기화 실행 (sync.sh) — 깃 푸시 + 슬랙 알림"
bash "$KB_PATH/sync.sh"

osascript -e "display notification \"${MOVED}개 페이지가 지식창고에 발행되었습니다\" with title \"지식창고 발행 완료\"" 2>/dev/null
echo ""
echo "✨ 완료. ${MOVED}개 페이지 발행됨."
