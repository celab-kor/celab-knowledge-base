# PRD — EzyCourse 영상 → CELab 나만의 PPT 자동 재생산 파이프라인

**작성일**: 2026-05-23
**작성자**: Jade (박규호) + Claude
**상태**: Draft v1.0
**관련**: 영상회의록추출앱 Rev.3, EzyCourse 자막 자동화 (별도 진행 중)

---

## 1. 한 줄 정의

> **EzyCourse 폴더 안 1,952개 강의 영상을 사람 손 없이 일괄 분석해, "PPT가 나오는 구간"만 골라내고 중복 슬라이드를 자동 제거한 후, CELab 다크 테마 PPTX로 자동 재생산한다.**

---

## 2. 목적과 동기

### 사용자(Jade)의 핵심 의도
> "내가 본 화공공학 강의들에서 실제로 PPT가 화면에 나오는 부분의 내용만 추출하고 싶다. 강사 얼굴만 나오는 부분은 빼고, 같은 슬라이드가 반복되는 동안은 한 장만 뽑고, 결국 **내 손에는 강의 본 결과로 만들어진 CELab 스타일 PPT만 남아 있도록**."

### 왜 자동화가 필요한가
- 1,952개 영상을 Rev.3 앱으로 1개씩 수동 처리 = 약 1만 시간 사람 손
- Rev.3 앱의 슬라이드 검수 UI(✕ 삭제 버튼)는 5~50장이면 OK지만, 영상당 평균 80장 × 2,000영상 = **16만 장 수동 검수는 불가능**
- 자막 자동화는 진행 중이지만 **시각적 슬라이드 정보**는 자막만으로 복원 안 됨 → PPT 생산을 위해서는 영상의 시각 채널 분석 필수

### 비즈니스/학습 가치
- CELab 위키 Axis 2(Plant Design Economics) 콘텐츠 보강 자료로 PPTX 직접 활용 가능
- 미래 SnapScale 사내 교육 콘텐츠로 재가공 가능
- 본인 학습 시 빠른 review(영상 다시 안 봐도 PPT로 핵심만 훑기)

---

## 3. 핵심 사용자 시나리오

```
Jade가 EzyCourse 폴더에서 자동화 시작 ▶ 버튼 클릭

→ 시스템이 1,952개 영상을 다음과 같이 처리:
  - 영상 A (강사 얼굴만 30분): "PPT 부재" 감지 → 자동 스킵
  - 영상 B (PPT 40분 + 중간 얼굴 5분): PPT 구간만 캡쳐, 얼굴 구간 스킵, 중복 슬라이드 제거 → 약 18장 추출
  - 영상 C (PPT + 필기 추가): 같은 슬라이드의 필기 변화 시점마다 캡쳐 → 약 25장 추출
  - 영상 D (PPT가 1번이라도 나옴): 포함, PPT 부분만

→ 각 영상마다 자동 생성:
  - `{video_name}.captures/` — 정제된 PNG 슬라이드들
  - `{video_name}.lecture.json` — 슬라이드 구조 (4-Phase AI 결과)
  - `{video_name}.lecture.pptx` — CELab 다크 테마 최종 PPT

→ Jade는 결과 PPTX 1,000여 개 받아서 학습/재가공
```

---

## 4. 기능 요구사항 (Functional Requirements)

### F1. PPT 슬라이드 자동 감지 (가장 어려운 부분)
사용자 요구의 **핵심**: 영상의 어느 구간이 "슬라이드 + 필기" 화면이고 어느 구간이 "강사 얼굴" 화면인지 자동 구분.

**F1.1** — 영상 프레임 샘플링 후 각 프레임을 3가지로 분류:
- `slide`: PPT 슬라이드가 화면 대부분을 차지 (필기 포함)
- `face`: 강사 얼굴/상반신이 중심 (PPT 없거나 작음)
- `mixed`: 슬라이드 + 강사 얼굴 합성 (PiP, 분할 화면 등)

**F1.2** — 분류 알고리즘 (3단 hierarchical):
1. **Tier 1 (빠름·로컬)**: 프레임의 시각 통계
   - 텍스트 영역 비율 (OCR 미사용, 엣지 검출 기반)
   - 색 균일도 (PPT 배경은 단색·그라데이션, 얼굴은 피부톤 dominant)
   - 얼굴 검출 (OpenCV haarcascade 또는 macOS Vision API)
