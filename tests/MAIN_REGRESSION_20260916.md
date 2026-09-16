# main 테스트 수정 및 기본 저장 복원 검증 · 2026-09-16

기존 main(시작 HEAD 8226e9d)에서 진행했다. 시작 시 작업 트리는 깨끗했고,
상위 경로를 포함해 적용할 AGENTS.md는 발견되지 않았다. 게임 코드·비용·지급 규칙은 변경하지 않았다.

## 수정

- `mobilization_ai_test.gd`: 공통 조달·기존 철 수송·지역 철 공급 3건에 보병 장비 100명분 부족 조건을 설정했다. AI 계획의 부대 분할 이후 부족량을 확정한다. 실제 수송 처리 → 유료 생산 → 재고 1묶음 확보 → `Army.ai`가 대상 부대에 100명분 지급/재고 1 소모를 단계별 검증한다. 이후 실제 월 진행과 같은 달 AI 재호출도 검사한다. 시설·연구·자금·부대 조건은 통제 fixture이며 정상 무개입 플레이로 간주하지 않는다.
- 기존 생산 비용은 공통 28, 철 수송 후 제작 10, 지역 공급/제작 16으로 유지했다. 장비가 충분한 부대는 창고에 3묶음이 있어도 지급하지 않는 검사도 추가했다.
- `cutscene_test.gd`: 고정 개수 7 대신 필수 이벤트 ID 8개를 각각 확인한다. `noble_personnel_demand` 포함. 기존 재생·잠금·저장·중복 효과 검사는 유지했다.
- `main_host_save_test.gd`: 고유 시험 슬롯 생성/별도 프로세스 복원과 기존 JSON 슬롯 SHA256 보존을 검사하는 스크립트를 추가했다.

## 실제 실행 결과

Godot 4.7.2 stable Windows, headless. APPDATA를 변경하지 않았다.
초기 제한 환경 실행은 로그/결과 쓰기를 실패하여 완료로 세지 않았고, 승인된 실행 권한으로 재실행했다.

| 검사 | 결과 |
| --- | --- |
| AI 장비 지급 | 22 checks, 0 failures, exit 0 |
| 기존 동원·생산·저장 회귀 | 417 checks, 0 failures, exit 0 |
| 컷씬 | 90 checks, 0 failures, exit 0 |
| 기본 경로 저장 | 4 checks, 0 failures, exit 0 |
| 새 프로세스 복원 | 12 checks, 0 failures, exit 0 |

실제 기본 경로: `C:/Users/지용훈/AppData/Roaming/Godot/app_userdata/Samhan660/`

시험 슬롯: `main_office_probe_1789517428_25960.json` (검증용으로 보존).
저장 PID 25960이 exit 0으로 종료된 후 새 PID 26268에서 불러왔다.
632년 2월 백제, 금 1634와 날짜·세력·전 도시 상태·국가별 자금·도시 재고·부대 명부·이동 명령이 저장 직전과 같았다.
유료 1000명 모집과 월 진행 후 저장했으며, 불러오기 전 다른 시나리오/세력 상태와 다름도 확인했다.

기존 `campaign_save_35_regions_v1.json`의 SHA256은 저장/복원 전후
`3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3`으로 동일했다.
사용자 편집기나 기존 게임 프로세스는 종료하지 않고 이 검증에서 실행한 프로세스만 종료했다.

로그: `.godot/main-mobilization-ai.log`, `main-mobilization.log`, `main-cutscene.log`, `main-host-write.log`, `main-host-restore.log`.
상태/경로/프로세스/기존 슬롯 해시 증거: `.godot/main-host-save.json`.
재현은 Godot `--headless --path . --script tests/main_host_save_test.gd`로 저장 후,
종료를 기다리고 같은 명령 끝에 `-- restore`를 붙여 별도 실행한다. 두 실행 모두 기본 APPDATA를 사용해야 한다.

## 별도 미검증 항목

과거 원본 저장본이 필요한 `military_supply_expansion_test.gd` 및
`noble_power_lifecycle_test.gd`의 원본 재검증 2건은 계속 미검증이다.
이번 신규 슬롯 복원은 과거 저장본 재검증을 대체하지 않는다.
이전 대체 fixture 결과는 `GODOT_WARNING_CLEANUP.md` 기록과 구분해 유지한다.
이번 저장 검증은 실제 엔진의 headless 저장/재실행 검증이며 사무실 GUI 수동 조작 검증은 수행하지 않았다.
