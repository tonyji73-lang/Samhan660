# 대련·연태 지역 원화, 2026-10-02

- 제작: 내장 `image_gen` (CLI/API 별도 사용 없음). 사용자 첨부 현대 지도는 해안 윤곽 참고, 기존 atlas는 화풍 참고. 현대 국경·시설·도시를 새 게임 데이터로 추가하지 않음.
- `bohai.png`: 발해·요동·산둥 지역 바탕. 표시 영역 `Rect2(-650,-100,1000,1000)`은 기존 플레이 지도 native 좌표이며 위경도 투영이 아님.
- `bohai_join.png`: 실제 연결한 최종 바탕. 남쪽 외곽을 기존 중국 지도와 이어지도록 보완. 최초 바탕은 제작 이력으로 보존.
- `dalian.png`, `yantai.png`: 바탕의 각각 `(300,300,350,350)`, `(220,520,350,350)` 영역을 참조한 1254×1254 확대 묘사. 생성된 해안 변형은 `detail.gdshader`의 바탕 수면 보호로 제한. 지형 판정·게임 규칙에 사용하지 않음.
- 연결: `../unified_world_20261002/unified_ground.gd`. 이전 atlas와 확대 타일은 삭제·덮어쓰기하지 않음. 한반도 원본·성 좌표·남부/제주 자산은 유지.

## 제작 프롬프트 사양

Base: North-up top-down cartographic game terrain patch, Bohai Sea, Liaodong Peninsula tapering southwest to Dalian, Shandong Peninsula projecting east with Yantai on its north coast and Weihai at its east tip. Open Bohai Strait with a sparse Changshan island chain, no land bridge. Use the user's real geographic map for geography and the existing East Asia atlas for golden green painted relief/deep blue sea style only. No text, cities, borders or UI. Dalian normalized (0.51,0.53), Yantai (0.43,0.70), Weihai (0.53,0.73), Dandong (0.85,0.34). Bohai basin centered (0.26,0.38). Requested 3584 square; actual tool output 1254 square, so separate detailed region tiles are used rather than claiming the base has that requested resolution.

Detail (each guide separately): Upscale and refine this exact square terrain map crop into a crisp 1254×1254 game zoom tile. Strictly preserve normalized coastline, island, cape, water gap and ridge coordinates. No recomposition, zoom or rotation. Add small trees, rock faces and fine grass/water texture in the existing palette. No labels, roads, cities, buildings or UI. Match all four edges.

Southern join refinement: Preserve upper 83% of the base; extend only the bottom 17% mainland coast southeast to x=.62 at the bottom edge, following x=.34 at y=.84 and x=.48 at y=.92, to meet the existing adjoining atlas. Match golden green terrain and navy/turquoise water. This transition is a game-atlas join, not surveyed coastline data.

## Limits

The recognizable two-peninsula relationship is an illustrated correction based on the reference, not GIS-registered or historically surveyed geography. The southern outer join and the unchanged rest of China retain the old atlas's geographic limitations. Focus zoom detail covers Dalian/Yantai, not every part of China. Verification evidence: `tests/bohai_20261002/`.