2. **Tier 2 (중간·로컬)**: 위 신호 결합한 분류기 (간단한 규칙 또는 학습 안 한 SVM)
3. **Tier 3 (정확·유료)**: 의심스러운 프레임만 Claude Vision API로 1-shot 분류

**F1.3** — 영상 전체 판정:
- "한 번이라도 slide 또는 mixed 분류된 프레임 있으면 영상 포함" (사용자 명시)
- 0개면 "강사 얼굴 전용 영상" 으로 자동 스킵, 메타로 기록 (`{video}.face_only.json`)

### F2. 중복 슬라이드 자동 제거 (정확도가 두 번째 핵심)
같은 슬라이드가 30분간 화면에 떠 있고 강사가 5분에 한 번 필기 추가하면 — **각 필기 시점마다 1장**만 캡쳐.

**F2.1** — 1단계 캡쳐: ffmpeg scene detection (Rev.3 기존 로직 재사용)
- `select=gt(scene,0.25)` 변화 감지, `vsync vfr` 중복 제거
- 임계값 0.10~0.40 자동 튜닝 (장면 변화율로 영상 특성 판단 후 선택)

**F2.2** — 2단계 가지치기: 시각 유사도 클러스터링
- 캡쳐된 N장 PNG 중 perceptual hash (pHash) 또는 SSIM으로 페어 비교
- 유사도 ≥ 0.95 페어는 같은 슬라이드로 묶음
- 각 클러스터에서 **마지막 프레임** 유지 (필기가 가장 많은 시점)

**F2.3** — 3단계 얼굴 프레임 제거 (F1과 연동):
- 캡쳐된 PNG 중 face 분류된 것 자동 제거
- 결과: PPT 또는 mixed 슬라이드만 남음

**F2.4** — 최종 검증:
- 영상당 캡쳐 결과 5~50장 (정상 범위), 50장 초과 시 임계값 자동 조정 후 재시도

### F3. 강사 얼굴 전용 영상 자동 스킵
**F3.1** — F1으로 영상 전체가 face 분류 비율 ≥ 90%이면 스킵
**F3.2** — 스킵된 영상 메타 기록 → `_face_only_skipped.json`에 목록 (사용자 확인 후 강제 처리 가능)
**F3.3** — 자막(.en.vtt / .ko.vtt / .md)은 그대로 유지 (자막은 얼굴만 있는 영상도 가치 있음)

### F4. CELab 다크 테마 PPTX 자동 재생산
**F4.1** — Rev.3 앱의 4-Phase AI 파이프라인 재사용 (`slide_generator_lecture.py`):
- Phase 0: Transcript Analyst (우리가 만든 `.md` 강의 대본 사용)
- Phase 1: Vision Extractor (F2 결과 PNG 입력)
- Phase 2: Structure Designer
- Phase 3: CELab Writer (문장 개선)
- Phase 4: Quality Reviewer

**F4.2** — 입력:
- 캡쳐 PNG들 (F2 결과)
- 한글 강의 대본 (`{video}.md` — 우리 자막 자동화의 산출물)
- terminology.json (Aspen/HYSYS/P&ID 등 영문 유지 규칙)

**F4.3** — 출력:
- `{video}.lecture.json` — 슬라이드 구조 JSON
- `{video}.lecture.pptx` — CELab 다크 테마 PPTX (`pptx_lecture_template.py`)

### F5. 배치 자동화 + 모니터링
**F5.1** — 백그라운드 워커: `_pptx_worker.py`
- 자막 워커와 동일 패턴 (caffeinate + nohup + PID/lock)
- 무한 루프 (5분 sleep)
- 매 iteration: `.md` 존재하고 `.lecture.pptx` 없으면 큐 추가
- 처리: F1 → F2 → F3 → F4 순차

**F5.2** — 전제조건 (각 영상마다):
- ✅ `.en.vtt` 존재 (자막 자동화 완료)
- ✅ `.md` 존재 (강의 대본 완료)
- ❌ `.lecture.pptx` 없음 (미처리)

**F5.3** — `_player.html` 확장:
- 영상 카드에 `📊 PPTX` 진행 상태 점 추가 (자막 옆)
- "PPTX 생성" 우선 큐 버튼 (지금 자막 제작 버튼과 동일 패턴)
- 진행률 표시 (PPTX X/N)

