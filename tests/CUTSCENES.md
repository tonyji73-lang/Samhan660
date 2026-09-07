# 컷씬 프레임워크 v1

기반: `feature/trade-system-v1`의 `0b70001`. 구현 브랜치는
`feature/cutscene-framework-v1`이며 commit/push/merge는 하지 않았다.
전달 자료의 요구사항은 `cutscenes/CUTSCENE_FRAMEWORK_V1_KO.md`에 보존했다.

## 구조와 호출

- `cutscenes/event_presentation.gd`: 캠페인에 하나만 생성하는 서비스 겸 Director.
  Autoload나 이벤트별 Scene은 추가하지 않는다. 순서·모드·문구·초상화·결과는
  단일 `cutscene_catalog_v1.json`에서 읽는다.
- `cutscene_view.gd`: Illustrated / dialogue / map / battle_vs / result 공통 UI.
  하단 25%에 대사·수치·다음/건너뛰기/자동 진행/메뉴를 배치한다.
  첫 다음은 진행 중인 문장을 완성하고, 문장이 완성된 상태의 다음은 단계를 넘긴다.
- `map_cinematic_adapter.gd`: 기존 MapArea의 표시용 zoom/pan만 애니메이션하고,
  읽어 온 도시 위치·경계에 별도 점멸·경로를 그린다. 종료/건너뛰기/불러오기 때
  카메라와 도시 카드 및 입력을 복구한다. 원본 경계·좌표·세력은 변경하지 않는다.
- 본게임 연결: 새 게임 설정 소비 후 해당 660년 세력 오프닝, AI의 플레이어 도시
  공격 경보, 기존 공격 계산의 김유신(공격)–계백(수비) 대치 및 결과.
  전투 장수 조건은 JSON trigger에 있으며 진행 코드에 컷씬 ID 분기가 없다.

캠페인 노드의 공통 진입점:

```gdscript
# 호출자가 먼저 실제 결과를 한 번 확정한다. 아래 호출은 표시만 한다.
event_presentation.play("domestic_bountiful_harvest", {
    "province_name": province_name,
    "grain_delta": actual_grain_delta,
    "public_order_delta": actual_order_delta,
}, unique_event_occurrence_id)
```

`dispatch(context, payload, occurrence_id)`는 JSON의 trigger 모든 필드가
일치하는 이벤트를 찾아 같은 play 경로를 사용한다. 알 수 없는 ID와 필수 동적
값 누락은 false를 반환하며 입력을 잠그지 않는다. 여러 이벤트는 순서대로 재생한다.
일반 반복 이벤트의 세 번째 인수는 **발생 건별** 고유 ID이며 연출 재요청 중복을 막는다.
외부 시스템의 보상 중복 방지 책임을 대신하는 API는 아니다.

## 게임 결과와 저장

연출은 군량·금·치안·병력·영토를 쓰지 않는다. 기존 즉시 전투 계산을 그대로 한 번
끝낸 뒤, 확정된 병력·손실 값을 표시한다. 따라서 전투 시작 컷인과 결과 사이에
새 전술 전투를 실행하지 않으며 건너뛰기나 연출 최소 설정이 전투를 취소하지 않는다.
승리 시 수비 병력은 기존 계산에서 전부 교체되므로 수비측 피해 표시는 전장에서
제거된 병력이며, 별도로 전사/포로를 나누는 새 규칙을 도입하지 않았다.

기존 저장의 선택 필드 `event_presentation`에 다음을 보관한다.

- `completed_ids`: 일회성 이벤트의 소비 기록. 접수 시 먼저 기록하므로 오프닝
  중간에 저장하거나 표시 정책으로 생략해도 다시 나타나지 않는다.
- `occurrence_ids`: 호출자가 지정한 발생 ID의 소비 기록.
- `display_level`: `all` / `major` / `minimal`.

불러오기는 현재 연출/큐를 닫고 기록만 복원한다. 보상·생산·밀린 이벤트·오프닝을
실행하지 않는다. 구형 저장은 빈 연출 기록을 기본으로 쓰며 새 게임용 발동 경로를
호출하지 않는다. 원래 저장 형식과 무역·생산 장부는 그대로다.

컷씬 동안 전체 화면 UI가 지도 클릭을 차단하며 MapArea 입력 처리와 턴/도시 선택
명령도 검사한다. Esc 또는 컷씬의 메뉴 버튼으로 기존 캠페인 메뉴를 사용할 수 있다.
메뉴/확인 창이 열려 있으면 글자·자동 진행·카메라를 멈춘다. 기존 메뉴에 추가된
`이벤트 연출 → 전체 / 중요 이벤트만 / 최소`에서 표시 정책을 선택한다.

## 전달 자료와 명시적인 제한

