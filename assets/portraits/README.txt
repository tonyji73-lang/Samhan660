이 폴더는 인물 초상화 PNG들이 들어가는 곳입니다.

- 이미지가 없어도 절대 에러가 나지 않습니다. map_area.gd의 _get_portrait_texture()가
  ResourceLoader.exists()로 먼저 확인하고, 없으면 이니셜 글자(예: "김")로 대체해서
  그립니다.

- 실존 인물 초상화 파일명은 scenario_data.gd / map_area.gd 안의 PORTRAIT_PATHS,
  RULER_PORTRAIT_PATHS 딕셔너리에 나열되어 있습니다 (예: kim_yushin.png, gyebaek.png 등).

- 초상화가 없는 태수/장수에게는 자동으로 아래 형식의 "무명 장수" 그림이 배정됩니다
  (이름을 해시해서 결정론적으로 고르므로 같은 인물은 항상 같은 얼굴):
    warrior_male_01.png ~ warrior_male_08.png
    strategist_male_01.png ~ strategist_male_08.png
    warrior_female_01.png ~ warrior_female_08.png
    strategist_female_01.png ~ strategist_female_08.png
  (총 32장, 없어도 무방합니다.)
