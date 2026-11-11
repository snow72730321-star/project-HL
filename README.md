# project-HL · Godot 전투 / 모션 워크숍

1인 주인공 싱글 플레이 전투 게임을 위한 첫 실행형 프로토타입입니다.
현재는 **애니메이션 편집·재생 구조를 검증하는 단계**이며 참고 영상과 동등한 결과물이 아닙니다.

## 실행

Godot 4.6.x가 필요합니다. Node, pnpm, DB, 계정, API 키는 현재 구현에 필요하지 않습니다.

```bash
./scripts/godot.sh --headless --editor --import --quit
./scripts/godot.sh
```

또는 Godot에서 `godot/project.godot`을 열고 F6/F5로 실행합니다.
실행 스크립트는 쓰기 가능한 `.local/` 아래에 Godot 설정과 사용자 데이터를 보관합니다.
리눅스에서 화면 실행에는 X11/Wayland 디스플레이와 OpenGL이 필요합니다.

## 사용

- 하단 CUT / HEAVY / QUICK: 임의 배정 없는 고정 스킬 버튼. 현재 동일 모션에 피해 배율만 다릅니다.
- PREVIEW / PAUSE, 배속, 스크러버: 피해를 적용하지 않고 모션 확인.
- 키 선택 → 시간·위치·회전·크기·카메라 줌·포즈·보간 수정 → APPLY KEY.
- ADD AT PLAYHEAD / DELETE KEY: 키 추가·삭제. 포즈 개수 제한 없음.
- 포즈: 기본 `idle`, `windup`, `strike`, `hurt`, `guard` 또는 `res://assets/custom.png` 경로. 새 이미지를 Godot 프로젝트에 넣고 임포트한 뒤 사용합니다.
- 이벤트 목록: 타격 시간·피해·히트스톱·VFX 지속시간·각도·크기·색 편집. ADD FX로 다중 타격 작성.
- 클립 이름 입력 → SAVE JSON / LOAD JSON. `user://<클립 이름>.json` 저장. 저장 위치는 화면에 표시됩니다.
- RESET TARGET: 대상 체력 복원.

## 검증

```bash
./scripts/godot.sh --headless -- --smoke
```

타임라인 샘플링, 타격 시점, JSON 왕복, 잘못된 JSON 거부, 1회 피해, 미리보기 피해 격리,
다중 타격 유지, 키 추가·삭제를 검사합니다. Godot의 assert 실패는 출력도 확인해야 합니다.

현재 인스턴스에서 Godot 4.6.3 임포트 및 위 검사 통과.
Xorg dummy 디스플레이 + Mesa llvmpipe에서 실제 네이티브 창 실행, 하단 공격 버튼 클릭,
대상 체력 100→88, 타임라인 스크럽과 VFX 표시를 확인했습니다. 하드웨어 GPU·오디오·다른 OS는 미검증입니다.

요구사항과 다음 작업: [docs/DEVELOPMENT_KO.md](docs/DEVELOPMENT_KO.md).
