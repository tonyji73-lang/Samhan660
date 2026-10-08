# Living City V1.3 — 장식 자산 제작 준비

작성: 2026-09-29. 기준: 현재 V1.2, 632년 신라·금성. **게임 화면·기능·폰트·자산 연결 변경 없음.** 이번 산출물은 조사·규격 문서와 작은 검토 묶음이다. 기존 미커밋 작업, 보호 파일, 원래 검증 자료를 보존했으며 stage/commit/push/merge하지 않았다. 작업 경로와 상위 경로에서 별도 AGENTS.md는 발견되지 않았다.

## 기준과 조사 방법

`tests/LIVING_CITY_UI_V1_2.md`, 현재 UI·테마·폰트 자료를 확인했다. 승인된 1번 시안은 `dev/living_city_ui_v1_1_source/samhan660_living_city_ui_v1_1/reference/domestic_default.png` 및 `approved_personnel.png`이다. 두 시안과 현재 네 캡처를 직접 열어 비교했다. 시안의 642년 예시 값은 실제 632년 데이터와 구분한다.

현재 화면은 시안의 목재/금속 장식 대신 단색 면과 선을 사용한다. 날짜/자원도 독립 장식 칸이 아니라 한 Label에 들어 있다. 시안의 후보 선택 광택·모서리 문양, 붉은 버튼의 양끝 장식, 제목 아래 장식선은 아직 독립 자산으로 없다.

아래 실제 크기는 게임을 변경하지 않고 정상 새 캠페인에서 노드 레이아웃만 읽은 값이다. Godot `canvas_items` 논리 좌표 1920×1080, 720p 배율 2/3. 소수점은 레이아웃 좌표이며 실제 래스터 경계는 픽셀 반올림된다. 표의 **권장 자산 크기·분할 폭은 제작 제안**으로, 현재 적용된 값이 아니다. 모두 1080p 기준 1배 PNG 캔버스 크기다.

## 자산별 규격과 연결 위치

공통 구현은 `domestic_assignment_overlay.gd`(이하 Overlay), `ui/living_city_v1/living_city_theme.gd`(CityStyle), `ui/light_atlas_v1/atlas_theme.gd`(Atlas)이다. 대부분의 노드는 코드에서 생성되어 `.tscn`에 독립 장식 노드가 없다.

