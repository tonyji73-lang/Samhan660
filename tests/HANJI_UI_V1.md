# 한지 내정 UI v1 적용 — 2026-09-28

> **대체됨:** 현재 게임은 [살아 있는 도시 UI v1](LIVING_CITY_UI_V1.md)을 사용한다. 아래 내용과 `hanji_review` 캡처는 이전 적용 기록이다.

## 적용과 실행

다운로드의 `Samhan660_Hanji_UI_V1_20260928.zip`을 읽고 현재 main 작업 폴더에 적용했다. 원본 문서와 시안은 `dev/hanji_ui_source/samhan660_hanji_ui_v1/`에 보관한다. 새 브랜치/worktree, stage, commit, push는 하지 않았다. 기존 미추적 `tests/HOME_HANDOFF_20260923.md`는 수정하지 않았다.

게임 실행 → 642년 신라 → 금성 선택 → **영지**에서 한지 내정, **인사**에서 같은 도시의 태수 임명을 연다. 내정의 태수 변경으로도 진입한다. 다음 달은 기존 월 처리와 사건 표시를 위해 지도로 복귀한다. 결과는 내정을 다시 열어 확인한다.

## 변경 파일과 연결

- `domestic_assignment_overlay.gd`: 기존 농업·상업 담당자 팝업을 한지 전체 화면으로 교체. 국가/도시/날짜/국고/군량, 도시 그림과 별도 장소 버튼, 업무 기록, 도시 현황, 태수와 담당자 초상, 후보 가로 스크롤, 예측 정보, 확정/취소/해임/탐색을 구현했다.
- `ui/hanji_domestic_v1/hanji_theme.gd`: 기존 Atlas 글꼴과 포커스/비활성 스타일을 재사용하는 국정 화면 전용 테마.
- `ui/hanji_domestic_v1/assets/city.png`: 제공된 투명 도시 PNG의 원본 복사. 금성에만 표시한다. 다른 도시에는 전경 준비 중임을 표시하고 실제 데이터는 정상 연결한다.
- `settlement_overlay.gd`: 전략지도 인사 버튼을 선택 도시의 새 태수 화면에 연결. 기존 전체 정치 화면은 새 화면의 조정으로 접근한다.
- `tests/hanji_ui_play.gd`: 정상 642 캠페인 GUI 입력, 저장 슬롯, 예외 상태 및 화면 캡처 검증.

개발은 `get_domestic_quote/start_domestic/cancel_domestic`, 운영 수치는 `city_operation_quote/get_city_operation_text`, 인사는 `noble_personnel.quote/appoint`, 인계 조건은 `Power.quote/intercept`를 사용한다. 초상은 현재 레지스트리에서 이름을 읽어 기존 `map_area._get_portrait_texture` 연결을 재사용한다. 새 계산식/정치 계수/인물/업무를 추가하지 않았다.

## 이번에 실제 실행한 검사

Godot 4.7.2, Windows, D3D12 / RTX 4060 Laptop GPU. 사람이 직접 플레이한 검증이 아니라 실제 Godot 창에 자동 마우스·키보드 입력을 넣은 검사다.

- 새 GUI 검사 **58개, 실패 0**: 영지/인사 진입, 읽기 전용 미리보기와 취소, 개발 접수·중복 확정·환불, 다음 달 완료, 임명·중복 정치 효과 방지, 저장/복원, 금 부족, 후보 4명 이상과 끝 후보 선택, 후보 없음, 공석, 키보드 포커스, 반복 Esc/닫기, 도시 변경, 기존 생산/외교 연결.
- 기존 `domestic_assignment_test.gd` 회귀 **131개, 실패 0**. `.godot` 출력 디렉터리 쓰기가 실패하여 테스트 내용은 유지하고 출력 경로만 `tests/hanji_review/regression/`으로 바꾼 임시 복사본을 실행했다. 세 국가의 능력/비용/상한/충돌/태수 효과/월 결산/저장 호환을 검사했다.
- 후보 초상 확대와 인사 화면의 불필요한 업무 탭 제거 후 **시각 검사 23개, 실패 0** 재실행. 1280×720, 1920×1080, 2560×1440 내정과 1280×720, 1920×1080 인사에서 확인했다.
- `git diff --check` 통과. 로그의 Windows 루트 인증서 저장소 경고는 남아 있으나 스크립트 오류 및 검사 실패는 최종 실행에 없다.

