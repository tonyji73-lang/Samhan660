# Living City UI V1.4 — 생산·건설·연구 장식 확장

2026-09-29. V1.3에서 제안한 다음 작업과 `LIVING_CITY_UI_V1_4_VS_CODE_TASK.md`에 따라 기존 생산·건설·연구 창에 장식과 제목 서체를 연결했다. 견적·업무·월 처리 규칙은 변경하지 않았다.

## 수정 파일

| 파일 | 실제 변경 |
| --- | --- |
| `production_overlay.gd` | 기존 창에 work_panel 장식, 동적 도시명·생산 제목, 날짜·금 본문 분리, 생산 시작 버튼의 붉은 장식 연결. 닫기 버튼을 필드로 노출 |
| `industry_assignment_overlay.gd` | 건설·연구·생산 관리 제목에 명조, 국고는 기존 본문 서체 유지. 접수 버튼 장식, 긴 선택 문구 말줄임·담당자 전체 문구 툴팁, 가로 스크롤 방지 |
| `ui/living_city_v1/industry_style.gd` | 두 창에서 사용하는 작은 표현 전용 헬퍼. 기존 V1.3 리소스·장식·버튼 스타일 재사용. 버튼의 기존 글꼴·크기·최소 크기·상태별 콘텐츠 여백 복원 |
| `tests/living_city_ui_v1_4_play.gd` | 632년 신라·금성 수정 전후 캡처, 두 해상도의 경계 상태·키보드·실제 버튼 동작·내정 비율 검사 |
| `tests/living_city_v1_4_review/` | 비교 HTML/JPG, 원본 PNG, 회귀 검증용 사본, 실행 로그, 해시, 수정 전 소스 사본 |

원본 PNG·TTF·manifest·생성된 `.res`는 변경하거나 재생성하지 않았다. `work_panel`과 `primary` 프로파일의 원본 영역·논리 크기·9분할을 그대로 사용한다. 창 장식은 기존 Node2D로 그려 입력·포커스·Container 슬롯을 차지하지 않는다. 공용 Atlas 테마는 수정하지 않았다.

제목만 NanumMyeongjo ExtraBold 30px을 사용한다. 실제 도시명과 업무 종류에 따라 Label을 갱신하며 고정 제목 이미지를 사용하지 않는다. 본문과 버튼의 기존 서체·글자 크기를 유지한다. 생산 창의 20/16 패딩, 업무 창의 18 패딩, 창 앵커, 확정·취소·닫기 순서와 하단 배치를 보존했다. 제목 행의 높이는 커져 내부 스크롤 영역만 그만큼 줄어든다.

## 보존 확인

작업 경로는 `.worktrees/project-foundation-v1`, 실제 브랜치는 기존과 같은 `main`이다. 브랜치 전환·stage·commit·push·merge·reset·clean을 하지 않았다.

작업 시작 시 기록한 SHA-256과 비교한 `campaign_main.gd`, `domestic_assignment_overlay.gd`, `settlement_overlay.gd`, `ui/light_atlas_v1/atlas_theme.gd`, `tests/HOME_HANDOFF_20260923.md` 5개 파일이 모두 동일하다. 기존 미커밋 변경을 보존했다. 양쪽 해상도에서 실제 내정 화면의 도시 65%·업무 35%도 검사했다.

## 이번 실행 결과

과거 V1.2/V1.3 수치는 합산하지 않는다. 중간 재실행을 중복 합산하지 않은 **최종 검증 485개, 실패 0개**다.

| 이번 최종 실행 | 검사 | 실패 | 로그 |
| --- | ---: | ---: | --- |
| 생산 회귀, 현재 UI 진입을 사용하는 검증용 사본 | 193 | 0 | `production-regression-current.log` |
| 건설·연구·생산 담당자 회귀 | 155 | 0 | `industry-regression.log` |
| 실제 GUI 장기 업무 흐름 | 55 | 0 | `functional-gui-final.log` |
| 720p·1080p 화면·상태·입력·내정 비율 | 82 | 0 | `visual-final.log` |

별도로 수정 전 화면 확보 실행은 28개 검사, 실패 0개였다. 위 485개에는 포함하지 않았다. `git diff --check`도 통과했다.

- 실제 632년 신라 시작, 금성 담당자를 기존 이동 명령으로 금관가야에 보내 월 도착을 확인했다. 제련소·군기감 건설과 도검 제작 연구를 각각 접수하고 비용 1회 지불, 진행 중 저장·복원, 실제 다음 달 버튼을 통한 완료를 확인했다. 생산 담당자를 배정하고 두 생산 공정을 시작한 뒤 실제 칼 재고 증가를 확인했다. 자원·날짜·인물을 주입하지 않은 GUI 흐름이다.
- 금성 화면 검사는 1280×720과 1920×1080에서 생산 기본·조건/버튼 영역·건설·연구·생산 담당자 화면을 캡처했다. 두 해상도에서 접수·비활성·일시 중지·변경/재개·첫 진척 전 취소 환불·닫기·Esc·지도 입력 복구를 확인했다.
- normal/hover/pressed/hover_pressed/disabled의 텍스처 연결을 검사하고 실제 마우스 hover·누름과 키보드 focus·Tab 이동을 캡처했다. 버튼 밖에서 마우스를 놓으면 접수되지 않음을 확인했다.
- 긴 이름·빈 후보·90줄 설명은 **UI만 변경한 경계 테스트**다. 실제 인물·게임 데이터는 바꾸지 않고 검증 후 목록을 재구축했다. 긴 이름은 창 너비를 늘리지 않으며 툴팁에 전체 문구가 남는다. 빈 후보는 접수 불가, 긴 설명은 내부 세로 스크롤로 표시한다.

