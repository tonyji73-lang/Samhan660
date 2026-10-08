# 확대 누락 구역 보완 — 2026-10-06

- 내장 image_gen으로 제작. 기존 지도/발해 남쪽 합성 화면에서 같은 native 구역을 잘라 위치 참조로 사용했다. 원본 자산은 변경하지 않았다.
- `manifest.json`: 발해 지역 7장과 서해 섬 2장. 각 1254² 픽셀 / native 350², 최대 확대 3.5 screen pixel/native에 대응한다. 단순 확대 저장·샤프닝 필터만 적용한 자산이 아니다.
- 기존 발해 두 타일의 수면 판정은 해안까지 저해상도 바탕으로 대체했고, 남쪽 상세를 끄는 처리는 넓은 흐린 띠를 만들었다. 새 구역에는 해안/수면을 포함한 상세를 사용하며 내부 25 native 겹침은 한쪽만 전환해 바탕 노출을 피한다. 열린 바다로 끝나는 외곽만 전환한다.
- 기존 35개 성 좌표·사용자 저장·게임 규칙에 사용하지 않는 표시 전용 자산이다. 지형 측량/해안선 정확도의 신규 검증을 의미하지 않는다. 모든 세계 지도의 확대 원화를 재제작한 것은 아니다.
- 실제 게임 비교/검증: `tests/map_detail_20261006/`. 구역별 제작 참조와 수정 전 표시 코드도 보존했다.

## 공통 제작 프롬프트 (각 참조 구역에 별도 호출)

Refine this EXACT square game terrain tile into a crisp detailed 1254x1254 zoom tile. Preserve ALL geography and exact normalized coordinates: land and water silhouette, island count/size/location, shoreline, river course, mountains, every feature at all four edges. No zoom, rotation, crop, new islands, roads, structures or text. Match existing golden green painted strategy-game relief and deep blue sea with turquoise shallows. Add genuinely small detailed trees, rocks and vegetation on land, sharply resolved rocky sandy shoreline, restrained fine wave texture on sea. Absolutely no soft blurry coastline or blur halo. Do not redesign broad shapes or change lighting/color. Preserve the original framing pixel-for-pixel in normalized coordinates; only supply missing fine detail. It will be tiled against other crops of same map, so keep ALL boundary features aligned.
