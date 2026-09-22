# 달구벌 UI handoff v1 — 실제 캠페인 연결

2026-09-17. 현재 `main`, 기준 HEAD `d953cfac9fb70e10c2c45ef659eb0d1bd57e5aaf`에서 구현. 브랜치 변경·되돌리기·커밋·Push 없음. 기존 해안 비교 작업과 미추적 UID 파일을 보존했다. 적용되는 상위/프로젝트 AGENTS.md는 발견되지 않았다.

## 원본과 실행 방법

- ZIP: `C:/Users/지용훈/Downloads/Samhan660_UI_Handoff_v1.zip`.
- 저장소 밖 새 폴더: `C:/Users/지용훈/Downloads/Samhan660_UI_Handoff_v1_review_20260917/Samhan660_UI_Handoff_v1/`.
- APPLY_IN_VSCODE.txt, START_HERE_KO.md, UI_IMPLEMENTATION_KO.md, VALIDATION_STATUS_KO.md, 두 spec JSON과 참조 JPG를 읽었다. SHA256SUMS.txt의 11개 파일 해시가 모두 일치한다.
- Godot **4.7.2 stable**, Windows D3D12 Forward+, RTX 4060 Laptop GPU에서 실행했다.
- **F5 → 캠페인 시작/불러오기 → 상단 `거점 지도`**, 또는 게임 메뉴의 `달구벌 · 거점 지도`. 캠페인 장면은 `res://campaign_main.tscn`이다. 별도 데모 캠페인을 만들지 않는다.
- `기존 전체 지도` 또는 Esc로 원래 지도에 복귀한다. `저장·메뉴`에서 기존 메뉴/저장 접근을 유지한다. 새 UI만 강제하지 않는다.

## 실제 연결

- 검정·금색 상단, 좌측 영지/군사/생산/인사, 독립 지형/성/깃발/이름/병력/선택/경로, 하단 실제 영지 상태와 지원 미리보기.
- 지형 원본 1254×1254를 논리 세계 6144×4096의 `(3072,2048,1024,1024)`에 배치한다. 성 지면 앵커는 이미지 상자의 `(0.5,0.67)`이며 게임 UV를 변경하지 않는다. 확대 단계마다 같은 보정 지형을 사용한다. PNG를 확대 가공하지 않았고 mipmap 가져오기만 활성화했다.
- 모든 성은 현재 런타임 병합 좌표와 활성 캠페인 provinces를 사용한다. 54개 좌표 및 35개 한반도 지역 데이터를 유지한다. 경로는 현재 `province_connections`를 읽어 그리므로 사벌–추풍령도 누락하지 않는다.
- 축소 시 병력 숫자를 숨기고 주요 거점을 우선하며, 확대 시 첫 다섯 거점/선택 거점의 병력과 실제 상세 작업 상태를 늘린다. 겹치는 이름은 선택 거점과 첫 다섯 거점을 우선하고, 나머지 정보는 성 툴팁으로 확인할 수 있다.
- 날짜·세력·금·주둔 병력·군량·태수·치안·성벽·생산 상태는 현재 캠페인에서 읽는다. 건설/연구 진행의 남은 기간은 `Industry.remaining_months`의 현재 조건 견적이다. 적 생산/담당자 상세는 노출하지 않고, 기존 지도에 공개되던 병력/소속 범위를 유지한다.
- 네 메뉴는 기존 공통 화면을 연다. 인사는 선택 도시의 태수 항목을 선택한다. 닫기/Esc 후 선택 거점·지도 이동 위치를 유지하고 실제 상태를 다시 읽는다.
- 지원 출발지는 직접 연결된 현재 아군 도시만 제시한다. 기존 `queue_province_transfer`의 **1개월** 규칙을 읽기 전용 `province_transfer_turns`로 추출해 미리보기와 실제 예약이 공유한다. 산악로 예시 2개월을 새 규칙으로 넣지 않았다.
- 미리보기는 선과 도착 예정만 표시한다. 확정은 기존 부대 화면의 부대 선택·지휘관 및 이동 자격/업무/군권 검증을 거쳐 기존 명령을 실행한다. UI에 별도 결제나 병력 이동 구현은 없다.
- 유효한 아군 대상 침공 예고만 지도 우측 상단에 표시한다. 예고 당시 병력/예정 월을 읽고, 클릭하면 기존 복수 침공/대응 화면을 연다. 침공이 없거나 취소되면 경고가 사라진다.
- 월 진행·메뉴 복귀·기존 저장 불러오기 후 갱신한다. 새 저장 필드를 추가하지 않았으며 선택 도시 ID도 기존 저장 필드를 사용한다.

## 실제 검증

### 정상 캠페인 및 GUI 자동 입력

`tests/settlement_ui_test.gd`:

- 새 642년 신라, 보통/역사적 캠페인. 시작은 실제 **642년 7월, 금 1,000**이며 참조 JPG의 643년 3월을 복사하지 않았다.
- 1280×720, 1920×1080에서 실제 InputEvent로 다섯 성 클릭, 휠 확대/축소, 드래그, 네 메뉴 왕복, 지원 미리보기/취소, 원래 지도 복귀를 검증했다. 기본 프로젝트 1920 캔버스를 1280 창에 표시하는 배율도 별도 캡처했다.
- 모든 메뉴/미리보기 왕복 전후 날짜·금·provinces·strategy·예약 전체 비교에서 무변경. 메뉴 클릭/상단 휠이 지도를 움직이지 않는다.
- 기존 부대 화면에서 금성의 **unit:14, 28,000명**을 달구벌로 지원했다. 한 번만 예약되고 반복 클릭으로 다시 출발하지 않는다. **642년 8월, 1개월 뒤 도착**하며 달구벌 병력은 8,800→36,800명으로 갱신된다. 자원·병력·날짜 주입이나 AI 중지는 하지 않았다.
- 별도 확인으로 금성의 제련소 건설/제검술 연구를 공통 정상 명령으로 시작했다. 실제 금은 1,000→560, 현재 조건의 건설 약 5개월/연구 약 3개월이 화면에 표시된다. 이 작업 시작 확인은 지원 대기 저장을 다시 불러온 뒤의 별도 분기이며, 연구·건설 완료 검증을 뜻하지 않는다.

