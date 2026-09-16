# 642년 신라 귀족·군권 정치 확장 v1

## 기준 보존 및 변경 범위

2026-09-16, 기존 `main`에서 진행했다. 회귀 관련 4개 파일을 검토하고
`80a4cac` (`test: fix equipment and cutscene regressions and verify host saves`)로 커밋했다.
사용자가 원격 목적지를 명시 승인한 뒤 `https://github.com/tonyji73-lang/Samhan660`의
`main`에 일반 push 완료(8226e9d → 80a4cac). force push/브랜치 전환은 하지 않았다.
이후 이 문서에 기록한 642 확장은 작업 트리에 남겨 검토할 수 있게 했다.

| 파일 | 변경 |
| --- | --- |
| `noble_politics.gd` | 시나리오별 집단 설정으로 분리, `goguryeo_coup_642` 새 캠페인의 신라 정치 활성화 |
| `noble_politics_overlay.gd` | 게임용 집단이 역사적으로 확정된 파벌이 아니라는 안내 명시 |
| `tests/noble_politics_test.gd` | 미지원 시나리오 검사에서 이제 지원하는 642 제외 |
| `tests/silla_642_politics_playtest.gd` | 정상 인사·유료 산업·12턴, GUI 입력/캡처, 별도 기본 경로 저장 |
| `tests/silla_642_politics_test.gd` | 632/642 명부 보존, 구형 스키마, 협의/요구/생산 보정 통제 검증 |
| `tests/silla_642_politics_restart.gd` | 별도 프로세스 전체 상태 복원 및 기한 도래 협의 완료 |

`main_host_save_test.gd.uid`는 Godot가 생성한 메타데이터이며 기존 회귀 스크립트 내용을 변경하지 않았다.
자산·시나리오 명부·게임 비용·훈련·전투 공식·사용자 저장 슬롯은 수정하지 않았다.
상위 경로를 포함해 적용할 AGENTS.md는 없었으며 기존 프로젝트의 원본/저장 보존 방침을 유지했다.

## 642년 게임용 집단

`data/officers_v1.json`의 기존 642 명부와 `OfficerRegistry.new_game()` 결과를 확인했다.
아래 6명은 모두 기존 데이터상 생존·활동 중이며 신라 소속이다.
이 표는 **게임 초기 상태 확인**이며 실제 역사상의 파벌·직책·정확한 재임 도시를 확정하는 자료가 아니다.

| 집단 | 인물 | 기존 위치 | 기존 군주/태수 |
| --- | --- | --- | --- |
| 왕실 직속 | 선덕여왕(대표) | 금성 | 신라 군주, 태수 아님 |
| 문치 귀족 연합 | 김춘추(대표) | 금성 | 금성 태수 |
| 문치 귀족 연합 | 알천 | 국원소경 | 태수 아님 |
| 군사 귀족 연합 | 김유신(대표) | 금성 | 태수 아님 |
| 군사 귀족 연합 | 김흠순 | 국원소경 | 국원소경 태수 |
| 군사 귀족 연합 | 품일 | 사벌주 | 사벌주 태수 |

기존 ID·생존·활동·소속·위치·능력·가족·업무·군주/태수 배치를 그대로 유지한다.
초기 지휘관을 새로 임명하거나 미배정 병력을 왕실 기반으로 계산하지 않는다.
632년의 5인 집단은 변경하지 않았다. 660/663/670에는 새 초기화를 적용하지 않는다.

신라 정치 상태가 생기면 기존 태수·지휘관 인사, 충성/협력 반응, 산업 담당자의 협력 보정,
인사 요구, 군권 인계 협의 및 정치 화면이 공통 경로로 작동한다.
기존 `RULES`와 저장 형식은 그대로이며 642 전용 비용/훈련/전투 공식은 없다.
초기화 호출은 기존 새 캠페인 경로에만 있다. 정치 자료 없는 저장을 로드해 새 집단을 추가하지 않는다.

## 실제 실행

Godot `4.7.2.stable.official.ed1daf0bf`, Windows.
GUI는 D3D12 Forward+ / RTX 4060 Laptop GPU이며 headless 결과와 구분한다.

| 검증 | 최종 결과 |
| --- | --- |
| 642 정상 명령 headless | 29 checks, 0 failures, exit 0 |
| 642 정상 명령 + GUI | 34 checks, 0 failures, exit 0 |
| 632/642 명부·저장·통제 경계 | 170 checks, 0 failures, exit 0 |
| 프로세스 재시작 복원 | 17 checks, 0 failures, exit 0 |
| 기존 632 귀족 정치 회귀 | 87 checks, 0 failures, exit 0 |
| 기존 정치 보충 회귀 | 14 checks, 0 failures, exit 0 |
| 기존 군권 제약 및 지원 조합 회귀 | 67 checks, 0 failures, exit 0 |

### 정상 12턴

642년 7월 신라·역사·보통에서 seed 64220260916로 시작해 643년 7월까지 진행했다.
인물·능력·돈·시설·기술·영향력·날짜를 주입하지 않았다. AI도 기존 월 처리에 참여했다.
정치 화면에서 김유신을 금성 태수 및 금성 부대 지휘관으로 임명했다.
GUI 실행에서는 실제 버튼 좌표에 마우스 입력을 보내 결과와 지도 잠금 해제를 확인했다.
산업 명령과 월 진행은 공통 게임 명령 API로 수행했으며 사람이 수동 플레이한 결과로 표현하지 않는다.

