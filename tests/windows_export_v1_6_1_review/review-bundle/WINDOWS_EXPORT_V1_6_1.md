# V1.6.1 Windows 실행본 갱신·검수

2026-09-30. V1.6 군수·편성·훈련 UI를 반영한 Windows x86_64 배포본이다. **최종 배포본 132개 검사, 실패 0개**. 실행할 파일은 **`Samhan660.exe`**다. 기존 V1.5 ZIP과 저장 파일을 보존했다. 다른 Windows PC 검수는 미검증이다.

## 기준과 변경 범위

- worktree: `E:/OneDrive - GRTech/문서/samhan-660-2026-09-02-00-00-33-home/Samhan660-faction-rulers-v1/.worktrees/project-foundation-v1`
- 실제 브랜치 `main`, HEAD `1dbe7e6546dfb05af9a21a54cf0a3cc3ae8956b5`. 경로 이름을 근거로 브랜치를 바꾸지 않았다.
- 프로젝트와 상위 경로에 적용할 AGENTS.md가 없음을 확인했다. `LIVING_CITY_UI_V1_6.md`, `WINDOWS_EXPORT_V1_5.md`, `WINDOWS_DPI_V1_5_1.md`를 읽고 실제 코드·프리셋과 대조했다.
- 기존 미커밋 작업을 기준으로 소스·자산·설정 **1,282개**의 경로/SHA-256을 기록했다. `windows_export_v1_6_1_review/source-start.json`, `source-final.json`과 실행 ZIP의 `SOURCE_SHA256.json` 참조. Git 변경 명령은 실행하지 않았다.
- 이번 게임 변경은 `army_readiness_overlay.gd`의 `unit_summary.text`에서 병력 출력 형식 **`%s` → `%d` 한 곳**이다. JSON 복원 뒤 `1000.0명`으로 보이던 값을 `1000명`으로 표시한다. 병력·저장 데이터·견적·훈련/전투/재정 공식은 변경하지 않았다.
- 그 외 추가물은 이 보고서와 `tests/windows_export_v1_6_1_review/`의 검수 코드·결과·캡처·패키징 자료다. 내정 65:35, 원본 이미지/폰트/manifest/장식 영역·9분할은 기존 V1.6 그대로다.
- 보호 문서 `tests/HOME_HANDOFF_20260923.md`, 기존 V1.5 ZIP, 원래 저장 197개 및 작업 시작 시 존재했던 전체 저장 JSON 204개를 해시로 비교한다. 기존 파일을 삭제하거나 덮어쓰지 않았다.

## 환경과 배포 구성

| 항목 | 값 |
| --- | --- |
| PC / OS | GRT-069, Windows 11 build 10.0.26200 |
| GPU / 렌더러 | NVIDIA GeForce RTX 4060 Laptop GPU / D3D12 Forward+ |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| 템플릿 / 프리셋 | `4.7.2.stable` / `Windows Desktop`, x86_64, release |
| PE machine | `0x8664` |
| 새 외부 빌드 루트 | `%LOCALAPPDATA%/Temp/Samhan660_V1_6_1_20260930` |
| 배포 파일만 있는 실행 폴더 | 위 폴더의 `play-copy/` |

V1.5 때 받은 공식 템플릿 TPZ를 재사용하되 전체 SHA-512를 다시 확인했다:

```text
CA4D71C4D7B81DFC15D1A98BAA07534AA95B03FDDA78A0075B06672E1648D2E5F40980C9ADC28D23E1B92E732EE7BF3461997AA804AF74EC2FCD7A93CCB84079
```

실행 ZIP에는 `Samhan660.exe`, `Samhan660.pck`, `licenses/`, `README_실행안내.txt`, `OTHER_PC_CHECKLIST.md`, `BUILD_INFO.json`, `SOURCE_SHA256.json`, `SHA256SUMS.txt`를 포함한다. 프로젝트·편집기·원본 저장·대용량 로그는 포함하지 않는다. EXE만 옮기지 말고 PCK와 함께 둔다.

