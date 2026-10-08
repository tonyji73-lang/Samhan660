# V1.5 Windows 실행본 제작·검증

2026-09-29. **Windows x86_64 검수 실행본 제작, 별도 폴더 실행, 기본 user:// 저장과 두 차례 프로세스 재시작 검증을 완료했다.** 최종 실행본의 자동 검사 **168개, 실패 0개**. V1.4 검사 수를 합산하지 않았다.

## 2026-09-30 동일 요청 재확인

현재 브랜치는 여전히 `main`이며 적용할 AGENTS.md는 발견되지 않았다. V1.4 보고서와 현재 Windows 프리셋을 다시 확인했다. Godot 실행 버전 `4.7.2.stable.official.ed1daf0bf`와 별도 템플릿 `4.7.2.stable`이 일치한다.

현재 소스·자산·라이선스 386개를 기존 export 소스 사본과 비교하여 차이가 없음을 확인했다. `project.godot` 비교에서는 빌드 사본에만 추가한 기존 검수용 QA autoload 한 줄을 제외했다. ZIP 내부 체크섬 목록의 22개 파일은 모두 일치하고 HTML의 누락 링크는 0개다. 이전부터 있던 저장 JSON 197개도 모두 동일하다.

따라서 게임 코드 변경·재빌드·새 슬롯 생성·GUI 검사 반복은 하지 않았다. **168개 통과는 9월 29일 실제 실행 결과이며 오늘 새로 실행한 검사 수로 표시하지 않는다.** 오늘은 소스 일치·ZIP 무결성·저장 보존을 재확인했다. 기존 ZIP의 이름·내용을 그대로 보존한다. 증거는 `windows_export_v1_5_review/recheck-20260930.json`, `zip-recheck-20260930.json`, `saves-recheck-20260930.json`에 기록했다. 아래 제작·캡처·재시작 결과와 다음 작업 지시문은 여전히 유효하다.

## 환경과 보존

- worktree: `E:/OneDrive - GRTech/문서/samhan-660-2026-09-02-00-00-33-home/Samhan660-faction-rulers-v1/.worktrees/project-foundation-v1`
- 실제 브랜치: `main`. 경로 이름과 다르지만 전환하지 않았다. workspace와 상위 경로에서 적용할 `AGENTS.md`가 발견되지 않았다. V1.4 보고서를 읽었다.
- Windows x86_64, OS 빌드 `10.0.26200.0`, NVIDIA GeForce RTX 4060 Laptop GPU, D3D12 Forward+.
- 편집기와 템플릿 모두 `4.7.2.stable`, 실제 실행 로그 `4.7.2.stable.official.ed1daf0bf`. EXE의 PE machine은 `0x8664`다.
- stage·commit·push·merge·reset·clean을 실행하지 않았다. 기존 미커밋 게임 코드 5개와 보호 파일 `tests/HOME_HANDOFF_20260923.md`의 시작/종료 SHA-256이 동일하다.
- 기존 기본 저장 폴더의 JSON **197개 모두 해시 동일**. 기존 저장을 삭제하거나 덮어쓰지 않았다. 이 작업의 새 검수 슬롯도 남겨두었다.
- 기존 Godot 편집기 PID 25592에 정상 창 닫기를 요청했고 프로세스 종료를 확인했다. import/export용 별도 CLI 편집기 역시 종료된 후 실행본을 검사했다.

## 실제 수정과 발견한 배포 문제

| 파일 | 이유와 변경 |
| --- | --- |
| `export_presets.cfg` | `Windows Desktop`, x86_64 유지. 비어 있던 포함 필터에 JSON/CSV/TSV/TXT 추가. tests/dev/ZIP/log 및 배포에 필요 없는 개발용 addon 제외 |
| `project.godot` | export 전용 `windows_export_assets` 플러그인 등록만 추가 |
| `addons/windows_export_assets/plugin.cfg`, `plugin.gd` | 지도 등록 검사가 FileAccess로 읽는 원본 PNG·셰이더 바이트 보존. 제공 장식 PNG 원본도 포함. export 스냅샷에서 편집기 helper autoload 제거 후 편집기 메모리 설정 복원 |
| `licenses/` | Godot MIT·엔진 서드파티 고지, 본문 Samhan UI Sans OFL, NanumMyeongjo OFL, Phosphor 아이콘 라이선스 |
| `tests/windows_export_v1_5_review/` | 재현용 빌드 스크립트, 검수 전용 코드, 실제 캡처·로그·결과·해시·초기 실패 증거 |

게임 규칙·견적·저장 형식·명령 처리·UI 레이아웃은 바꾸지 않았다. 원래 `.godot` 캐시를 삭제하거나 권한을 변경하지 않았다.

