# 현재 지도 코드에 표시 보정 추가

## 적용 파일

| 파일 | 역할 |
|---|---|
| `central_east_display_layer.gd` | `_draw()` 안에서만 호출하는 보조 객체 |
| `../data/central_east_display_mesh.json` | 규칙적인 화면 망의 UV·색감·투명도 |
| `../assets/central_east_detail_candidate.png` | 기존과 동일한 상세 후보, 이미 있으면 해시 확인 후 재사용 |

이 묶음은 최신 `approved_korea_map.gd`나 `settlement_overlay.gd` 전체를 포함하지 않는다. 현재 프로젝트의 코드에 연결 부분만 추가한다.

## 연결 형태

아래 경로는 예시다. 실제 프로젝트에서 이미 사용하는 `central_east/` 위치에 맞춘다.

```gdscript
const CentralEastDisplayLayer = preload("res://ui/korea_layout_v1/central_east/central_east_display_layer.gd")
var _central_east_display = CentralEastDisplayLayer.new()

# 기존 준비 과정에서 1회 실행. 프레임마다 다시 만들지 않는다.
func _prepare_corrected_detail() -> void:
    var loaded: bool = _central_east_display.configure(
        "res://ui/korea_layout_v1/central_east/central_east_display_mesh.json",
        "res://ui/korea_layout_v1/central_east/central_east_detail_candidate.png"
    )
    if not loaded:
        push_error(_central_east_display.last_error)
```

기존 `_draw()`에서 승인 원본을 그린 직후, 영토·지원 경로·성·글자보다 먼저 호출한다.

```gdscript
# 기존 승인 지도 draw_texture_rect(...) 뒤에 삽입.
# 이 조건명은 현재 비교 화면의 상태에 맞춰 구현한다.
if corrected_comparison_selected:
    _central_east_display.draw_on(self, _get_displayed_map_rect(), 1.0)
# 기존 영토, 경로, 성, 글자 그리기는 그대로 이어진다.
```

`_get_displayed_map_rect()`는 **전체 1254×1254 승인 지도**가 현재 Control 좌표에서 차지하는 Rect2다. 화면 전체의 사각형이나 상세 후보만의 사각형을 넘기지 않는다. 기준 좌표 `(512, 544, 264, 176)`에서 같은 변환을 적용하므로 성을 옮길 필요가 없다.

- 원본/기존 후보/보정 후보 중 하나만 활성화한다. 기존 상세 사각형과 보정 망을 동시에 그리지 않는다.
- 보조 객체는 멤버 변수로 보관한다. 임시 로컬 변수로 만들고 버리면 지연 그리기에 필요한 mesh/texture 수명이 끝날 수 있다.
- 별도 최상위 자식 Control로 덧붙이면 경로와 성을 덮을 수 있다. 호스트 `_draw()`의 순서로 연결한다.
- 선택·드래그·휠 입력은 기존 코드가 처리한다. 이 보조 객체는 입력을 받지 않는다.
- 새 후보 파일의 로드 해상도는 1536×1024를 유지한다. 기존 필터·밉맵 정책을 확인하고, 이 작업 때문에 다른 자산의 import 설정을 일괄 변경하지 않는다.
- 현재 비교용 토글에서 사용한다. `automatic_lod_approved` / `production_auto_switch_allowed`는 false를 유지한다. 이 코드에는 자동 LOD 활성화 기능이 없다.

## 처리와 한계

67×45 정점이 만드는 5,808개 삼각형은 원본 좌표에서 고정돼 있다. 각 정점의 UV만 달라져 상세 그림의 수계를 원본 쪽으로 옮긴다. 정점 RGB는 넓은 영역의 색감 차이를 줄이고, alpha는 가장자리 및 잔여 수계 불일치 구간에서 원본을 드러낸다. 성 좌표·성 크기·영토 폴리곤·길찾기·월 결산·저장은 읽거나 수정하지 않는다.

전체 이미지의 상세화 완료를 뜻하지 않는다. 국원 남쪽 지류와 되돌림 구간은 흐림이 남는다. 기존 산줄기와 상세 산 그림의 완전한 정합, 성 바닥 전체 검증도 남는다.

## 필요한 실제 게임 확인

- Godot 스크립트 로드 및 실제 망 렌더링. 이 환경에서는 GDScript 실행을 하지 못했다.
- 1280×720 / 1920×1080, 보고에 사용한 같은 위치·5배율에서 세 상태 캡처. 넓은 배율에서 사각 테두리, 확대에서 물길 이중상·지형 늘어짐도 확인.
- 북한산성 북서 합류점, 당항성 서쪽 만·반도, 국원 남쪽 강 출구, 하슬라~실직 해안 대조.
- 기존 6개 거점 좌표 불변, 성·글자·지원 경로가 지형 위에 표시되는지 확인.
- 비교 토글/닫기/재열기와 기존 선택 유지. 실제 변경 영향이 있는 지도 회귀만 수행.

## API 근거

Godot의 [CanvasItem.draw_mesh](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-draw-mesh)는 텍스처를 사용해 2D 망을 그릴 수 있다. 정점·UV·색·인덱스는 [Mesh 배열 형식](https://docs.godotengine.org/en/stable/classes/class_mesh.html)을 따르며 [ArrayMesh.add_surface_from_arrays](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html#class-arraymesh-method-add-surface-from-arrays)로 구성한다. 실제 프로젝트 버전의 동작 확인은 별도다.
