# V1.7.1 Windows 실행본 갱신·정치 상태 복원 검수

2026-09-30. V1.7 조정·귀족 정치 UI를 포함한 Windows x86_64 실행본을 제작했다. 실행 파일은 **`Samhan660.exe`**다. 이번 자동 검사 **363개, 실패 0개**이며 이전 V1.7의 349개는 합산하지 않았다. 실제 Windows 150% 대표 화면·입력을 확인하고 100%로 복원했다. 다른 PC는 미검증이다.

## 기준·보존·변경

- worktree: `E:/OneDrive - GRTech/문서/samhan-660-2026-09-02-00-00-33-home/Samhan660-faction-rulers-v1/.worktrees/project-foundation-v1`
- 실제 브랜치 `main`, HEAD `1dbe7e6546dfb05af9a21a54cf0a3cc3ae8956b5`. 경로 이름을 근거로 변경하지 않았다. 적용할 AGENTS.md는 프로젝트와 상위 경로에서 발견되지 않았다.
- `LIVING_CITY_UI_V1_7.md`, 기존 `WINDOWS_EXPORT_V1_5.md`, `WINDOWS_EXPORT_V1_6_1.md`, `WINDOWS_DPI_V1_5_1.md` 및 빌드·DPI 도구를 확인했다.
- 기존 미커밋 작업을 포함한 소스·자산·설정 **1,284개**를 SHA-256으로 기록했다. 기준은 `windows_export_v1_7_1_review/source-start.json`, 최종은 `source-final.json` 및 실행 ZIP의 `SOURCE_SHA256.json`이다.
- 기존 저장 관련 JSON **207개**를 V1.7 기록의 경로·해시와 대조하여 보존했다. 루트 폴더만 세면 205개이므로 이를 전체 207개 기준 대신 사용하지 않았다. 기존 V1.5/V1.6.1 실행 ZIP과 보호 문서도 보존했다.
- **게임 수정은 `ui/living_city_v1/court_overlay.gd` 한 곳:** 인물 업무의 `industry` 내부 코드 대신 실제 연결된 작업의 생산/건설/연구 이름을 표시한다. 작업 연결이 없으면 산업으로 표시한다. 조회용 문구 변경이며 정치 규칙·비용·저장 처리·내정 65:35·초상/장식 자산은 변경하지 않았다.
- 나머지 추가물은 이 보고서와 `tests/windows_export_v1_7_1_review/`의 검수·패키징 스크립트, 해시, 결과, 캡처다. stage·commit·push·merge·reset·clean을 실행하지 않았다.

## 실행 환경과 배포 구성

| 항목 | 결과 |
|---|---|
| PC / OS | 현재 Windows 11 PC, build 10.0.26200 |
| GPU / 렌더러 | NVIDIA GeForce RTX 4060 Laptop GPU / D3D12 Forward+ |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| 템플릿 / 프리셋 | `4.7.2.stable` / Windows Desktop / x86_64 / release |
| 실제 EXE PE machine | `0x8664` |
| 프로젝트 밖 새 빌드 폴더 | `%LOCALAPPDATA%/Temp/Samhan660_V1_7_1_20260930/` |
| 실제 배포 실행 위치 | 위 폴더의 `play-copy/Samhan660.exe` |
| 기본 저장 위치 | `%APPDATA%/Godot/app_userdata/Samhan660/` |

기존 공식 템플릿 TPZ의 SHA-512를 빌드 전에 재확인했다:

```text
CA4D71C4D7B81DFC15D1A98BAA07534AA95B03FDDA78A0075B06672E1648D2E5F40980C9ADC28D23E1B92E732EE7BF3461997AA804AF74EC2FCD7A93CCB84079
```

기존 Godot 편집기 PID 38088에 정상 종료를 요청하고 편집기 0개 상태를 확인했다. import/export 프로세스가 종료된 뒤 프로젝트·편집기가 없는 `play-copy`에서 배포 EXE를 직접 실행했다. 같은 PC의 다른 폴더 실행이며 다른 PC 검증으로 기록하지 않는다.

