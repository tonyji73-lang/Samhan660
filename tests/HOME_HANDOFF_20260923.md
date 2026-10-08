# 2026-09-23 작업 재개 확인 기록

이 문서는 이번 재개 요청에서 새로 작성했다. 요청에 언급된 같은 이름의 사무실 인계 원본은 현재 저장소 및 가져온 Git 이력에 없었다. 대신 `HOME_START_KO.md`, `tests/SOUTH_CONTINUOUS_V3.md`, 다운로드 패키지의 `CODEX_APPLY.md`를 읽었다. 사용자는 현재 main의 `1dbe7e6`으로 진행하도록 확인했다.

## 기준과 보존

- 실제 연결 폴더: `E:/OneDrive - GRTech/문서/samhan-660-2026-09-02-00-00-33-home/Samhan660-faction-rulers-v1/.worktrees/project-foundation-v1`. 별도의 집 PC 폴더로 이동한 것으로 가정하지 않았다.
- `git fetch origin` 후 HEAD와 원격 main: `1dbe7e6546dfb05af9a21a54cf0a3cc3ae8956b5`, 일치.
- 시작 시 현재 작업 트리 깨끗함. 다른 브랜치/worktree는 건드리지 않았다. 강제 체크아웃/reset/clean 하지 않았다.
- `Downloads/samhan_south_v3_apply.zip`의 PNG·셰이더·바다 마스크 SHA256이 현재 적용본과 모두 일치. 이미 구현된 자산과 코드를 재적용하거나 과거 파일로 덮어쓰지 않았다.
- 적용 중인 남부 v3는 일반 새 캠페인에서 금성·달구벌의 검증된 내륙만 자동 LOD. 대가야·해안·하구·외곽은 미승인으로 원본 유지. 승인 범위와 자산 해시는 `SOUTH_CONTINUOUS_V3.md` 참조.
- 제주 메시 SHA256 `c6566173dd01cfcf8880aab646fa962a9ec3258a9788957a1fa15b9903b0b33f`, 성 배치 SHA256 `b199ee4a532d37e1bb15cbf0d018d86ac964116bea7731b4d32644796d53d654` 유지.
- 사용자 기본 저장 SHA256 `3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3`. 시험은 고유 별도 슬롯만 사용한다.

## 이번 실행

Godot 4.7.2에서 `tests/south_v3_play.gd`로 프로젝트 메인 장면 → 일반 새 캠페인 → 632년/642년 신라를 GUI 자동 입력한다. 개발 검토 사용자 인자는 전달하지 않는다. 1280×720와 1920×1080에서 금성·달구벌·대가야의 휠 확대/축소·클릭, 셰이더 LOD 값 전달, 지원창 왕복, 제주 LOD를 재확인한다. 사람의 수동 F5 플레이가 아니다.

실행 명령(프로젝트 루트):

```powershell
& "C:/Users/지용훈/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --path . --script tests/south_v3_play.gd --log-file .godot/south-v3-home-play.log
```

최신 일반 플레이 캡처와 실제 레이어/해시/가중치 기록은 `tests/art_review/south_v3/production/`에 있다. 원화 비교와 전체 패치 지리 정합은 기존 검토 기록을 참고하며 이번 일반 플레이 재실행과 구분한다. 자동 승인 범위를 추가 확대하지 않았다. 게임 규칙·성 좌표·원화 변경 없음.

대가야의 강폭·지류/강둑 차이, 부분 상세 경계의 질감 밀도 차이, 전 지역 정합 및 기존 과거 저장 재검증 2건은 계속 미완료다.