선덕여왕이 제철시설(금240)과 군기감(금320)을 순서대로 건설하고 김춘추가 도검 제작 연구(금200)를 완료했다.
기초 제철은 기존 642 초기 연구를 사용했다. 이후 김춘추를 생산 담당자로 배정하고 공통 철 조달/칼 제작을 예약했다.
마지막 2개월에 칼 2묶음을 생산했다. 최종 금17306, 금성 철0·칼2.
문치 집단 협력44, 담당자 월 작업량147, 기존 정치 보정 ×0.988이 생산 화면에 표시됐다.

자연 발생한 선택 사건은 다음 두 건이다.

- 642년 8월: `noble_personnel_demand` 1건, 김흠순의 인사 요구를 거절. 군사 집단 협력54→48 및 김흠순 충성50→44.
- 642년 9월: `domestic_crop_failure` 1건, 기존 세금 유지 선택.

12턴 종료 군사 집단 영향력은 약23.33으로, 이 정상 진행에서 군권 인계 협의가 발생했다고 주장하지 않는다.

### 별도 조건 검증

기존 신라 부대를 금성으로 모으고 지휘관/태수만 지정한 **통제 fixture**에서 군권 집중을 만들었다.
보상·기한 보장·강제 회수, 중복 선택 차단, 강제 회수 작업량0.8, 제안/대기/완료 상태 저장을 검증했다.
별도 요구 fixture의 포상 비용은 기존 금100이며 중복 포상이 차단됐다.
정상 플레이 저장의 협력을 0/50/100으로 바꾼 비교에서는 작업량 증가와 배치당 공통 조달/제작 금28 전액 지출,
같은 월 생산 재호출의 무효를 확인했다. 이 조건 변경은 정상 12턴 기록에 섞지 않았다.

초기 검증 실패는 fixture의 태수 표시 동기화 누락과 협의 기한을 1개월로 가정한 테스트에 있었다.
표시를 기존 동기화 함수로 맞추고 실제 견적의 3개월 기한을 따라 검사했다. 게임 저장·기한 코드를 변경하지 않았다.

### 저장 및 재시작

APPDATA를 변경하지 않은 실제 기본 경로:
`C:/Users/지용훈/AppData/Roaming/Godot/app_userdata/Samhan660/`

정상 GUI 저장: `silla_642_normal_1789518128_29252.json`.
GUI PID29252와 fixture PID18336이 종료된 후 PID32496에서 새 엔진을 시작했다.
정상 12턴 저장과 fixture 11개(632/642 초기, 정치 없는 구형 스키마, 협의 제안/대기/완료, 미처리 요구)의
날짜·세력·자금·전 도시·전체 strategy_state·이동 명령이 일치했다.
대기 중 협의는 복원 후 정상 월 명령으로 3개월 진행해 예정 월에 완료됐고 그 전 2개월에는 권한이 유지됐다.

기존 사용자 `campaign_save_35_regions_v1.json`의 최종 SHA256은 이전과 동일한
`3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3`이었다.
모든 신규 저장은 고유 시험 슬롯이며 시험 슬롯과 실행 증거를 남겼다.

## 증거와 재현

`.godot/silla-642-politics/normal.json`, `fixtures.json`, `restart.json`에 상태·슬롯·PID·검사를 기록했다.
로그는 `.godot/silla-642-{normal,gui,fixtures,restart,regression-politics,regression-supplement,regression-power}.log`.
GUI 캡처 5장 중 초기 정치·12턴 정치·12턴 생산 화면을 직접 열어 집단/인물/안내/생산 보정이 표시되는 것을 확인했다.

- [초기 정치](../.godot/silla-642-politics/initial-politics.png)
- [태수 임명](../.godot/silla-642-politics/appointed-governor.png)
- [지휘관 임명](../.godot/silla-642-politics/appointed-commander.png)
- [12턴 정치](../.godot/silla-642-politics/month-12-politics.png)
- [12턴 생산](../.godot/silla-642-politics/month-12-production.png)

Godot `--path . --script tests/silla_642_politics_playtest.gd` 실행/종료 후,
`--headless --path . --script tests/silla_642_politics_test.gd`, 이어서
`--headless --path . --script tests/silla_642_politics_restart.gd` 순서로 별도 프로세스 실행한다.
각 실행은 고유 저장을 만들며 앞 실행이 실패한 결과로 다음 검증을 완료 처리해서는 안 된다.

## 남은 범위

과거 원본이 없는 `military_supply_expansion_test.gd`와 `noble_power_lifecycle_test.gd`의 원본 재검증 2건은 계속 미검증이다.
이번 정치 없는 저장 검사는 명시적으로 만든 구형 스키마 fixture이며 회수하지 못한 과거 원본을 대체했다고 표시하지 않는다.
642 정상 캠페인 통일 완주나 12턴 이후 장기 정치 균형, 다른 시나리오/국가 정치 집단 확대는 이번 범위가 아니다.