실행 ZIP에는 EXE, PCK, 5개 라이선스 고지, 한글 실행 안내, 다른 PC 검수표, `BUILD_INFO.json`, `SOURCE_SHA256.json`, `SHA256SUMS.txt`가 있다. 전체를 압축 해제하고 EXE와 PCK를 함께 둔다. 장식 PNG·제목 한글 폰트·초상·동적 JSON·필요 원본 지도 바이트는 기존 export 설정/플러그인으로 포함했다. 실행본 내부에서 데이터/라이선스 존재, 원본 지도 해시, 한글 글리프, V1.7 조정 및 조회 리소스를 검사했다.

검수 사본/PCK에만 명시적 `--qa-v1-7-1` 옵션에서 작동하는 QA autoload를 포함했다. 옵션 없는 일반 실행에서는 검사 노드를 즉시 제거한다. 원본 `project.godot`에는 추가하지 않았다. 실제 렌더링·Godot 입력 이벤트·기존 명령 및 저장 진입 함수를 사용하는 자동 검사이며 전 과정을 사람이 수동 플레이한 것으로 표현하지 않는다. Windows DPI 검사는 별도로 실제 OS 입력을 사용했다.

## 이번 검사 수

| 이번 실행 | 검사 수 | 결과 |
|---|---:|---|
| prepare: 자산·두 해상도·정상 미응답 상태 저장 | 50 | 통과 |
| respond-compensate: 태수/지휘관 보상 + 요구 포상 | 52 | 통과 |
| reload-compensate: 새 프로세스 복원·월 처리 | 37 | 통과 |
| respond-wait: 태수/지휘관 기한 보장 + 요구 수락 | 52 | 통과 |
| reload-wait: 새 프로세스 복원·기한 완료 | 39 | 통과 |
| respond-force: 태수/지휘관 강제 회수 + 요구 거절 | 52 | 통과 |
| reload-force: 새 프로세스 복원·기간 종료 | 42 | 통과 |
| visual: 업무 이름 수정 후 최종 EXE 화면·입력·상태 조회 재검증 | 39 | 통과 |
| **합계** | **363** | **실패 0** |

정치 처리/저장 검사는 324개다. 이 검사는 업무 이름 문구 수정 전의 배포본에서 실행했고, 수정 후에는 영향받는 표시·입력·복원 조회 39개와 실제 DPI 화면을 재검증했다. 정치/저장 처리 코드는 전후 동일하다. 이전 V1.7의 349개, 초기 검사 실패, 같은 검사 재실행, DPI 대기 과정의 반복 자산 확인은 합산하지 않았다. 캡처 저장 성공도 assertion에 포함되므로 363개가 모두 서로 다른 게임 규칙인 것은 아니다.

## 정치 상태와 실제 종료·복원

### 미응답 상태

- 권력 제약은 기존 정상 플레이에서 생성된 636년 11월 신라 군권 집중 상태 `.godot/noble-power-results/normal-concentrated.json`에서 기존 임명/인계 진입 함수를 사용했다. 태수와 지휘관을 각각 동일 상태에서 시작했다. 자원·병력·충성·영향력을 검사용 숫자로 주입하지 않았다.
- 요구는 새 642년 신라 캠페인에서 정상 태수/지휘관 임명으로 영향력 조건을 만들고 기존 `Noble.propose()`로 생성했다.
- `handover:1` 태수, `handover:1` 지휘관은 서로 다른 시작 저장의 ID다. 요구는 `noble:1`이다. 각각 미응답 상태를 고유 `user://windows_export_v1_7_1_<timestamp>_<ticks>_pending-*.json`에 저장하고 EXE를 종료했다.
- 다음 프로세스에서 전체 캠페인 스냅샷과 별도 정치 요약을 대조했다. 국고·충성·협력·영향력·인물·부대·업무·요구/인계 레코드가 일치했다. 대상·발생월·선택지, 인계의 보장 기간/기한 데이터도 유지됐다. 귀족 요구에 원래 없는 별도 마감 기한을 만들지 않았다.

### 같은 시작 상태의 세 대응

각 대응 프로세스는 동일한 미응답 저장을 다시 불러왔다. 선택·취소는 상태 불변이며, 확정은 실제 비용·정치 레지스트리·부대 레지스트리가 UI 미리보기와 일치했다. 대응 직후 각각 새 기본 경로 슬롯에 저장하고 프로세스를 종료했다.

