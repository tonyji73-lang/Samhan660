# Samhan660 Living City UI V1.3 — 실제 장식 자산

6종 PNG, 제목용 한글 서체 2종, 적용표, 원본 영역/9분할 명세, 참고 GDScript와 VS Code 지시문을 포함한다.

1. ZIP을 풀고 **index.html**을 열어 자산과 상태를 확인한다. 인터넷 연결 없이 동작한다.
2. VS Code 에이전트에 **VS_CODE_TASK.md**의 지시문을 전달한다.
3. 실제 Godot의 720p/1080p 화면과 기존 내정 동작까지 확인한 뒤 적용 완료로 판단한다.

이 파일은 게임 실행 프로젝트가 아니다. 기존 프로젝트의 project.godot를 계속 사용한다. 원본 PNG를 바로 넣으면 여백 때문에 잘못 보일 수 있으므로 ASSET_SPEC.md와 manifest의 원본 영역을 적용한다.

기본 방향: 1번 ‘살아 있는 도시’, 도시 65%/업무 35%, 동적 텍스트와 기존 기능 유지. 나눔명조는 제목에만 적용한다. 붓글씨는 선택 비교용이다.

이곳에서 완료한 것: 자산 제작·측정·폰트 확보·미리보기 HTML의 경로/구문 확인. 미완료: 브라우저 미리보기 실행, 사용자 Windows 프로젝트 연결과 Godot 실행. 아래 reference 화면은 사용자가 제공한 **V1.2 실제 화면**이며 V1.3 적용 결과가 아니다.

- ASSET_SPEC.md: 적용 규칙과 변경된 분할 폭
- asset_manifest.json: 실제 원본 크기/영역/표시 프로필/해시
- integration_examples/ornament_resources.gd: 읽기·영역 대응·9분할 참고 코드
- SOURCES.md: 서체 출처/버전/라이선스와 기술 문서
- QA.md: 이 패키지의 검수 결과와 미검증 범위
- PROMPTS.json: 최종 이미지 생성 프롬프트