| 항목 | 실제 노드/연결 위치 | 실제 720p / 1080p 크기(px) | 현재 자산·재사용 | 권장 제작 크기 / 투명 배경 |
| --- | --- | --- | --- | --- |
| 상단 국가·날짜·자원 전체 프레임 | Overlay `_ready()`의 `top_panel`(98행), `header`; CityStyle `panel(true)` | 1280×52 / 1920×78 | StyleBoxFlat 어두운 면·금색 2px 선. 텍스트 재사용 | `top_frame.png` 1920×78. 면은 불투명, 외곽 장식 여백만 alpha |
| 상단 정보 내용 영역 | `header` Label, 상단 HBox; 별도 날짜/자원 프레임 없음 | 1162×23.3 / 1743×35 | 국가·도시·연월·금·군량을 문자열로 갱신 | 날짜 배지 필요 시 **신규 노드 연결 필요**. 240×64 시안용 소형 프레임 제안, 바깥 alpha. 실제 칸 폭은 향후 Label 분리 후 확정 |
| 하단 전체 메뉴 프레임 | Overlay `footer_panel`(282행), CityStyle `panel(true)` | 1280×58.7 / 1920×88 | 단색 프레임. 기존 메뉴·아이콘 유지 | `bottom_frame.png` 1920×88. 불투명 중심+alpha 외곽 |
| 하단 메뉴 일반/선택 표시 | `navigation`의 Button, `refresh_quote()` → CityStyle `button(selected)` | 내정 버튼 기준 186×42.7 / 279×64 | 일반 어두운 면, 선택 금색 채움, 기존 SVG 아이콘 | `nav_normal/selected.png` 각각 280×64. 테두리/밑줄/빛만 alpha 오버레이 권장. 메뉴별 폭 가변 |
| 붉은 확정 버튼 | `execute_button`; CityStyle `button(primary=true)` | 개발·임명 모두 432×48 / 648×72 | 붉은 StyleBoxFlat+금색 선. 글자·버튼 동작 유지 | `primary_normal/hover/pressed/disabled.png` 각각 648×72. 양끝 절삭 모서리 바깥 alpha, 중심 붉은 면. `primary_focus.png` 같은 크기·중앙 투명 |
| 오른쪽 업무 패널 | `CityWorkPanel`(160행), `_panel(body)` | 448×609.3 / 672×914 | 크림 StyleBoxFlat + `assets/ui/hanji_overlay_texture_v1.png` 불투명도 0.12 | `work_panel_frame.png` 672×914. 중앙 투명으로 기존 크림 면·종이 질감 재사용 권장 |
| 업무 제목 구분 장식 | `title_row`(172행), `title`; 현재 별도 장식선 없음 | 제목 행 432×35.3 / 648×53 | 동적 Label, 배경 장식 없음 | `title_divider.png` 648×12, 배경 투명. **신규 장식 TextureRect/분리선 연결 필요**. 제목 행 하단에 겹치되 글자 영역 침범 금지 |
| 세부 정보/임명 변화 구분 장식 | `effect_heading`(241행) | Label 432×24.7 / 648×37 | 텍스트만 있음. 기존 HSeparator 테마는 단순 1px 선 | 위 `title_divider.png` 재사용 가능. 추가 높이를 넣으면 720p 재배치 확인 필요 |
| 도시 제목 프레임 | `city_heading`(127행), `city_title` | 797.3×55.3 / 1196×83 | 크림 프레임, 동적 도시명 Label | `city_heading_frame.png` 1196×84, 중앙 투명. 글자를 그림에 포함하지 않음 |
| 담당자 카드 일반/선택 테두리 | `_build_officer_cards()`(404행)의 PanelContainer | 기본 후보 432×121.3 / 648×182 | 일반 1px/선택 금색 3px StyleBoxFlat. 기존 초상·이름·상태 유지 | `officer_card_normal/selected.png` 각각 648×184, 중앙 투명. 높이는 사유 줄 수에 따라 가변 |
| 태수 후보 카드 일반/선택 테두리 | `_build_candidates()`(379행), `candidate_row`의 VBox와 이름 Button | 카드 123.3×98 / 185×147; 이름 버튼 123.3×32 / 185×48 | 현재 전체 카드 프레임 없음. 이름 버튼만 일반/금색 선택. 초상 재사용 | `personnel_card_normal/selected.png` 각각 192×152, 중앙 투명. **전체 카드에 Panel/오버레이 연결 필요**; 기존 카드185×147에 9분할 적용 |

권장 파일명은 제작용 이름이며 아직 생성하지 않았다. 향후 Living City 전용 `ui/living_city_v1/assets/ornaments/`에 두고 CityStyle에서 참조하는 방식을 권장한다. 다른 UI도 사용하는 Atlas 전역 테마는 이번 장식 때문에 바꾸지 않는다.

## 늘림·반복·모서리 보존 규칙

다음 여백은 1배 원본 픽셀 기준 L/R/T/B다. Godot `StyleBoxTexture.texture_margin_*` 또는 `NinePatchRect`로 연결하고 720p에서는 노드 전체를 2/3로 표시한다. 단일 이미지 전체를 가로로 늘려 문양까지 찌그러뜨리지 않는다.

| 자산 | 보존할 영역 | 늘려도 되는 영역 |
| --- | --- | --- |
| 상단 프레임 | 좌우 끝 각64, 상하12. 끝 금속 문양 고정 | 가운데 어두운 목재 결은 가로 반복/타일. 큰 문양은 별도 alpha 오버레이 |
| 날짜 배지(선택 제작) | 좌우24, 상하12의 절삭 모서리 | 중앙 바탕만 가로 늘림; 날짜는 Label |
| 하단 프레임 | 좌우64, 상하16 | 가운데 어두운 면·직선 테두리 가로 반복 |
| 메뉴 선택 표시 | 좌우20, 상하10. 작은 끝 장식 고정 | 밑줄과 은은한 빛의 중앙 가로 늘림. 아이콘·글자는 별도 |
| 붉은 주 버튼 | 좌우48, 상하16. 양끝 금속 장식을 보존 | 가운데 붉은 질감/수평 선만 늘림·반복. normal/hover/pressed/disabled의 분할 위치 동일 |
| 업무 패널 프레임 | 네 모서리24×24 고정, 외곽 테두리 약12 안에 문양 배치 | 중앙은 투명. 상하 직선은 가로, 좌우 직선은 세로 반복 |
| 제목 장식선 | 좌우24×12 끝 문양 고정 | 가운데 가는 선만 가로 늘림. 글자가 들어갈 중앙에는 장식 덧씌우지 않음 |
| 도시 제목 프레임 | 좌우32, 상하12 | 가운데 종이 면·직선만 늘림 |
| 담당자 카드 | 네 모서리16×16 고정 | 중앙 투명, 가로/세로 직선 가장자리만 늘림. 긴 사유로 높이가 커질 수 있음 |
| 태수 후보 카드 | 네 모서리12×12 고정 | 중앙 투명, 변 길이만 늘림. 금색 광택은 카드 안쪽에 넣어 ScrollContainer 잘림 방지 |

