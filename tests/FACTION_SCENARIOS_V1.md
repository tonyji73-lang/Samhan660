# 시나리오별 세력 선택 원화 연결

2026-09-22. Downloads/Samhan660_Faction_Scenarios_v1.zip의 요청문·README·integration/APPLY_KO.md를 읽고 현재 검증된 UI 위에 추가했다. main·기존 변경 보존. 패키지의 옛 UI나 보조 스크립트로 현재 UI를 교체하지 않았다.

## 연결

assets/faction_selection/scenario_art_v1에16개 시각 프로필과 배경·투명 초상을 추가했다. new_game_setup.gd에서 실제 scenario_id/faction_id로 카탈로그 키를 명시적으로 연결하고 군주 이름까지 대조한다. 해당 프로필이 없는 경우 기존 실제 군주 portrait_paths/배경을 사용하며 다른 군주의 초상으로 대체하지 않는다. 잠긴 조합을 열거나 미리보기 접근 권한을 추가하지 않았다.
632 신라의 기존 승인 초상·배경·선언문 경로는 유지했다. 나머지는 해당 연도의 투명 PNG·배경·선언문·인장을 함께 갱신한다. 소개·군주·수도·주요 인물은 기존 게임 데이터다. 제목 중복 제거·나이 툴팁·소개 스크롤·버튼2줄·세력별 시작 문구도 유지했다.
시작 표식은 ScenarioData.get_starting_province → 현재 ui/korea_layout_v1/data/castle_layout_v1.json의 render_xy →1254 지도 UV → 실제 KEEP_ASPECT_CENTERED 사각형 순서로 변환한다. 승인 PNG 해시가 등록표와 일치할 때만 등록좌표를 사용한다. 패키지 preview_location_id와 source_world_uv는 사용하지 않는다. 지도상의 표식·라벨은 초상보다 위에 표시한다. 수도와 시작 거점이 다르면 오른쪽 정보에서 구분한다. 등록되지 않은 시작 위치는 임의 표식을 만들지 않는다.
ui/faction_selection_v1/faction_selection.gd의 지도 라벨/인장을 모델로 바꾸고3글자 인장도 동일 영역 안에 맞췄다. 기존 초상 비율 유지와 입력 통과 정책을 유지한다.

## 실제 실행 범위

tests/faction_scenarios_v1_test.gd, Godot4.7.2 D3D12, GUI 자동 입력. 기존 타이틀→새 게임 경로 및 재열기, 빠른 선택 변경을 검사한다. 현재 선택 가능한 조합마다1280×720/1920×1080 캡처, 실제 군주/수도/시작표식/잠금/버튼을 대조하고 각 조합으로 캠페인에 실제 진입한다. 가상·어려움 전달과 최초 선택 거점도 확인한다. 패키지의 정적 자산 수치를 실제 검사 횟수로 사용하지 않는다.
로그:.godot/faction-scenarios.log. 조합별 실제 캡처·연결표:.godot/faction-scenarios-v1/{해상도}-{연도}-{세력}.png 및 result.json.
사람의 수동 플레이·새 프로세스 저장 복원·잠긴 세력의 강제 시작은 수행하지 않았다. 지도r3/자동 LOD false·성 좌표·게임 규칙·사용자 저장은 변경하지 않았다. 과거 원본 저장 재검증2건과 지도 정합 미완료 범위 유지.

## Runtime binding table

| Scenario | Faction | Ruler | Start ID | Portrait |
|---|---|---|---|---|
|silla_equilibrium_632|silla|선덕여왕|geumseong|res://ui/faction_selection_v1/assets/seondeok.png|
|silla_equilibrium_632|baekje|무왕|sabi|res://assets/faction_selection/scenario_art_v1/portraits/mu_wang_selection_overlay.png|
|silla_equilibrium_632|goguryeo|영류왕|pyongyang|res://assets/faction_selection/scenario_art_v1/portraits/yeongnyu_wang_selection_overlay.png|
|goguryeo_coup_642|silla|선덕여왕|geumseong|res://assets/faction_selection/scenario_art_v1/portraits/seondeok_queen_642_selection_overlay.png|
|goguryeo_coup_642|baekje|의자왕|sabi|res://assets/faction_selection/scenario_art_v1/portraits/uija_wang_642_selection_overlay.png|
|goguryeo_coup_642|goguryeo|보장왕|pyongyang|res://assets/faction_selection/scenario_art_v1/portraits/bojang_wang_642_selection_overlay.png|
|baekje_fall_660|silla|김춘추|geumseong|res://assets/faction_selection/scenario_art_v1/portraits/kim_chunchu_660_selection_overlay.png|
|baekje_fall_660|baekje|의자왕|sabi|res://assets/faction_selection/scenario_art_v1/portraits/uija_wang_660_selection_overlay.png|
|baekje_fall_660|goguryeo|보장왕|pyongyang|res://assets/faction_selection/scenario_art_v1/portraits/bojang_wang_660_selection_overlay.png|
|baekgang_663|silla|김법민|geumseong|res://assets/faction_selection/scenario_art_v1/portraits/kim_beopmin_663_selection_overlay_alpha_v3.png|
|baekgang_663|goguryeo|보장왕|pyongyang|res://assets/faction_selection/scenario_art_v1/portraits/bojang_wang_663_selection_overlay_alpha_v3.png|
|silla_tang_war_670|silla|김법민|geumseong|res://assets/faction_selection/scenario_art_v1/portraits/kim_beopmin_670_selection_overlay_alpha_v3.png|

최종 결과: **313건 통과/0실패, 실제12개 캠페인 진입**. 전체 화면↔1280 창 전환 별도 검사 **3건 통과/0실패**(.godot/faction-scenarios-window.log). 최종 주 검사 로그는 .godot/faction-scenarios-final.log이며 오류·경고 없음.
실제 선택 가능 조합:632/642/660 신라·백제·고구려(9),663 신라·고구려(2),670 신라(1). 총24개 조합/해상도 캡처를 생성했다. 현재 선택 가능한 범위의 초상·배경·선언문·시작표식 누락0. 당·부흥군 프로필4개도 자산/매핑에 포함했지만 현재 잠금 정책상 선택·시작할 수 없어 강제 실행하지 않았다. 기타 잠긴 왜·초원 세력도 기존 정책대로 유지한다.
야간 배경에서 제목·선언문 대비가 부족해632 신라를 제외한 프로필에 밝은 제목/짙은 외곽선과 밝은 종이 혼합을 적용했다.632 신라의 승인 대비는 그대로 유지했다. 주요 군주 캡처를 육안 대조해 왕관·얼굴·투명 배경·표식 표시를 확인했다. 패키지의 아트 역사 고증이나 지도 전체 정합을 검증한 것은 아니다.
사용자 기본 저장 해시 유지:3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3.
