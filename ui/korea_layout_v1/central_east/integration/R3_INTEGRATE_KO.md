# 현재 검증된 r2에 r3 보충 원화 연결

## 추가하는 자료

- `assets/central_east_detail_r3.png` — 1536×1024, 새 원화.
- `data/central_east_r3_fill_mesh.json` — 같은 `(512,544,264,176)` 범위. UV가 항등변환이다.

원본 전체 지도와 r2 후보 PNG·`central_east_display_mesh.json`은 이전과 동일하다. 실제 프로젝트의 검증된 보조 스크립트가 `configure()` / `draw_on()` 인터페이스를 유지하면 재사용한다. 프로젝트에서 수정한 버전을 이 ZIP의 예전 참고본으로 덮어쓰지 않는다.

## 호출 예시

실제 프로젝트의 경로와 기존 변수명에 맞춘다. 아래 코드는 새 원화의 바탕 레이어를 초기화하고 그리는 부분이다.

```gdscript
# 기존 r2에 사용한 preload 상수 재사용.
var _r3_fill = CentralEastDisplayLayer.new()

# 준비 시 1회. 실패하면 기존 r2 상태를 유지하고 오류를 보고한다.
func _prepare_r3_fill() -> void:
    var loaded: bool = _r3_fill.configure(
        "res://ui/korea_layout_v1/central_east/central_east_r3_fill_mesh.json",
        "res://ui/korea_layout_v1/central_east/central_east_detail_r3.png"
    )
    if not loaded:
        push_error(_r3_fill.last_error)
```

기존 `_draw()`의 비교 모드 분기에서:

```gdscript
# 승인 전체 지형은 이미 그린 상태.
var map_rect: Rect2 = _get_displayed_map_rect()
if r3_comparison_enabled:
    _r3_fill.draw_on(self, map_rect, 1.0)
# 기존 r2 보정 그리기를 바로 이어서 수행.
_central_east_display.draw_on(self, map_rect, 1.0)
# 기존 영토·경로·성·글자를 이어서 그림.
```

변수명·경로·기존 비교 조건을 그대로 복사하라는 뜻이 아니다. 현재의 r2 코드에 맞춰 연결한다. r3 토글을 끄면 기존 r2만 그려야 한다. 원본/미보정 후보 모드에 r3 바탕을 남기지 않는다.

## 가장 중요한 두 조건

1. **r3 새 PNG에 r2의 변형 UV를 쓰지 않는다.** r3는 원본 표시 좌표를 바탕으로 그린 이미지다. 새 fill JSON의 항등 UV를 사용한다. r2 JSON을 새 PNG와 묶으면 이중 보정으로 물길이 다시 이동한다.
2. **r2보다 아래에 그린다.** 위에 그리면 새 이미지의 전체 영역이 r2를 덮는다. 의도는 r2의 선명한 부분을 그대로 두고, 원본으로 되돌리던 부분만 세부 묘사로 보충하는 것이다.

새 망도 67×45 정점이다. 외곽 alpha는 0이며 내부 바탕은 불투명하다. r2가 alpha 1인 곳의 최종 픽셀은 바뀌지 않는다. 선택 좌표와 입력 처리는 기존 코드에 그대로 남긴다.

## 비교 화면 및 실행 확인

- 기존 보정 비교에 r3를 임시 비교 옵션으로 연결한다. 현재 r2로 돌아갈 수 있게 한다. 정식 캠페인의 자동 LOD는 **현재처럼 꺼둔다**.
- 1280×720·1920×1080, 기존 보고와 같은 위치·5배율에서 r2/r3를 대조한다.
- 국원 남쪽 지류·출구, 북한산성 합류점, 당항성 서해안, 하슬라~실직 해안을 확인한다. 선명도와 물길 위치는 따로 평가한다.
- 강의 이중 윤곽, 남는 물길 차이, 성 바닥과 물가 겹침을 캡처한다. 성을 옮겨 숨기지 않는다.
- 현재 코드에서 이미 고친 재열기 카메라 유지가 보존되는지, 선택·지원 경로가 지형 위에 표시되는지 확인한다.
- 원화 전체 정합·35곳 성 바닥·영토 경계·세계 접합·자동 LOD 완료로 보고하지 않는다.

## 실제 검증 범위

이번 환경의 별도 표시 코드에서 상세 사각형 밖의 픽셀과 r2가 불투명하게 그리는 영역의 픽셀은 모두 유지됐다. 이는 Godot 실행 결과가 아니다. 기존 r2의 56건 통과는 사용자 보고이고, r3는 실제 프로젝트에서 확인해야 한다.
