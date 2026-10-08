# Living City UI V1.3 — 장식·제목 서체 적용

2026-09-29. `Samhan660_Living_City_UI_V1_3_Art_20260929.zip`의 `VS_CODE_TASK.md`에 따라 실제 게임에 적용했다. **PNG 복사만 한 상태가 아니라 Godot 렌더링과 명령 동작까지 확인한 결과**다.

## 작업 위치와 보존

현재 경로는 `.worktrees/project-foundation-v1`이다. 요청에 적힌 브랜치 이름은 `feature/project-foundation-v1`이나 실제 `git branch --show-current` 결과는 **main**이었다. 브랜치 전환·생성 없이 현재 worktree에서 작업했다. stage/commit/push/merge/reset/clean은 실행하지 않았다.

기존 미커밋 변경을 유지했다. `campaign_main.gd`, `settlement_overlay.gd`, `ui/light_atlas_v1/atlas_theme.gd`, 보호 파일 `tests/HOME_HANDOFF_20260923.md`는 작업 전후 SHA-256이 동일하다. 기존 도시 전경·초상·65:35 배치·개발/임명/인계/저장 규칙도 유지했다. ZIP 원본은 다운로드 폴더에 그대로 있고, 작업용 원본은 `.gdignore` 아래 `dev/living_city_ui_v1_3_art_source/`에 보관했다.

## 실제 변경 파일

| 파일 | 역할 |
| --- | --- |
| `domestic_assignment_overlay.gd` | 상하단·업무 패널·도시 제목·후보 전체 카드의 장식 연결, 동적 제목 서체, 긴 상단/메뉴 문구 클리핑 |
| `ui/living_city_v1/living_city_theme.gd` | 붉은 주 버튼의 5개 상태, 네이티브 포커스, 선택 메뉴 밑줄, 제목 폰트 참조 |
| `ui/living_city_v1/ornament_resources.gd` | manifest의 원본 영역·논리 텍스처·9분할을 코드 상수로 옮긴 리소스 캐시 |
| `ui/living_city_v1/ornament_overlay.gd` | 레이아웃 공간과 입력을 차지하지 않는 그리기 전용 장식 Node2D |
| `ui/living_city_v1/assets/ornaments/v1_3/` | 제공 PNG 6종과 원본 픽셀을 담은 `generated/*.res` |
| `ui/living_city_v1/assets/fonts/nanummyeongjo/` | 원본 ExtraBold TTF, OFL, 실행용 `title_font.res` |
| `tests/living_city_ui_v1_3_play.gd` | 실제 GUI·업무 동작·manifest 대응·버튼 상태·포커스·배치 검사 |
| `tests/living_city_v1_3_review/build_resources.gd` | 원본에서 전용 `.res`를 재생성하는 개발 도구 |
| `tests/living_city_v1_3_review/build-comparisons.ps1` | V1.2 전후 및 승인 시안 비교판 생성 |

NanumBrushScript는 비교용으로만 제공됐으므로 게임 리소스로 복사하지 않았다. HTML·reference·예제 코드는 게임 진입점으로 등록하지 않았다.

## 장식 적용과 원본·9분할

원본 PNG 6종의 SHA-256은 manifest와 모두 일치한다. TTF도 SOURCES의 `60c0077f…ce46db7`과 일치한다. 알파나 원본 파일을 수정하지 않았다.

| 자산 | 사용한 원본 영역 x/y/w/h | 연결 |
| --- | --- | --- |
| lacquer_bar | 2 / 356 / 1847 / 135 | 상단78·하단88 높이의 기존 프레임 |
| primary_red | 40 / 260 / 1894 / 250 | 개발 지시·임명 확정 |
| work_panel_frame | 29 / 48 / 1017 / 1367 | 672×914 업무 패널 |
| candidate_frame | 25 / 85 / 1360 / 938 | 담당자 가로 카드와 태수 후보 전체 카드 |
| title_divider | 48 / 318 / 2095 / 61 | 도시 제목 하단의 빈 여백, 선택 메뉴 밑줄 |
| city_heading_frame | 28 / 285 / 2055 / 174 | 도시 제목 프레임 |