기존 프리셋은 `all_resources`여도 동적으로 여는 JSON이 빠질 수 있었다. 또한 가져온 Texture 리소스만 들어가면 `FileAccess.get_sha256(original_png)`가 성립하지 않아 지도 등록이 거부될 수 있었다. 포함 필터와 export 전용 플러그인으로 원본 바이트를 보존했다. 실제 실행본에서 데이터·라이선스 존재, 원본 지도 해시, 제목의 한글 글리프를 검사했다. PNG·TTF를 재제작하거나 임의 수치로 대체하지 않았다.

본문/제목 폰트는 실행본의 PCK에 들어간 리소스를 사용한다. 제공 장식은 기존 `.res`와 원본 PNG 모두 포함한다. 라이선스는 PCK 내부와 실행 폴더의 `licenses/`에 함께 제공한다.

## 템플릿과 빌드 위치

설치된 export template이 없어 [Godot 공식 4.7.2 릴리스](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)의 `Godot_v4.7.2-stable_export_templates.tpz`와 `SHA512-SUMS.txt`를 받았다. 공식 체크섬과 전체 TPZ가 일치했으며 Windows x86_64 파일과 version.txt만 추출했다.

```text
SHA512
CA4D71C4D7B81DFC15D1A98BAA07534AA95B03FDDA78A0075B06672E1648D2E5F40980C9ADC28D23E1B92E732EE7BF3461997AA804AF74EC2FCD7A93CCB84079

작업 루트: C:/Users/지용훈/AppData/Local/Temp/Samhan660_V1_5_20260929
source/    현재 작업 파일을 복사한 소스; 원래 .godot/tests/dev/git 제외
tools/     같은 버전 편집기, 별도 self-contained 편집기 데이터와 템플릿
build/     export-release 결과 EXE/PCK
play-copy/ 배포 파일만 복사한 실제 실행 검증 폴더
```

`play-copy`의 실행본은 원래 프로젝트나 Godot 편집기를 통해 실행하지 않았다. 템플릿 release 바이너리는 `--path`와 외부 `--script` 테스트에 의존할 수 없어 그런 방식의 검증은 채택하지 않았다.

검수 PCK에만 `qa/windows_export_v1_5.gd`와 opt-in autoload를 넣었다. **일반 실행에는 `--qa-v1-5`가 없으므로 검수 노드를 즉시 제거하고 원래 타이틀로 시작한다.** 프로젝트 원본에 QA autoload를 추가하지 않았다. 자동 검사는 정상 타이틀 → 새 게임 → 632년 → 신라의 실제 버튼 입력으로 시작한다. 자원·날짜·능력·인물을 주입하지 않는다. 검사 노드는 실제 게임 버튼 및 기존 명령/저장 진입 함수를 사용하며, 수동 플레이 전체를 수행했다고 표현하지 않는다.

최종 검수 옵션 없는 실행도 별도로 수행했다. 실제 창 제목 `Samhan660`을 확인하고 정상 창 닫기로 종료했다. 이 실행의 로그에 오류가 없고, Godot 편집기 프로세스도 없었다.

## 실제 실행 결과

| 최종 프로세스 | 검사 | 실패 | 결과 |
| --- | ---: | ---: | --- |
| prepare | 109 | 0 | 6개 화면 × 두 해상도, 입력·버튼 상태, 태수 실제 임명, 개발 완료, 건설·연구 진행 중 새 저장 |
| reload | 42 | 0 | 첫 종료 후 새 프로세스에서 저장 내용 일치, 연구·건설 완료, 생산 담당자·두 공정 가동, 생산 후 두 번째 저장 |
| production-reload | 17 | 0 | 두 번째 종료 후 새 프로세스에서 생산 설정·재고·국고 포함 일치, 다음 달 진행 |
| 합계 | **168** | **0** | 같은 최종 EXE/PCK로 실행 |

일반 타이틀 실행·정상 종료, 파일 해시/PE 형식, 빌드 스크립트 구문, ZIP 구성 검사는 위 자동 검사 합계에 넣지 않았다. `git diff --check`도 통과했다.

### 화면과 입력

632년 신라·금성의 내정, 담당자 카드, 태수 임명, 생산, 건설, 연구를 **1280×720 및 1920×1080**의 실제 렌더링으로 캡처했다. [캡처 보기](windows_export_v1_5_review/index.html)에서 두 해상도를 같은 표시 크기로 비교할 수 있다.

