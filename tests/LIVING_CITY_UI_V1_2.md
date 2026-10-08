# Living City UI V1.2 적용 보고서

2026-09-28. V1.1에서 초상 표시, 개발 담당자 선택, 견적 요약을 개선했다. **632년 신라·금성의 정상 새 캠페인**을 기준으로 실행했다.

## 수정 파일과 연결

| 파일 | 실제 변경 |
| --- | --- |
| `domestic_assignment_overlay.gd` | 선덕여왕 표시 범위 분리, 담당자 카드 목록, 선택/취소 상태, 비용·완료 예정·성과 요약 |
| `campaign_main.gd` | 내정 Esc를 `back()`으로 연결. 담당자 목록에서는 선택 취소, 기본 화면에서는 닫기 |
| `tests/living_city_ui_v1_2_play.gd` | 실제 GUI 입력·게임 상태 비교·화면 캡처·배치 검사 |
| `tests/living_city_v1_2_review/build-comparisons.ps1` | 두 해상도의 수정 전후·시안 비교 이미지 생성 |
| `design-qa.md` | V1.2 시각 비교 결과. 이전 기록은 V1.1 검사 폴더에 보관 |

V1.1의 미커밋 작업과 보호 파일 `tests/HOME_HANDOFF_20260923.md`를 보존했다. 기존 도시 전경·65:35 구성·게임 수식·초기 수치·지도·거점 위치·인물 원본 자산은 변경하지 않았다. stage/commit/push/merge는 하지 않았다.

## 1. 초상

기존 선덕여왕 오버레이를 그대로 사용한다. 큰 초상은 AtlasTexture 범위를 `(205, 0, 610, 610)`, 작은 초상은 `(240, 0, 480, 560)`으로 분리했다. 기존 큰 범위 832×832보다 얼굴·어깨 비중이 커졌다. 두 표시 모두 비율을 유지하고 관모와 얼굴을 포함한다.

김춘추·김유신은 기존 초상 조회 경로를 유지한다. 세 후보를 각각 선택해 큰 초상과 썸네일을 직접 확인했다. 선덕여왕 외 인물의 사각 배경도 원본 그대로다. 원본 파일이나 인물·연도별 데이터 연결을 바꾸지 않았다.

## 2. 담당자 카드

농업·상업의 담당자 버튼을 누르면 업무 패널 안에 후보 목록이 열린다. 도시와 현재 태수·효과 요약을 유지하며, 중복되는 큰 태수 초상은 선택 중에 접어 목록 공간을 확보한다.

- 카드: 기존 초상, 이름, 정치·지력, 현재 업무, 배정 가능/불가 사유. 기존 인사 카드의 초상 함수·버튼 테마·선택 표현을 재사용한다.
- 선택 중인 후보는 금색 테두리와 `선택 중` 문구로 구분한다. 긴 이름은 버튼 안에서 제한하고 전체 이름·역할은 툴팁으로 확인한다.
- 카드의 이름 버튼으로 선택하면 업무 화면으로 돌아와 기존 견적을 갱신한다. 불가 후보도 사유를 확인할 수 있지만 개발 실행은 기존 견적에 따라 차단된다.
- 선택 취소/Esc는 기존 선택·게임 상태를 보존한다. 개발 접수는 `개발 지시`에서만 기존 `start_domestic`을 호출한다.
- 목록이 많으면 내부 세로 스크롤을 사용한다. 빈 목록은 안내와 선택 취소를 제공한다.

이전 OptionButton은 호환용 내부 선택 모델로만 남으며 화면과 팝업에는 노출되지 않는다. 새 목록은 `get_city_officer_ids`, `get_officer`, `get_domestic_quote`를 사용한다.

## 3. 견적 요약

필요 금 / 완료 예정 / 예상 성과를 별도 세 칸으로 배치했다. 금과 성과는 30, 날짜는 26 논리 픽셀이다. 날짜는 `632. 2월` 형태이며 툴팁에 연도·월·월 진행 횟수를 표시한다. 위치·역할·관련 능력·현재 업무·태수 효과 등은 아래 상세 스크롤로 옮겼다. 실행 불가 사유는 확정 버튼 바로 위에 있다.

값은 기존 quote의 `cost`, `due_month`, `gain`을 사용한다. 진행 중인 업무는 접수 기록의 `due_month`, `planned_gain`을 표시한다. 견적에 성과가 제공되지 않는 불가 상태는 `—`로 표시한다. 후보별 미래 세입/수확 수식은 추가하지 않았다.

## 이번에 직접 실행한 검증

Godot 4.7.2 / Windows / D3D12. 실제 게임 창 자동 입력 검사이며 장시간 수동 플레이와 구분한다.

| 검사 | 최종 결과 |
| --- | --- |
| V1.2 GUI: 기능·상태·배치·캡처 검사 | **167개 통과, 실패 0** |
| 기존 내정 회귀: 세 국가·비용·상한·충돌·태수 효과·결산·저장 호환 | **131개 통과, 실패 0** |
| `git diff --check` | 통과 |

GUI 검사 수에는 캡처 저장과 버튼 bounds 검사도 포함한다. 이전 버전의 통과 수를 합산하지 않았다. 기존 내정 회귀는 출력 경로만 `tests/living_city_v1_2_review/regression/`으로 변경한 복사본으로 새로 실행했다. 최종 로그에는 스크립트 오류가 없으며 Windows 루트 인증서 경고는 남는다.

정상 흐름 결과:

