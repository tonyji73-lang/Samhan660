이 폴더에 아래 두 이미지를 넣으면 지도가 정상적으로 표시됩니다.

1. samhan660_east_asia_korea_center_6144x4096.png  [아직 없음]
   - 캠페인 지도 배경 원본 이미지 (6144x4096 권장)

2. samhan660_territory_id_map_35.png  [적용 완료]
   - 35개 전략 지역을 색상 ID로 구분한 마스크 이미지
   - territory_material 셰이더가 이 이미지를 읽어 세력별 영토 색과 경계선을
     정확하게 칠합니다 (알파 채널 = 지역 ID, 그린 채널 = 경계 픽셀).
