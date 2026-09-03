삼한 660 캠페인 - 프로젝트 안내
================================

화면 흐름
---------
title_screen.tscn (타이틀)
  -> new_game_setup.tscn (시나리오/세력/난이도/플레이스타일 선택)
      -> campaign_main.tscn (실제 캠페인 화면: 지도 + 영지 상세정보 + 개발/징병/공격)
          -> (공격 버튼) battle_overlay.gd 가 만드는 전술 전투 오버레이

핵심 스크립트
-------------
- title_screen.gd / title_screen.tscn        : 타이틀 화면
- new_game_setup.gd / new_game_setup.tscn    : 세력 선택 화면 (씬은 최소 구조,
  UI는 스크립트가 코드로 직접 구성합니다)
- campaign_main.gd / campaign_main.tscn      : 캠페인 메인 화면
- map_area.gd                                : campaign_main.tscn 안에 내장된
  지도 컨트롤 (campaign_main.tscn이 이미 CampaignMapBackground와 지역별
  버튼들을 갖고 있어서 별도 .tscn 없이 바로 붙습니다)
- samhan_strategy_systems.gd (RefCounted)    : 내정/모병/외교/전략 계산 백엔드
- domestic_overlay.gd (Control)              : 영지 내정 화면 오버레이
- battle_overlay.gd (Control, class_name BattleOverlay) : 전술 전투 화면
- world_map_data.gd / scenario_data.gd / korea_35_data.gd : 공용 데이터

데이터 전달 방식
----------------
new_game_setup.gd가 "게임 시작"을 누르면
  get_tree().root.set_meta("new_game_settings", {...})
로 세력/난이도/플레이스타일/시나리오 정보를 심어두고 campaign_main.tscn으로
전환합니다. campaign_main.gd의 _ready() -> _apply_new_game_settings()가
그 메타를 읽어서 게임을 시작합니다.

지금 없는 것 (선택 사항, 없어도 에러 없이 실행됩니다)
------------------------------------------------------
- assets/maps/ 안의 실제 지도 배경 PNG 2장 (README 참고)
- assets/portraits/ 안의 인물 초상화 PNG들 (README 참고)
- title_background_samhan660.jpg : 지금은 제가 만든 임시 단색 그라디언트
  이미지가 들어가 있습니다. 실제 타이틀 배경 그림으로 교체하세요.
- res://assets/audio/title_theme.mp3, setup_theme.mp3 : 배경음악 (없으면
  그냥 무음으로 실행됩니다)
- res://campaign_map_9_regions.png, res://campaign_map.png : new_game_setup.gd가
  일부 화면에서 대체 지도 이미지로 시도하는 경로입니다 (없어도 안전하게
  건너뜁니다)

실행 방법
---------
Godot 4.3 이상에서 이 폴더를 "프로젝트 임포트"로 열면 project.godot 설정에
따라 title_screen.tscn부터 바로 시작됩니다.
