# 출처와 제작 기록

장식 PNG 6종: 이 대화에서 내장 image_gen 도구로 제작. 승인된 1번 화면과 사용자 제공 V1.2 캡처를 방향/규격 참고로 사용했다. 외부 게임 화면을 복사한 자산은 아니다. 생성 PNG는 바이트 그대로 포함했다. 최종 프롬프트는 PROMPTS.json.

폰트는 아래 Google Fonts 공식 저장소에서 2026-09-29에 받은 원본이다. 각 폴더에 원문의 SIL Open Font License 1.1을 함께 포함했다. 라이선스 조건의 원문은 해당 OFL.txt를 따른다.

- `NanumMyeongjo-ExtraBold.ttf`
  - 출처: https://github.com/google/fonts/tree/main/ofl/nanummyeongjo
  - 원본: https://raw.githubusercontent.com/google/fonts/main/ofl/nanummyeongjo/NanumMyeongjo-ExtraBold.ttf
  - 라이선스: https://raw.githubusercontent.com/google/fonts/main/ofl/nanummyeongjo/OFL.txt
  - 버전: Version 2.032;PS 1;hotconv 1.0.56;makeotf.lib2.0.21325
  - SHA-256: `60c0077fce069ba90ae97c0a3679f6eb3712e0ca637bdd0c15b72d335ec46db7`
- `NanumBrushScript-Regular.ttf`
  - 출처: https://github.com/google/fonts/tree/main/ofl/nanumbrushscript
  - 원본: https://raw.githubusercontent.com/google/fonts/main/ofl/nanumbrushscript/NanumBrushScript-Regular.ttf
  - 라이선스: https://raw.githubusercontent.com/google/fonts/main/ofl/nanumbrushscript/OFL.txt
  - 버전: Version 1.100;PS 1;hotconv 1.0.57;makeotf.lib2.0.21895
  - SHA-256: `27ceaf578c96f594cdf07fe0181b251790acbb746a164e45c1f6473f89911a31`

Godot 공식 문서(2026-09-29 확인):
- https://docs.godotengine.org/en/stable/classes/class_imagetexture.html — imported Texture2D.get_image(), create_from_image(), set_size_override()
- https://docs.godotengine.org/en/stable/classes/class_image.html — get_region(), 압축 이미지 처리
- https://docs.godotengine.org/en/stable/classes/class_styleboxtexture.html — 9분할, texture margin과 content margin 구분

참고 코드는 해당 API를 바탕으로 작성했으며 이 환경에는 Godot 실행기가 없어 실제 엔진 검증을 하지 않았다. 프로젝트 버전에 맞게 확인한다.
