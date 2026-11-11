# project-HL · 전투 에셋 제작기

Godot 실제 3D 맵 위의 2D 캐릭터 스프라이트, 카메라, 노드 VFX, 피격·합 연출을 함께 제작하는 도구입니다.

**현재 상태: 개발 프리뷰. 원본 영상 수준의 완성품이 아닙니다. Godot 네이티브 실행·GPU 화면은 아직 검증되지 않았습니다.**

## Codex로 이어 개발하기

먼저 [AGENTS.md](AGENTS.md), [인수인계](docs/CODEX_HANDOFF_KO.md), [사용자 요구](docs/USER_REQUIREMENTS_KO.md)를 읽으세요. 소스·원본 참고·기존 AI의 설계안을 구분해 정리했습니다.

Codex에 아래 요청을 입력하면 됩니다.

> AGENTS.md와 docs/CODEX_HANDOFF_KO.md를 읽고 전투 에셋 제작기를 이어 개발해. Godot 4.6 import·네이티브 테스트·실제 UI부터 검증하고 오류를 해결해. 포즈 수는 고정하지 않으며, 실제 3D 맵·안정적인 카메라·조건부 3+1·합 연출을 유지해. 확인한 결과와 미검증 범위를 구분해서 보고해.

## 구성

- [godot/](godot/): Godot 제작기 전체. [실행 설명](godot/README_KO.md).
- [app/godot/](app/godot/), [lib/godot/](lib/godot/): Godot 데이터 웹 편집기·스키마·시퀀서.
- [tests/](tests/): 데이터/판정/기존 Canvas 검증.
- [references/](references/): 사용자 첨부 참고 자료와 출처 목록.
- 기존 루트 웹 화면은 schemaVersion 1의 Canvas 제작기이며, Godot 실행 결과와 구분합니다.

Node >=22.13, pnpm 11.25.0, Godot 4.6 대상입니다. 설치·DB·검사 명령과 제한은 인수인계 문서에 있습니다.

이 저장소에는 호스팅 DB·계정 연결·비밀 값이 포함되지 않습니다. GitHub push만으로 기존 Sites 배포가 바뀌지는 않습니다.
