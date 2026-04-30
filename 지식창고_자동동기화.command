#!/bin/bash
# CELab 지식창고 자동 동기화 (터미널에서 실행)
# 더블클릭하면 백그라운드에서 파일 변경을 감시하고 자동으로 GitHub에 올립니다

KB_PATH="$HOME/Documents/celab-knowledge-base"

echo "╔════════════════════════════════════════╗"
echo "║  CELab 지식창고 자동 동기화 시작       ║"
echo "║  파일이 바뀌면 자동으로 GitHub에 올림  ║"
echo "║  종료: Ctrl+C                          ║"
echo "╚════════════════════════════════════════╝"
echo ""

# git 설정
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
cd "$KB_PATH" || { echo "❌ 지식창고 폴더를 찾을 수 없습니다: $KB_PATH"; exit 1; }

echo "📁 감시 폴더: $KB_PATH"
echo "⏰ 변경 감지 후 10초 대기 후 자동 push"
echo ""

sync_if_changed() {
  CHANGES=$(git status --porcelain 2>/dev/null)
  if [ -n "$CHANGES" ]; then
    COUNT=$(echo "$CHANGES" | grep -v "^$" | wc -l | tr -d ' ')
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "🔄 [$TIMESTAMP] 변경 감지: ${COUNT}개 파일"
    git add -A
    git commit -m "Auto sync: ${COUNT}개 파일 업데이트 ($TIMESTAMP)"
    git push origin main
    echo "✅ GitHub Pages 반영 완료 (약 30초 후 업데이트)"
    osascript -e "display notification \"${COUNT}개 파일이 자동 동기화되었습니다\" with title \"CELab 지식창고\"" 2>/dev/null
    echo ""
  fi
}

# 초기 동기화
sync_if_changed

# fswatch로 파일 변경 감시 (Homebrew로 설치 필요)
if command -v fswatch &>/dev/null; then
  echo "🔍 fswatch로 실시간 감시 중..."
  fswatch -r -l 5 --exclude="\.git" --exclude="\.sync" "$KB_PATH" | while read event; do
    sleep 10  # 연속 변경이 안정될 때까지 대기
    sync_if_changed
  done
else
  # fswatch 없으면 30초마다 폴링
  echo "⚠️  fswatch 미설치 → 30초 간격으로 변경 확인"
  echo "   (실시간 감시: brew install fswatch)"
  echo ""
  while true; do
    sleep 30
    sync_if_changed
  done
fi