| 권력 대응 | 시작 국고 | 직후 국고 | 김유신 충성 | 군사 집단 협력 | 군사 영향력 | 상태 |
|---|---:|---:|---:|---:|---:|---|
| 태수 보상 | 100578 | 100448 | 54 | 52 | 41.1827 | 즉시 인계 |
| 지휘관 보상 | 100578 | 99858 | 54 | 52 | 15.5960 | 즉시 인계 |
| 태수/지휘관 기한 보장 | 100578 | 100578 | 58 | 54 | 46.7383 | 2개월 기한 보장 |
| 태수 강제 | 100578 | 100578 | 38 | 42 | 41.1827 | 즉시 인계·도시 2회 차질 |
| 지휘관 강제 | 100578 | 100578 | 38 | 42 | 15.5960 | 즉시 인계·부대 1회 차질 |

요구 포상은 금 1000→900, 군사 집단 협력 54→60이었다. 수락은 금 1000 유지, 영향력 20.4494→26.4229, 거절은 금 1000 유지, 협력 54→48이었다. 이 값은 해당 정상 시작 저장에서 측정한 결과이며 게임에 고정한 예시 수치가 아니다.

대응 후 별도 EXE 프로세스에서 다시 불러와 전체 저장 상태가 정확히 일치함을 확인했다. `Core.influence()`의 기반 도시/부대 목록은 구성원이 같아도 JSON 복원 후 나열 순서가 바뀔 수 있어, 검사에서 **이 두 목록만 정렬**하여 비교했다. 모든 수치와 이력·업무 등 다른 배열은 그대로 대조했다.

- 같은 요구/협의 ID와 같은 선택을 다시 실행해도 비용·효과가 반복되지 않았다.
- 보상 복원 후 월 진행에서 실제 납부 비용은 태수 130, 지휘관 720으로 유지됐다.
- 기한 보장 복원 후 실제 월 진행 2회로 인계 완료, 비용 0을 확인했다.
- 강제 복원 직후 도시 작업량 계수 0.8 또는 부대 출정·훈련 제약이 유지됐다. 실제 월 처리로 도시 2회/부대 1회 뒤 해제되고 비용이 재청구되지 않았다.
- 월별 국고·관계·영향력·기간·부대·업무를 `*-timeline.json`에 기록했다. 월 세입과 다른 정상 업무로 인한 국고 변화는 정치 비용과 구분했다.
- 귀족 요구 수락/포상/거절도 대응 직후 저장→종료→재실행→복원→월 진행을 완료했다. 월 진행 중 별개로 발생한 요구는 기존 거절 함수를 통해 처리했으며 해당 처리와 검수 대상 ID를 구분했다.

원본/신규 테스트 저장을 삭제하지 않았다. 기본 `user://` 경로 쓰기는 차단되지 않았다. 로그의 각 프로세스 ID·시작/종료 시각·결과는 `restart-processes.json`, 실제 슬롯과 전체 스냅샷은 `pending.json` 및 `*-restart.json`에 있다. 저장·대용량 스냅샷은 작은 검토 ZIP에서 제외했다.

## 화면·입력·실제 150%

- 실제 1280×720·1920×1080 렌더링으로 조정, 선택 집단 상세, 인물 이력/업무, 대응 비용·관계·기간을 확인했다. 한글·초상·제목 폰트·선택 테두리·확정/비활성 버튼을 표시했다.
- Tab·Shift+Tab, Space 집단 선택/확정/취소, Esc, 내부 스크롤을 확인했다. 닫기 후 `settlement_overlay.busy()`가 해제되고 도시를 다시 선택하여 조정에 재진입했다.
- 모니터 해상도 **1920×1080**, 실제 Windows 설정 **150%**, 게임 물리 클라이언트 **1600×901**, 테두리 포함 **1625×960**으로 검사했다. 게임이 보고한 논리 창은 약 1067×601이며 viewport 크기만 바꾼 DPI 검사가 아니다.
- 실제 Win32 마우스로 다른 집단을 클릭한 결과 선택 ID가 일치했다. 실제 휠 입력으로 상세 스크롤이 이동하고, OS Tab·Esc 후 조정이 닫히며 지도 입력 차단이 해제됐다.
- `GetDpiForWindow`는 96을 반환했다. 이를 150% 설정의 대용으로 사용하지 않고 Windows 설정 선택값·물리 창 크기를 별도 기록했다. 확대 시 기존의 부드러운/흐린 표시 특성은 남지만 대표 화면에서 글자 잘림·장식 겹침·클릭 위치 어긋남은 재현하지 못했다.
- 검수 후 `finally`에서 **원래 100%로 복원**했다. `dpi-native-result.json`, `restored-display.json` 참조.