모든 자산은 RGBA PNG 권장. 실제 알파 채널을 사용하고 체크무늬 배경을 구워 넣지 않는다. 모서리와 선·면을 레이어로 분리한 제작 원본도 보관한다. 2배 원본으로 납품할 경우 위 크기와 분할 여백을 모두 2배로 만들고 적용 시 1배 대응을 명시한다. 테두리 그림과 컨테이너의 콘텐츠 여백은 별개다. 현재 패널 여백12, 버튼 normal 여백9를 임의로 키우면 720p 버튼 겹침이 다시 생길 수 있다.

상태별 배경을 교체해도 `normal/hover/pressed/disabled/focus`와 필요 시 `hover_pressed`를 모두 연결한다. 선택은 금색뿐 아니라 `선택 중`/`선택` 문구를 유지한다. 장식 노드는 `MOUSE_FILTER_IGNORE`로 입력을 가로채지 않는다.

## 서체 재고와 제목 적용 준비

| 파일/위치 | 확인된 용도·굵기 | 라이선스 자료 | 제목 재사용 판단 |
| --- | --- | --- | --- |
| `ui/faction_selection_v1/assets/SamhanUISans-Medium.ttf` | Samhan UI Sans Medium. 일반 Label·본문. ASSET_NOTES 기준 Noto Sans KR 정적 weight500 파생 | 같은 폴더 `OFL.txt`, `ASSET_NOTES.md` 있음. Adobe 저작권 고지 및 SIL OFL1.1 포함 | 가독성 있는 보조 제목 가능. 서예 스타일 아님 |
| `ui/faction_selection_v1/assets/SamhanUISans-SemiBold.ttf` | Samhan UI Sans SemiBold. 제목·인물명·버튼. ASSET_NOTES 기준 weight650 파생 | 위 두 자료 공유 | 현재 제목용으로 재사용 가능. 승인 시안의 붓글씨를 구현하려면 별도 한글 제목 서체 필요 |
| `addons/gut/fonts/`의 AnonymousPro, CourierPrime, LobsterTwo 계열 | GUT 테스트 도구용. 각 계열 Regular를 직접 검사했으며 `가`/`국` 글리프 없음 | 해당 폴더 `OFL.txt` 있음 | 한글 제목 대체 후보로 사용하지 않음 |

프로젝트의 TTF/OTF 목록에서 별도 한글 서예/명조 제목 서체는 발견하지 못했다. 두 Samhan 폰트의 실제 family/style 및 한글 글리프 유무도 FontFile로 확인했다. 이번 작업은 로컬 라이선스 자료 존재 확인이며 외부 서체 선정·다운로드·권리 심사는 하지 않았다.

추가 확보 항목: 게임에 포함 가능한 한글 제목용 TTF/OTF, 원 출처·버전·저작권·라이선스 파일, 필요한 한글/숫자/문장부호 범위. 확보 전에는 기존 SemiBold를 유지한다. 제목에만 별도 Font override를 적용하고 본문은 Medium으로 유지하는 것이 연결 범위다.

### 글꼴·크기·굵기 설정 위치

