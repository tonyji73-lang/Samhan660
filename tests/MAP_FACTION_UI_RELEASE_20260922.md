# 지도·세력 선택 UI 작업 통합 — 2026-09-22

현재 작업 폴더: `Samhan660-faction-rulers-v1/.worktrees/project-foundation-v1`, 브랜치 main, 변경 전 HEAD d953cfac9fb70e10c2c45ef659eb0d1bd57e5aaf.

## 포함 범위

거점 지도/승인 한국 지도, 수동 중부·동해 r2/r3 비교와 이전 지도 검토 장면, 먹색·금색 UI, 시나리오별 군주 초상, 세력별 시작 거점 표식, 잠금 툴팁, 선언문 16개와 순차 재생을 포함한다. 필요한 PNG/WebP/폰트 라이선스/JSON/셰이더/장면/스크립트와 Godot .uid 및 .import 설정을 함께 추적한다. .import 설정은 원본의 가져오기 설정이며 .godot 캐시는 제외한다.

기존 원본 자산과 검토용 지도 경로는 보존한다. 외부 ZIP·백업·.godot의 임시 스크립트/로그/캡처 및 사용자 저장은 커밋하지 않는다. 상세 검증은 각 작업의 기존 tests/*.md 기록을 유지한다.

## 이번 짧은 실행 검증

Godot 4.7.2 D3D12 GUI 자동 입력, 1280×720. 타이틀에서 세력 선택 화면 진입 → 642년 백제/신라 전환 → 신라 선언문 자연 재생 완료 → 실제 642년 신라 캠페인 → 거점 지도 열기. **4 checks, 0 failures**, 로그 `.godot/commit-smoke.log`.
전체 기존 회귀를 재실행하지 않았다. 최초 스테이징에서 발견한 테스트 2개와 셰이더 1개의 불필요한 파일 끝 빈 줄을 정리했다. 게임 동작 오류는 발견되지 않았다.

추가 보존 확인: 663 고구려 남색 초상은 aaef1a42417a68abdb774a3ff87eb57078f144eaca8291a12e130ab508a2c7c2. 잠긴 세력의 툴팁은 “아직 오픈되지 않았습니다”. 사용자 저장 SHA-256은 3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3으로 동일하다.

## 미완료와 브랜치 보존

지도 해안·물길·35개 성 바닥 전체·미할당 마스크 9곳·세계 지도 접합은 기존 기록의 확인 범위만 유효하다. 자동 LOD는 꺼져 있다. 과거 원본 저장이 필요한 재검증 2건과 사람의 수동 플레이는 미검증으로 유지한다.

trade-system, faction-selection-background, faction-selection-rulers 작업용 worktree 각각에 미커밋 변경이 있어 브랜치/worktree를 보존했다. backup-remote-before-sync-20260904에는 main에 없는 커밋 2개가 있어 보존했다. 깨끗한 detached integration worktree도 이번 브랜치 정리 대상에서 제외했다. 안전하게 삭제할 불필요한 병합 완료 브랜치가 없다.
