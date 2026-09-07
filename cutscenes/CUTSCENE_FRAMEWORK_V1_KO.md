# 삼한660 이벤트·컷씬 프레임워크 v1

## 목표

`EventPresentation` 하나로 세력 오프닝, 내정 이벤트, 침공 경보, 전투 컷인,
역사 이벤트와 튜토리얼을 표시한다. 컷씬마다 별도 코드를 만들지 않고
`cutscene_catalog_v1.json`의 장면 데이터만 추가한다.

## 권장 구조

- `EventPresentation`: 외부 시스템이 호출하는 공통 진입점
- `CutsceneDirector`: 장면 단계 진행, 자동 재생, 건너뛰기와 입력 잠금 관리
- `CutsceneView`: 배경, 초상화, 제목, 대사, 결과 수치와 버튼 표시
- `MapCinematicAdapter`: 지도 이동·확대, 지역 점멸, 이동 경로와 세력색 연출
- `CutsceneAudio`: 음악 전환, 북소리, 봉화, 군중, 전투 효과음 관리
- `EventSettings`: `전체 / 중요 이벤트만 / 최소` 표시 정책 관리

## 표시 계층

1. 전체 화면 배경: Illustrated Cutscene 또는 실시간 지도
2. 색조·암전 오버레이
3. 좌·우 Portrait 또는 장면 속 인물
4. 제목·연도·지역 표시
5. 화자명·대사·효과 수치
6. `다음 / 건너뛰기 / 자동 진행` 조작부

생성된 일러스트에는 글자를 넣지 않았다. 한글 제목과 대사, 병력 및 보상 수치는
항상 Godot UI가 표시해야 번역과 수치 변경이 가능하다.

## 화면 기준

- 기준 비율: 16:9
- 원본: `illustrated/*.png`, 1672×940~941
- 게임용: `game_ready/*.webp`, 1920×1080, 품질 92
- 권장 게임 표시: WebP를 `KEEP_ASPECT_COVERED`로 채우고 가장자리만 안전하게 자름
- 대사창 안전 영역: 화면 하단 약 22~25%
- 이미지 경로 권장: `res://assets/cutscenes/illustrated/<file>.webp`
- 인물 초상 경로: `res://assets/portraits/<portrait>.png`

## v1 콘텐츠

| ID | 형식 | 발동 | 핵심 연출 | 이미지 |
|---|---|---|---|---|
| `silla_660_intro` | Illustrated + Map | 660년 신라 시작 | 김춘추 → 금성에서 백제 방향 이동 | `silla_660_intro.webp` |
| `baekje_660_intro` | Illustrated + Map | 660년 백제 시작 | 의자왕·계백 → 국경 경보 | `baekje_660_intro.webp` |
| `goguryeo_660_intro` | Illustrated + Map | 660년 고구려 시작 | 연개소문 → 평양·당 국경 긴장 | `goguryeo_660_intro.webp` |
| `domestic_bountiful_harvest` | Illustrated | 가을 수확 대성공 | 풍년 표제 → 군량·치안 증가 | `domestic_bountiful_harvest.webp` |
| `enemy_invasion_alert` | Map + Illustrated | 적군이 국경 진입 | 대상 영지 이동·적색 점멸 → 파발 | `enemy_invasion_alert.webp` |
| `battle_hwangsanbeol` | Battle | 김유신군과 계백군 조우 | 장수 대치 → 병력 표시 → 전투 결과 | `battle_start_hwangsanbeol.webp`, `battle_result_generic.webp` |

## 공통 호출 규약

다른 시스템은 연출 구현을 직접 알 필요 없이 다음 정보만 넘긴다.

```gdscript
EventPresentation.play(
    "domestic_bountiful_harvest",
    {
        "province_name": "금성",
        "grain_delta": 1200,
        "public_order_delta": 3,
    }
)
```

전투 호출 예시:

```gdscript
EventPresentation.play(
    "battle_hwangsanbeol",
    {
        "attacker_name": "김유신",
        "attacker_troops": 15000,
        "defender_name": "계백",
        "defender_troops": 10000,
        "battle_grade": "대승",
        "attacker_losses": 2800,
        "defender_losses": 9100,
    }
)
```

## 재생 규칙

- 첫 입력 시 자동 진행은 꺼진 상태로 시작한다.
- `다음`은 현재 문장을 즉시 완성한 뒤 다음 단계로 이동한다.
- `건너뛰기`는 컷씬을 종료하지만 게임 결과 적용을 취소하지 않는다.
- 결과 수치와 영토 변경은 연출과 분리하여 게임 시스템이 한 번만 적용한다.
- 컷씬 재생 중 지도 입력과 턴 진행은 잠그되 일시정지 메뉴는 허용한다.
- 저장·불러오기 직후 같은 일회성 오프닝이 다시 재생되지 않도록 완료 ID를 저장한다.

## 이미지 제작 기준

- 이름 있는 인물은 `/삼한660/Portrait`의 해당 원본을 얼굴·나이·수염·머리·복식 기준으로 사용한다.
- 같은 인물을 새로 해석하거나 서로 다른 장수의 얼굴을 섞지 않는다.
- 고우영풍에 가까운 강한 먹선, 한지 질감, 절제된 광물 안료 색을 유지한다.
- 7세기 한국 건축·갑주·의복을 사용하고 조선시대 관모와 서양식 갑옷은 제외한다.
- 글자·수치·UI는 이미지에 직접 넣지 않는다.

## 구현 순서

1. 공통 뷰와 Director 제작
2. `silla_660_intro`로 다음·건너뛰기·자동 진행 검증
3. 지도 카메라 어댑터 연결 후 세력 오프닝 3종 검증
4. 풍년 이벤트로 동적 변수와 결과 수치 검증
5. 침공 경보로 지도 점멸과 입력 잠금 검증
6. 황산벌 전투로 좌우 장수·병력·결과 단계 검증
7. 설정에 이벤트 연출 수준 추가
