# 사용자 플레이 검수본 v1

2026-09-15. 현재 `feature/project-foundation-v1` 미커밋 통합본을 사용했다. HEAD는 `419e90a50529890d1743b417d68718609ccb7945`이며 HEAD만으로 이번 검수본을 재현할 수 없다.

## 실행 파일과 프로필

작업 루트는 `E:/OneDrive - GRTech/문서/samhan-660-2026-09-02-00-00-33-home/Samhan660-faction-rulers-v1/.worktrees/project-foundation-v1`이다. 이하 상대 경로는 이 루트 기준이다.

- 더블클릭 실행기: [PLAYTEST_V1.cmd](../PLAYTEST_V1.cmd)
- 짧은 안내: [PLAYTEST_README_KO.txt](../PLAYTEST_README_KO.txt)
- 검수 사용자 저장의 정확한 경로: `E:/OneDrive - GRTech/문서/samhan-660-2026-09-02-00-00-33-home/Samhan660-faction-rulers-v1/.worktrees/project-foundation-v1/.godot/player-playtest-profile/Godot/app_userdata/Samhan660/`
- 실행 로그: 같은 worktree의 `.godot/player-playtest-profile/launch-*.log`
- Godot: `C:/Users/지용훈/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`, 실제 버전 `4.7.2.stable.official.ed1daf0bf`.

실행기는 자신의 디렉터리로 이동하고 project.godot 및 통합본 스크립트와 Godot 파일 존재 여부를 확인한다. 모든 경로 인수는 인용했다. 다른 설치 위치는 사용자가 `PLAYTEST_GODOT_PATH.txt`에 경로 한 줄을 지정할 수 있다. `setlocal` 안에서 자식 프로세스의 APPDATA만 지정하며 전역 환경변수·레지스트리·권한은 수정하지 않는다. 일반 실행은 기존 프로젝트 메인 화면을 사용한다. 샘플 복사는 이번 준비 단계에서만 수행했으며 실행기에는 저장 복사·삭제·초기화 명령이 없다.

## 검증 상태의 구분

| 항목 | 상태 |
|---|---|
| 632년 신라 정상 자동 플레이106개월 통일 | 선행 검증 성공 유지. 이번에는 불필요하게 재실행하지 않음 |
| 정상 마지막 전투·승리 GUI | 선행 검증 성공 유지 |
| 독립 프로필 저장·재시작·복원 | 선행 검증 성공. 이번 전달용 별도 프로필도 확인 |
| 호스트 기본 사용자 저장 경로 | 환경상 미검증 유지. 이번 전용 프로필 성공과 혼동하지 않음 |
| 개발 도구로 첫12개월 화면 조작 | 성공 · 최종 UI 실행 실패0, 내부 게임 명령 직접 호출 없음 |
| 사용자의 직접 재미·난이도·이해도 평가 | 전달 이후 확인할 항목 |

적용 위치/상위·tests의 AGENTS.md는 발견되지 않았다. NORMAL_CAMPAIGN_COMPLETION, MILITARY_SUPPLY_EXPANSION, NOBLE_POWER_CONSTRAINTS 보고서와 관련 구현을 읽었다. 시작 사본 `.godot/player-playtest-baseline-20260915-175056/`에 루트 GDScript, status와 HEAD를 보관했다. 기존 미커밋 변경을 HEAD로 되돌리지 않았다. stage/commit/push/merge/reset/clean을 실행하지 않았고 `_handoff`를 열거나 수정하지 않았다. project.godot/addons/승인 선택 화면/기존 이미지도 보존했다.

## 정상 샘플 저장

[원본/사본 SHA256 및 정확한 경로](../.godot/player-playtest-results/sample-manifest.json). 세 사본의 바이트 해시가 정상 완주 원본과 같다. 경계 시험 저장은 포함하지 않았다.

| 검수 프로필 파일 | 원본 | 날짜·도시·금 | 실제 상태·추천 행동 |
|---|---|---|---|
| 01_632-02_start.json | normal-completion-final/month-001.json |632년2월 /16도시 /2,391| 초반 정상 병력 이동2건. 플레이어 진행 중 산업 업무 없음. 장수/태수 확인, 개발 접수, 군수 연구/시설 조건 확인 |
| 02_635-02_front.json | normal-completion-final/month-037.json |635년2월 /28도시 /90,866| 책성→국내성795명 지원이1개월 남음. 이동 도착 확인, 출발지 방어·군량 견적 확인, 기존 장비 보유군을 전선에 배치 |
| 03_638-02_unification.json | normal-completion-final/month-073.json |638년2월 /34도시 /203,949| 적 비열홀42,046명, 접수된 병력 이동 없음. 여러 아군 도시의 병력을 집결하고 보급 경로 확인 후 공격 판단 |