| 내용 | 위치와 현재 설정 | 1080p / 720p 글자 크기 |
| --- | --- | --- |
| 기본 본문 | Atlas `FONT`(14행), `make_theme()` 기본 font; CityStyle `make_theme()` 기본23 | 기본23 / 15.3 |
| 굵은 서체 | Atlas `BOLD_FONT`(15행); Overlay `_label()`은 요청 크기30 이상일 때 SemiBold | 크기에 따라 적용 |
| 버튼 | Atlas `apply_button()`에서 SemiBold; CityStyle `button()`에서 상태·주 버튼 override | 일반23 / 15.3, 주 버튼30 / 20 |
| 도시 제목 `city_title` | Overlay `_ready()`, `_label(...,40)` | 40 / 26.7, SemiBold |
| 업무 제목 `title`, 브랜드, 인물 이름 | Overlay `_ready()`, `_label(...,36)` | 36 / 24, SemiBold |
| 인물 능력 | `hero_ability`, `_label(...,29)` | 29 / 19.3, Medium |
| 세부 구분 제목 | `effect_heading`, `_label(...,25)` | 25 / 16.7, Medium |
| 설명·불가 사유 | `details`, `status`, `_label(...,22)` | 22 / 14.7, Medium |
| 견적 수치·날짜 | `quote_values` 최초30, 날짜만 font_size26 override | 30 / 20 및 26 / 17.3. 날짜도 기존 SemiBold 유지 |
| 후보 이름 버튼·카드 설명 | 인사 이름20 override; 담당자 이름 기본23. 업무/사유 Label20 | 이름20/13.3 또는23/15.3, SemiBold; 설명20/13.3, Medium |

도시명·업무명·인물명은 반드시 동적 Label로 유지한다. `refresh_quote()`의 `city_title.text`, 업무별 `title.text`, `_personnel_quote()`의 태수 임명 제목 연결을 보존한다. `금성 내정`이나 `농업 개발`을 고정 서예 PNG로 만들지 않는다. 장식선과 글자는 분리한다.

## 재사용 캡처와 최신성

V1.2 최종 관련 코드 수정 시각은 Overlay 2026-09-28 17:52:56, campaign 17:49:17, CityStyle 17:15:02이다. 네 캡처는 같은 날 17:53:04~17:53:13에 생성됐고 최종 로그는17:53:38이다. 현재 코드의 V1.2 최종 변경(담당자 선택 중 큰 태수 초상 접기, 분리된 초상 범위, 한 줄 완료 예정)과 캡처 표시도 일치한다. 이 세션의 최종 구현과 수정 시각·화면을 함께 대조해 재사용했다. 당시 소스 해시 명세가 없어 과거 파일 해시의 동일성까지 소급 증명하는 것은 아니다.

- [내정 기본 1280×720](living_city_v1_2_review/domestic-1280.png)
- [담당자 후보 카드 1280×720](living_city_v1_2_review/officer-1280.png)
- [태수 임명 1280×720](living_city_v1_2_review/personnel-1280.png)
- [태수 임명 1920×1080](living_city_v1_2_review/personnel-1920.png)

별도 재캡처 없이 원본 PNG를 바이트 그대로 복사한다. 기존 원본과 V1.2 전체 검증 자료는 보존한다. 이번 작업의 소스/보호 파일 해시와 노드 측정치는 `tests/living_city_v1_3_asset_review/source-hashes.json`, `measurements.json`에 남겼다.

## 이번 확인 범위와 전달 묶음

실행한 것은 정상 화면의 노드 크기·폰트 메타데이터 측정, 네 이미지 규격/복사 일치 확인, HTML 상대경로와 ZIP 항목 검사다. **V1.2 기능 검증 전체를 재실행하지 않았으며 새 기능 검사 통과 수를 주장하지 않는다.** 측정 실행에는 기존 Windows 루트 인증서 경고가 있었고 스크립트 오류는 없었다.

ZIP에는 이 계획서, 원본 V1.2 적용 보고서, 네 장의 최신 캡처와 `index.html`만 포함한다. HTML은 상대경로로 네 이미지를 연다. V1.2 보고서는 원문을 보존하므로 그 안의 과거 비교판·로그 링크는 작은 ZIP에 포함되지 않는다. 필요한 네 화면은 HTML 또는 위 링크로 확인한다. 배경 원본·전체 초상·이전 캡처·대용량 로그·게임 실행 파일은 포함하지 않는다.

**결과 분류: 장식 자산 제작 준비 완료. 실제 게임 화면 변경 항목: 없음.** 장식 제작·서체 확보와 실제 연결, 이후 720p/1080p 레이아웃 재검증은 다음 적용 단계다.
