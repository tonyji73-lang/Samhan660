> 현재 적용 및 검증은 [Living City V1.1](LIVING_CITY_UI_V1_1.md)을 참조한다. 아래는 이전 버전 기록이다.

# 살아 있는 도시 UI v1 — 교체 기록

2026-09-28, `Samhan660_Living_City_UI_V1_20260928.zip` 기준. 이전 한지 국정 장부 디자인을 대체한다.

## 사용 방법

게임 실행 → 642년 신라 → 금성 → **영지 / 인사**. 영지는 개발 담당자 선택, 인사는 태수 후보 비교·임명으로 연결된다. 태수 변경으로 두 화면을 오갈 수 있다. 군수·조정·외교는 기존 화면으로 연결된다.

## 교체한 내용

- 도시 65% / 업무 패널 35% 구성. 제공된 불투명 채색 전경을 도시 영역에만 표시하며 비율을 보존해 가장자리만 자른다.
- 어두운 상하단, 청동·금색 테두리/선택, 크림색 오른쪽 패널, 붉은 확정 버튼.
- 오른쪽 상단의 큰 초상은 내정에서는 현재 태수, 인사에서는 선택 후보를 표시한다. 기존 인물 초상과 식별자를 유지한다.
- 농경지·시장·공방은 실제 버튼이다. 업무 탭으로도 같은 기능에 접근한다.
- 후보/작업 상세는 스크롤하며 비용을 표시한 확정 버튼, 불가 사유, 취소·닫기는 화면에 유지한다.
- 이전 개발/임명/정치 견적/저장 연결을 유지했다. 게임 규칙, 초기 수치, 승인된 지도와 거점 좌표는 수정하지 않았다.

## 파일

- `domestic_assignment_overlay.gd`: 새 화면 구성·자산·선택 인물 표시. 기존 명령 함수 호출 유지.
- `ui/living_city_v1/living_city_theme.gd`: 전용 색상과 버튼/프레임 테마. 기존 한글 글꼴·아이콘·종이 질감 재사용.
- `ui/living_city_v1/assets/city.png`: 패키지 전경 원본 복사.
- `tests/living_city_ui_play.gd`: 새 UI 자동 입력/스크린샷/기능 검사.
- `tests/hanji_ui_play.gd`: 새 테스트로 연결하는 호환 진입점. 이전 캡처를 덮어쓰지 않는다.
- `dev/living_city_ui_source/samhan660_living_city_ui_v1/`: 새 원본 지시서와 참고 이미지.
- `dev/hanji_ui_source/retired_runtime/`: 이전 테마와 전경 보관. `.gdignore` 하위이며 현재 게임에서 로드하지 않는다.
- `tests/HANJI_UI_V1.md`: 대체된 기록임을 명시. 이전 QA는 `tests/hanji_review/design-qa.md`에 보관하고 루트 `design-qa.md`는 새 디자인 기준으로 갱신했다.

현재 main 작업 위치에서 수정했다. 별도 브랜치/worktree 생성, stage/commit/push는 하지 않았다. 기존 `tests/HOME_HANDOFF_20260923.md`는 보존했다.

## 이번에 새로 실행한 검증

Godot 4.7.2 / Windows / D3D12 / RTX 4060 Laptop GPU. 실제 게임 창에 자동 입력을 넣은 검사이며 사람의 장시간 수동 플레이와 구분한다.

| 검사 | 이번 결과 |
| --- | --- |
| Living City GUI: 정상 플레이, 예외 상태, 후보 스크롤, 도시 전환, 65:35 비율, 큰 초상 연동 | 63개 통과, 실패 0 |
| 기존 내정 회귀: 세 국가, 비용/능력/상한/담당자 충돌/태수 효과/결산/저장 호환 | 131개 통과, 실패 0 |
| 마지막 표시 정보 정리 후 화면·배치 재검사 | 27개 통과, 실패 0 |
| `git diff --check` | 통과 |

기존 회귀는 `.godot` 출력 폴더 쓰기 문제를 피하려고 출력 경로만 `tests/living_city_review/regression/`으로 바꾼 임시 복사본을 실행했다. 테스트 판정과 게임 코드는 바꾸지 않았다. 로그에 Windows 루트 인증서 경고는 있으나 최종 검사에서 스크립트 오류나 실패는 없다.

정상 642년 신라: 선덕여왕 담당으로 금 **100** 지불, 국고 **1000→900**. 접수 때 농업 **74** 유지, 2월 처리 후 **79**. 취소·재접수·중복 확정·실제 업무 저장/복원 확인. 태수 **김춘추→선덕여왕**, 같은 시점 실제 월 세입 견적 **160→159**. 임명 후 정치 값과 저장/복원 일치. 결과는 `living_city_review/results.json`.

금 부족, 공석, 후보 없음, 후보 4명 이상은 정상 경로 검증 후 별도 메모리 fixture에서 확인했다. 정상 경로에 자금/능력/규칙 수정은 없었다. 저장은 검사 폴더 안 별도 슬롯만 사용했다.

## 화면 근거

- 교체 전: [내정](living_city_review/before-domestic-1280.png), [인사](living_city_review/before-personnel-1280.png)
- 새 내정: [1280×720](living_city_review/domestic-1280.png), [1920×1080](living_city_review/domestic-1920.png), [2560×1440](living_city_review/domestic-2560.png)
- 새 인사: [1280×720](living_city_review/personnel-1280.png), [1920×1080](living_city_review/personnel-1920.png)
- 정상 접수/완료: [접수](living_city_review/pending-1920.png), [월 완료](living_city_review/completed-1920.png)
- 원본과 나란히 비교: [내정](living_city_review/comparison-domestic.png), [인사](living_city_review/comparison-personnel.png)
- 로그: `living_city_review/play.log`, `regression.log`, `visual.log`.

## 남는 시각 차이와 미검증

시안의 새 얼굴은 사용하지 않았다. 기존 초상은 사각 배경과 저해상도 질감을 가지므로 원본의 큰 투명 인물화와 다르다. 별도 목재/금속 장식 스프라이트가 없어 어두운 프레임과 금색 선으로 표현했으며 조각 문양·광택·서예 제목을 픽셀 단위로 재현하지 않았다. 가짜 업무나 예시 수치를 채워 넣지 않았다.

도시 그림은 금성 대표 화면에만 적용한다. 다른 도시 전경은 준비 중 표시를 사용한다. 임명 전후 세입/수확의 별도 공통 견적 API는 없어 수식을 복제하지 않았고 현재 운영 값·정치 예측·인계 조건을 표시한 뒤 임명 후 실제 값을 갱신한다.

권력 인계 협의의 모든 분기, 생산 업무의 정지·재개 전 분기, 배포 export와 장시간 수동 플레이는 이번 교체 검증에 포함하지 않았다. 다음 달은 기존 사건 처리 흐름에 따라 지도로 돌아가며 내정을 다시 열면 실제 결과가 표시된다.

## 재실행

```powershell
& 'C:/Users/지용훈/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe' --path . --script tests/living_city_ui_play.gd --log-file "$((Get-Location).Path)/tests/living_city_review/play.log"
```

끝에 `-- --visual-only`를 추가하면 초기 화면과 배치만 검사한다.

