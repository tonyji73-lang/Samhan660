# 밝은 아틀라스 UI v1 — 2026-09-23

## 적용

입력은 Downloads/Samhan660_Light_Atlas_v1.zip 안의 CODEX_START_HERE.md다. README_KO.md, manifest.json, light_atlas.patch, THIRD_PARTY.md, VALIDATION.md 및 선택 시안 이미지를 읽었다. 압축은 프로젝트 밖 Temp/Samhan660_Light_Atlas_review_20260923_091201에 해제했다.

기준 main f5a5c731, 시작 작업 트리 깨끗함. 패키지 baseline 4개 파일에는 실제 기준보다 파일 끝 빈 줄이 하나씩 많아 git apply --check가 실패했다. 줄바꿈과 끝 공백을 제외한 내용이 모두 같음을 확인한 뒤 SHA-256을 검사한 payload 20개를 적용했다. 이후 실행 중 발견한 카드 조작 문제를 수정했다. 기존 코드 강제 원복이나 브랜치 전환은 하지 않았다.

- 세력 선택: 아이보리 왼쪽 정보 패널, 상단 연도 선택, 주황색 주요 행동. 기존 군주 초상·간접 지도·세력별 시작 거점 색·한지 선언·잠금 툴팁 유지.
- 거점 지도: 상단 아이콘 메뉴, 왼쪽 성 카드, 주황색 선택 테두리/지원 경로, 오른쪽 확대·축소와 다음 달 버튼. 기존 비교 모드는 `지도 보기`에서 접근한다.
- 새 공통 테마와 Phosphor SVG 13개/MIT 라이선스를 ui/light_atlas_v1에 추가했다. 게임 전체 테마로 확장하지 않는다.
- 최초 GUI 검사에서 스크롤 후 카드 닫기 버튼이 가려져 두 검사가 실패했다. 성 이름·닫기를 상단에 고정하고, 지원군 선택·취소도 고정 하단으로 분리했다. 본문과 경로 확인은 카드 안에서 스크롤한다.
- 현재 승인 지도/r2/r3 검사의 입력 좌표를 get_global_transform_with_canvas() 기반으로 고치고, 숨겨진 지도 보기 패널과 성 카드 스크롤을 사용하도록 조정했다. 데이터·지원·저장 검증은 유지했다.

## 실제 Godot 검증

Godot 4.7.2, D3D12, 실제 GUI 자동 입력이다. 패키지의 정적 검사 숫자나 이전 실행 결과를 이번 통과 숫자로 재사용하지 않았다.

| 이번 실행 | 결과 | 범위 |
|---|---|---|
| light_atlas_ui_test.gd | 381 checks, 0 failures | 1280×720/1920×1080, 시나리오·잠금·시작, 카드 닫기/복귀/고정 행동, 성 선택, 확대 버튼, 5개 명령 메뉴·저장 메뉴 왕복, 정상 지원 선택 화면 |
| settlement_style_v1_test.gd | 85 checks, 0 failures | 두 해상도 마우스 휠/이동, 6개 성 선택, 침공 목록 복귀, 실제 지원 발령, 다음 달 결산과 도착, 별도 저장 |
| light_atlas_restart_test.gd | 9 checks, 0 failures | 새 프로세스 로드, 날짜·세력·자원·부대·정치·대기 지원 복원, 지원 도착/예약 정리, 카드 조작 |
| faction_selection_ui_v1_test.gd | 116 checks, 0 failures | 활성 조합 전환·잠금, 소개 스크롤, Esc/재열기, 632 신라·642 백제 캠페인 시작/모드·난이도 |
| faction_declarations_v1_test.gd | 1206 assertions, 0 failures | 16개 데이터 대응, 12개 활성 조합×두 해상도, 글자 순서/영역, 자연 재생·진행도·빠른 전환·재열기·캠페인 진입 |
| faction_selection_tooltip_test.gd | 2 checks, 0 failures | 실제 인물 나이 마우스 오버와 캡처 |
| central_east_r3_test.gd | 70 checks, 0 failures | 새 배율/지도 보기 메뉴의 r2/r3 비교, 성 선택, 지원 경로, 자동 LOD 차단 |

선언문 1206건은 개별 글자 영역/순서 assertion을 포함한다. 독립적인 1206개 캠페인 검증이라는 의미가 아니다. 수정한 옛 approved/r2/LOD 전용 검사 전체는 이번에 각각 다시 실행하지 않았고, 최신 r3 검사와 실제 플레이 검사를 실행했다. 최종 로그에 SCRIPT ERROR/실패 없음.

로그: `.godot/light-atlas-gui-release.log`, `light-atlas-play.log`, `light-atlas-restart.log`, `light-atlas-faction.log`, `light-atlas-declarations.log`, `light-atlas-tooltip.log`, `light-atlas-r3.log`.

## 정상 지원·저장

642년 신라 7월에 금성의 실제 부대 unit:14를 달구벌로 지원 발령했다. 8월 정상 결산 후 달구벌 도착, 1920×1080에서 추가 다음 달을 눌러 9월 진행을 확인했다. 자원·날짜·병력 주입 없음.
대기 중 별도 슬롯 `user://approved_castle_layout_1790122544_55444.json` 저장. 저장 프로세스 PID 55444와 다른 새 프로세스에서 로드해 전체 저장 상태를 대조하고 8월 도착/예약 제거를 확인했다. 사용자 기본 저장은 사용하지 않았다.

실행 중 침공 목록은 기존 UI로 열고 닫았다. 이번 짧은 진행에서 자연 침공이나 방어 승리 포상이 발생했다고 주장하지 않는다.

## 캡처와 보존 범위

- 세력 선택: `.godot/declarations-v1/1280-660-silla.png`, `1920-660-silla.png` (선언 완료).
- 거점 지도: `.godot/light-atlas-v1/1280-support-card.png`, `1920-support-card.png` (고정 닫기/지원 버튼 적용 후 실제 화면).
- 턴 진행/재시작: `.godot/settlement-style-v1/1280-after-turn.png`, `1920-after-turn.png`, `atlas-restart.png`.
- 기존 지도 원본 SHA-256: 36594c1d1ee0cbcd80a175d72790d3e22423103cf81d6b191f8bf2d317e1f246.
- 보장왕 663 남색 PNG: aaef1a42417a68abdb774a3ff87eb57078f144eaca8291a12e130ab508a2c7c2.
- 사용자 기본 저장: 3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3. 모두 이전과 같다.

시안의 성별 풍경 그림은 새 자산이 아니므로 기존 공통 성 스프라이트를 카드에 사용한다. 지도 색/바다/해안은 기존 아트를 유지하여 시안과 픽셀 단위로 같지 않다. 확대 흐림·해안/물길·35개 성 바닥·미할당 마스크 9곳·세계 지도 접합은 해결 처리하지 않는다. r2/r3는 수동 비교이고 자동 LOD는 꺼져 있다. 사람의 수동 플레이와 과거 원본 저장 재검증 2건은 기존 미검증 상태다.