목표는 모두 기존 고정35도시 직접 점유다. 세 저장은 자원·날짜·병력·소유권을 편집하지 않았다. 플레이어가 초기 장비 보유군 중심으로 완주한 출처여서 ‘플레이어 군수 사업이 진행 중인 튜토리얼’로 소개하지 않는다. 새 게임에서 직접 건설/연구를 접수하거나 점령지의 실제 시설을 확인해야 한다. 초기군의 기본 장비와 신규 지급을 구분한다.

타이틀 **불러오기** 및 캠페인 **Menu → 저장 파일 선택**에서 실제 파일명을 입력/선택하여 세 사본의 날짜를 확인했다. 샘플 저장을 불러온 뒤 상단 **저장**은 별도 기본 진행 슬롯 `campaign_save_35_regions_v1.json`에 쓰므로 샘플을 덮어쓰지 않는다.

## 실제 UI 조작과 발견한 문제

`tests/player_playtest_ui.gd`는 실행기의 `--audit` 개발 검수 옵션으로 시작한다. 동일 실행기·Godot·worktree·독립 프로필을 사용하고 메인 타이틀부터 화면을 조작한다. 게임 명령 함수를 직접 호출하거나 인물/자원/날짜를 주입하지 않는다. 버튼 클릭, 실제 팝업의 방향키/Enter, 파일명 키 입력, 지도 도시 클릭으로 진행했다. 상태 읽기는 확인·기록용이다. 이는 사람이 마우스로12개월 플레이한 평가가 아니라 개발 도구의 실제 UI 입력 검수다.

실제 흐름:

1. 타이틀 불러오기에서 초반 정상 사본을 열어632년2월 확인.
2. Menu → 세력 선택으로 → 확인 → 기존 시작 버튼으로632년 신라 역사·보통 새 게임.
3. Menu → 캠페인 목표·전쟁 준비에서 현재16/35도시·목표 확인.
4. Menu → 귀족·군권·인사정치에서 금성 태수의 김춘추→선덕여왕 변경 견적·능력·충성/협력 변화 확인 후 실행. 군주와 태수 자동 동시 부여가 아니라 명시적으로 선택한 인사다.
5. 금성 지도 클릭 → 상세에서 인물/도시 확인, 내정에서 같은 도시 담당 개발 접수. 즉시 금100과 다음 월 성과를 확인.
6. 첫 월 후 생산 → 건설·연구 업무 관리: 제철시설, 철검 제작 연구를 서로 다른 실제 담당자에게 접수. 기본 제련은 이미 최고 단계여서 재접수하지 않음.
7. 매달 상단 턴 종료와 실제 사건 창 버튼으로 처리.7개월 후 군기감 착수.11개월 후 철 조달·정련(공통) 명령. 첫12개월 안에 끝나도록 계수를 변경하지 않음.
8. 징병 → 부대 편성·장비 지급·훈련, 이동 → 육상 군량·철·칼 수송으로 메뉴와 제한 안내 확인.
9. 상단 저장/불러오기와 Menu 파일 선택으로 계속 진행 및 중후반 사본 확인.

확인·수정 사항:

| 문제·근거 | 수정·검증 |
|---|---|
| 실제 초기 타이틀에서 샘플3개가 존재해도 불러오기 비활성. 기존 타이틀은 구형9지역 고정 파일만 검사 | 기존 불러오기 버튼에 FileDialog 연결, 선택 경로를 기존 CampaignLoadBridge로 전달. 기존 메뉴로 세 샘플과 새 진행 저장 복원 |
| 저장 파일 선택과 귀족 인계 메뉴가ID8, 결과와 AI계획 메뉴가ID7을 공유(코드 확인) | 파일 선택9, 결과10으로 분리. 실제 파일 선택 시 인계 창이 함께 열리지 않고 입력 복원 |
| 공통 철 조달이 생산 품목 이름 분기에서 칼 제작으로 표시(코드 확인) | 기존 recipe.name을 사용해 철 공급/철로 칼 제작/철 조달·정련(공통) 구분. 실제 품목 선택·견적 캡처 |
| 파일 창 썸네일 표시에서 긴 샘플 이름이 잘림 | 목록 표시로 바꾸고 타이틀 불러오기 제목/버튼을 명확히 표시 |

UI 검수 도구 자체의 시행착오도 구분한다. 최초에는 파일명 입력 후 FileDialog의 비활성 확인 버튼을 눌러 열리지 않았으며 입력 칸 Enter 경로로 수정했다. 긴 팝업이 열리지 않은 경우 키보드 Space로 실제 팝업을 연 뒤 방향키/Enter로 선택했다. 기본 저장 파일명과 태수 원장 키를 잘못 가정했던 검사도 공통 SAVE_PATH/get_governor_id 조회로 바로잡았다. 이 실패를 게임 데이터 오류나 성공 검사로 감추지 않았다.

