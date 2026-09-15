# Godot 경고 정리 검증

- 기준: `dd1e22d`, Godot 4.7.2, 2026-09-16.
- 작업 시작 시 Git 변경 없음. 프로젝트 설정·시나리오 데이터·LowPolyTerrain 원본 보존. 공식 GUT 테스트 의존성만 추가.
- Godot 언어 서버: 게임/테스트 123개 스크립트의 경고 **104개 → 0개**.
  추가 회귀 테스트를 포함한 124개에서 파서 오류도 0개.
- 최종 애드온/GUT 포함 **352개 스크립트: 경고 0개, 파서 오류 0개**.

## 수정

- `reference`를 인물용 `officer_ref`, 세력용 `faction_ref`로 변경하고 모든 사용처를 함께 수정.
  저장 데이터의 `"reference"` 키는 유지.
- `count`, `position`, `owner`, `name`, `load` 등과 테스트 지역 변수의 이름 충돌 해결.
- 미사용 인물 목록 복사·모집 카운터·선택 데이터 조회 제거.
  인물 이동은 Registry, AI 모집은 MilitaryPlanning이 이미 담당한다.
  미사용 `moved` 조회도 제거: 준비 부대는 기존 `Preparation.ids(plan)` 제외 로직으로 보호된다.
- 운송의 미사용 `nodes` 인자와 호출부 제거. 실제 소유 도시·경로·재고 검증은 기존 공통 견적을 사용한다.
- 건설 견적의 시나리오/공급 규칙 인자는 기존 호출 호환을 위해 밑줄 접두어로 유지.
  생산 가능 지역/시나리오 제한은 생산 배치 검증에서 처리된다.
- 미사용 테스트 값과 불필요한 `await` 제거, 키 입력의 enum 변환 명시.
- 정수 나눗셈은 나눗셈 후 `int()`로 소수부를 버리는 기존 계산 순서를 유지.
  모집 단위·생산 배치·분할 병력/장비·연월·예산 계산을 확인했다.
  음수 외교 관계는 내림이 아닌 **0 방향 버림**을 유지한다.
- 기존 `@warning_ignore("integer_division")` 5곳도 원인을 해결해 제거했다.
  전역 경고 설정은 변경하지 않았다.

## 검증 결과

- 새 게임 설정의 663년/고구려 선택과 실제 시작 버튼 신호로 캠페인 진입.
  기존 시작 계절대로 **663년 7월**, 금 1,000, 고구려이며 입력 잠금 해제 확인.
- 새 회귀 테스트: 수정 전 1,499개, 수정 후 기준 결과 비교 포함 1,500개 통과.
  D3D12 Forward+ 실제 렌더링과 화면 저장 포함 1,501개 통과.
- 원본 전략 스크립트와 직접 비교 2,008개 통과:
  외교 관계 -100~100, 무역 수입, 시드 기반 인물 이름 및 자녀 능력.
- 기존 테스트 **14개 / 2,414개 검사 통과**:
  production, diplomacy, officer_registry, domestic_assignment, industry_assignment,
  army_readiness, mobilization, faction_economy, supply_transport,
  ai_military_planning, noble_politics, noble_power_constraints,
  campaign_ending, bountiful_harvest.
- mobilization은 상속된 저장 테스트의 출력 폴더 준비 후 재실행해 오류 없이 통과.
- campaign_ending의 저장 실패 로그 1개는 없는 경로에 저장하는 의도적인 실패/재시도 검사이며 통과.
- 프로젝트 수정분 `git diff --cached --check -- . ':!addons/gut'` 통과.
  공식 GUT 원본의 공백/파일 끝 빈 줄 지적 18개는 배포본을 그대로 보존했다. Godot 경고는 아니다.

## GutTest 의존성 해결

LowPolyTerrain 테스트 두 파일은 `extends GutTest`인데 프로젝트에 GUT가 없었다.
Godot 4.7용 공식 [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1)의
`addons/gut`를 MIT 라이선스와 함께 고정 버전으로 추가했다. 원본 파일 전체 해시 비교 결과 차이 0개.
출처와 아카이브 SHA-256은 [UPSTREAM.md](../addons/gut/UPSTREAM.md)에 기록했다.
편집기 플러그인 활성화나 게임 경고 설정 변경은 필요하지 않았다.

| 테스트 | 최종 결과 |
| --- | --- |
| `test_low_poly_terrain.gd` | 81/81 통과 |
| `test_low_poly_terrain_servers.gd` | 71/71 통과 |
| 합계 | **152개 테스트 / 1,328개 assertion 통과, exit 0** |

최초 샌드박스 실행에서 사용자 폴더 저장이 차단된 2개 검사는 적절한 실행 권한으로 재실행해 통과했다.
실행 스크립트: `tests/run_lowpoly_terrain.ps1`.

## 기존 실패 4건: 원인과 수정 전후

기준 원본은 `dd1e22ded04221c206b1e4b7df851693cfc0eea7`의 독립 작업 트리였다.
이번 작업은 아래 assertion이나 관련 기능을 변경하지 않았다.

