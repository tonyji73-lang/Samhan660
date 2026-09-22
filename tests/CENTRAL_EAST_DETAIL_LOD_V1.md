# 중부·동해 상세 비교 및 LOD 연결

2026-09-21, 현재 main. 기존 변경 보존. 세력 선택 UI는 변경하지 않았다.
바탕화면의 지정 폴더는 발견하지 못해 Downloads/Samhan660_Central_East_Detail_v1.zip을 사용했다. START_HERE_KO.md, LOD_INTEGRATION_KO.md, data/central_east_detail_manifest.json을 읽고 연결했다.

## 변경과 실행

- ui/korea_layout_v1/approved_korea_map.gd: Rect2(512,544,264,176)에 동일 위치·배율 비교와 미래 정합 자산의 LOD 연결.
- settlement_overlay.gd: 중부·동해 이동 및 후보 보기 / 원본 보기 버튼.
- ui/korea_layout_v1/central_east/: 후보 PNG, 원본 crop, manifest, 전달 문서.
- tests/central_east_lod_test.gd 및 이 기록.

F5 → 642년 신라 → 거점 지도 → 중부·동해 → 후보 보기. 전환 시 카메라는 유지된다. 기본 지도는 기존 승인 지도이고 후보의 자동 전환은 차단했다. 가장자리 흐림으로 지리 차이를 숨기지 않았다.

## 해상도와 원인

실제 표시 텍스처는 원본 1254×1254, 후보 1536×1024. 원본 import는 lossless mode=0, process/size_limit=0으로 불필요한 축소가 없다. import의 mipmaps/generate=false와 별개로 기존 로더가 런타임 밉맵을 생성하며 두 텍스처에서 확인했다. 보간 확대나 샤프닝으로 해상도를 늘리지 않았다.

화면 픽셀 / 텍스처 1픽셀 측정:

| 창 해상도 | 줌 | 원본 | 후보 |
| --- | ---: | ---: | ---: |
| 1280×720 | 1 | 0.352 | 0.060 |
| 1280×720 | 5 | 1.758 | 0.302 |
| 1280×720 | 10 | 3.517 | 0.604 |
| 1920×1080 | 1 | 0.639 | 0.110 |
| 1920×1080 | 5 | 3.194 | 0.549 |
| 1920×1080 | 10 | 6.388 | 1.098 |

1080p 줌5에서 원본의 264×176 부분이 약843×562 화면 픽셀로 늘어나 흐려진다. 후보는 같은 부분에 약5.82배 높은 픽셀 밀도를 제공하지만 지리 정합은 별개다.
픽셀 배율 계산을 viewport.get_final_transform() * get_global_transform_with_canvas()로 연결했다. 엔진 프로브에서 get_screen_transform()만으로 창 stretch가 반영되지 않음을 확인했다. 1920 논리 UI를 1280 창에 표시하는 2/3 배율도 검사했다.

## 미래 정합 자산 연결

전체 지도 → 상세 지도 → 영토/지원 경로 → 성/이름 순서. 좌표와 성 크기는 변경하지 않았다.
현재 manifest의 production_auto_switch_allowed=false 및 status=art_candidate_needs_registration을 유지했다. 향후 아트 정합을 검토한 뒤 texture/size를 갱신하고 production_auto_switch_allowed=true, status=registered, registered_detail_sha256=실제 상세 SHA256을 제공해야 자동 LOD가 허용된다. 원본 해시·사각형·로드 크기도 검사한다. 메타데이터는 사람의 승인 기록이며 지리 정합의 자동 증명이 아니다.
승인 조건을 충족하면 원본1px이 화면1.5~2px가 되는 범위에서 smoothstep으로 상세 가중치가0→1로 변한다. 명시적인 후보 비교는 가중치1. detail_diagnostics()는 후보1px이 화면1.25px를 넘으면 higher_density_needed를 반환한다.

## 이번 실제 검증

Godot4.7.2 D3D12 GUI 자동 입력·엔진 캡처이며 사람의 수동 플레이와 구분한다.

- 신규 검사45 checks, 0 failures. 두 해상도 줌1/5/10 동일 카메라 비교, 사각형, 로드 크기/밉맵, 북한산성·당항성·국원·하슬라·실직·죽령 선택, 지원 경로, 하단 UI, 휠 입력 시 후보 자동 전환 차단.
- 미래 LOD는 메모리 통제 조건으로 승인 필드를 임시 설정하여 실효 배율1/1.75/2.5의 가중치0/0.5/1을 확인 후 복구했다. 디스크 manifest는 false이며 아트 승인 검증이 아니다.
- 기존 승인 지도 GUI 회귀를 이번에 재실행:248 checks, 0 failures. 실제 타이틀→642 신라→거점 지도, 35개 거점 선택·소유권·병력, 창 복귀, 정상 지원 발령과 월 진행 후 도착, 별도 시험 슬롯 저장. 과거 숫자 재사용 아님.
- 최종 로그:.godot/central-test-final.stdout, .godot/central-approved-regression.stdout. 이번 후보의 새 프로세스 복원은 재실행하지 않았다.
- 캠페인 상태 보존 검사 통과. 사용자 기본 저장 SHA256 유지:3bca5c5286be3abb44ed60fbb9e1efe39815c29f6ff255d2ad825273aa5275d3.

캡처:.godot/central-east-lod/{1280,1920}-z{1,5,10}-{before,after}.png, 각 해상도의 *-support.png, 측정 result.json. before/after는 코드 수정 전후가 아닌 동일 카메라의 승인 원본/상세 후보이다.

## 이미지 수정 대상

원본 crop·후보 및 실행 캡처를 육안 대조한 대략적 범위. 좌표는 승인 전체 지도1254 기준이며 정밀 측량이나 자동 정합 점수가 아니다.

| 좌표 범위 | 수정 대상 |
| --- | --- |
| x552~582,y599~626 | 북한산성 북쪽/서쪽 큰 강 합류점의 폭·분기 각도·강둑 |
| x512~567,y624~720 | 북한산성·당항성 서쪽 만·반도·작은 섬, 왼쪽/아래 경계 단절 |
| x592~686,y690~720 | 국원 남쪽 강줄기의 폭·굴곡·하단 출구와 원본 강 연결 |
| x710~776,y544~650 | 하슬라~실직 동해안, 특히 오른쪽 x776,y635~650 해안 높이·굴곡 |

성 주변 숲과 지면도 달라 중심점만으로 성 바닥 전체 정합을 보증하지 않는다. 상세 사각형 밖은 여전히 원본 해상도다. 전체 확대 문제, 성 바닥 전체, 35곳 정합, 영토 마스크 미할당9곳, 세계 지도 접합은 완료 처리하지 않는다. 사람의 수동 플레이와 과거 원본 저장 재검증2건은 미검증 유지.
원본 SHA256:36594c1d1ee0cbcd80a175d72790d3e22423103cf81d6b191f8bf2d317e1f246.
후보 SHA256:20be0889282839a2555d87b67777aa83be00dee6375268889e83182caa0f9a5f.
승인 배치 JSON SHA256 보존:b199ee4a532d37e1bb15cbf0d018d86ac964116bea7731b4d32644796d53d654.