기본 제련의 ‘이미 최고 단계’는 정상 안내다. 비용을 내고 같은 연구를 반복할 필요가 없으며 철검 제작 연구로 진행했다. 담당자를 고르지 못할 때는 현지 명부/기존 업무가 원인인지 견적에 표시한다. 창고 칼 묶음과 지급 인원분, 국고와 선택 도시 군량을 각 화면에서 확인했다. 전제 조건을 갖춘 작업의 예정 완료를 기다린 시간과 UI 입력 실패 때문에 진전하지 못한 시간을 구분했다.

## 결과와 재현 자료

- [UI 행동·월별 자원/업무 로그](../.godot/player-playtest-results/ui-actions.json)
- [샘플 목록](../.godot/player-playtest-results/sample-picker.png)
- [목표](../.godot/player-playtest-results/new-objectives.png)
- [태수 변경 견적](../.godot/player-playtest-results/governor-preview.png), [결과](../.godot/player-playtest-results/governor-result.png)
- [내정 견적](../.godot/player-playtest-results/domestic-quote.png)
- [제철시설 견적](../.godot/player-playtest-results/quote-smelter.png), [철검 연구](../.godot/player-playtest-results/quote-swordsmithing.png)
- [공통 철 조달](../.godot/player-playtest-results/production-common-iron.png)
- [실제 사건 선택](../.godot/player-playtest-results/event-choice-632-9.png)
- [부대 화면](../.godot/player-playtest-results/army-equipment-training-menu.png), [수송 화면](../.godot/player-playtest-results/cargo-transport-menu.png)

이번 UI 변경은 저장 수량/군수 처리/정치 계수를 바꾸지 않는다. `campaign_ending_test`56, `noble_power_lifecycle_test`25, `industry_assignment_test`155 확인은 각각 실패0으로 이번에 다시 실행했다. 이 검사는 별도 회귀 프로필에서 수행했고 전달용 사용자 진행을 덮어쓰지 않았다.106개월 통일을 다시 실행하지 않았다.

## 남은 한계

- 이 실행기는 Godot 설치형 검수본이다. Godot가 없는 PC용 독립 배포 실행 파일은 아니다.
- 기본 호스트 경로 `C:/Users/지용훈/AppData/Roaming/Godot/app_userdata/Samhan660/`의 쓰기/복원은 환경상 미검증을 유지한다. 성공한 것은 명시된 검수 프로필이다.
- 상단 저장은 현재 기본 슬롯 하나를 갱신한다. 샘플 사본은 보존되지만 서로 다른 직접 플레이를 여러 슬롯으로 관리하는 일반 저장 UI 개선은 후속이다.
- 긴 정치/군수 설명은 스크롤이 필요하다. 조달·훈련·인계의 장래 기간은 현재 조건 유지 가정이며 전쟁/담당자 상실로 달라질 수 있다.
- 초기632신라의 실제 인사 변경은 권력 집중 임계 미만이었다. 강제 인계 상황을 만들려고 초기군·권력·인구를 편집하지 않았다. 보상/기한/강제의 기존 견적·기간·차질 규칙은 선행 정치 검증을 재사용한다.
- 이번12개월에 실제 도달하지 않은 완성 장비 지급·전쟁 승리까지 새 게임에서 완료했다고 주장하지 않는다. 기존 정상 중간 저장과 선행 완주 기록으로 구분해 제공한다.
- 실제 사용자 플레이 평가는 미실시다. 실행/명령/복원 성공이 재미·명확성·밸런스의 사용자 승인을 뜻하지 않는다.

제품 수정은 `title_screen.gd`, `campaign_main.gd`, `production_overlay.gd`이다. 실행기/안내와 `tests/player_playtest_{base,inspect,ui,restore}.gd`, 본 보고서는 이번 신규 파일이다. `.godot`의 캐시·프로필·저장·캡처는 직접 구현 파일과 구분한다. 검수용 최초 샘플 사본은 명시적으로 준비했으며 엔진 자동 생성물로 표현하지 않는다.

## 첫12개월 실제 수치

아래는 최종 UI 실행의 각 월 처리 직후 금성과 국가 국고이다. 해당 월 처리 뒤 접수한 건설/연구 비용은 다음 행의 국고에 반영된다.