| 테스트명 / assertion | 실패 원인 | 수정 전 | 수정 후 |
| --- | --- | --- | --- |
| `mobilization_ai_test.gd::_run/common` / `AI issues actual produced bundles common` | 632.02 백제의 미장비 부대가 0개. 생산비 28은 정상이나, 기존 부대가 이미 장비를 갖춘 상태에서도 즉시 `equipment_issue` 이력을 요구함 | 실패 | 동일 실패 |
| `mobilization_ai_test.gd::_run/stock_transport` / `AI issues actual produced bundles stock_transport` | 632.02 백제의 미장비 부대가 0개. 철 수송·생산비 10은 정상이나 지급 수요 없이 지급 이력을 요구함 | 실패 | 동일 실패 |
| `mobilization_ai_test.gd::_run/regional` / `AI issues actual produced bundles regional` | 632.02 신라의 미장비 부대가 0개. 지역 생산비 16은 정상이나 지급 수요 없이 지급 이력을 요구함 | 실패 | 동일 실패 |
| `cutscene_test.gd::_run` / `single catalog contains existing events and crop failure` | `p.events.size() == 7`이라는 이전 기대값. JSON의 7개에 `EventPresentation.setup()`이 `noble_personnel_demand`를 추가하므로 실제 8개 | 실패 | 동일 실패 |

- mobilization_ai: 수정 전/후 모두 **15개 검사 중 3개 실패**, exit 1.
  현재 상태를 읽는 별도 진단으로 세 모드 모두 미장비 부대 0개, 장비 지급 이력 없음 확인.
  `Army.initialize`는 기존 시나리오 병력의 장비를 보존하며, 군수 계획은 부족분에만 장비를 지급한다.
- cutscene: 수정 전/후 모두 **83개 검사 중 1개 실패**, exit 1.
- 원본/수정 후 로그의 SHA-256과 테스트별 결과는 [검증 기록](evidence/godot-warning-cleanup.json)에 보관.

## 저장본에 의존하는 검증 2건

프로젝트 전체(숨김/무시 파일 포함), 사용자 Godot 저장 폴더와 Downloads에서 확인했다.
과거 `supply-expansion-results/{silla,baekje}-60months.json`,
`noble-power-results/normal-concentrated.json`, `playability-results/politics-B-12months.json`,
`supply-expansion-before/{silla,baekje}-initial.json`은 없었다.
따라서 **과거 원본 저장본을 그대로 사용하는 재검증은 두 건 모두 미검증**이다.

현재 존재하는 정상 30개월 저장 `noble-results/audit-silla.json`과 새 시나리오 시작에서
기존 테스트의 정상 명령 경로로 대체 저장본을 재생성해 기능 검증을 추가로 완료했다.
과거 원본으로 표시하거나 기존 경로를 덮어쓰지 않았다.
모든 대체 저장본은 `.godot/warning-fixtures/`에 구분해 보관하고 해시를 검증 기록에 남겼다.

1. `campaign_playability_audit_test.gd::political_branches`를 기존 `audit-silla.json`에서 실행:
   정상 건설/연구/이동/인사 명령과 12개월 분기, 59개 검사 통과.
2. `noble_power_normal_test.gd`를 재생성한 B 분기에서 실행:
   기존 병력 이동·합병 2개월 후 군사 집단 영향력 50.2700619, `normal-concentrated.json` 저장.
3. 632년 신라/백제 새 캠페인 각각 seed `63220260915`로 시작.
   `military_supply_expansion_audit.gd`의 정상 월 진행을 각각 60개월 실행해 결과 저장.
   과거 `military_supply_expansion_before.gd`의 보존 스냅샷 제한은 우회하지 않았다.

| 테스트 | 대체 저장본 실행 | 과거 원본 실행 |
| --- | --- | --- |
| `military_supply_expansion_test.gd` | **69개 검사 통과**, exit 0 | 원본 부재, 미검증(exit 77) |
| `noble_power_lifecycle_test.gd` | **25개 검사 통과**, exit 0 | 원본 부재, 미검증(exit 77) |

두 테스트에 `--fixture-root`와 저장본 존재 사전 검사를 추가했다.
저장본이 없으면 잘못된 기본 캠페인으로 검사를 진행하는 대신 정확한 경로와 미검증 상태를 출력한다.
기존 기본 저장 경로와 실제 게임 로직은 유지된다.

## 실행 및 증거

```powershell
& $Godot --headless --path . --script res://tests/warning_regression_test.gd
# 실제 렌더링과 화면 저장
& $Godot --path . --script res://tests/warning_regression_test.gd
```

기준 결과 JSON이 있으면 회귀 테스트가 수정 전/후 결과도 비교한다.
검증 산출물은 Git에서 제외되는 `.godot/`에 보관한다.

- `warnings-before.json`, `warnings-after.json`, `warnings-including-addons.json`: 정적 진단.
- `warnings-calculations-before.json`, `warnings-calculations-after.json`: 계산 결과.
- `warnings-campaign-663.png`: 실제 캠페인 화면.
- `warnings-strategy-differential.log`: 원본 전략 계산 비교.
- `warning-checks/`: 기존 테스트 및 원본 재현 로그. 동원 재검증은 `mobilization-retry.log`.

### 마무리 재실행 명령

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_lowpoly_terrain.ps1 -Godot $Godot
& $Godot --headless --path . --script res://tests/military_supply_expansion_test.gd -- --fixture-root=res://.godot/warning-fixtures/
& $Godot --headless --path . --script res://tests/noble_power_lifecycle_test.gd -- --fixture-root=res://.godot/warning-fixtures/
```

기존 실패의 전체 로그는 `.godot/warning-checks/baseline-mobilization-ai.log`,
`baseline-cutscene.log`, `mobilization-ai-final.log`, `cutscene.log`에 있다.
원본 저장본은 대체 저장본의 재생성만으로 복구됐다고 판단하지 않는다.