대표 캡처:

- [632년 조정 720p](windows_export_v1_7_1_review/court-720.png) / [1080p](windows_export_v1_7_1_review/court-1080.png)
- [집단 상세 720p](windows_export_v1_7_1_review/court-details-720.png) / [인물 상세 1080p](windows_export_v1_7_1_review/court-person-1080.png)
- [태수 보상 720p](windows_export_v1_7_1_review/governor-compensate-preview-720.png) / [1080p](windows_export_v1_7_1_review/governor-compensate-preview-1080.png)
- [지휘관 강제 720p](windows_export_v1_7_1_review/commander-force-preview-720.png) / [1080p](windows_export_v1_7_1_review/commander-force-preview-1080.png)
- [요구 포상 720p](windows_export_v1_7_1_review/demand-gift-preview-720.png)
- [기한 보장 재실행 복원](windows_export_v1_7_1_review/governor-wait-restored.png)
- [최종 표시 수정 후 720p](windows_export_v1_7_1_review/final-court-720.png) / [1080p](windows_export_v1_7_1_review/final-court-1080.png)
- [150% 업무 이름 수정 전](windows_export_v1_7_1_review/before-duty-label.png) / [수정 후](windows_export_v1_7_1_review/dpi150-group.png)
- [150% 스크롤](windows_export_v1_7_1_review/dpi150-scroll.png) / [Tab](windows_export_v1_7_1_review/dpi150-tab.png)
- [QA 옵션 없는 일반 실행 타이틀](windows_export_v1_7_1_review/ordinary-title.png). 정상 종료 코드 0, 자동 생성 테스트 슬롯 수 21→21로 불변이었다. 초기/재실행에서 만든 테스트 슬롯도 삭제하지 않았다. 이 일반 실행 확인은 자동 검사 363개에 추가 합산하지 않았다.

## 발견 사항과 수정 범위

1. **게임 표시:** `industry` 업무 코드가 인물 카드에 노출됐다. 기존 job_id로 실제 작업 종류를 읽어 한글 이름을 표시했다. 최종 EXE에서 39개 영향 검사와 150% 대표 화면을 재검증했다. 규칙·데이터 변경은 없다.
2. **검사 비교:** 전체 저장은 같으나 영향력 기반 도시 목록의 나열 순서를 상태 손실로 판단한 초기 검사 1개가 실패했다. 실제 차이는 `국원, 금성, 사벌`과 `금성, 국원, 사벌` 순서뿐이었다. 구성원과 모든 수치는 같아 조회 결과의 두 집합성 목록만 정렬해 검사했다. 실패 로그/차이 파일을 보존했다.
3. **패키징:** 초기 ZIP에서 한글 이름의 실행 안내가 빠진 것을 파일 목록 검사로 발견했다. Unicode 파일 경로를 직접 전달하도록 패키징 도구를 수정하고 이번에 만든 V1.7.1 ZIP만 다시 생성했다. 최종 ZIP의 필수 파일과 payload 해시를 재확인했다. 기존 버전 ZIP은 손대지 않았다.

## 전달물·미검증·다음 작업