정상 캠페인 결과 (`hanji_review/results.json`):

- 선덕여왕 농업 담당: 실제 견적 비용 금 100, 국고 1000→900. 확정 시 농업 74 유지, 642년 2월 처리 후 **74→79**.
- 개발 취소와 재접수 후 저장/복원하여 동일 업무·담당자·국고를 확인.
- 태수 **김춘추→선덕여왕** 임명. 같은 시점 월 세입 견적 **160→159**, 실제 개인 충성과 집단 협력/영향력도 기존 인사 계산으로 갱신. 임명 후 저장/복원 일치.
- 금 부족/후보 없음/4명 이상/공석은 정상 플레이 완료 뒤 별도 메모리 fixture로 확인했다. 정상 결과를 만들기 위해 초기 자금·능력·규칙은 바꾸지 않았다.

기존 레거시 `map_area`는 새 전략지도 아래에서 항상 잠겨 있다. 현재 입력 복구는 `settlement_overlay.busy()`와 화면 닫힘을 기준으로 검증한다. 레거시 잠금을 억지로 해제하지 않았다.

## 캡처

- 적용 전: [before-1280.png](hanji_review/before-1280.png)
- 내정: [1280](hanji_review/domestic-1280.png), [1920](hanji_review/domestic-1920.png), [2560](hanji_review/domestic-2560.png)
- 태수 후보: [1280](hanji_review/personnel-1280.png), [1920](hanji_review/personnel-1920.png)
- 실제 접수/완료: [접수](hanji_review/pending-1920.png), [완료](hanji_review/completed-1920.png)
- 시안 비교: [내정](hanji_review/comparison-domestic.png), [인사](hanji_review/comparison-personnel.png)
- 실행 로그: `hanji_review/play.log`, `regression.log`, `visual.log`.

## 시각 차이와 한계

원본의 붓글씨 제목·붓자국 버튼·인장·매화 장식은 독립 자산으로 제공되지 않았다. 기존 한글 글꼴·한지와 붉은 버튼/밑줄을 사용했으므로 시안과 픽셀 단위로 일치하지 않는다. 기존 장수 초상의 색감·배경도 시안의 새 얼굴과 다르며 요청대로 교체하지 않았다. 빈 업무 상태에 시안의 가짜 작업을 넣지 않았다.

태수 임명 전후의 세입·수확 숫자를 계산하는 공통 견적 API가 없어 UI에 별도 공식을 복제하지 않았다. 현재 운영 수치와 인사 정치 예측/인계 제한을 표시하고 성공 후 실제 운영 수치를 갱신한다. 타 도시 전경, 개별 붓글씨/인장 자산은 후속 시각 작업이다.

이번 UI를 통한 모든 인계 협의 분기, 수작업 장시간 플레이, 배포용 export는 미검증이다. 건설/생산의 업무 정지·재개는 기존 화면과 실제 업무 기록으로 연결하며 이번 GUI 검사에서 전 분기를 재실행하지 않았다. 사용자 기본 저장 파일은 사용하지 않고 이 검사의 별도 프로젝트 내 슬롯만 썼다.

## 재실행

```powershell
& 'C:/Users/지용훈/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe' --path . --script tests/hanji_ui_play.gd --log-file "$((Get-Location).Path)/tests/hanji_review/play.log"
```

끝에 `-- --visual-only`를 추가하면 정상 초기 상태의 화면과 배치만 확인한다.
