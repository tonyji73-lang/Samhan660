삼한660 — V1.5 Windows 검수 실행본

실행
1. ZIP을 모두 풀어주세요.
2. Samhan660.exe를 실행하세요. Godot 설치는 필요하지 않습니다.
3. Samhan660.exe와 Samhan660.pck는 같은 폴더에 두세요.
4. 새 게임 → 632년 → 신라 → 캠페인 시작 → 금성을 선택합니다.
5. 내정/인사/군수 메뉴에서 개발·태수 임명·생산·건설·연구를 확인할 수 있습니다.
6. 닫기 또는 Esc로 이전 화면에 돌아갑니다. 화면 내 목록은 휠로 스크롤합니다.

저장
기본 위치는 %APPDATA%\Godot\app_userdata\Samhan660 입니다.
저장·메뉴에서 새 파일명을 선택하여 저장하고, 타이틀의 불러오기에서 선택합니다.
기존 세이브를 덮어쓰지 않으려면 새 이름을 사용하세요.
프로그램 폴더와 별도로 저장되므로 실행 파일을 다른 폴더로 옮겨도 같은 계정에서 불러올 수 있습니다.
검수 과정에서 만들어진 windows_export_v1_5_*.json은 이 ZIP에 포함하지 않았습니다.

확인 환경
Windows x86_64, Godot 4.7.2.stable, D3D12, GeForce RTX 4060 Laptop GPU.
1280×720과 1920×1080 창에서 검사했습니다. 다른 GPU/Windows 환경은 별도 확인이 필요합니다.
licenses 폴더에 엔진·서드파티·본문 글꼴·제목 글꼴·아이콘 라이선스를 동봉했습니다.

자료
review/index.html: 실제 실행본의 화면 캡처.
review/WINDOWS_EXPORT_V1_5.md: 적용·실행·재실행 검증 결과와 남은 확인 항목.

검수 옵션 (일반 플레이에는 필요 없음)
이 검수용 PCK에는 --qa-v1-5 옵션으로만 실행되는 자동 검증 코드가 포함되어 있습니다.
옵션 없는 실행에서는 검증 노드가 즉시 제거되어 일반 타이틀로 시작합니다.
검수를 재현하면 정상 명령으로 새 캠페인을 진행하고 기본 저장 폴더에 새 슬롯을 생성합니다.
PowerShell에서 이 폴더로 이동한 뒤:

New-Item -ItemType Directory -Force evidence
$qaOut = (Resolve-Path evidence).Path.Replace('\','/')
& .\Samhan660.exe --log-file evidence/prepare.log -- --qa-v1-5 --phase=prepare "--out=$qaOut" | Out-Host
& .\Samhan660.exe --log-file evidence/reload.log -- --qa-v1-5 --phase=reload "--out=$qaOut" | Out-Host
& .\Samhan660.exe --log-file evidence/production-reload.log -- --qa-v1-5 --phase=production-reload "--out=$qaOut" | Out-Host

각 단계가 종료된 뒤 다음 단계를 실행하세요. prepare-result.json 등의 failures가 0인지 확인합니다.
기본 저장 경로가 막힌 경우 다른 경로로 바꿔 성공한 것으로 처리하지 않습니다.
