# Living City UI V1.1 적용 기록

2026-09-28. 다운로드의 `Samhan660_Living_City_UI_V1_1_20260928.zip`을 기존 Living City V1에 적용했다. 정상 새 캠페인 **632년 신라·금성**이 기준이다. 첨부된 사용자 저장은 없으므로 같은 연도의 새 캠페인을 사용했다. 시안의 642년 예시 수치는 게임에 옮기지 않았다.

## 변경과 실제 연결

- `domestic_assignment_overlay.gd`: 현재 태수와 현재 월 세입·운영 효과, 선택 후보의 큰 초상·이름·능력·역할, 임명 시 변화를 분리했다. `Personnel.quote`의 읽기 전용 결과로 능력·개인 충성·집단 협력·집단 영향력의 전후와 차이를 표시한다. 영향력 증가는 중립색이다.
- `campaign.city_operation_quote`는 현재 효과에만 사용한다. 세입·수확의 후보별 미래 견적 API가 없어 UI 계산식을 추가하지 않았다. 임명 후 현재 태수·실제 효과·후보·업무를 다시 읽는다.
- 도시/업무/후보가 바뀌면 설명 스크롤을 첫 줄로 초기화한다. 같은 후보의 갱신은 읽던 위치를 유지한다. 위아래 여백과 상세 스크롤 표시를 추가했다.
- 65:35 도시/업무 구성을 유지하고 초상·이름·능력을 강조했다. 기존 1024px 초상을 사용하며 선덕여왕은 기존 투명 오버레이의 상반신을 AtlasTexture로 표시한다. 원본 얼굴이나 자산 파일은 수정하지 않았다.
- `ui/living_city_v1/living_city_theme.gd`: 붉은 주 버튼 높이 72, 글자 30, 금색 테두리 및 hover/pressed/focus/disabled 상태. 취소·닫기는 보조 버튼, 해임은 현재 태수 옆에 대상 이름을 명시한다. 해임 확인창을 거친 뒤 기존 `campaign.dismiss_governor`를 호출하며 기존 인계 제약을 유지한다.
- 개발은 기존 `get_domestic_quote` → `start_domestic`/`cancel_domestic`, 임명은 `Personnel.quote` → `Personnel.appoint` 및 `Power.quote` 경로를 유지한다. 기존 지도 영지/인사 진입점과 조정·군수·외교 연결도 유지한다.
- 기존 검증은 활동 중인 같은 세력의 현지 장수를 허용하며 군주 금지 규칙은 없다. 선덕여왕에 **신라 군주**를 표시하고 기존 태수 겸임 가능 규칙을 유지한다.

원본 패키지는 `dev/living_city_ui_v1_1_source/`에 보관했다. 게임 규칙·초기 수치·전략 지도·거점 좌표는 변경하지 않았다. 기존 작업과 `tests/HOME_HANDOFF_20260923.md`를 보존했으며 stage/commit/push는 하지 않았다.

## 이번 실행 결과

Godot 4.7.2, Windows, 실제 GUI 렌더링/자동 입력. 별도 테스트 저장 슬롯만 사용했다.

| 검사 | 결과 |
| --- | --- |
| V1.1 UI 기능·배치·긴 텍스트·캡처 검사 | 105개 통과, 실패 0 |
| 기존 내정 회귀: 3개 국가, 비용·능력·상한·충돌·태수 효과·결산·저장 호환 | 131개 통과, 실패 0 |

정상 개발: 선덕여왕 담당, 금 **100**, 국고 **1000→900**. 접수 직후 농업 **74** 유지, 정상 다음 달 완료 후 **79**. 취소·재접수·중복 확정 방지·저장 복원을 확인했다.

정상 임명: 현재 **김춘추** / 후보 **선덕여왕**, 정치 **98→93(-5)**. 미리보기는 상태를 바꾸지 않는다. 임명 후 현재 태수가 선덕여왕으로 바뀌고 같은 시점의 실제 월 세입은 **160→159**로 갱신됐다. 반복 임명으로 정치 효과가 중복되지 않으며 저장/복원 결과도 일치한다. [수치 결과](living_city_v1_1_review/results.json).

금 부족·후보 없음·공석·후보 4명 이상·긴 이름/사유는 정상 플레이 이후 별도 메모리 fixture로 검사했다. 긴 사유는 UI 레이아웃 스트레스용 문자열이다. 해당 fixture에서 발견한 하단 버튼 겹침은 상세 영역의 최소 높이를 줄여 수정했다. 첫 진입·후보 변경의 스크롤 시작, 같은 후보의 스크롤 유지, Esc·닫기·도시 전환 후 지도 입력 복구도 검사한다.

내정 회귀는 `.godot` 폴더 쓰기 문제를 피하기 위해 출력 위치만 이번 검사 폴더로 바꾼 복사본으로 실행했다. Windows 루트 인증서 읽기 경고는 남아 있다.

## 화면 근거

수정 전후 같은 632년 1월·금성 상태에서 캡처했다. 각 비교판은 왼쪽 수정 전, 오른쪽 수정 후다.

- [내정 전후](living_city_v1_1_review/before-after-domestic.png), [담당자 선택 전후](living_city_v1_1_review/before-after-officer.png), [태수 후보 전후](living_city_v1_1_review/before-after-personnel.png)
- 수정 후 720p: [내정](living_city_v1_1_review/domestic-1280.png), [담당자 선택](living_city_v1_1_review/officer-1280.png), [인사](living_city_v1_1_review/personnel-1280.png)
- 수정 후 1080p: [내정](living_city_v1_1_review/domestic-1920.png), [담당자 선택](living_city_v1_1_review/officer-1920.png), [인사](living_city_v1_1_review/personnel-1920.png)
- 임명 후: [720p](living_city_v1_1_review/appointed-1280.png), [1080p](living_city_v1_1_review/appointed-1920.png)
- [긴 텍스트](living_city_v1_1_review/long-text-1280.png), [접수](living_city_v1_1_review/pending-1920.png), [월 완료](living_city_v1_1_review/completed-1920.png)
- 승인 시안(왼쪽)과 구현(오른쪽): [내정](living_city_v1_1_review/reference-domestic.png), [인사](living_city_v1_1_review/reference-personnel.png)

자세한 시각 비교는 [design-qa.md](../design-qa.md)에 기록했다. 세 화면의 수정 전 캡처도 `before-화면-1280/1920.png`로 보관했다.

## 남는 차이·미검증

선덕여왕 외 인물은 기존 사각 배경 초상이다. 시안의 새 얼굴은 적용하지 않았다. 목재 조각·금속 광택·서예 제목 등의 독립 자산이 없어 어두운 프레임과 금색 선으로 단순화했다. 도시 전경은 금성만 제공되며 다른 도시에는 준비 중 표시가 나온다. 세입·수확 임명 전 예측은 미연결이며 임명 후 실제 값만 갱신한다.

권력 인계 협의 모든 분기, 생산 업무의 모든 정지/재개 분기, 해임 확정의 GUI 전체 경로, 배포 export, 장시간 수동 플레이는 이번 검증에 포함하지 않았다. 해임 확인/취소와 기존 내정 회귀의 해임 이력은 확인했다.

## 재실행

```powershell
& 'C:/Users/지용훈/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe' --path . --script tests/living_city_ui_v1_1_play.gd --log-file "$((Get-Location).Path)/tests/living_city_v1_1_review/play.log"
```

화면만 다시 검토할 때는 끝에 `-- --visual-only`를 추가한다. `--before`는 적용 전 캡처용 옵션이므로 현재 상태에서 실행하면 보관 중인 이전 화면을 덮어쓴다.