- 원래 도시 전경·인물·한글·제목 서체·금색 테두리·붉은 버튼이 표시된다. 캡처를 직접 확인했으며 이 범위에서 장식과 글자의 겹침이나 누락이 보이지 않았다.
- 내정 도시 65% 비율, 담당자 카드 목록, 선택 취소의 상태 불변, 카드 선택 중 Esc, 태수 상세 스크롤, 생산 내부 스크롤을 확인했다.
- 개발·건설·연구의 키보드 포커스와 Tab 이동, 실제 hover/pressed를 캡처했다. 담당자 미선택 시 비활성, 실제 접수 후 상태 변경, 닫기/Esc 후 지도 입력 복구를 검사했다.
- 금성의 태수를 정상 자격 후보인 선덕여왕으로 실제 임명하고 저장·복원 대상에 포함했다. 후보 미리보기와 확정을 구분했다.

생산 본문이 720p에서 작고 설명량이 많은 점은 V1.4의 기존 상태다. 이번 export 작업에서 폰트 크기나 화면 구조를 다시 설계하지 않았다.

### 정상 캠페인과 저장·재실행

금성 농업 개발은 정상 접수 후 다음 달 완료했다. 기존 이동 명령으로 김춘추·김유신을 금관가야로 보내고 월 도착 후 제련소 건설과 도검 제작 연구를 맡겼다. 금성 화면과 기능은 위에서 별도 확인했으며, 지역 철 공급 → 칼 생산의 정상 경제 흐름은 실제 공급 가능 도시인 **금관가야**에서 검증했다.

첫 저장은 632년 3월, 국고 3,586, 건설·연구가 진행 중인 상태다. 프로그램 종료 후 타이틀의 기존 불러오기 진입 함수로 새 슬롯을 선택했다. 날짜·태수·담당자·진척·국고·재고를 포함하는 전체 검증 스냅샷이 일치했다. 연구와 제련소 완료 후 군기감을 건설하고 생산 담당자를 지정했다. 철 공급과 칼 제작 모두 예약되었는지 별도 확인한 후 실제 다음 달 버튼으로 3개월 진행해 칼 재고가 **0 → 4**가 되었다.

두 번째 저장은 633년 3월, 국고 23,744, 칼 4개, 두 공정 가동 상태다. 다시 프로그램을 종료·재실행하고 스냅샷 일치 및 생산 예약 복원을 확인한 뒤 다음 달을 진행했다.

기본 저장 경로를 변경하지 않았다:

```text
C:/Users/지용훈/AppData/Roaming/Godot/app_userdata/Samhan660/
  windows_export_v1_5_1790673173.json
  windows_export_v1_5_production_1790673224.json
```

위 두 파일은 최종 성공 실행의 새 슬롯이다. 초기 검사에서 만든 다른 `windows_export_v1_5_*.json`도 보존했다. 모두 고유 이름이며 기존 기본 세이브를 덮어쓰지 않았다. 실행 도구의 sandbox 밖에서 일반 사용자 경로 쓰기를 허용하여 검증했으며 관리자 전용 폴더나 대체 저장 경로를 사용하지 않았다. **기본 user:// 저장은 미검증이 아니라 실제 성공**이다.

### 초기 검증 실패 기록

초기 prepare의 3개 실패는 업무 창을 다시 열면 담당자 선택이 보존되는 동작을 미선택으로 잘못 가정한 검사였다. 검사에서 명시적으로 미선택을 선택한 뒤 비활성을 확인하도록 고쳤다.

초기 reload의 1개 실패는 품목 변경 직후 자동 클릭이 Container 배치보다 빨라 철 공급 버튼을 놓친 것이다. 실제 저장에는 칼 제작만 예약되어 철 부족으로 보류된 것이 확인되었다. 클릭 전 프레임 대기를 보완하고 각 공정의 예약 상태를 검사하도록 수정했다. 게임 로직을 우회하거나 자원을 주입하지 않았다. 초기 로그·결과는 `initial-*` 파일에 남겼고 최종 수에 중복 합산하지 않았다.

import/export의 sandbox 실행에서는 Windows 루트 인증서 저장소 경고가 있었다. 최종 배포본의 prepare/reload/production-reload 및 옵션 없는 일반 실행 로그에는 ERROR/WARNING/FAIL이 없었다.

## 재현 명령

작업 밖 새 폴더를 사용하며 기존 폴더를 재사용하거나 지우지 않는 빌드 스크립트는 `windows_export_v1_5_review/build_windows.ps1`이다. 현재 게임 소스와 검수 코드로 import/export 후 실행 폴더에 복사한다. `licenses/`를 그대로 포함한다.

