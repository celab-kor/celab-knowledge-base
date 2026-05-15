# CELab 지식창고 — Claude 작업 지침

## 표준 용어

모든 HTML 문서 작성 시 반드시 `TERMS.md`의 용어를 준수하십시오.
- 회사명: SnapScale (스냅스킬/시냅스케일 금지)
- 기술: P&ID, EPC, PAWG, AutoFlow, 온톨로지 (온톨러지 금지)
- 제품: Claude Code, Oh My ClaudeCode, OMC

## HTML 작성 규칙

모든 pages/ 하위 HTML 파일에 반드시 포함해야 하는 요소:

### 1. 홈 버튼 (고정)
```html
<a href="../index.html" id="home-btn">🏠 지식창고</a>
```
CSS:
```css
#home-btn {
  position: fixed; top: 14px; right: 16px; z-index: 9999;
  background: #c9a84c; color: #0d1b2a;
  padding: 8px 16px; border-radius: 8px;
  font-weight: 700; font-size: 0.8rem;
  text-decoration: none;
  box-shadow: 0 2px 12px rgba(0,0,0,0.35);
  transition: background 0.15s, transform 0.1s;
  display: flex; align-items: center; gap: 6px;
}
#home-btn:hover { background: #e8c96a; transform: translateY(-1px); }
```

### 2. 사이드바 목차 연동 (scrollTo 충돌 금지)
`scrollTo`는 브라우저 내장 함수와 충돌합니다. 반드시 `navTo`로 명명하세요:
```javascript
function navTo(id, el) {
  const section = document.getElementById(id);
  if (section) section.scrollIntoView({ behavior: 'smooth', block: 'start' });
  document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
  if (el) el.classList.add('active');
}
```
onclick: `onclick="navTo('section-id', this)"`

## index.html 업데이트 규칙

새 HTML 파일 추가 시 반드시 index.html의 `PAGES` 배열에도 항목을 추가합니다.
새 카테고리 추가 시 CSS에 `.cat-{카테고리명}` 스타일도 추가합니다.

## 파일 동기화

`지식창고_자동동기화.command`가 로컬 변경을 자동으로 GitHub에 푸시합니다.
수동 푸시는 불필요하지만, 즉시 반영이 필요할 때: `bash sync.sh`

---

## 자동 오픈/접근 인프라 (2026-05-15 확정)

박규호 부장(Jade) 작업 환경 기준. 다음 4개 진입점이 동시 작동합니다.

### 1) 부팅 시 자동 진입 (0클릭)
- macOS Login Items에 **`지식창고열기.app`** 등록됨
- 위치: `~/Applications/지식창고열기.app` (AppleScript 컴파일)
- 동작: 부팅 + 잠금 해제 → Chrome 자동 실행 → 갤러리(`https://celab-knowledge-base.pages.dev/`) 자동 표시 (Cloudflare Pages, Access OTP 인증 후 7일 자동 통과)

### 2) 즉시 호출 단축키
- **⌥ ⌘ K** (Option + Command + K) → Raycast Quicklink "지식창고"
- 어디서든 Chrome으로 갤러리 점프
- (참고: Raycast 기본 매핑이었던 "Create Quicklink"의 `⌥⌘K`는 제거하거나 비활성화한 상태)

### 3) 백업 진입점
- 데스크탑 `지식창고.webloc` — 더블클릭 시 기본 브라우저로 갤러리 열림
- `~/Library/Services/지식창고열기.workflow` — Quick Action, 시스템 설정에서 단축키 추가 가능 (현재 미매핑)

### 4) 발행 자동화 (HTML 만들면 슬랙 알림 자동)
- 동기화: `sync.sh` — untracked `pages/*.html` 감지 시 git push + 슬랙 발송
- 슬랙 헬퍼: `scripts/notify_slack.py` (curl 기반, macOS SSL 이슈 회피)
- Webhook 키: `scripts/.env.local` (gitignored, 평문 키 푸시 차단됨)
- LaunchAgent: `com.celab.company-schedule-sync.plist` (주기 자동 동기화)

---

## 발행 워크플로 (3가지 경로)