`source_region`을 먼저 취한 뒤 `ImageTexture.set_size_override()`로 manifest의 `logical_texture_size`를 대응시키고 `slice_lrtb`를 사용한다. 담당자 카드도 후보와 같은 **192×152 논리 텍스처·16/16/16/16 분할**을 648×182에 그린다. 원본 전체를 가로 카드 크기로 먼저 찌그러뜨리지 않는다. 실제 자산/논리 크기별 텍스처는 캐시한다.

top/bottom/primary/work_panel/candidate/officer_card/nav_border/divider/nav_underline/city_heading의 10개 프로필은 manifest와 대응 검사를 통과했다. 이 중 `nav_border`는 준비된 프로필이며 메뉴에는 기존 버튼 테두리+선택 밑줄을 사용한다.

투명 프레임 아래 크림 면·한지 질감을 유지한다. 장식은 Node2D로 그려 Container의 형제 Control 항목을 추가하지 않는다. 따라서 최소 높이·분리 간격·키보드 포커스·마우스 입력을 차지하지 않는다. 2D 선형 필터, 반복 꺼짐이며 원본 픽셀의 손실 압축을 사용하지 않는다.

### 실제 화면을 보고 조정한 항목

- 초기 상단·업무 패널 문양이 로고/업무 제목과 겹쳤다. manifest 분할값은 유지하고 같은 외곽 사각형 안에서 상하단 모서리를 0.5배, 업무 패널 모서리를 0.4배로 작게 그렸다. 가운데 직선 부분이 길어지는 방식이며 기존 콘텐츠 패딩은 늘리지 않았다.
- 제목 폰트 메트릭 차이로 행 높이가 달라지지 않도록 업무 제목 행53, 도시 제목 패널83의 V1.2 높이를 유지했다.
- 오른쪽 업무 제목 행에는 추가12px 구분선 공간이 없다. 새 행을 삽입하지 않고 도시 제목 하단의 기존 여백과 메뉴 밑줄에만 제공 구분선을 적용했다. 업무 제목은 명조 서체와 패널 프레임으로 구분한다.
- 긴 상단 문자열은 한 줄 말줄임 및 전체 정보 툴팁으로 유지하며 메뉴도 폭 밖으로 늘어나지 않게 했다.

## 서체와 버튼 상태

NanumMyeongjo ExtraBold를 `city_title` 40px, `title` 36px에만 적용했다. 본문·능력·금·연월·후보 이름·주 버튼은 기존 Samhan UI Sans다. 도시명·업무명은 기존 Label 갱신을 유지하며 텍스트 이미지를 만들지 않았다. 폰트 원본과 OFL을 함께 보관한다.

주 버튼은 같은 PNG에 normal 1.0, hover1.08, pressed0.78, hover_pressed0.85, disabled0.6/alpha0.72를 적용한다. focus는 중심을 칠하지 않는 별도 2px 크림 StyleBoxFlat이다. `hover_pressed` 포함 5개 상태의 스타일 연결·계수를 검사했고, 실제 포인터의 normal/hover/press와 키보드 focus 및 실제 접수 후 disabled 화면을 두 해상도에서 확인했다. 카드 일반 테두리는0.65/alpha0.55, 선택은 원본색이며 선택 문구도 유지한다.

## 이 환경의 리소스 가져오기 문제와 처리

에디터 import에서 기존 `.godot/imported` 및 editor 설정 캐시에 쓰기 오류가 발생했다. 이 상태에서는 신규 TTF/PNG를 직접 preload할 수 없었다. 원본을 바꾸거나 보호 영역 권한을 수정하지 않고 `build_resources.gd`로 프로젝트 내부에 압축 `.res`를 생성했다. 텍스처 `.res`에는 원본 픽셀을 저장하고 실행 시 위 source_region/논리 크기/9분할을 적용한다. 폰트 `.res`에는 제공된 원본 TTF 데이터를 담았다.

