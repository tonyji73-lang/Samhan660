# 세력 선택 초상 수정판 적용 — 2026-09-22

## 적용

- 입력: Downloads/Samhan660_Faction_Scenarios_v1 (1).zip. VSCODE_REQUEST.txt, README_KO.md, integration/APPLY_KO.md, review/PORTRAIT_MATCH_V1.md를 읽고 적용했다.
- 기존 JSON 기반 컨트롤러를 그대로 사용한다. `assets/faction_selection/scenario_art_v1/profiles.json`을 portrait_match_v1로 갱신하고 같은 디렉터리의 portraits에 새 PNG 6장만 추가했다. 이전 PNG와 원본 Portrait는 보존했다.
- 실제 변경 조합: 642 백제/고구려, 660 신라/백제/고구려, 663 고구려. 나머지 10개 프로필은 이전 자료와 동일하다.
- 인물 등록 대조: 김춘추 historical:003, 의자왕 historical:013, 보장왕 historical:024. scenario_data.gd의 실제 시나리오/세력/군주와 해당 portrait_paths를 대조했다. 인물·시나리오 데이터는 변경하지 않았다.
- 문서의 공통 주황 표식보다 최근 사용자 요청을 우선해 고구려 파랑·백제 빨강·신라 주황 및 금빛 테두리를 유지했다. 632 신라 승인 화면, 기존 배치, 잠금 규칙, 지도 r3 및 자동 LOD 꺼짐을 유지했다.

## 원본 대조

새 PNG 6장의 SHA-256은 모두 ZIP 내 파일과 일치한다. 새 파일명을 직접 참조하여 이전 리소스 경로를 재사용하지 않는다.

| 참고 Portrait | 프로젝트와 SHA-256 대조 |
|---|---|
| kim_chunchu.png | 동일: c167eda587c5b033173168269d3730e9a9b1fd0d1f882b0b0c3b39b08abab56e |
| uija_wang.png | 동일: 26e6d2cdf758f1f6c977f1ca0dad084ab6388460e2cf3c8cc860361ccada5bae |
| bojang_wang.png | 다름: ZIP 8984ca34ea9d818a3d307b2a0955c5e32aff2bf8a695a804797d8a9ea856fe08 / 프로젝트 3f5a0442ce680a4ad748a698c649bfc2eac85fbbfba1cd5d69734cc98f369dfc |

보장왕의 기존 작은 Portrait를 첨부 참고 파일로 교체하지 않았다. 새 오버레이가 현재 프로젝트의 작은 Portrait와 동일한 원본을 바탕으로 제작됐다고 보장하지 않는다.

## 실제 Godot 실행

- Godot 4.7.2, D3D12 실제 GUI의 자동 입력 검증이다. 사람의 수동 플레이가 아니다.
- `tests/faction_scenarios_v1_test.gd`를 이번 자산 적용 후 다시 실행: 313 checks, 0 failures, 12개 정상 선택 가능 조합 모두 실제 캠페인 진입 확인.
- 1280×720 / 1920×1080에서 24장 캡처. 새 초상 6개의 얼굴·투명 배경·왕관 여백·비율, 시작 거점 이름과 표식, 시작 버튼을 확인했다. 빠른 세력 전환과 화면 재열기, 모드/난이도 전달 및 잠금 상태도 검사했다.
- 로그: `.godot/portrait-match-import.log`, `.godot/portrait-match-gui.log`. 화면: `.godot/faction-scenarios-v1/{1280,1920}-{연도}-{세력}.png`.
- 별도 임시 GUI 검사 `.godot/portrait_match_cache.gd`: 새 초상 6개를 연도·세력 연속 전환으로 3회 순회하며 실제 TextureRect의 resource_path를 확인. 18 checks, 0 failures (`.godot/portrait-match-cache.log`). 이번 실행 합계 331 checks, 0 failures.
- 사용자 저장 SHA-256: 3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3 (이전과 동일).
- 기존 검증 숫자를 재사용하지 않았다. 잠긴 당/부흥군을 해금하지 않았으며 해당 조합의 캠페인 시작은 미검증이다. 이번 연결 대상 6개 초상에 누락은 없다.