```powershell
# 현재 worktree에서 실행. Destination은 존재하지 않는 새 외부 폴더로 지정한다.
.\tests\windows_export_v1_5_review\build_windows.ps1 `
  -Editor 'C:\Users\지용훈\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' `
  -TemplateArchive "$env:TEMP\Samhan660_V1_5_20260929\templates.tpz" `
  -TemplateSHA512 'CA4D71C4D7B81DFC15D1A98BAA07534AA95B03FDDA78A0075B06672E1648D2E5F40980C9ADC28D23E1B92E732EE7BF3461997AA804AF74EC2FCD7A93CCB84079' `
  -Destination "$env:TEMP\Samhan660_V1_5_Rebuild"

# 생성된 play-copy 폴더로 이동하고 편집기를 정상 종료한 뒤:
New-Item -ItemType Directory -Force evidence
$qaOut = (Resolve-Path evidence).Path.Replace('\','/')
& .\Samhan660.exe --log-file evidence/prepare.log -- --qa-v1-5 --phase=prepare "--out=$qaOut" | Out-Host
& .\Samhan660.exe --log-file evidence/reload.log -- --qa-v1-5 --phase=reload "--out=$qaOut" | Out-Host
& .\Samhan660.exe --log-file evidence/production-reload.log -- --qa-v1-5 --phase=production-reload "--out=$qaOut" | Out-Host
```

일반 사용은 ZIP 전체를 풀고 `Samhan660.exe`를 실행하면 된다. Godot 설치가 필요하지 않으며 EXE와 PCK는 같은 폴더에 둔다. 상세 안내는 ZIP의 `README_WINDOWS.txt`에 있다. 생성 스크립트 구문은 확인했으며, 실제 사용한 개별 import/export 명령과 결과는 로그에 남겼다. 정리한 스크립트로 두 번째 전체 클린 빌드를 반복하지는 않았다.

## 전달물과 해시

다운로드 폴더의 `Samhan660_Windows_V1_5_Review_20260929.zip`에 실행 파일·PCK·라이선스 5종·실행 안내·보고서·6개 화면의 12장 캡처·상대경로 HTML을 담았다. 편집기·템플릿·소스 트리·기존 세이브·대용량 로그는 ZIP에 넣지 않는다. 원래 검증 자료는 worktree의 `tests/windows_export_v1_5_review/`에 보존한다.

```text
Samhan660.exe SHA256
3D19EE4A764E8BB153BFA7F811F98E0DFB0139C9E0C8BC6B76B93D3ED09185BF
Samhan660.pck SHA256
F584BCCD20B654F705DB64EB490312D3517946C9D84DB25F60CF800F622BFFB9
```

## 미검증과 다음 우선순위

1. **별도 PC 검수**: Godot이 설치되지 않은 다른 Windows PC, 내장 GPU, DPI 125%/150%, 다른 사용자 계정에서 실행·한글·기본 저장을 확인한다. 이번 검증은 현재 PC의 별도 실행 폴더에서 수행했으며 다른 물리 PC 검증은 아니다.
2. **배포 마감**: 검수 옵션 없는 배포 전용 구성과 코드 서명 여부를 결정한다. 현재는 opt-in QA가 포함된 미서명 검수본이다. 엔진·폰트·아이콘 고지를 동봉했으며 프로젝트 이미지·음원의 상업 배포 권리 검토까지 수행한 것은 아니다.
3. **그다음 UI 개선**: 생산 본문의 720p 가독성과 긴 설명을 별도 UX 범위로 다룬다. V1.4에서 보존한 본문 크기·드롭다운 구조를 이번에 변경하지 않았다.

모든 시나리오·도시, DPI 조합, 게임패드, 후보 대량 추가, 장기 캠페인 엔딩, OS 장애 중 저장 복구는 이번 검증 범위가 아니다. 저장 파일 선택 대화상자의 모든 키보드 경로를 검증한 것도 아니다. 정상 명령/기본 저장 API와 타이틀 불러오기 진입 함수 및 프로세스 간 복원을 검증했다.

### 바로 전달할 VS Code 지시문

```text
현재 지침과 tests/WINDOWS_EXPORT_V1_5.md를 확인하라.
기존 미커밋 작업·보호 파일·현재 브랜치를 보존하고 stage/commit/push/merge/reset/clean하지 마라.
V1.5 검수 ZIP을 Godot이 없는 별도 Windows PC에 복사해 720p/1080p와 DPI 125%/150%를 확인하라.
632년 신라·금성의 내정·담당자·태수·생산·건설·연구, 기본 user:// 새 슬롯 저장과
종료·재실행 복원을 검증하라. 별도 PC를 사용할 수 없으면 그 사실을 명시하고 성공으로 표시하지 마라.
문제가 재현된 경우에만 필요한 부분을 수정하고 영향받는 검증을 실행하라.
검수용 QA를 제외한 배포 구성, 라이선스 동봉, 코드 서명 필요 여부를 정리하되
게임 규칙이나 UI 구조를 이 작업에 섞어 바꾸지 마라.
tests/WINDOWS_EXPORT_V1_5_EXTERNAL_QA.md에 환경·실제 검사 수·캡처·남은 문제를 기록하라.
```
