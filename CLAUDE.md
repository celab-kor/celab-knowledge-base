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