- 농업·상업 담당자 선택/취소 후 자원·장수·도시·업무 상태가 그대로인지 비교했다. 카드 선택 후 견적만 바뀌고 접수되지 않는다.
- 선덕여왕 농업 개발: 금 **100**, 국고 **1000→900**, 접수 직후 농업 **74**, 다음 달 완료 후 **79**. 취소 환불·재접수·중복 실행 방지·실제 저장 복원을 확인했다.
- 후보 변경과 임명: **김춘추→선덕여왕**, 임명 직전/직후 실제 월 세입 **160→159**. 미리보기 무변경, 반복 임명 방지, 저장 복원을 확인했다.
- 담당자 목록 Esc는 취소, 내정 화면 Esc·닫기는 지도 입력 복구. 군수·외교 연결과 도시 전환도 확인했다.
- 정상 캠페인 이후 별도 메모리 fixture로 금 부족, 업무 충돌, 공석, 후보 없음, 10명 추가 후보, 긴 이름/사유, 목록 마지막 후보 선택을 검사했다. 많은/빈 목록과 긴 이름 상태는 720p에서도 확인했다.

[실행 수치](living_city_v1_2_review/results.json), [GUI 로그](living_city_v1_2_review/play.log), [내정 회귀 로그](living_city_v1_2_review/regression.log).

## 수정 전후 및 시안 비교

수정 전 V1.1도 이번 작업 시작 시 같은 632년 1월 금성에서 다시 캡처했다. 비교 이미지의 왼쪽은 수정 전 또는 승인 시안, 오른쪽은 V1.2다.

| 화면 | 전후 720p | 전후 1080p | 승인 시안 대비 |
| --- | --- | --- | --- |
| 내정 기본 | [비교](living_city_v1_2_review/before-after-domestic-1280.png) | [비교](living_city_v1_2_review/before-after-domestic-1920.png) | [720p](living_city_v1_2_review/reference-domestic-1280.png) / [1080p](living_city_v1_2_review/reference-domestic-1920.png) |
| 담당자 선택 | [비교](living_city_v1_2_review/before-after-officer-1280.png) | [비교](living_city_v1_2_review/before-after-officer-1920.png) | [720p](living_city_v1_2_review/reference-officer-1280.png) / [1080p](living_city_v1_2_review/reference-officer-1920.png) |
| 태수 임명 | [비교](living_city_v1_2_review/before-after-personnel-1280.png) | [비교](living_city_v1_2_review/before-after-personnel-1920.png) | [720p](living_city_v1_2_review/reference-personnel-1280.png) / [1080p](living_city_v1_2_review/reference-personnel-1920.png) |

담당자 카드 선택 전용 승인 시안은 없으므로 해당 시안 비교판은 내정 기본 시안을 기준으로 도시/업무 비중·색·정보 위계만 비교한다. 선택 상태가 다름을 감안해야 한다. 시안의 642년 예시 수치는 실제 632년 데이터와 다르다.

[선덕여왕](living_city_v1_2_review/portrait-0-1280.png), [김춘추](living_city_v1_2_review/portrait-1-1280.png), [김유신](living_city_v1_2_review/portrait-2-1280.png), [임명 후](living_city_v1_2_review/appointed-1280.png), [많은 후보](living_city_v1_2_review/many-officers-1280.png), [빈 목록](living_city_v1_2_review/empty-officers-1280.png), [긴 담당자 이름](living_city_v1_2_review/long-officer-summary-1280.png).

## 시각 검토와 남은 차이

세 칸 요약을 처음 추가했을 때 720p에서 보조 버튼이 하단 메뉴에 겹쳤다. 완료 예정 표시를 한 줄로 정리한 뒤 캡처와 bounds 검사로 겹침 해소를 확인했다. 카드 목록에서는 현재 태수의 큰 초상을 중복 표시하지 않아 정상 후보 3명이 한 번에 보인다. 큰 초상과 후보 썸네일의 관모/얼굴·비율, 글자·여백·스크롤을 실제 렌더링으로 확인했다.

목재/금속 조각·광택과 서예 제목은 후속 자산 작업이다. 기존 사각 초상은 승인 시안의 새 투명 인물화와 다르다. 실제 상세 정보와 보조 버튼이 있어 원본보다 정보가 많으며 일부 내용은 스크롤한다. 금성 외 도시 전경은 기존 준비 중 표시를 유지한다. 픽셀 단위 시안 복제 완료를 주장하지 않는다.

미검증: 권력 인계 협의 모든 분기, 해임 확정 GUI 전체 경로, 생산 전체 분기, 배포 export, 장시간 수동 플레이. 이번 ZIP은 **보고서·비교 화면 묶음**이며 게임 실행용 배포본이 아니다.

## 전달 및 재실행

`tests/Samhan660_Living_City_UI_V1_2_Review_20260928.zip`에 이 보고서, 시각 QA, 비교 이미지와 개별 캡처, 실행 로그를 함께 담았다. 압축을 푼 뒤 `tests/living_city_v1_2_review/index.html`을 열면 세 화면을 바로 비교할 수 있다.

```powershell
& 'C:/Users/지용훈/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe' --path . --script tests/living_city_ui_v1_2_play.gd --log-file "$((Get-Location).Path)/tests/living_city_v1_2_review/play.log"
```

현재 UI 재검증은 V1.2 스크립트를 사용한다. 이전 버전 스크립트·기록은 당시 동작을 설명하는 자료로 보존한다. `--before` 옵션은 이전 캡처를 덮어쓰므로 재실행하지 않는다.
