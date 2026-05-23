# PRD v2.0 — EzyCourse 영상 → CELab 나만의 PPT 자동 재생산

**작성일**: 2026-05-23 · **작성자**: Jade + Claude · **상태**: Draft v2.0

---

## 🔄 v1.0 → v2.0 핵심 변경

| 항목 | v1.0 | v2.0 |
|---|---|---|
| 슬라이드 텍스트 추출 | Claude Vision API ($) | **macOS Vision OCR (무료)** |
| 얼굴/슬라이드 분류 | Claude Vision Tier 3 ($) | **OpenCV (무료)** |
| PiP 화면 처리 | 미정 | **슬라이드로 간주 + 영역 crop** |
| 중복 제거 정책 | 마지막 1장 | **필기 없는 첫 깨끗한 화면 1장** |
| 저장 위치 | 미정 | **원본 옆 sidecar** |
| **영상당 비용** | $0.10 | **약 $0.02** |
| **총 예상 비용** | 약 28만 원 | **약 5만 5천 원** |

---

## 1. 정의
EzyCourse 1,952개 영상에서 PPT 구간만 자동 추출, **macOS Vision OCR**로 텍스트 무료 추출, **필기 없는 첫 깨끗한 화면 1장**만 유지, CELab 다크 테마 PPTX 자동 생성.

---

## 2. 사용자 의도 (확정)
1. 얼굴 전용 영상 → 스킵 (자막은 유지)
2. PPT 1번이라도 나오면 → 포함
3. PiP (작은 슬라이드 + 강사 얼굴) → **슬라이드로 간주**, 슬라이드 영역만 crop
4. 같은 슬라이드 + 필기 진행 → **필기 없는 첫 화면 1장만**
5. 결과 PPTX → `{video}.lecture.pptx` 영상 옆 sidecar

### "왜 첫 깨끗한 화면만?"
강사 필기는 학습 보조, **PPT 원본 그대로 재생산**이 목표. 가장 글자(필기) 적은 시점 1장.

---

## 3. 시나리오

```
Jade가 bash _start_pptx.sh (백그라운드)
  ↓
1,952 영상 자동 처리:
  영상 A (얼굴만 30분)        → 스킵
  영상 B (PPT 40 + 얼굴 5)    → PPT 캡쳐만 ~18장
  영상 C (PPT + 필기 5단계)   → 첫 깨끗 1장
  영상 D (PiP 작은 슬라이드)  → 슬라이드 영역 crop 후 추출
  ↓
각 영상마다:
  {video}.captures/        — 정제 PNG
  {video}.slides.md        — Vision OCR 텍스트
  {video}.lecture.json     — 4-Phase AI 슬라이드 구조
  {video}.lecture.pptx     — 최종 PPT
```

---

## 4. 기능 요구사항

### F1. 얼굴/슬라이드 자동 분류 (모두 로컬, 무료)
**분류**: `slide` / `face` / `mixed (PiP)`

**알고리즘**:
1. 얼굴 검출 — OpenCV haarcascade 또는 macOS Vision face detection
2. 텍스트 영역 비율 — OpenCV Canny + contour
3. 색 균일도 — HSV histogram (PPT 단색, 얼굴 피부톤)
4. 결합 규칙:
   - 얼굴 > 30% & 텍스트 < 10% → `face`
   - 얼굴 < 15% & 텍스트 > 30% → `slide`
   - 둘 다 → `mixed` (슬라이드 처리)
5. **PiP crop**: mixed 프레임은 얼굴 영역 mask 후 슬라이드 영역만 남김

**영상 전체 판정**: slide+mixed 프레임 0개 → 스킵

### F2. 중복 슬라이드 제거 (필기 없는 첫 화면 정책)
1. ffmpeg scene detection (Rev.3 재사용): `select=gt(scene,0.25)`
2. pHash 클러스터링 (imagehash) — 유사도 ≥ 0.85 묶음
3. 클러스터 안 **"필기 없는 첫 화면" 선정**:
   - 시간순 정렬
   - 각 프레임 텍스트 픽셀 비율 (Vision OCR로 글자 수 측정)
   - **글자 수 가장 적은 + 시간 가장 빠른** 프레임 1장 선정
4. 최종 검증: 영상당 5~50장 (50장 초과 시 임계값 자동 조정)

### F3. 얼굴 전용 영상 자동 스킵
- F1로 영상 전체 face 비율 ≥ 90% → 스킵
- `_face_only_skipped.json` 메