### 경로 A · 회의 영상에서 시작
영상회의록 추출기 Rev.3 앱 → 영상→TXT→HTML → 앱 안 편집 → "발행하기" 버튼
→ 앱이 자동으로 pages/ 복사 + index.html 갱신 + git push + 슬랙 발송

### 경로 B · 외부 HTML 발행 (공개/비공개 2채널)

데스크탑에 발행 인박스 2개가 있으며, 어디로 드래그하느냐로 공개 여부를 결정한다.

| 인박스 | 대상 저장소 | 명령 파일 | 갤러리 자동 등록 |
|---|---|---|---|
| 🌐 `🌐_지식창고_발행대기/` | `celab-knowledge-base` (**PUBLIC**) | `⚡공개_지식창고_발행.command` | ON (index.html PAGES) |
| 🔒 `🔒_위키_발행대기/` | `celab-wiki` (**PRIVATE**) | `⚡비공개_위키_발행.command` | OFF (수동 관리) |

두 .command 파일은 동일한 `celab-knowledge-base/scripts/process_inbox.sh`를 호출하지만, 환경변수(`INBOX`, `KB_PATH`, `KB_VISIBILITY`, `KB_BASE_URL`, `KB_REGISTER_INDEX`)로 동작을 분기한다. **스크립트 본체는 `celab-knowledge-base/scripts/`에만 두고 단일 소스로 유지**(wiki는 .command만 가짐).

슬랙 알림은 두 채널 모두 공통 webhook으로 발송되며, 메시지에 🌐 공개 / 🔒 비공개 라벨이 자동 부착된다. 비공개 발행 시 슬랙 링크는 GitHub 로그인 후 조직 멤버만 열람 가능.

### 경로 C · Claude에게 요청 (가장 권장)
"지식창고에 ~ 발행해줘" 한 마디
→ Claude가 HTML 생성 + index.html PAGES 배열 등재 + git push + 슬랙 발송 일괄 처리

---

## Claude가 새 페이지 만들 때 따라야 할 순서

1. `pages/YYYY-MM-DD_제목.html` 작성 (CLAUDE.md 상단 HTML 작성 규칙 준수)
2. PAGES 배열 등재 (택1)
   - 자동: `python3 scripts/register_page.py pages/YYYY-MM-DD_제목.html` — title 자동 추출, `index.html`과 `pages-data.json` 동시 업데이트
   - 수동: `index.html`의 `PAGES` 배열 **맨 앞**에 항목 추가 + `pages-data.json`도 같은 entry 추가 (Rev.3 앱이 stale json을 읽고 PAGES를 되돌리지 않도록 양쪽 sync 필수)
3. `bash sync.sh` 실행 → 자동 commit + push + 슬랙 발송
4. 결과 확인: `.sync.log`의 마지막 줄에 `[slack] 200` 표시

수동 `git push`로 직접 푸시하면 슬랙 발송이 누락됩니다. **반드시 `sync.sh` 경유**.

### Path B (인박스) 사용 시 주의
`process_inbox.sh`는 `register_page.py`를 자동 호출해 PAGES 배열·pages-data.json을 함께 갱신합니다. 따라서 데스크탑 `📁 지식창고_발행대기`에 HTML 드래그 → `⚡발행대기처리.command` 더블클릭만 하면 갤러리 카드가 자동 등록됩니다.

---

## 분류 정책 (2026-05-15 결정)

- **물리 폴더로 분류하지 않음**. 11개 카테고리 폴더(`02 CELab/인터뷰/팀 미팅/` 등)는 폐기.
- `pages/` 폴더는 평평하게 유지 (하위 폴더 생성 금지 — 슬랙·갤러리 동작 안 함).
- 분류는 `index.html` PAGES 배열의 `category` + `tags` 필드로만 (갤러리 필터에서 가상 분류).
- 카테고리 목록: 투자 · IR · 분석 · 전략 · 기타 · 교육 (새 카테고리 추가 시 CSS `.cat-{이름}` 스타일도 함께 추가)

---

## 참고 문서

- 사용 매뉴얼 (사용자용): `pages/2026-05-15_user-manual.html` — 머메이드 포함 스텝바이스텝
- 워크플로 SOP (결정 근거): `pages/2026-05-15_workflow-sop.html` — 5개 후보 점수 비교