### 중간 실패와 수정한 검증 경로

오래된 생산 검사는 숨겨진 구형 지도 카드에서 시작하고 자식 인덱스로 닫기 버튼을 찾았다. 검증용 사본에서 현재 캠페인 생산 진입 핸들러와 명시적 닫기 버튼 필드로 바꿨다. 따라서 이 사본의 생산 진입 검사는 구형 카드의 전체 신호 체인을 검증한 것으로 해석하면 안 된다.

오래된 장기 GUI 검사는 숨겨진 `end_turn_button`을 눌렀고, 633년 1월 나타난 전투 공훈 창을 닫지 못했다. 사본에서 현재 `settlement_overlay.buttons.month`를 누르고 공훈 창은 Esc로 닫도록 보완했다. 게임의 월 처리·전투 규칙은 변경하지 않았다. 초기 실패 로그 `production-regression.log`, `functional-gui.log`, `functional-gui-current.log`도 보존한다. 최종 로그에는 스크립트 오류가 없고, 기존 환경의 Windows 루트 인증서 저장소 경고만 남는다.

## 화면 비교와 자료

[수정 전후 비교 HTML](living_city_v1_4_review/index.html)에서 같은 표시 크기의 좌우 비교와 원본 해상도 이미지를 연다. 생산 기본, 생산 조건/버튼, 건설 담당자, 연구 담당자, 생산 담당자 5종 × 2개 해상도를 제공한다.

| 화면 | 720p 비교 | 1080p 비교 |
| --- | --- | --- |
| 생산 기본 | [비교](living_city_v1_4_review/compare_720_production.jpg) | [비교](living_city_v1_4_review/compare_1080_production.jpg) |
| 생산 조건·버튼 | [비교](living_city_v1_4_review/compare_720_requirements.jpg) | [비교](living_city_v1_4_review/compare_1080_requirements.jpg) |
| 건설 담당자 | [비교](living_city_v1_4_review/compare_720_build_selected.jpg) | [비교](living_city_v1_4_review/compare_1080_build_selected.jpg) |
| 연구 담당자 | [비교](living_city_v1_4_review/compare_720_research_selected.jpg) | [비교](living_city_v1_4_review/compare_1080_research_selected.jpg) |
| 생산 담당자 | [비교](living_city_v1_4_review/compare_720_production_selected.jpg) | [비교](living_city_v1_4_review/compare_1080_production_selected.jpg) |

원본 `before_*.png`·`after_*.png`를 보존한다. `after_*_pending/paused/hover/pressed/focus/no_candidates/long_name/scroll/domestic_unchanged.png`와 `functional/` 아래의 장기 업무 캡처도 있다. 전달 ZIP은 보고서와 비교 HTML·20개 원본 화면·10개 비교 JPG만 포함한다.

## 남은 차이와 미검증

- V1.3 내정 시안의 자산 언어를 생산 모달에 확장했다. 생산 전용 승인 시안은 없으므로 그 시안과 픽셀 단위로 일치한다고 주장하지 않는다. 기존 어두운 바탕과 긴 설명·드롭다운 구조를 유지했다. 후보 카드 전환이나 비용 요약 재배치는 이번 범위가 아니다.
- 원래 버튼 높이와 본문 크기를 보존하여 붉은 버튼이 내정 화면보다 얇고, 생산 본문은 720p에서 작다. 폰트 전체 확대와 설명 재구성은 별도 UX 작업으로 남긴다. 현재 캡처에서는 테두리·제목·버튼 간 겹침이 보이지 않는다.
- 두 해상도 외 화면 비율, 운영체제 DPI 조합, 게임패드, 많은 후보의 네이티브 팝업, 모든 도시·시나리오의 수동 플레이는 검증하지 않았다. 장기 정상 GUI는 720p에서 실행했으며 1080p에서는 화면과 접수·중지·재개·취소를 검사했다.
- `.godot` 캐시 환경 정상화, 실제 export 실행과 배포물 OFL 동봉은 이번에 수행하지 않았다. V1.3에서 마련한 명시적 `.res`를 계속 사용한다.

## 다음 작업과 VS Code 지시문

다음 우선 작업은 배포 전용 별도 디렉터리에서 export·실행·라이선스를 확인하는 것이다. 본문 확대나 담당자 카드 전환은 별도 범위로 정한다.

```text
현재 프로젝트 지침과 tests/LIVING_CITY_UI_V1_4.md를 확인하라.
기존 미커밋 작업·보호 파일·브랜치를 유지하고 stage/commit/push/merge하지 마라.
원본 worktree의 .godot 권한을 바꾸거나 캐시를 삭제하지 말고,
배포 검증용 별도 작업 디렉터리와 기존 export 설정을 조사하라.
Godot import/export에 필요한 최소 환경을 준비하고 Windows 배포본을 실행해
632년 신라·금성의 내정·생산·건설·연구에서 폰트/장식 리소스 누락과
저장·재실행을 확인하라. NanumMyeongjo OFL 및 기존 폰트 라이선스 동봉을 확인하라.
실제 수행 결과·배포 파일 크기·실행 방법·미검증을 보고하고,
게임 규칙이나 UI 구조를 이 배포 작업에 섞어 변경하지 마라.
```