- 실행 ZIP: `C:/Users/지용훈/Downloads/Samhan660_Windows_V1_7_1_20260930.zip`
- 실행 ZIP 크기 **467.55 MiB (490,260,735 bytes)**. SHA-256: `618ACB2342BFA3DA81A11AD92EB9ACCFACB0C888D4F44EACEAD3ACD19D297514`.
- 실행할 정확한 이름: **`Samhan660.exe`**. Godot 편집기 설치 없이 EXE와 PCK를 같은 폴더에서 실행한다.
- 작은 검토 ZIP: `tests/Samhan660_Windows_V1_7_1_Review_20260930.zip`. 이 보고서와 선정 캡처만 포함한다.
- 빌드/EXE/PCK/ZIP 해시는 `BUILD_INFO.json`, `SHA256SUMS.txt`, 검수 폴더의 `package-result.json`에 기록했다. 실행 ZIP 내부 payload를 다시 읽어 SHA-256을 확인했다.
- 최종 PCK SHA-256: `F0C74A2C16A0C8548E942769E15EAD5687E1FDCE31DE0531C1E0EF7B6EAD8042`. 체크섬 목록을 제외한 **11개 payload**를 ZIP 내부에서 검증했다. `git diff --check` 통과, 최종 소스 변경은 위 업무 문구 파일 1개이며 계획 외 변경은 0개다.
- 다른 Windows PC는 접근 가능한 환경이 없어 **실행·입력·저장·재실행 복원 모두 미검증**이다. 전달용 `OTHER_PC_CHECKLIST.md`를 갱신하여 실행 ZIP에 넣었다.
- 재부팅/로그아웃 후 DPI, 서로 다른 DPI 모니터 사이 이동, 모든 정치·업무 조합, 장시간 플레이는 미검증이다. 이번 대표 150% 검수를 모든 환경 통과로 확대하지 않는다.

다음 우선순위는 **동일 ZIP의 다른 PC 검수**, 이어서 다중 모니터/로그인 조건의 DPI 선명도·입력 확인이다. 정치 규칙이나 새 집단을 추가하기보다 재현된 배포/입력 문제를 먼저 해결한다.

```text
V1.7.1 동일 실행 ZIP의 다른 Windows PC 검수를 진행해라.
AGENTS.md, 현재 worktree, tests/WINDOWS_EXPORT_V1_7_1.md와 OTHER_PC_CHECKLIST.md를 확인해라.
미커밋 작업·보호 파일·기존 저장·기존 ZIP을 보존하고 Git 변경 명령은 실행하지 마라.
ZIP 해시를 확인하고 새 폴더에 풀어 Samhan660.exe를 실행해라.
조정·집단/인물 상세·대응 확인을 720p/1080p 및 실제 Windows 150%에서 확인하고
배율을 원래 값으로 복원해라. 같은 PC의 다른 폴더는 다른 PC 검증으로 기록하지 마라.
정상 미응답 요구/인계 상태를 새 슬롯에 저장→종료→재실행해 대상·기한·선택지를 비교해라.
같은 시작 상태의 보상/기한 보장/강제 회수 직후도 각각 저장→종료→복원→월 처리하고
국고·관계·영향력·기간·부대/업무 제약 및 같은 ID의 중복 처리 방지를 확인해라.
접근할 수 없는 환경은 미검증으로 유지하고 실제 실행 결과만 별도 집계해라.
재현된 문제와 영향 범위만 수정·재검증하고 작은 보고서/캡처 ZIP을 제공해라. 커밋하지 마라.
```

## 재현 명령

빌드는 `windows_export_v1_7_1_review/build_windows.ps1`에 실제 4.7.2 편집기·템플릿 TPZ·위 SHA-512·프로젝트 밖 **새 Destination**을 전달한다. 원래 폴더를 삭제하거나 덮어쓰지 않는다. 검수 out에는 위 정상 플레이 저장을 `normal-concentrated.json`으로 복사한다.

```powershell
# 각각 앞 프로세스가 완전히 종료된 뒤 실행한다.
& '<play-copy>/Samhan660.exe' --log-file '<out>/prepare.log' -- --qa-v1-7-1 --phase=prepare '--out=<out>'
# action은 compensate, wait, force 순서로 각각 수행
& '<play-copy>/Samhan660.exe' --log-file '<out>/respond-<action>.log' -- --qa-v1-7-1 --phase=respond-<action> '--out=<out>'
& '<play-copy>/Samhan660.exe' --log-file '<out>/reload-<action>.log' -- --qa-v1-7-1 --phase=reload-<action> '--out=<out>'
& '<play-copy>/Samhan660.exe' --log-file '<out>/visual.log' -- --qa-v1-7-1 --phase=visual '--out=<out>'
# 별도 DPI 대기 실행 뒤 native_dpi.ps1로 실제 설정/입력을 확인하고 복원
& '<play-copy>/Samhan660.exe' --log-file '<out>/dpi.log' -- --qa-v1-7-1 --phase=dpi '--out=<out>'
```