PNG 장식, 제목 NanumMyeongjo, 본문 폰트, 동적 JSON 및 필요한 원본 지도 바이트는 기존 export 필터/플러그인을 통해 포함된다. 실행본 내부에서 데이터/라이선스 존재, 원본 지도 SHA-256, 제목 한글 글리프, V1.6 `military_style.gd` 리소스를 검사했다. 외부 `licenses/`에는 Godot MIT·서드파티, 두 폰트 OFL, Phosphor 고지가 있다.

원래 프로젝트의 Godot 편집기 PID 35304를 정상 종료했다. import/export 프로세스 종료 후 `play-copy/Samhan660.exe`를 직접 실행했다. 최종 확인 중 다시 열린 편집기 PID 38924가 발견되어 정상 종료 후 편집기 0개를 확인하고 복원 검증을 다시 실행했다(`editor-closed-final.json`). 반복 실행은 검사 수에 중복 합산하지 않는다. 프로젝트 비교 캡처는 별도 소스 사본의 **게임 실행 모드**에서 얻었다. 다른 PC 검증으로 기록하지 않는다.

검수 PCK에만 opt-in QA autoload를 포함한다. `--qa-v1-6-1` 없는 일반 실행에서는 검사 노드를 즉시 제거한다. 원래 `project.godot`에는 추가하지 않았다. 자동 검사는 실제 렌더링과 Godot 입력 이벤트, 기존 게임 명령/저장 진입 함수를 사용했다. 아래 Windows DPI 입력은 별도로 Win32 마우스/키보드로 수행했다. 전 과정을 사람이 수동 플레이한 결과로 표현하지 않는다.

## 검사 결과와 집계 원칙

최종 **prepare 106개 + reload 26개 = 132개, 실패 0개**다. 이전 V1.6의 **769개**, V1.5의 168개를 이번 검사에 합산하지 않는다. 초기 실패/서식 수정 전 실행도 최종 실행본의 통과 수에 합산하지 않는다.

| 구분 | 검사 범위 |
| --- | --- |
| 최종 prepare | 실제 타이틀→632년 신라, 군수·편성·훈련 720p/1080p, 키보드 선택·취소, 정상 생산·수송·모집·지급·훈련·진행 중 새 슬롯 저장 |
| 최종 reload | 새 프로세스 복원, 반복 로드 중복 방지, 병력 정수 표시, 월 완료와 추가 월 중복 처리 방지 |
| 프로젝트 비교 | 같은 소스 사본의 같은 초기 상태, 별도 34개 검사. 배포본 검사 수와 분리 |
| 네이티브 DPI | Windows 설정 150%, 실제 마우스 탭 선택·Tab·Esc, 물리 화면 캡처. 자동 assertion 수에 합산하지 않음 |

### 화면과 입력

632년 1월 신라·금성, 국고 1000의 동일 조건을 프로젝트/실행본으로 비교했다. 기본 부대는 기존 28,000명 부대이므로 훈련 조건 불충족 상태가 정상 표시된다. 실행 가능한 장비·훈련 견적은 이후 정상 모집한 1,000명 부대에서 따로 확인했다.

| 화면 | 720p 비교 | 1080p 비교 |
| --- | --- | --- |
| 군수 | [프로젝트 / 실행본](windows_export_v1_6_1_review/compare-supply-720.jpg) | [프로젝트 / 실행본](windows_export_v1_6_1_review/compare-supply-1080.jpg) |
| 편성 | [프로젝트 / 실행본](windows_export_v1_6_1_review/compare-formation-720.jpg) | [프로젝트 / 실행본](windows_export_v1_6_1_review/compare-formation-1080.jpg) |
| 훈련 | [프로젝트 / 실행본](windows_export_v1_6_1_review/compare-training-720.jpg) | [프로젝트 / 실행본](windows_export_v1_6_1_review/compare-training-1080.jpg) |

