# 삼한660 한국 35지역 안전 병합본

이 패키지는 정상 복구된 기존 월드 기능을 보존하면서 한국 캠페인만 35개 지역으로 확장합니다.

## 적용 전

1. Godot를 완전히 종료합니다.
2. 현재 프로젝트 폴더를 통째로 백업합니다.
3. 기존 9지역 저장은 유지되지만 새 35지역 캠페인과 섞이지 않습니다.

## 덮어쓸 위치

- `campaign_main.gd` → `res://campaign_main.gd`
- `map_area.gd` → `res://map_area.gd`
- `world_map_data.gd` → `res://world_map_data.gd`
- `korea_35_data.gd` → `res://korea_35_data.gd` (새 파일)
- `assets/maps/samhan660_territory_id_map_35.png` → 같은 경로
- `assets/maps/samhan660_east_asia_korea_center_6144x4096.png` → 같은 경로로 덮어쓰기

`scenario_data.gd`와 `new_game_setup.gd`는 덮어쓰지 마세요. 배경 지도 PNG는 이번 패키지의 새 고지도 스타일 파일로 교체합니다.

## 적용 후 확인

1. Godot를 열고 스크립트 파서 오류가 없는지 확인합니다.
2. 새 캠페인을 시작합니다.
3. 선택한 세력의 수도가 화면 중앙에 보이는지 확인합니다.
4. 한국 지도에 35개 도시 표식과 51개 연결망이 표시되는지 확인합니다.
5. 안시성·국내성·평양성·웅진성·사비성·고사부리·국원·사벌·금성 좌표를 확인합니다.
6. 지역 선택, 인접 공격, 턴 종료, 저장 및 불러오기를 확인합니다.

새 저장 경로는 `user://campaign_save_35_regions_v1.json`입니다.

## 보존한 기존 기능

- 중국·일본·유목 지역 및 지도 표식
- `get_steppe_diplomacy()`
- `get_world_overrides()`
- `get_world_officer_assignments()`
- 기존 9개 핵심 도시의 경제·병력·장수 수치
- 기존 시나리오 데이터와 새 게임 설정 화면
