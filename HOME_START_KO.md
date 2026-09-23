# 집에서 삼한660 작업 이어가기

2026-09-23 인계. 현재 기준은 origin/main. Godot **4.7.2 stable**에서 검증했다.

## 받기와 실행

개발을 이어갈 때는 Git 사용을 권장한다.

```powershell
git clone https://github.com/tonyji73-lang/Samhan660.git
cd Samhan660
git switch main
```

이미 집에 저장소가 있다면 먼저 `git status`로 현지 변경을 확인한다. 깨끗한 main에서 `git pull --ff-only origin main`으로 받는다. 집의 미커밋 변경을 덮어쓰거나 reset/clean 하지 않는다.

함께 만든 `Samhan660_Home_Project.zip`은 Git 없이 열 수 있는 같은 작업본이다. 기존 폴더에 덮어쓰지 말고 새 폴더에 푼다. 압축에는 .git/.godot 캐시·인증정보·사용자 저장이 없다. 이전 R3/v2 비교 캡처도 이 ZIP에는 보존했다. Git에는 최신 v3 캡처와 이전 검증 문서/JSON만 포함한다.

Godot 프로젝트 관리자에서 **project.godot**를 가져온 뒤 리소스 가져오기가 끝날 때까지 기다린다. 또는 실제 집 PC 경로로 실행한다.

```powershell
& "C:\실제경로\Godot_v4.7.2-stable_win64.exe" --editor --path "D:\실제경로\Samhan660"
```

F5 → 새 캠페인 → 632년 또는 642년 신라 → 밝은 아틀라스 거점 지도 → 금성·달구벌 휠 확대. 개발 검토 인자는 사용하지 않는다. 일반 플레이에서 `south_continuous_v3` 내륙 부분이 자동 표시된다. 전체 지도 버튼은 같은 지도의 축소다.

## 현재 완료와 남은 작업

- 밝은 아틀라스 통합, 기존 세력 선택 UI·초상·선언문, 전 권역 R3 연결, 제주 자동 LOD를 유지했다.
- 남부 v3 원화·전용 외곽 셰이더·바다 렌더 마스크 및 LOD 전달 연결. 금성·달구벌의 검증된 내륙 다각형만 자동 상세 승인. 이전 v2와 미완료 자료 보존.
- 대가야 물길, 남부 해안/하구/패치 외곽은 아직 미승인이라 일반 플레이에서 원본을 표시한다. 내륙 부분 경계의 질감 밀도 차이도 남았다. 성 좌표를 옮기거나 흐림으로 완료 처리하지 않는다.
- 35곳 전체 정합, 마스크 9곳, 세계 지도 접합, 사람 수동 플레이 및 과거 원본 저장이 필요한 재검증 2건은 미완료 상태다.

다음 작업 전에 `tests/SOUTH_CONTINUOUS_V3.md`를 읽는다. 세부 승인 범위·해시·실행 캡처가 있다. 이어서 `tests/SOUTH_CONTINUOUS_V2.md`, `tests/SOUTH_R3_REGISTRATION_V1.md`, `tests/FULL_R3_ALL_REGIONS_V1.md`를 참고한다.

이번 실제 검증: 일반 GUI 자동 입력 145건, 새 프로세스 복원 17건, 동일 카메라 비교 22건, 무결성/통제 15건 모두 실패 0. 과거 검사 수치를 재사용하지 않았다. 코드 변경이 없으면 전체 회귀검사를 다시 돌릴 필요는 없다.

## 개인 저장 가져오기

별도 `Samhan660_User_Save_PRIVATE.zip`은 GitHub에 올리지 않은 개인 저장 백업이다. Windows 저장 폴더:

`%APPDATA%\Godot\app_userdata\Samhan660`

집의 기존 저장을 먼저 별도 백업한다. ZIP의 `campaign_save_35_regions_v1.json`을 **별도 파일명**으로 옮겨 게임의 불러오기 파일 선택 창에서 연다. 기존 같은 이름 파일은 덮어쓰지 않는다. 새 캠페인만 할 경우 이 복사는 필요 없다.

원본 저장 SHA256: `3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3`.

전달 폴더의 `TRANSFER_MANIFEST.json`에는 기준 커밋, 파일별 해시와 ZIP 무결성 확인 결과가 들어 있다. 원본 작업 폴더와 사용자 저장은 그대로 남겨 두었다.