한글·초상·제목 서체·장식·선택 테두리·비활성/확정 버튼을 확인했다. 군수 상세는 내부 스크롤, 군사 실행 정보도 내부 스크롤이며 닫기 버튼은 화면 안에 유지된다. 프로젝트와 실행본의 배치 차이 또는 누락을 발견하지 못했다. 첫 비교 캡처의 프로젝트 측은 병력 서식 수정 전이지만 초기 병력 값은 정수이므로 수정 전후 표시가 동일하다. 복원 후 표시 수정은 별도 캡처/검사로 확인했다.

Godot 입력 이벤트로 후보 Space 선택, 취소 버튼 Space, Tab·Shift+Tab, 장비/지휘관/훈련 Space 확정, Esc 닫기를 검사했다. 선택·취소·장비 미리보기 단계의 캠페인 스냅샷 불변을 확인했다. OS 키보드로도 후보 선택 후 Tab으로 취소 버튼에 접근해 Space를 실행했다.

[장비 지급 전 720p](windows_export_v1_6_1_review/equipment-preview-720.png) · [1080p](windows_export_v1_6_1_review/equipment-preview-1080.png) · [훈련 견적 720p](windows_export_v1_6_1_review/training-quote-720.png) · [1080p](windows_export_v1_6_1_review/training-quote-1080.png)

### 정상 진행·저장·새 프로세스 복원

자원·능력·병력·날짜를 검사용 값으로 주입하지 않았다. 선덕여왕을 기존 이동 명령으로 금관가야에 보내 제련소→군기감→도검 제작 연구를 완료했다. 실제 생산 예약 후 월 진행으로 칼을 생산하고, 기존 수송으로 금성에 10묶음을 보냈다. 담당자도 정상 이동으로 돌아왔다.

금성에서 실제 모집한 보병 1,000명에게 창고 **10→0묶음**, 부대 장비 **0→1,000명분**을 지급했다. 선덕여왕을 지휘관/훈련 담당자로 확정하고 한 달 진행하여 숙련도 **50→61**, 납부 금 50의 진행 중 상태를 기본 `user://` 새 슬롯에 저장했다.

프로세스 종료 후 새 EXE 프로세스의 기존 불러오기 진입으로 복원했다. 날짜·국고·전체 provinces·export_strategy 스냅샷(부대·장비·도시 재고·담당자·훈련 이력/진척 포함)이 정확히 일치했다. 추가 2회 불러오기도 같은 스냅샷으로, 로드만으로 비용/장비가 반복 처리되지 않았다.

다음 달 실제 월 진행으로 숙련도 **70**, 훈련 완료, 누적 납부 **100**을 확인했다. 추가 한 달 후에도 해당 부대와 완료 훈련 작업이 동일해 중복 처리되지 않았다. 월 세입/다른 생산 때문에 전체 국고가 변하는 것은 별도 정상 경제 처리이며 훈련 원장과 구분했다.

[복원 후](windows_export_v1_6_1_review/training-restored-720.png) · [훈련 완료 720p](windows_export_v1_6_1_review/training-complete-720.png) · [1080p](windows_export_v1_6_1_review/training-complete-1080.png)

기본 경로 `%APPDATA%/Godot/app_userdata/Samhan660/`를 사용했다. 우회 저장 경로를 쓰지 않았다. 고유 `windows_export_v1_6_1_<timestamp>.json` 슬롯을 생성 전 존재 여부로 검사했고, 기존 슬롯에는 쓰지 않았다. 초기 검수에서 새로 만든 슬롯도 삭제하지 않았다.

### 실제 Windows 150%

Windows 설정의 디스플레이 배율을 실제 변경했고 `finally`에서 원래 **100%로 복원**했다. 모니터 해상도는 1920×1080, 150% 검수 시 물리 게임 클라이언트는 **1600×901**, 테두리 포함 **1625×960**이다. viewport 변경을 DPI 검증으로 대신하지 않았다.

