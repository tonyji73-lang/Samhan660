# 승인 한국 지도·35개 거점 기본 연결

2026-09-21, 기존 main / HEAD d953cfac9fb70e10c2c45ef659eb0d1bd57e5aaf. 새 브랜치·커밋·Push 없음. 기존 미커밋 게임/UI/지도 코드와 검증 기록을 보존했다.

## 자료와 실제 변경

지정한 바탕화면 폴더는 현재 PC에서 찾지 못했다. 기본 Desktop, OneDrive 바탕화면을 확인한 뒤 다운로드에서 같은 이름의 `C:\Users\지용훈\Downloads\Samhan660_Korea_Castle_Layout_v1.zip`을 찾아 사용했다. 이 사실은 작업 중 사용자에게 알렸다. ZIP의 VS_CODE_REQUEST.txt, APPLY_IN_GODOT_KO.md와 지도 모듈을 읽었다. 프로젝트/상위 경로의 AGENTS.md는 발견되지 않았으며 세션 지침을 적용했다.

ZIP은 프로젝트 밖 `C:\Users\지용훈\AppData\Local\Temp\samhan-castle-layout-d1anpq92\Samhan660_Korea_Castle_Layout_v1`에 풀어 예제를 검사했다. 예제 project.godot/demo 파일을 현재 게임에 복사하지 않았다.

- `ui/korea_layout_v1/`: 승인 지도 모듈, PNG 두 장, 좌표 JSON을 새 경로로 추가. 원본 스크립트·두 PNG·JSON은 ZIP 해당 파일과 바이트 동일하다. Godot import/UID 파일도 생성됐다.
- `settlement_overlay.gd`: 지도 preload를 승인 모듈로 연결. 거점 지도의 일반 진입에서 바로 표시하며 한국 시안/동해 상세 버튼을 거칠 필요가 없다. 전체 버튼은 fit_all(), 경로 취소는 clear_route()에 연결했다. 기존 세계 지도 복귀와 영지/군사/생산/인사/지원 명령은 그대로 재사용한다.
- `tests/approved_castle_layout_test.gd`, `tests/approved_castle_layout_restart.gd`: 기본 진입부터 실제 캠페인 GUI와 새 프로세스 복원을 확인하는 검사.

과거 settlement_map.gd·동해 상세 셰이더·원본 PNG·기존 기록은 삭제하거나 덮어쓰지 않았다. 이제 거점 지도의 기본 렌더러는 승인 지도이므로, 과거 비교 모드 전용 검사는 그 당시 화면을 대상으로 한 기록이다. 이번 화면은 새 검사로 구분했다. 세력 선택 UI는 수정하지 않았다.

승인 지형 SHA256: `36594c1d1ee0cbcd80a175d72790d3e22423103cf81d6b191f8bf2d317e1f246`. 35개 표시 좌표·성 크기·marker_only 설정을 그대로 사용했다. 표시 좌표를 WORLD_CITY_MAP_UV나 이동/전투/저장 좌표로 치환하지 않았다. 소속과 병력은 기존 캠페인의 provinces에서 ID로 읽는다.

## 실제 실행

Godot 4.7.2 사용. 별도 예제 import 및 layout_smoke.gd **150 checks, 0 failures**. 엔진 구문 수정 없이 통과했다.

현재 프로젝트 검사는 ProjectSettings의 main_scene을 실제 로드하고 타이틀 새 게임 → 642년 시나리오 → 신라 → 시작 → 거점 지도 버튼을 GUI 자동 입력으로 눌렀다. 편집기에서 사람이 F5 키를 누른 수동 플레이가 아니라, F5와 같은 메인 장면에서 시작한 실제 엔진 GUI 자동 검증이다.

캠페인 GUI 검사 **248 checks, 0 failures**:

- 1280×720 및 1920×1080에서 승인 지도가 기본 표시됨을 확인했다.
- 각 해상도에서 35개 등록 ID, 실제 소유권/병력, 전체보기 최근접 판정, 확대 후 실제 마우스 클릭 선택을 확인했다. 이름표는 밀집 구역에서 기존 제공 모듈의 겹침 회피 정책으로 일부 생략된다. 선택한 이름은 하단 캠페인 정보에 표시된다.
- 실제 휠 확대/축소와 커서 기준 좌표 유지, 드래그 이동, 영지/군사/생산/인사 창 열기·Esc 복귀 후 선택/카메라 유지, 기존 세계 지도 복귀 시 입력 잠금 해제를 확인했다.
- 지원 경로 미리보기/취소, 출발지 ID 연결, 하단 UI와 안내문 화면 내 배치를 확인했다. 다구간 경로의 실제 GUI 명령은 이번 캠페인 검사 범위 밖이며, 단일 지원 명령을 검증했다.
- 금성의 기존 부대를 기존 군사 화면에서 달구벌로 실제 지원 발령했다. 정상 한 달 진행 후 도착했고, 게임 WORLD_CITY_MAP_UV가 바뀌지 않았음을 확인했다.
- 표시/창 조회만 했을 때 캠페인 전체 상태가 바뀌지 않았음을 확인했다.

별도 저장 `user://approved_castle_layout_1789965209_8252.json`을 사용했다. 새 프로세스 복원 검사 **5 checks, 0 failures**:

- 날짜·세력·자원·부대·진행 중 지원 주문 등 전체 저장 상태 일치.
- 복원 후에도 승인 지도와 35개 거점이 기본 표시됨.
- 정상 한 달 뒤 지원 부대 도착, 남은 중복 예약 없음.

최종 세 검사 로그에 ERROR/WARNING/FAIL 없음. 사용자 기본 저장의 SHA256은 검사 전후 `3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3`로 동일하다. 별도 시험 슬롯 외 사용자 슬롯에 쓰지 않았다.

## 실제 화면과 남은 범위

캡처/결과는 `.godot/approved-castle-layout/`에 있다. `{1280,1920}-all35.png`, 각 해상도의 달구벌·실직·금성·울릉 확대, 지원 경로, 정상 월 진행 후 final-gameplay.png, 새 프로세스 restart-gameplay.png를 남겼다. normal.json/restart.json은 검사 수와 시험 슬롯·프로세스 정보를 담는다. 로그는 `.godot/castle-sample-test.log`, `.godot/approved-castle-test.stdout`, `.godot/approved-castle-restart.stdout`.

- [1920 달구벌 실제 게임](../.godot/approved-castle-layout/1920-dalgubeol.png)
- [1280 전체 지도](../.godot/approved-castle-layout/1280-all35.png)
- [1920 지원 경로](../.godot/approved-castle-layout/1920-support.png)
- [새 프로세스 복원](../.godot/approved-castle-layout/restart-gameplay.png)

새 지형용 확정 영토 폴리곤이 없어 경계는 표시하지 않는다. 영토 마스크 미할당 9곳, 성 바닥 전체·역사적 지리 정합·세계 지도 접합을 이번 연결로 완료 처리하지 않았다. 승인 자산의 일부 지역은 marker_only 설정대로 표식이며 이를 성 누락이나 마스크 교정으로 집계하지 않는다. 과거 원본 저장 재검증 2건, 사람의 수동 플레이는 기존 미검증 상태다.