**F5.4** — `_player_server.py` API 확장:
- `POST /api/prioritize-pptx {source, rel}`
- `GET /api/status` 에 pptx 진행률 추가

---

## 5. 비기능 요구사항 (Non-Functional)

### N1. 정확도 우선
- **F1 (PPT 감지)**: false positive ≤ 5% (얼굴 전용 영상을 슬라이드로 잘못 분류하면 안 됨)
- **F2 (중복 제거)**: 사람이 보기에 같은 슬라이드는 1장으로, 다른 슬라이드는 2장으로 — 96% 이상 일치
- **F4 (CELab PPT)**: 원본 내용 ≥ 95% 보존, 오타·환각 0건

### N2. 비용 관리
- 영상당 평균 비용 목표: **$0.10 이하**
- 1,952 영상 × $0.10 = 약 **$200 (≈ 28만 원)**
- 비용 폭주 방지: Tier 3 Claude Vision 호출은 의심 프레임만 (영상당 평균 ≤ 5회)

### N3. 처리 시간
- 영상당 평균: 10분 이하 (대부분 시간은 ffmpeg 캡쳐 + AI 호출)
- 1,952 영상 / 24시간 가동: **약 14일** (자막 작업과 병렬 가능)

### N4. 안정성
- 영상 1개 실패가 전체 중단 안 함 (자막 워커 패턴 동일)
- `.pptx_failed` 사이드카로 blacklist, 무한 재시도 방지

### N5. 사용자 통제권
- 사용자가 언제든 `--stop` 가능
- 결과 PPTX는 보존, 큐 상태도 보존
- 사용자가 검수 후 "이 영상은 다시 처리" 명령 가능 (`.pptx_failed` 삭제로)

---

## 6. 기술 설계 (High-Level)

### 6.1 새로 만들 파일
```
/Users/visionschool/Downloads/EzyCourse_Backup/
├── _pptx_worker.py            # 신규: PPTX 배치 워커 (자막 워커와 병렬)
├── _frame_classifier.py        # 신규: F1 (slide/face/mixed 분류)
├── _slide_dedup.py             # 신규: F2 (pHash/SSIM 중복 제거)
├── _pptx_progress.json         # 신규: 진행 상태
├── _pptx.pid / _pptx.lock      # 신규: 워커 라이프사이클
└── (참조) slide_generator_lecture.py  # Rev.3 앱에서 복사 또는 import
```

### 6.2 파이프라인 의존성
```
mp4 (다운로드)
  ↓ (자막 워커 — 별도)
  → en.vtt → ko.vtt → both.vtt → md
  ↓ (PPTX 워커 — 본 PRD)
  → 1) F1 영상 전체 face-only 판정 → skip / proceed
  → 2) ffmpeg scene capture (Rev.3 재사용)
  → 3) F1 프레임별 face 제거
  → 4) F2 중복 슬라이드 제거 (pHash 클러스터링)
  → 5) F4 4-Phase AI 파이프라인 (md + 캡쳐 PNG 입력)
  → 6) pptx_lecture_template.py로 .pptx 생성
```

### 6.3 의사결정 — Tier 3 Claude Vision 사용 시점
- 영상당 평균 80장 캡쳐 중, Tier 1+2가 명확히 분류 못 한 ~5장 정도만 API 호출
- 호출당 비용: 약 $0.003 (image input + 100 token response)
- 영상당 비용: ~$0.015 (Vision) + ~$0.08 (4-Phase Writer) = **약 $0.10**

### 6.4 의존성 (새로 설치 필요)
- `opencv-python` (얼굴 검출, edge detection)
- `imagehash` 또는 `Pillow` (pHash)
- `python-pptx` (Rev.3 앱에 이미 사용 중 — 추가 설치 불필요)
- `anthropic` (이미 설치됨)

---

## 7. 단계별 마일스톤

### Phase A — F1 분류기 정확도 검증 (1~2일)
- 10개 영상 샘플로 frame 분류 직접 라벨링
- Tier 1+2 정확도 측정, Tier 3 호출 빈도 측정
- 정확도 < 95%면 임계값 튜닝 또는 Tier 3 비율 조정
- **승인 게이트**: 분류 정확도 95%, Tier 3 평균 ≤ 5회/영상

