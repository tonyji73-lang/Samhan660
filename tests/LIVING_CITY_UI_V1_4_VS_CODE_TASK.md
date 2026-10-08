# 다음 작업 지시문 — Living City 생산·건설·연구 스타일 확장

이 문서는 다음 작업을 위한 제안이며 아직 실행하지 않았다.

현재 `project-foundation-v1` worktree에서 V1.3 장식/서체를 생산·건설·연구로 확장하라.

1. 프로젝트 지침, `tests/LIVING_CITY_UI_V1_3.md`, 현재 diff와 실제 브랜치를 확인하라. 기존 미커밋 작업과 보호 파일을 보존하고 stage/commit/push/merge/reset/clean·임의 브랜치 전환을 하지 마라. 지난 확인에서는 경로명과 달리 브랜치가 main이었다.
2. `production_overlay.gd`, `industry_assignment_overlay.gd`, `campaign_main.gd`의 실제 진입·quote·command·월 처리·저장 연결을 읽어 범위를 확정하라. 건설·연구는 생산 화면의 기존 requirement/command 흐름을 사용하며 새 게임 규칙을 만들지 마라.
3. 수정 전 632년 신라·금성의 생산 기본, 건설/연구 요구 조건, 담당자 선택·진행 상태를 캡처하라. 필요한 화면만 대상으로 하며 전투·외교·지도 전체 개편은 하지 마라.
4. `ui/living_city_v1/living_city_theme.gd`, `ornament_resources.gd`, `ornament_overlay.gd`를 재사용하라. manifest 원본 영역·논리 크기·9분할과 기존 PNG를 보존하라. 공용 Atlas 전역 테마를 변경하지 마라. 원본 파일을 바꾸지 않았다면 `.res`를 불필요하게 재생성하지 마라.
5. 제목만 NanumMyeongjo ExtraBold를 적용하고 본문·능력·비용·기간·버튼은 기존 폰트를 유지하라. 장식이 레이아웃 공간·입력·포커스를 차지하지 않도록 하고 기존 패딩·확정/취소 위치를 보존하라.
6. 기존 견적의 비용·기간·생산량·건설/연구 조건을 사용하라. 실행 불가 이유·진행 중·정지/재개·취소 가능 여부를 구분하라. 생산량이나 자금·기간·승패 조건을 시안에 맞춰 바꾸지 마라.
7. 720p·1080p 실제 Godot에서 해당 화면의 겹침·긴 이름·빈 목록·스크롤·hover/pressed/disabled/focus·Tab/Esc·지도 복귀를 확인하라. 정상 생산·건설·연구 접수와 월 처리, 관련 저장/복원 및 영향을 받은 기존 회귀만 실행하라.
8. `tests/LIVING_CITY_UI_V1_4.md`에 수정 파일·실제 실행 결과·전후 캡처·미검증·남은 시각 차이를 기록하라. 이전 버전 검사 수를 재사용하지 마라. 기존 내정 65:35 화면이 유지되는지 확인하고 커밋하지 않은 상태로 마무리하라.

별도 후속 과제: `.godot` 캐시 쓰기 환경 정상화, 배포 export 실행 확인, 폰트 OFL의 배포물 포함 확인. 이 작업에서 export까지 요청되지 않았다면 완료한 것처럼 보고하지 마라.
