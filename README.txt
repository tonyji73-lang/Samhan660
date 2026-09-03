삼한660 - 오늘 정리한 최종 파일 세트 (9개)
=================================================

이 zip 안의 9개 파일을 프로젝트 루트에 전부 덮어쓰시면 됩니다.
(9개를 부분적으로만 적용하면 다시 파싱 에러가 날 수 있으니, 꼭 다 같이 교체해주세요)

battle_overlay.gd          - 전술 전투 화면 (병종/장수 특성 시스템 포함)
campaign_main.gd           - 전투/내정 연결, 1턴=1달, 로스터 기반 병종 판정
domestic_overlay.gd        - 내정 화면 (원본 그대로, 버튼 연결만 campaign_main.gd에서 새로 함)
korea_35_data.gd           - REGION_BORDERS 빈 딕셔너리 추가 (한국 35개 지역 경계선 좌표는 추후 필요)
map_area.gd                - 국경선 렌더링 병합 충돌 정리
new_game_setup.gd          - 병합 충돌 정리
samhan_strategy_systems.gd - 원본 그대로 (건물/연구/모병 밸런스 검토 완료)
scenario_data.gd           - 원본 그대로
world_map_data.gd          - OUTSIDE_REGION_BORDERS + 전투배경 크롭 + 1턴=1달 이동시간 보정

[배포 전 검증 항목 - 전부 통과]
- 9개 파일 전부 병합 충돌 마커 없음
- 9개 파일 전부 괄호/들여쓰기 문법 통과
- 파일 간 참조(Korea35Data/WorldMapData/ScenarioData/SamhanStrategySystems/
  DomesticOverlay/BattleOverlay) 전부 실제 정의와 대조 완료, 누락 없음
- 각 파일 내 중복 함수 없음

[알려진 제한사항]
- korea_35_data.gd의 REGION_BORDERS가 비어있어서, 한국 지역 국경선은
  아직 안 그려집니다 (중국/일본 국경선은 정상 표시됨). 실제 좌표
  데이터 작업은 별도로 진행해야 합니다.
- 내정 화면(domestic_overlay.gd) 여는 버튼이 .tscn에 아직 없습니다.
  campaign_main.gd에 _open_domestic_overlay(province_id) 함수는
  준비되어 있으니, 씬 에디터에서 버튼 만들어 이 함수에 연결해주세요.
- main.gd/main.tscn은 미사용 파일로 확인되어 이 세트에서 제외했습니다.
  (삭제하셔도 안전합니다)
