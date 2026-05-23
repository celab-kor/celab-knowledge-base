# PRD v2.0 — EzyCourse 영상 → CELab 나만의 PPT 자동 재생산

**작성일**: 2026-05-23 · **작성자**: Jade + Claude · **상태**: Draft v2.0

## 🔄 v1.0 → v2.0 핵심 변경
| 항목 | v1.0 | v2.0 |
|---|---|---|
| 슬라이드 텍스트 추출 | Claude Vision API ($) | **macOS Vision OCR (무료)** |
| 얼굴/슬라이드 분류 | Claude Vision Tier 3 ($) | **OpenCV (무료)** |
| PiP 처리 | 미정 | **슬라이드로 간주 + 영역 crop** |
| 중복 제거 | 마지막 1장 | **필기 없는 첫 깨끗한 화면 1장** |
| 저장 위치 | 미정 | **원본 옆 sidecar** |
| 영상당 비용 | $0.10 | **약 $0.02** |
| 총 예상 비용 | 28만 원 | **약 5만 5천 원** |

## 1. 정의
1,952 영상 → PPT 구간만 추출 → Vision OCR로 텍스트 무료 추출 → 필기 없는 첫 화면 1장 → CELab 다크 PPTX.

## 2. 사용자 정책 (확정)
- 얼굴 전용 영상 → 스킵 (자막은 유지)
- PPT 1번이라도 등장 → 포함
- PiP → 슬라이드로 간주, 슬라이드 영역만 crop
- 같은 슬라이드 + 필기 → 필기 없는 첫 화면 1장만
- 결과 PPTX → `{video}.lecture.pptx` 영상 옆 sidecar

## 3. 시나리오
```
Jade가 bash _start_pptx.sh (백그라운드)
  ↓
1,952 영상 자동:
  영상 A (얼굴만 30분)        → 스킵
  영상 B (PPT 40 + 얼굴 5분)  → PPT만 ~18장
  영상 C (PPT + 필기 5단계)   → 첫 깨끗 1장
  영상 D (PiP 작은 슬라이드)  → 슬라이드 crop 후 추출
  ↓
각 영상마다 sidecar:
  {video}.captures/        — 정제 PNG
  {video}.slides.md        — Vision OCR 텍스트
  {video}.lecture.json     — 4-Phase AI 슬라이드 구조
  {video}.lecture.pptx     — 최종 PPT
```

## 4. 기능 요구사항

### F1. 얼굴/슬라이드 자동 분류 (로컬·무료)
**분류**: `slide` / `face` / `mixed (PiP)`

**알고리즘**:
1. 얼굴 검출 — OpenCV haarcascade
2. 텍스트 영역 비율 — Canny edge + contour
3. 색 균일도 — HSV histogram
4. 결합 규칙:
   - 얼굴 > 30% & 텍스트 < 10% → `face`
   - 얼굴 < 15% & 텍스트 > 30% → `slide`
   - 둘 다 있음 → `mixed`
5. **PiP crop**: mixed 프레임은 얼굴 영역 mask 후 슬라이드 영역만 남김

**영상 판정**: slide+mixed 0개 → 스킵

### F2. 중복 제거 (필기 없는 첫 화면 정책)
1. ffmpeg scene capture (Rev.3 재사용): `select=gt(scene,0.25)`
2. pHash 클러스터링 (유사도 ≥ 0.85)
3. **클러스터 안에서 글자 수 가장 적은 + 시간 가장 빠른 1장 선정** (Vision OCR로 글자 수 측정)

### F3. 얼굴 전용 영상 스킵
- 영상 전체 face 비율 ≥ 90% → 스킵
- `_face_only_skipped.json` 기록 (사용자 검수 후 강제 처리 가능)

### F4. Vision OCR + Claude Haiku 4-Phase 파이프라인
1. **Phase 0** Transcript Analyst (우리 .md 강의 대본) — Haiku
2. **Phase 1 Vision Extractor → macOS Vision OCR**로 교체 (무료)
3. **Phase 2** Structure Designer — Haiku
4. **Phase 3** CELab Writer (문장 개선) — Haiku
5. **Phase 4** Quality Reviewer — Haiku

Phase 1만 무료 전환, 나머지 4개 phase는 Haiku 유지.

### F5. 배치 자동화 (자막 워커 패턴)
신규 파일들 (모두 `/Users/visionschool/Downloads/EzyCourse_Backup/`):
- `_pptx_worker.py` — 무한 루프 + caffeinate + lock/PID
- `_extract_slides.py` — 단일 영상 처리 (F1~F4)
- `_frame_classifier.py` — OpenCV 분류기
- `_slide_dedup.py` — pHash 중복 제거
- `_start_pptx.sh` — 백그라운드 시작 (자막 워커와 동일 패턴)

플레이어 UI 확장:
- 영상 카드에 `📊 PPT` 점 추가
- "PPT 생성" 우선 큐 버튼
- 진행률 표시

## 5. 비기능

| 항목 | 목표 |
|---|---|
| F1 정확도 | ≥ 95% |
| F2 중복 정확도 | ≥ 96% |
| F3 얼굴 영상 스킵 정확도 | ≥ 95% |
| 영상당 비용 | ≤ $0.02 |
| 총 비용 | ≤ 6만 원 |
| 영상당 처리 시간 | ≤ 10분 |
| 1,952 영상 완료 | ≤ 14일 |

## 6. 마일스톤

| Phase | 내용 | 소요 | 게이트 |
|---|---|---|---|
| A | F1+F2 정확도 검증 (10개 샘플) | 1-2일 | 95% |
| B | Vision OCR 한국어·영어 검증 | 0.5일 | 도메인 용어 인식 OK |
| C | 1개 영상 end-to-end | 1일 | 사용자 PPT 검수 OK |
| D | 배치 워커 + 플레이어 UI | 1일 | 10개 자동 성공 |
| E | 1,952개 자동 가동 | 14일 | — |

## 7. 리스크

| ID | 리스크 | 대응 |
|---|---|---|
| R1 | OCR이 깨진 글자/특수기호 인식 실패 | terminology.json 후처리 |
| R2 | OpenCV 얼굴 검출 false positive (수염·안경 등) | macOS Vision face API로 폴백 옵션 |
| R3 | PiP crop 영역 자동 검출 실패 | 검출 안 되면 전체 프레임 그대로 OCR |
| R4 | 같은 슬라이드인데 다른 시간에 다시 등장 | pHash 임계값 보수적, 의심 시 둘 다 유지 |
| R5 | 한국어 강의 + 영어 슬라이드 혼재 | OCR 양언어 동시 인식 (Vision 지원) |

## 8. 의존성 (신규 설치)
- `opencv-python` (얼굴 검출, edge)
- `pyobjc-framework-Vision` (macOS Vision OCR Python 바인딩)
- `imagehash` + `Pillow` (pHash)
- `python-pptx` (Rev.3 앱에 이미 있음)
- `anthropic` (이미 설치)

## 9. 다음 단계
이 v2.0 검토 후:
- ✅ 진행 → Phase A 시작
- ⏸️ 보류 → 자막 작업 완료 후
- ✏️ 수정 → 추가 정책 반영 후 v3