`tests/settlement_ui_restart.gd`:

- 지원 대기 상태를 **고유 `user://settlement_ui_<timestamp>_<pid>.json`** 슬롯에 저장하고 첫 프로세스를 종료한 뒤 다른 PID로 실행했다.
- 날짜·세력·국고·도시·부대·정치·예약 전체 상태 및 선택 달구벌이 저장 시점과 동일하다. 월 진행 후 원래 부대가 한 번 도착하고 해당 예약이 정리된다.
- 정상 AI를 유지하며 진행해 **643년 6월** 실제 **북한산성 / 643년 7월 예정 / 예고 당시 적 31,800명** 알림을 확인했다. 경고 클릭은 기존 침공 대응 화면을 열고, 자원을 쓰지 않으며 복귀 후 거점 선택을 유지한다. 다음 월 이후 경고 표시가 현재 pending 목록과 일치한다.
- 경고 취소와 소유권 변경 시 행동 비활성화는 **별도 통제 조건 검사**다. 해당 조건은 시험 상태에서만 만들고 원래 시험 저장으로 복원해 폐기했다. 정상 발생 사건으로 계산하지 않는다.
- 사람이 수행한 수동 플레이 및 브라우저 시안 검증과 구분되는 **Godot GUI 자동 입력** 결과다.

### 관련 기존 회귀

| 검사 | 결과 |
| --- | --- |
| settlement_ui_test.gd — 실제 GUI 및 정상 명령 | 97건, 실패 0 |
| settlement_ui_restart.gd — 새 프로세스/정상 AI/별도 통제 조건 | 16건, 실패 0 |
| army_readiness_test.gd | 337건, 실패 0 |
| production_test.gd | 193건, 실패 0 |
| cutscene_test.gd | 91건, 실패 0 |

총 **734건, 실패 0**. 최종 다섯 실행 로그에서 SCRIPT ERROR/ERROR/WARNING이 발견되지 않았다. `git diff --check`도 통과했다.

실행 예: 설치된 Godot 콘솔에서 `--path . --script res://tests/settlement_ui_test.gd`, 종료 후 `--path . --script res://tests/settlement_ui_restart.gd`. 기존 회귀에는 `--headless`를 추가했다. 최종 로그와 JSON 결과는 `.godot/settlement-*`, `.godot/settlement-ui/normal.json`, `restart.json`에 있다.

## 실제 화면 캡처

모두 Godot Viewport의 PNG이며 합성 시안이 아니다.

- `.godot/settlement-ui/1280-dalgubeol.png`
- `.godot/settlement-ui/1920-dalgubeol.png`
- `.godot/settlement-ui/1280-support-preview.png`
- `.godot/settlement-ui/1920-support-preview.png`
- `.godot/settlement-ui/1280-overview.png`, `1920-overview.png`
- `.godot/settlement-ui/after-normal-month.png`
- `.godot/settlement-ui/active-industry.png`
- `.godot/settlement-ui/1280-default-canvas-scale.png`
- `.godot/settlement-ui/restart-pending.png`
- `.godot/settlement-ui/natural-threat.png`, `resolved-threat.png`

## 변경 파일·보존·남은 범위

- 수정: `campaign_main.gd` — 진입 버튼/메뉴, Esc·원래 지도 잠금, 저장 불러오기 갱신, 기존 지원 기간 공통 조회.
- 추가: `settlement_map.gd`, `settlement_overlay.gd`, `assets/ui_handoff/` 원본 두 PNG/두 spec JSON와 가져오기 설정, 두 UI 시험 스크립트, 이 기록(및 Godot UID).
- 기존 게임 비용·생산·훈련·전투 계산, 도시 UV·점령 단위, 저장 형식 유지. 기존 해안 비교 장면/자료도 유지했다.
- 기존 사용자 `campaign_save_35_regions_v1.json` SHA-256은 작업 전후 **3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3**로 동일하다. 사용자 슬롯을 시험에 덮어쓰지 않았다.
- **해안/영토 미완료:** 금관가야·울릉의 새 육지와 기존 영토 마스크 바다가 불일치한다. 새 거점 지도에서 부정확한 옛 경계 중첩은 숨기고 소유 깃발을 표시하며, 기존 전체 지도에서는 원래 영토 경계를 계속 볼 수 있다. 주변 23개 새 타일이 없어 첫 구역 가장자리의 색/지형 접합선은 남아 있다.
- 그림 속 길·산·강과 논리 도로가 모든 지점에서 정합한 것은 아니다. 게임 좌표/도로를 그림에 맞춰 바꾸지 않았다. 동일 성 이미지는 배치용이며 지역별 최종 건축 고증이 아니다. 1254px 원본 이상의 상세 지형은 없다.
- 사람의 수동 플레이, 과거 원본 저장본이 필요한 재검증 **2건은 미검증 유지**. 이번 UI 검증으로 이를 통과 처리하지 않는다.