`GetDpiForWindow`는 기존과 같이 96이다. 실제 Windows 설정 선택값 150%와 물리 창 크기를 별도로 기록했다. 고배율에서 글자/테두리가 부드럽게 확대되는 기존 모습이 있지만, 대표 화면에서 글자 누락·초상 왜곡·장식 겹침·탭 클릭 위치 어긋남을 재현하지 못했다. 탭 클릭→훈련 화면, Tab 포커스, Esc 복귀를 실제 OS 입력으로 확인했다.

[150% 편성](windows_export_v1_6_1_review/dpi150-formation.png) · [150% 훈련](windows_export_v1_6_1_review/dpi150-training.png) · [Tab 포커스](windows_export_v1_6_1_review/dpi150-tab.png)

## 발견한 문제와 수정

1. **게임 표시 문제:** 복원된 JSON 숫자를 `%s`로 표시하여 `1000.0명`이 되었다. 병력 요약 한 곳을 `%d`로 수정했다. 실제 저장값/계산은 동일하며 새 실행본에서 복원 후 정수 표시를 검사했다. 수정 전 훈련 화면과 최종 복원 화면을 비교한다: [수정 전](windows_export_v1_6_1_review/before-troop-format.png), [수정 후](windows_export_v1_6_1_review/training-restored-720.png). 해상도/초기 후보 선택 상태가 다른 캡처이므로 병력 문자열만 비교한다.
2. **검사 코드 문제:** 후보를 선택하면 카드 객체를 교체하는데 초기 검사가 교체 전 객체의 메타데이터를 뒤늦게 읽었다. 선택 전 ID를 보관하도록 수정했다. `initial-prepare.log`를 보존했고 게임 결함/최종 통과로 집계하지 않았다.
3. 최초 sandbox import/export에 Windows 루트 인증서 저장소 경고가 있었다. 최종 export·prepare·reload 로그에서 ERROR/FAIL/WARNING이 없음을 확인했다. 게임 인증서/네트워크 설정은 수정하지 않았다.

## 완료 결과·파일

- 최종 저장 슬롯: `user://windows_export_v1_6_1_1790748723.json`. 저장 시 `unit:160`, 병력/장비 각 1000, 숙련도 61, 선덕여왕 담당, 훈련 납부 50, 국고 42909. 복원 후 정확히 일치했다.
- `final-preservation.json`: 원래 저장 **197/197**, 시작 시 전체 저장 **204/204**, 보호 문서와 V1.5 ZIP **2/2** 해시 동일. `source-final.json`에서 게임/자산 기준의 차이는 병력 서식 한 곳이 있는 파일 하나다.
- 실행 ZIP: `C:/Users/지용훈/Downloads/Samhan660_Windows_V1_6_1_20260930.zip`, **467.53 MiB** (490,242,041 bytes). 12개 항목, 체크섬 목록 외 11개 payload를 ZIP 내부에서 다시 해시 검증했다.
- 실행 ZIP SHA-256: `13B31FDA4229871A244F38DEF88D08EEB1EA5F24F94EA889642D251E652A5FA6`.
- EXE SHA-256: `3D19EE4A764E8BB153BFA7F811F98E0DFB0139C9E0C8BC6B76B93D3ED09185BF`.
- PCK SHA-256: `B85471FC7FDC334FB7F1B14A7B88393E81B282A58973F8935918A1B63856FCFB`. EXE는 동일한 엔진 템플릿이라 V1.5와 같고, 새 코드/자산은 변경된 PCK에 있다.
- 작은 검토 ZIP: `tests/Samhan660_Windows_V1_6_1_Review_20260930.zip`. 보고서·다른 PC 검수표·선정 캡처만 포함한다. 저장·소스·로그·원본 대형 자산은 제외했다.
- QA 옵션 없는 일반 실행에서도 [정상 타이틀](windows_export_v1_6_1_review/ordinary-title.png)을 확인했다. 기본 타이틀 시작과 정상 창 닫기는 자동 검사 합계에 포함하지 않는다.
- `git diff --check` 통과. stage·commit·push·merge·reset·clean을 실행하지 않았다.