- ZIP의 game_ready WebP 7개만 `assets/cutscenes/illustrated/`에 설치했다.
  고해상도 PNG와 미리보기 PNG는 추출하지 않았다. 초상화는 기존
  `assets/portraits/`의 김춘추·김유신·계백·연개소문 파일을 참조한다.
- 음악/효과음 ID는 전달받았지만 해당 음원이 없어 현재 무음이다.
  JSON `audio_cues`에 실제 리소스 경로를 등록하면 공통 AudioStreamPlayer가 사용한다.
- JSON `tang_east_border`는 기존 산동항을 당 방면의 연출 기준점으로 사용한다.
  `baekje_west_coast`는 임존성·웅진성·사비성의 서부 권역 점멸로 표시한다.
  실제 국경/해안 좌표를 새로 정의하지 않았으며 정밀 해안선 효과는 아니다.
- 프레임워크 v1 이후 풍년 API를 실제 9월 수확에 연결했다.
  판정·보상·저장 호환과 본게임 확인 경로는 [BOUNTIFUL_HARVEST.md](BOUNTIFUL_HARVEST.md)를 참조한다.
  정상 수확 45% 징수·9월 70%/10월 30% 계산은 그대로다.
- `battle_hwangsanbeol`은 두 장수의 대치 템플릿이다. 기존 캠페인에는 황산벌 전장 ID가
  없으므로 장수 조합으로 연결하고 임의의 새 역사 전투/도시 좌표를 배치하지 않았다.
  AI 경보는 기존 AI 공격 판정에서 발동하며 새로운 국경 통과 이동 시스템은 아니다.

## 직접 확인

1. 본게임 새 캠페인 → **660년** → **신라 / 백제 / 고구려** 중 하나 → 시작.
   각 세력의 Illustrated → 인물 대화 → 지도 단계가 나온다.
   F6로 `campaign_main.tscn`만 직접 실행하면 새 게임 오프닝을 발동하지 않는다.
2. 에디터에서 `tests/cutscene_preview.tscn`을 열고 **F6**.
   드롭다운에서 6개 이벤트 중 선택 → **선택한 컷씬 재생**.
   이 씬은 본게임 메뉴에서 연결되지 않는 독립 검증 환경이다.
3. 풍년: `domestic_bountiful_harvest` 선택 → 지역명·군량·치안 값을 입력 → 재생.
   프리뷰의 치안 증가량 기본값은 0이며 결과에 **치안 100 · 최대치**를 표시한다.
   예: **금관가야 / 777 / 4** → 다음 → **군량 +777, 치안 +4**.
   수치는 표시용이며 실제 캠페인 재고에 지급되지 않는다.
4. 침공: `enemy_invasion_alert` → 재생 → 사비성 이동·붉은 점멸 확인 → 다음.
   **신라군 15000명 / 사비성**의 파발 화면을 확인한다.
   Esc 메뉴를 열고 닫은 뒤 건너뛰어 지도 입력이 복구되는지 확인한다.
5. 전투: `battle_hwangsanbeol` → 재생 → **김유신 15000 대 계백 10000** → 다음.
   결과는 **대승 / 아군 -2800 / 적군 -9100**인 검증용 표시 데이터다.
   자동 진행으로도 시작→결과→종료를 확인한다.

## 검증

프로젝트 루트에서 Godot 4.7.2로 실행한다.

```text
godot --headless --path . --script res://tests/cutscene_test.gd
godot --headless --path . --script res://tests/production_test.gd
godot --headless --path . --script res://tests/geumgwan_ownership_test.gd
git diff --check
```

컷씬 테스트는 별도 캠페인 인스턴스와 OS 임시 저장 파일을 사용한다.
장수 배치/AI 공격 검증용 설정은 테스트에서만 수행한다. 기존 생산·소유권 회귀는
일반 표시 설정 `minimal`로 오프닝만 생략하여 원래 검증 대상을 유지한다.

헤드리스 검증: 컷씬 80개, 생산 193개, 소유권 181개.
동적 수치, 일회성/발생 ID 저장 복원, 입력 잠금, 큐, 결과 중복 적용 방지,
자원 불변, 카메라 복구와 종료된 Tween의 재생 방지를 포함한다.
Windows 인증서 저장소 오류는 기존 환경 메시지로 분리한다.

실제 창 1280×720에서 세 세력 오프닝, 백제 초상/지도, 풍년 777/4,
침공 사비성 점멸·Esc, 김유신/계백 대치·결과 화면을 확인했다.
버튼 신호와 키 입력으로 다음/건너뛰기/자동 진행을 조작했고,
수정 후 고구려 오프닝과 전투 자동 진행을 자연 시간으로 끝까지 확인했다.
캡처와 실행 로그는 `.godot/` 등 로컬 검증 산출물로만 취급한다.