| 경과월 | 날짜 | 국가 금 | 금성 군량 | 금성 농업 |
|---|---|---:|---:|---:|
| 1 | 632.2 | 2441 | 4987 | 79 |
| 2 | 632.3 | 3586 | 4683 | 79 |
| 3 | 632.4 | 5215 | 4381 | 79 |
| 4 | 632.5 | 6887 | 4080 | 79 |
| 5 | 632.6 | 8602 | 3781 | 79 |
| 6 | 632.7 | 10343 | 3483 | 79 |
| 7 | 632.8 | 12097 | 3187 | 79 |
| 8 | 632.9 | 13535 | 6416 | 79 |
| 9 | 632.10 | 15290 | 7577 | 79 |
| 10 | 632.11 | 17048 | 7224 | 79 |
| 11 | 632.12 | 18806 | 6875 | 79 |
| 12 | 633.1 | 20410 | 6562 | 79 |

최종633년1월 국고 등식은 `1,000 + 세입20,288 - 지출878 = 20,410`이다. 지출은 개발100, 제철시설240, 철검 제작 연구200, 군기감320, 공통 철 조달18이다. 농업은74→79, 제철시설은632년7월 완료(접수632년2월 이후5회 월 진행), 철검 제작 연구는632년5월 완료(3회), 군기감은633년1월 완료(접수632년8월 이후5회)했다.633년1월 금성 창고에는 실제 조달 철2, 칼0이 있다. 칼 제작 명령은 아직 켜지 않았으므로 무기를 만들어 지급했다고 집계하지 않는다. 첫12개월의 장비·훈련·수송은 해당 메뉴와 제한 안내 접근까지 확인했다.

개발은 군주에게 자동 태수직을 준 것이 아니라 UI에서 명시적으로 임명한 선덕여왕이 겸임했고, 다음 월에 완료·업무 해제된 후 제철시설 담당으로 배정했다. 철검 연구는 김춘추가 맡아 중복 업무 배정을 피했다. 월별 군량 변화에는 기존 주둔 소비·수확·창고 처리가 포함되며 수확기의 증가를 무료 군량 생성으로 해석하지 않는다.

## 실행·재시작 최종 결과

- 실행기의 `--audit` 경로: 최종 UI 검수 실패0. 실제 메뉴로 정상 사본3개 로드, 정상 새 게임12개월, 저장/불러오기 수행. [최종 UI 로그](../.godot/player-playtest-results/final-ui.log).
- 해당 프로세스 종료 후 같은 실행기의 `--restore`: 실패0.633년1월 진행 저장 복원, 두 번 더 UI 불러오기 시 전체 strategy_state 동일, 월 진행 가능. 정상 완주 종료 저장도 실제 파일 선택 창으로 로드한 뒤 새 캠페인/월 진행 복구. [복원 결과](../.godot/player-playtest-results/restore-result.json), [복원 로그](../.godot/player-playtest-results/final-restore.log), [복원 화면](../.godot/player-playtest-results/restart-restored.png), [종료 로드](../.godot/player-playtest-results/ending-load.png), [새 게임 복구](../.godot/player-playtest-results/restart-new-game.png).
- 새 캠페인을 시작했지만 저장하지 않았을 때 기존 진행 파일의 원문이 그대로 남았다. 실행할 때마다 샘플/진행을 초기화하지 않는다.
- 개발 옵션 없이 `PLAYTEST_V1.cmd`도 직접 실행했다. 동일 Godot 실행 로그가 생성되고 기존 진행 파일 SHA256이 유지됐다. [일반 실행 보존 결과](../.godot/player-playtest-results/plain-launch.json). WMI의 프로세스 명령줄 조회는 환경에서 거부돼 그 결과를 증거로 사용하지 않았다. 숨긴 콘솔로 처음 실행한 Windows 캡처는 검은 보조 창이어서 버렸다. 이후 일반 창 실행으로 `Samhan660 (DEBUG)` 타이틀을 직접 확인·캡처했고 창 닫기로 종료했다. [개발 옵션 없는 실제 타이틀](../.godot/player-playtest-results/plain-visible-title.png), [창 확인 기록](../.godot/player-playtest-results/plain-visible.json).
- 샘플3개의 준비 시점/최종 SHA256 동일 확인. 신규 직접 플레이 파일은 `campaign_save_35_regions_v1.json`이며 정상 완주 원본은 건드리지 않았다.

[검수 코드 SHA256](../.godot/player-playtest-results/code-manifest.json)으로 현재 미커밋 코드 상태를 식별한다. 재현은 작업 루트에서 `PLAYTEST_V1.cmd --audit`, 이 프로세스 종료 후 `PLAYTEST_V1.cmd --restore`이다. 이 두 옵션은 개발 검수용이며 새 게임/저장을 조작하므로 실제 사용자 진행을 쌓은 뒤 그대로 재실행하지 않는다. 사용자는 인수 없는 실행기를 사용한다.