## 미검증 및 다음 작업

- **다른 Windows PC:** 접근 가능한 별도 PC 없음. 압축 해제→시작→화면/입력→새 슬롯 저장→종료→재실행 복원 모두 미검증. [짧은 검수표](windows_export_v1_6_1_review/OTHER_PC_CHECKLIST.md)를 실행 ZIP에도 포함한다.
- Windows 로그아웃/재로그인·재부팅 뒤 고배율, 서로 다른 DPI 모니터 간 이동, 다른 GPU/해상도, 장시간 플레이는 미검증.
- 150%의 모든 군수/편성/훈련 하위 명령과 모든 키보드 경로 조합을 완주한 결과는 아니다. 720p/1080p의 명시된 경로와 150% 대표 탭/포커스/Esc 범위다.
- V1.6의 전체 769개 회귀 검사는 반복하지 않았다. 이번 한 곳의 서식 수정과 실행본 배포에 영향을 받는 경로를 검사했다.

다음 우선순위는 다른 PC에서 동일 ZIP 검수, 이어서 서로 다른 DPI 모니터/로그인 조건의 선명도·입력 확인이다. 확인된 재현 문제만 수정하고 게임 규칙이나 UI 구조를 추가로 바꾸지 않는다.

```text
V1.6.1 실행 ZIP과 tests/WINDOWS_EXPORT_V1_6_1.md를 기준으로 다른 Windows PC 검수를 진행하라.
AGENTS.md와 현재 worktree 상태를 먼저 확인하고 기존 미커밋 작업·보호 파일·저장을 보존하라.
동일 ZIP의 SHA-256을 확인하고 새 폴더에 압축 해제하여 Samhan660.exe를 실행하라.
OTHER_PC_CHECKLIST.md에 PC/OS/GPU/해상도/실제 배율/물리 창 크기를 기록하라.
군수·편성·훈련 입력과 새 테스트 슬롯의 저장→종료→재실행 복원→월 완료를 확인하라.
실제 Windows 배율 변경 후 원래 값으로 복원하라. 접근할 수 없는 환경은 미검증으로 남겨라.
기존 769개와 V1.6.1 검사 수를 새 결과로 합산하지 말고 재현된 문제만 수정·재검증하라.
Git 변경 명령을 실행하지 말고 작은 보고서/캡처 ZIP으로 결과를 전달하라.
```

## 재현

빌드 도구는 `windows_export_v1_6_1_review/build_windows.ps1`이다. 기존 폴더를 삭제하거나 재사용하지 않고 새 Destination을 지정한다. 엔진/템플릿 해시가 다르면 중단한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/windows_export_v1_6_1_review/build_windows.ps1 `
  -Editor '<Godot 4.7.2 exe>' -TemplateArchive '<4.7.2 templates.tpz>' `
  -TemplateSHA512 '<위 SHA512>' -Destination '<프로젝트 밖 새 폴더>'

# 각각 앞 프로세스가 종료된 뒤 같은 out 폴더로 실행한다.
& '<새 폴더>/play-copy/Samhan660.exe' --log-file '<out>/prepare.log' -- --qa-v1-6-1 --phase=prepare '--out=<out>'
& '<새 폴더>/play-copy/Samhan660.exe' --log-file '<out>/reload.log' -- --qa-v1-6-1 --phase=reload '--out=<out>'
# DPI용은 복원 후 대기한다. native_dpi.ps1은 실제 설정을 변경 후 복원한다.
& '<새 폴더>/play-copy/Samhan660.exe' --log-file '<out>/dpi.log' -- --qa-v1-6-1 --phase=dpi '--out=<out>'
```

검수용 기본 저장 쓰기는 일반 사용자 환경에서 실행했다. 편집기·프로젝트 소스가 없는 `play-copy`가 실행 기준이다. 전체 로그·해시·초기 자료는 원래 검수 폴더에 보존하고 작은 검토 ZIP에서는 제외한다.