실행 코드는 `.res`를 명시적으로 preload하므로 `.godot`의 신규 import 산출물이나 런타임 JSON·원시 PNG 읽기에 의존하지 않는다. JSON과 원시 파일 읽기는 개발용 생성/검사 스크립트에서만 사용한다. 따라서 런타임 리소스 종속성은 정적 참조로 드러난다. **실제 export는 이번에 하지 않았으며**, 배포 시 OFL 포함과 export 결과 리소스 로딩은 별도 확인해야 한다. 원본 PNG/TTF의 에디터 재import에는 기존 캐시 쓰기 문제가 남을 수 있다.

초기 import/실행 실패 로그는 원인 확인용으로 남겼다. 최종 게임 실행에는 리소스 로딩·스크립트 오류가 없고 기존 Windows 루트 인증서 경고만 남는다.

## 이번에 실행한 최종 검증

Godot4.7.2 / Windows / D3D12 / 실제 게임 창 자동 입력.

| 검사 | 최종 실행 결과 |
| --- | --- |
| V1.3 UI·업무·manifest·버튼 상태·배치·캡처 | **251개 통과, 실패0** |
| 기존 내정 회귀: 세 국가, 비용·상한·충돌·태수 효과·결산·저장 | **131개 통과, 실패0** |
| 원본 PNG6종·TTF 해시, 보호/기존 연결 파일 해시 | 일치 |
| `git diff --check` | 통과 |

이전 버전 수를 합산하지 않았다. GUI 수에는 리소스 계약·이미지 저장·버튼 bounds 검사도 포함한다. 초기 원본 영역 비교는 JSON 실수와 코드 정수 배열의 타입 차이로 실패해 비교값을 정수 좌표로 정규화했다. 실제 manifest 좌표를 바꿔 통과시킨 것은 아니다.

정상 632년 신라·금성에서 담당자 선택·취소·Esc는 상태를 바꾸지 않았고, 개발 지시에서 금100을 한 번 지불했다. 국고1000→900, 농업74를 유지하다 다음 달79가 됐다. 취소 환불·재접수·중복 확정 방지·저장 복원도 확인했다. 후보 선택/취소와 임명은 기존 경로를 사용하며 김춘추→선덕여왕 후 실제 월 세입160→159로 갱신됐다.

많은 후보·빈 목록·금 부족·업무 충돌·긴 이름/사유·긴 상하단 문구·Tab 포커스·닫기/Esc·도시 전환/지도 입력 복구를 확인했다. 예외 상태는 정상 흐름 이후 별도 메모리 fixture이며 저장은 테스트 슬롯만 사용했다. 기존 내정 회귀는 출력 경로만 이번 검사 폴더로 바꾼 복사본으로 새로 실행했다.

[최종 GUI 로그](living_city_v1_3_review/play.log), [내정 회귀 로그](living_city_v1_3_review/regression.log), [정상 명령 수치](living_city_v1_3_review/results.json).

## 같은 조건의 비교 캡처

V1.2 기준은 당시 최종 정상 캡처를 재사용했다. V1.3은 이번에 새로 캡처했다. 모두 632년1월 신라·금성이며 비교판 왼쪽V1.2/오른쪽V1.3이다. 커서 위치에 따른 보조 버튼 hover는 내용 변화와 구분한다.

| 화면 | 720p 전후 | 1080p 전후 | 새 화면 원본 |
| --- | --- | --- | --- |
| 내정 기본 | [비교](living_city_v1_3_review/before-after-domestic-1280.png) | [비교](living_city_v1_3_review/before-after-domestic-1920.png) | [720](living_city_v1_3_review/domestic-1280.png) / [1080](living_city_v1_3_review/domestic-1920.png) |
| 담당자 선택 | [비교](living_city_v1_3_review/before-after-officer-1280.png) | [비교](living_city_v1_3_review/before-after-officer-1920.png) | [720](living_city_v1_3_review/officer-1280.png) / [1080](living_city_v1_3_review/officer-1920.png) |
| 태수 임명 | [비교](living_city_v1_3_review/before-after-personnel-1280.png) | [비교](living_city_v1_3_review/before-after-personnel-1920.png) | [720](living_city_v1_3_review/personnel-1280.png) / [1080](living_city_v1_3_review/personnel-1920.png) |