### Phase B — F2 중복 제거 정확도 검증 (1일)
- Phase A 통과한 10개 영상의 캡쳐 결과로 pHash 클러스터링
- 사람이 검수해 false merge / false split 카운트
- **승인 게이트**: 96% 일치

### Phase C — 1개 영상 end-to-end 검증 (1일)
- 자막·대본 완료된 영상 1개 선정
- F1~F4 전체 파이프라인 실행
- 결과 PPTX 사람이 검수
- **승인 게이트**: PPTX 품질 사용자 OK

### Phase D — 배치 워커 + 큐 시스템 (1일)
- `_pptx_worker.py` 작성
- 자막 워커 패턴 따라 caffeinate + 무한 루프
- `_player.html` UI 확장
- **승인 게이트**: 10개 영상 자동 처리 성공

### Phase E — 1,952개 영상 자동 가동 (배경)
- 백그라운드 시작
- 매일 진행 상황 보고 (자동)
- 예상 완료: 약 14일

---

## 8. 리스크 + 대응

### R1. PPT 분류 false negative ("얼굴 영상을 PPT로 잘못 분류")
- **대응**: Tier 2에서 confidence < 70%이면 Tier 3 강제 호출. 그래도 애매하면 영상 통째로 보류 큐로 격리.

### R2. 중복 제거 over-merge ("다른 슬라이드를 같은 것으로 묶음")
- **대응**: pHash 임계값을 보수적으로 (95% 동일이어야 같은 것). 1장이라도 의심되면 둘 다 유지.

### R3. 한국어 강의 + 영어 슬라이드 (Aspen 화면 영어, 강의는 한국어)
- **대응**: 강의 대본은 한국어, 슬라이드 텍스트는 영어 그대로 추출. terminology.json이 영문 유지 강제.

### R4. AI 호출 비용 폭주
- **대응**: 영상당 비용 cap ($1) 설정, 초과하면 그 영상은 fail mark + 보고. prompt caching 적극 사용.

### R5. M4 부하 (자막 + PPTX 동시)
- **대응**: PPTX 워커는 자막 워커보다 낮은 nice priority. ffmpeg capture 만 동시 실행 X (lock).

### R6. 영상 자체에 무관한 화면 (광고, 인트로 등)
- **대응**: 영상 시작·끝 5초는 분석 제외 옵션. (필요시 추가)

---

## 9. 성공 지표 (KPI)

| 지표 | 목표 |
|---|---|
| 자동 처리율 | ≥ 95% (사람 손 안 가는 비율) |
| 얼굴 전용 영상 스킵 정확도 | ≥ 95% |
| 중복 슬라이드 제거 정확도 | ≥ 96% |
| 영상당 생성 비용 | ≤ $0.10 |
| PPTX 결과물 만족도 | Jade가 검수 후 "재가공 없이 그대로 사용 가능" 영상 비율 ≥ 80% |
| 1,952 영상 처리 완료 시간 | ≤ 21일 (24h 가동) |

---

## 10. Open Questions (사용자 확인 필요)

1. **Q1**: 강사 얼굴 전용 영상도 자막은 가치 있으니 자막은 그대로 유지하면 되겠죠? (현재 가정)
2. **Q2**: 중복 제거 임계값 — "같은 슬라이드 + 필기만 추가"는 둘 다 유지할지, 마지막 1장만 유지할지?
   - 현재 가정: **마지막 1장만** (필기 가장 많은 상태)
   - 만약 "필기 단계별 모두 유지" 원하시면 변경 필요
3. **Q3**: 결과 PPTX 저장 위치 — 영상 옆 sidecar (`{video}.lecture.pptx`) vs 별도 폴더 (`~/Documents/CELab_재생산_PPTX/`)?
4. **Q4**: 영상에 PPT가 작게 한쪽에만 보이는 PiP 화면도 슬라이드 추출 대상에 포함할지?
5. **Q5**: 비용 cap을 $200 (≈28만 원) 이내로 가져갈지, 정확도 우선으로 cap 풀어둘지?

---

## 11. 다음 단계

이 PRD 사용자 검토 후 결정:
1. ✅ 진행 — Phase A 시작 (F1 분류기 prototyping)
2. ⏸️ 보류 — 자막 작업 완료 후 시작
3. ✏️ 수정 — Open Questions 답변 + 요구사항 추가/변경 후 v2.0
