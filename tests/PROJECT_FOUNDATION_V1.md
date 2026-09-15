# Project foundation v1 실행 보고 — 2026-09-10

기존 생산·외교·사건·세력 선택을 별도 worktree에 통합했다. 최종 실행은 기존 테스트 726/726, 그래픽 통합 검증 80/80 통과. 수치는 이번 실행 로그에서 집계했으며 기존 문서의 결과를 인용하지 않았다. 모든 변경은 unstaged 작업 파일로 남아 있다.

## 경로와 기준

- 원본 작업 공간: `E:\OneDrive - GRTech\문서\samhan-660-2026-09-02-00-00-33-home\Samhan660-faction-rulers-v1`
- 실행 프로젝트: 위 경로의 `.worktrees\project-foundation-v1`
- 작업 브랜치: `feature/project-foundation-v1`
- HEAD/기준: `419e90a50529890d1743b417d68718609ccb7945`
- 실제 Godot: `C:\Users\지용훈\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- 버전: `4.7.2.stable.official.ed1daf0bf`
- 최종 그래픽 실행: Windows, D3D12 12_0 / Forward+, NVIDIA GeForce RTX 4060 Laptop GPU, 1280×720 캡처.

프로젝트와 상위 경로, 관련 worktree에서 적용할 `AGENTS.md`를 찾지 못했다. 이 작업의 사용자 지침을 적용했다. `_handoff`는 열거나 변경하지 않았다. Git의 소유권 확인이 필요한 다른 worktree 조회에는 명령별 `safe.directory` 옵션만 사용했다.

원래 브랜치는 `feature/faction-selection-rulers-v1`, HEAD는 위와 동일했다. `new_game_setup.gd`와 `scenario_data.gd`의 미커밋 변경(합계 +414/-72), 군주 Overlay PNG 및 import 메타데이터, 선언 재생 테스트·문서를 확인하고 보존했다. 기존 파일에 stash/reset/clean을 실행하지 않았다. 원본 아래에 새 worktree를 두었으며 `.worktrees/.gdignore`를 추가하여 원본 Godot의 중복 스캔을 막았다.

기존 다른 worktree:

| 폴더 | 브랜치 / HEAD | 시작 시 확인 |
|---|---|---|
| `../Samhan660` | `feature/trade-system-v1` / `50c8d87` | addons 삭제, project.godot 변경 등이 있음. 가져오지 않음 |
| `../Samhan660-faction-selection` | `feature/faction-selection-background-v1` / `419e90a` | 별도 선택 화면 변경과 로컬 자산 등이 있음. 가져오지 않음 |
| `../Samhan660-integration-v1` | `integration/trade-faction-selection-v1` / `419e90a` | 깨끗한 worktree. 기존 것을 보존하고 요청한 새 브랜치 생성 |

## 포함 관계와 통합 판단

읽기 전용 `git ls-remote`를 다시 실행하여 최신 원격 값을 확인했다. 일반 네트워크 제한으로 첫 조회가 실패했지만 권한 확장 후 성공했다.

| 브랜치 | 원격 재확인 커밋 | 이번 처리 |
|---|---|---|
| faction-selection-background-v1 | `419e90a50529890d1743b417d68718609ccb7945` | 기준 |
| event-choice-framework-v1 | `bb22d578fffcca8adb47c9b6896836b1c5df641c` | 기준의 조상. 재적용하지 않음 |
| trade-system-v1 | `50c8d87b15a2f89f41b6a50e6058f99fb72efb49` | 공통 생산 기반 이후의 외교 변경을 작업 파일에 적용 |

공통 생산 커밋은 `0b70001`. 기준에는 컷신 `6b426ec`, 풍년 연결 `310f8e1`, 흉년 선택 `bb22d57`, 세력 선택 `419e90a`가 순서대로 포함되어 있다. 외교 분기의 누락 커밋은 `50c8d87` 하나였다. `campaign_main.gd`는 문맥 충돌 5곳을 직접 조정하고 양쪽 동작을 보존했다. 한쪽 파일 전체로 덮어쓰지 않았다.

로컬 `feature/province-support-transfer-v1`은 해당 원격보다 앞선 `8387cad`를 가리키지만, 그 작업은 이미 기준의 조상에 포함되어 있어 다시 적용하지 않았다. `git log --all --not --remotes`에서 별도의 미포함 로컬 전용 커밋은 발견되지 않았다. 원본 및 별도 선택 worktree의 미커밋 군주 대사·초상 확장은 이번 통합에 포함하지 않았다. 승인 UI/초상 자산과 연결된 별도 작업이므로 다음 단계에서 개별 검토할 수 있다.

## 수정 파일

| 파일 | 변경 |
|---|---|
| `campaign_main.gd` | 외교 UI/명령 연결, 새 게임 초기 관계와 구형 저장의 재지급 방지, 사건과 외교의 동시 진입 차단, 생산↔외교 전환 및 지도 잠금 연결 |
| `campaign_navigation_menu.gd` | 기존 외교 메뉴 항목과 신호 추가 |
| `samhan_strategy_systems.gd` | 외교 사절 검증, 월별 사용 기록, 결정적 협상 결과, 통상협정 조건·해지, 구형 관계 키 호환 |
| `diplomacy_overlay.gd`, `.uid` | 외교 브랜치의 기존 화면 및 UID 추가 |
| `map_area.gd` | 생산·외교 모달용 입력 잠금을 컷신 잠금과 별도로 관리 |
| `cutscenes/event_presentation.gd` | 사건 시작 전에 낮은 레이어의 생산·외교 화면을 닫고 이후 입력 상태를 저장 |
| `tests/diplomacy_test.gd`, `.uid`, `DIPLOMACY.md` | 외교 브랜치에서 가져옴. 테스트만 도입 연출 최소 설정으로 조정 |
| `tests/project_foundation_test.gd` | 다섯 연도 실제 씬 전환, 정상 632년 진행, 세 사건 선택지와 저장·중복 방지·입력 복구 검증 |
| `tests/run_project_foundation.ps1` | 재실행 진입점 |
| `tests/PROJECT_FOUNDATION_V1.md` | 이 보고서 |

`project.godot`, `addons`, 기존 Portrait·Overlay 및 배경 이미지, 승인된 UI 배치, `new_game_setup.gd`, `scenario_data.gd`는 기준과 동일하다. 장수 명단·내정 능력 공식·군량 수송·전투 개편은 하지 않았다.

초기화는 기존 도시/장수/시나리오 설정 확정 후 전략 상태를 만들고, 새 게임일 때만 시작 기술·관계를 적용한다. 구형 저장의 전략 상태 생성에는 시작 관계를 재지급하지 않는다. 저장 버전 4와 각 기능의 기존 상태 필드를 유지했다.

월 진행 순서는 기존대로 다음과 같다.

1. 달력 전진 → 상업 수입 → 계절 수확(풍년·흉년 피해 확정).
2. 도시 병력 군량 소비 → 저장 손실 → 월별 생산.
3. 치안 회복 → 이동 명령 → AI.
4. 계절이 바뀔 때 건설·연구·교역 등 전략 정산.
5. 표시 갱신 → 풍년 연출 → 미결 흉년 선택.

외교 행동은 명령 시 즉시 정산하고 연·월 사용 기록을 저장한다. 교역은 기존 계절 정산을 유지한다. 도시 군량의 원장은 `provinces[id].food_stock`, 철·칼 등 생산 재고는 `strategy_state.city_inventory`다. 선택 대기/완료는 `crop_failure_events.pending/resolved`, 연도 피해 기록은 `years`에 유지된다.

## 이번 실행 결과

| 테스트 | 통과 / 검사 | 프로세스 종료 |
|---|---:|---:|
| production_test | 193 / 193 | 0 |
| geumgwan_ownership_test | 181 / 181 | 0 |
| diplomacy_test | 132 / 132 | 0 |
| cutscene_test | 83 / 83 | 0 |
| bountiful_harvest_test | 47 / 47 | 0 |
| crop_failure_test | 90 / 90 | 0 |
| project_foundation_test, 실제 그래픽 | 80 / 80 | 0 |
| 합계 | **806 / 806** | 모두 성공 |

로그: [최종 실행 폴더](../.godot/foundation-results/final). `iron_supply_test.gd`, `iron_pilot_test.gd`는 생산 테스트가 호출하는 RefCounted 보조 테스트이며 위 193개에 포함된다. 최초에 독립 실행을 시도한 두 보조 프로세스는 종료했고 독립 통과 수로 계산하지 않았다. 최초 외교 실행은 132개 중 6개 실패했으며, 660년 도입 컷신 중 외교를 열던 테스트 전제를 고친 뒤 132/132로 재실행했다. 최종 로그에는 게임 스크립트 오류가 없다.

### 632년 신라 정상 진행

날짜·자원·기술·사건 판정을 직접 주입하지 않았다. 선택 화면에서 시작하고 정상 생산/외교 명령과 월 진행을 사용했다. 금관가야 제철시설 금 240 지출 → 생산 예약 → 백제 친선 사절 금 200 지출. 2월 통상협정은 확률 70, 판정 35로 성공했다. 제철시설은 계절 정산 2회 후 7월 완공, 다음 달부터 생산했다.

| 저장 시점 | 월 | 국가 금 | 금관가야 군량 | 치안 | 철 |
|---|---:|---:|---:|---:|---:|
| 2월/협정 후 | 2 | 2,040 | 4,497 | 73 | 0 |
| 흉년 선택 대기 | 9 | 13,413 | 4,830 | 100 | 4 |
| 강제 징발 | 9 | 13,413 | 5,330 | 88 | 4 |
| 세금 유지 | 9 | 13,413 | 4,830 | 94 | 4 |
| 구휼 | 9 | 13,413 | 4,030 | 100 | 4 |
| 구휼 후 10월 | 10 | 15,096 | 4,682 | 100 | 6 |

9월에는 기존 풍년 연출 종료 후 금관가야 흉년이 발생한다. 확정 수확 손실 576, occurrence ID는 `crop_failure:v1:silla_equilibrium_632:632:geumgwan`. 같은 실제 미결 저장을 다시 열어 세 선택지를 각각 검증했다. 구휼 치안은 이미 100이므로 실제 변화 +0으로 표시된다.

선택 대기 중 저장·복원, 완료 결과에서 저장·복원, 동일 월 생산 재호출, 사용한 외교 재시도, 세 정책의 중복 신호 및 다음 달의 재호출을 검증했다. 자원·큐·외교·피해/선택 영수증은 유지되며 중복 지급·차감이 없었다. 테스트 저장은 `.godot/foundation-results/*.json`만 사용하여 기본 사용자 저장을 덮어쓰지 않았다.

### 화면과 입력

다섯 연도 모두 신라 선택에서 실제 `_on_start_pressed` 흐름으로 캠페인 씬에 진입했다. 660년 도입 컷신의 잠금과 종료 후 복구도 확인했다. 정상 컨트롤 신호/콜백과 Godot viewport에 주입한 포인터·Esc 이벤트를 함께 사용했다. 생산 건설·예약, 친선 사절, 월 진행, 사건 선택은 실제 버튼 위치를 클릭했다. 사람의 수동 마우스 조작 검증은 아니다.

생산 닫기 버튼·Esc, 외교 닫기 신호·Esc, 생산↔외교 전환, 사건 Esc 메뉴, 사건 메뉴에서 외교 진입 차단, 선택 복원, 완료 후 지도 도시 선택 및 월 진행을 확인했다. 기본 설정의 실제 GPU 렌더링 결과를 캡처했다.

| 연도 | 선택 화면 | 캠페인 |
|---|---|---|
| 632 | [선택](../.godot/foundation-results/selection_632.png) | [캠페인](../.godot/foundation-results/campaign_632.png) |
| 642 | [선택](../.godot/foundation-results/selection_642.png) | [캠페인](../.godot/foundation-results/campaign_642.png) |
| 660 | [선택](../.godot/foundation-results/selection_660.png) | [캠페인](../.godot/foundation-results/campaign_660.png), [도입](../.godot/foundation-results/opening_660.png) |
| 663 | [선택](../.godot/foundation-results/selection_663.png) | [캠페인](../.godot/foundation-results/campaign_663.png) |
| 670 | [선택](../.godot/foundation-results/selection_670.png) | [캠페인](../.godot/foundation-results/campaign_670.png) |

[생산](../.godot/foundation-results/production_632.png) · [외교](../.godot/foundation-results/diplomacy_632.png) · [사건 선택](../.godot/foundation-results/event_choice_632.png) · [구휼 결과](../.godot/foundation-results/event_result_632.png) · [강제 징발](../.godot/foundation-results/force_requisition_632.png) · [세금 유지](../.godot/foundation-results/maintain_tax_632.png) · [10월 복원 지도](../.godot/foundation-results/restored_october_632.png)

## 기존 문제와 이번 통합 문제의 구분

- **기존 동작, 수정 제외:** 월별 AI 병력 충원 뒤 `unit_rosters` 캐시가 뒤처지고 불러오기에서 `ensure_unit_rosters()`가 도시 병력에 맞춘다. 이 함수와 월별 충원 경로는 기준 코드에도 있다. 실제 `provinces[].troops`와 자원은 불러오기로 변하지 않는다. 원시 전후 비교는 `february/pending_choice/october-before.json` 및 `-after.json`에 보존했다. 통합 저장 비교는 이 전투 캐시만 제외하며 도시 병력과 나머지 전략 상태는 비교한다. 전투 개편 때 검토할 항목이다.
- **기존 데이터, 수정 제외:** 632년에도 공통 장수 데이터의 김법민 등이 사절 목록에 나온다. 연도별 장수·직책 정비의 후속 입력이며 이번에는 데이터나 능력 공식을 바꾸지 않았다.
- **기존 UI:** 생산 설명이 길어 명령 버튼까지 스크롤이 필요하다. 승인 배치를 유지했고 검증 스크립트가 버튼을 스크롤 안으로 이동한 후 클릭한다. 로컬 미커밋 군주 확장을 제외하여 기준의 큰 Overlay/선언은 632 신라에만 적용된다.
- **이번 통합에서 수정:** 사건 메뉴로 외교를 중첩하면 턴 잠금 스냅샷이 잘못 복원될 가능성. 사건 중 외교 열기·실행을 막고 사건 시작 시 모달을 닫았다. 생산·외교 지도 잠금을 컷신 잠금과 분리했다.
- **검증 도구에서 수정:** 기존 외교 테스트의 도입 컷신 전제, 스크롤 밖 버튼 클릭, 불러오기 직후 미배치 버튼 클릭을 수정했다. 제품 자원을 조작하여 통과시키지 않았다.
- **환경 경고:** 샌드박스 Windows 루트 인증서 저장소 읽기, 첫 headless editor 종료의 개인 editor_settings 쓰기, 초기 상대 log 경로의 user 디렉터리 생성 경고가 있었다. 최종 GUI는 절대 로그 경로를 사용한다. 첫 OpenGL 보조 실행에서 shader 초기화 경고가 있었으나 최종 기본 D3D12 실행은 정상이다. 승인 설정을 고치지 않았다. 환경 때문에 생략한 요청 검증은 없다. 장기간 플레이·전체 세력 조합·수동 사람 입력까지 검증한 것은 아니다.

## 생성 파일과 재현

직접 수정한 파일은 위 표와 원본의 `.worktrees/.gdignore`다. Godot가 생성한 `.godot/imported`, `editor`, UID/클래스 캐시는 직접 편집하지 않았다. 실행 스크립트가 만든 로그·스크린샷·격리 저장과 원시 상태 비교도 `.godot/foundation-results`에 구분해서 보관했다. 새 외교 `.gd.uid` 둘은 외교 커밋에서 가져온 파일이며 이번 자동 생성물로 세지 않았다. 보호 대상의 tracked diff와 staged diff는 모두 비어 있다. stage/commit/push/Git merge 명령을 실행하지 않았다.

통합 worktree에서 재현:

```powershell
$godot = 'C:\Users\지용훈\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& .\tests\run_project_foundation.ps1 -Godot $godot -WithGraphics
```

새 환경은 먼저 `& $godot --headless --path . --editor --import`로 리소스를 가져온다. 테스트 외 실제 게임은 이 worktree의 `project.godot`를 열거나 `& $godot --path .`로 실행한다. 테스트 결과 폴더는 Git ignore 대상이므로 전달 시 이 보고서와 함께 별도 보존해야 한다.

**다음 작업 판단:** 이 작업 버전에서 장수·직책 작업에 착수할 수 있다. 먼저 현재 통합 diff를 기준으로 이어가고, 원본의 미커밋 군주 화면 확장은 별도로 검토한다. 전투 캐시 문제는 기록만 유지하며 장수 명단 수정과 함께 임의로 고치지 않는다.