[버튼 상태720](living_city_v1_3_review/button-states-1280.jpg), [버튼 상태1080](living_city_v1_3_review/button-states-1920.jpg), [긴 상하단720](living_city_v1_3_review/long-header-footer-1280.png), [긴 상하단1080](living_city_v1_3_review/long-header-footer-1920.png), [임명 후](living_city_v1_3_review/appointed-1920.png).

승인된 1번 시안과도 같은 표시 크기로 비교했다: [내정](living_city_v1_3_review/reference-domestic-1280.png), [태수 임명](living_city_v1_3_review/reference-personnel-1280.jpg). 시안의 예시 연도·인물·금액은 실제 데이터로 대체하지 않았다. 담당자 카드 전용 승인 시안은 없으므로 내정 시안의 비중·색·문양 기준을 따른다.

## 남은 차이와 미검증

이번에 실제 적용한 것은 칠기 상하단, 붉은 주 버튼, 패널·제목·후보 테두리, 메뉴 밑줄, 두 제목의 명조 서체다. 원본 시안과 완전히 같은 붓글씨·로고·장식 배치는 아니다. 다른 장수의 기존 사각 초상과 실제 상세 스크롤 구조를 유지한다. 오른쪽 제목 구분선 추가는 공간 부족으로 보류했다.

권력 인계 모든 분기·해임 확정 GUI 전체 경로·생산 전체 분기·export·장시간 수동 플레이는 미검증이다. 생산·건설·연구 화면의 장식 확장은 이번에 하지 않았다.

## 다음 작업과 VS Code 지시문

다음 작업은 **생산·건설·연구 화면의 Living City 스타일 확장**을 권장한다. 실제 연결은 `production_overlay.gd`의 생산/건설/연구 버튼과 `industry_assignment_overlay.gd`의 담당자 배정 화면이다. 새로운 게임 규칙 없이 이번 전용 테마와 리소스를 재사용하는 범위로 시작한다. 배포 작업 전에는 캐시 쓰기 환경과 OFL 포함을 별도 확인한다.

바로 복사해 사용할 지시문은 [LIVING_CITY_UI_V1_4_VS_CODE_TASK.md](LIVING_CITY_UI_V1_4_VS_CODE_TASK.md)에 있다. 이번에는 이 후속 작업을 실행하지 않았다.

```text
현재 project-foundation-v1 worktree에서 Living City V1.3을 기준으로
생산·건설·연구 화면의 스타일을 확장하라.
tests/LIVING_CITY_UI_V1_3.md와 tests/LIVING_CITY_UI_V1_4_VS_CODE_TASK.md를 먼저 읽고,
기존 미커밋 작업·보호 파일·게임 규칙·내정 화면을 보존하라.
실제 브랜치를 확인하되 임의로 전환하거나 커밋하지 마라.
장식 리소스와 제목 서체를 재사용하고 720p·1080p의 화면과 기존 명령을 검증하라.
이번에 실행한 검사와 전후 캡처, 남은 차이를 별도 보고하라.
```

## 재실행

```powershell
& 'C:/Users/지용훈/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe' --path . --script tests/living_city_ui_v1_3_play.gd --log-file "$((Get-Location).Path)/tests/living_city_v1_3_review/play.log"
```

원본 자산을 바꿨을 때만 `tests/living_city_v1_3_review/build_resources.gd`로 전용 리소스를 다시 생성한다. 생성 시 원시 이미지 읽기/export 경고는 개발 도구에 한정되며 실제 게임 실행 경로는 `.res`를 사용한다.
