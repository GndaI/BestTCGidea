# 최고의TCGidea 작업 규칙

이 파일은 이 프로젝트에서 작업하는 AI 코딩 도구가 반복해서 지켜야 할 기준입니다.

## 기본 원칙

- Godot 프로젝트를 원본으로 취급합니다.
- Windows Desktop 실행판을 기본 배포판으로 사용합니다. 웹판은 같은 원본에서 만드는 보조 배포판입니다.
- 사용자의 기존 변경과 관계없는 파일은 임의로 되돌리거나 정리하지 않습니다.
- 커밋, 병합, 푸시와 배포는 사용자가 요청했을 때만 수행합니다.

## 소스 구조

- 게임의 유일한 루트 장면은 `src/scenes/main.tscn`입니다.
- `main.tscn`의 `ScreenHost`에 현재 화면 장면을 하나씩 교체하여 표시합니다. 공통 배경과 화면 틀은 루트에 유지합니다.
- 독립 화면 장면은 `src/scenes/screens/<화면 이름>/`에 둡니다.
- 화면 위에 표시되는 장면은 `src/scenes/overlays/`에 둡니다.
- 화면 전환과 상태 처리 코드는 역할에 맞는 `src/scenes/controllers/` 파일에 둡니다.
- `main.gd`에는 현재 화면 선택과 전체 갱신만 둡니다. 화면별 세부 구현을 다시 모아 거대한 단일 파일로 만들지 않습니다.
- 현재 컨트롤러 순서는 `main → 전투 행동 → 전투 화면 → 전투 입력·연출 → 덱 → 온라인 → 계정 → 시작 화면 → 공통 앱`입니다. 순서를 바꾸면 `docs/SCENE_MAP.md`도 함께 갱신합니다.
- `app_controller.gd`의 빈 함수 선언은 아래쪽 공통 코드가 위쪽 컨트롤러의 함수를 호출하기 위한 연결부입니다. 실제 구현과 중복된 코드로 오해해 임의로 다른 파일로 옮기거나 삭제하지 않습니다.
- 복잡한 화면 장면은 `Content` 노드를 화면 내용의 진입점으로 사용합니다. 설정과 게임 규칙은 팝업이 아니라 독립 화면 장면으로 유지합니다.
- 전투 규칙은 `src/core/`, 카드 데이터와 효과는 `src/cards/`, AI 판단은 `src/ai/`, 온라인 기능은 `src/online/`에 둡니다.
- 이미지, 글꼴, 아이콘과 소리는 `src/assets/`에 두고 게임 동작을 구현하는 `.gd`와 `.tscn`은 넣지 않습니다.
- 자세한 장면 흐름과 컨트롤러 구조는 `docs/SCENE_MAP.md`를 기준으로 합니다.

## 프로젝트 루트와 Godot 생성 파일

- `project.godot`과 `export_presets.cfg`는 Godot가 정해진 이름과 위치로 찾는 파일이므로 프로젝트 루트에서 옮기거나 이름을 바꾸지 않습니다.
- `.editorconfig`, `.gitattributes`, `.gitignore`, `AGENTS.md`도 프로젝트 전체에 적용되므로 루트에 둡니다.
- `.gd.uid`는 Godot가 스크립트를 식별하는 파일입니다. 대응하는 `.gd`와 함께 이동하고 Git에 포함하되 내용을 직접 편집하지 않습니다. 스크립트를 옮긴 뒤 남은 오래된 `.uid`만 실제 참조 여부를 확인하고 제거합니다.
- `.godot/`과 `build/`는 자동 생성 폴더이며 Git에 포함하지 않습니다.
- 프로젝트 루트에 빈 `export_templates/`, `feature_profiles/`, `script_templates/`, `text_editor_themes/`가 생기면 제한된 환경에서 Godot가 공용 설정 경로 대신 만든 것인지 확인합니다. 내용이 없고 Git에서 제외되어 있을 때만 제거합니다.
- Godot 편집기 검사와 내보내기는 공용 설정 폴더에 정상적으로 접근할 수 있는 일반 실행 환경에서 수행합니다.
- 제한된 도구 환경에서 Godot 자동 검사를 실행할 때에는 프로젝트 루트가 아닌 별도의 임시 폴더를 프로세스 작업 위치로 사용하고, `--path`에는 이 프로젝트의 절대 경로를 전달합니다. `tests/`는 검사 코드의 위치이며 Godot 사용자 설정 폴더를 생성하는 장소로 사용하지 않습니다.

## 문서와 보관함

- 루트 `README.md`는 사람이 처음 읽는 짧은 프로젝트 안내로 사용합니다. 세부 규칙과 긴 개발 기록을 중복해서 넣지 않고 `docs/` 문서로 연결합니다.
- `docs/README.md`는 현행 문서의 목차로 유지합니다.
- 작업을 시작할 때 `docs/WORKING_CONTEXT.md`를 읽고, 다른 대화에서 이어받아야 할 진행 중 작업, 임시 결정, 미해결 질문과 다음 작업을 확인합니다.
- `docs/WORKING_CONTEXT.md`에는 다른 작업의 범위나 구현 방향을 바꿀 수 있는 내용만 간결하게 기록합니다. 전체 대화, 일상적인 진행 과정, 반복 가능한 명령 출력과 이미 다른 문서가 관리하는 사실은 넣지 않습니다.
- 내용이 확정되면 종류에 맞는 기준 문서로 옮기고 `docs/WORKING_CONTEXT.md`에서는 제거합니다. 계속 지킬 작업 규칙은 `AGENTS.md`, 게임 규칙은 `docs/RULEBOOK.md`, 장면과 코드 구조는 `docs/SCENE_MAP.md`, 출시 변경점은 게임 패치노트가 관리합니다.
- 작업을 마칠 때 `docs/WORKING_CONTEXT.md`의 완료된 항목을 정리하고, 아직 다음 대화에 필요한 내용만 남깁니다. 문서가 비어도 파일과 기본 제목은 유지합니다.
- 현행 규칙은 `docs/RULEBOOK.md`, 카드 작성 양식은 `docs/CARD-TEMPLATE.md`를 기준으로 합니다.
- 장면과 컨트롤러 구조는 `docs/SCENE_MAP.md`, Windows 온라인 시작 방법은 `docs/setup/README.md`를 기준으로 합니다.
- `src/`, `tests/`, `server/`, `src/assets/` 안의 `README.md`는 해당 폴더만 설명합니다.
- 문서 파일을 옮기거나 이름을 바꾼 뒤에는 프로젝트 전체에서 이전 경로를 검색하고 Markdown 상대 링크가 실제 파일로 연결되는지 확인합니다.
- 현재 사용하지 않는 과거 자료는 `archive/`에 보관합니다.
- `archive/`의 코드와 문서를 현행 기능에서 직접 참조하지 않습니다. 다시 사용할 때는 현재 규칙에 맞게 갱신한 뒤 현행 폴더로 옮깁니다.
- 계속 지켜야 하는 규칙만 `AGENTS.md`에 기록하고, 일회성 요청은 프로젝트 규칙으로 만들지 않습니다.

## 변경 후 검사

- 구조, 경로, 전투 규칙 또는 UI를 변경한 뒤에는 아래 현행 검사를 모두 실행합니다.

```powershell
godot --headless --path . --script res://tests/rules/test_card_auto.gd
godot --headless --path . --script res://tests/rules/test_card_rework.gd
godot --headless --path . --script res://tests/rules/test_rulebook.gd
godot --headless --path . --script res://tests/ai/test_ai_modes.gd
godot --headless --path . --script res://tests/ui/test_drag.gd
godot --headless --path . --script res://tests/ui/test_rulebook_ui.gd
```

- 온라인 코드를 변경했을 때에는 `tests/online/`의 관련 통합 검사도 별도로 실행합니다.
- 자동 검사가 통과해도 화면 구조나 연출을 바꿨다면 Godot에서 주요 화면을 직접 확인합니다.
- 검사 결과는 통과 개수와 실패 개수를 실제 출력 그대로 보고합니다. 이전 실행의 숫자를 현재 결과처럼 재사용하지 않습니다.

## 온라인 구조

- 기본 온라인 서버는 `https://besttcgidea-render-server.onrender.com`입니다.
- 플레이어 화면은 공개 방 목록과 방 만들기 흐름을 사용합니다. 사용자의 별도 요청 없이 비공개 방이나 방 코드 방식을 다시 추가하지 않습니다.
- 중앙 WebSocket 서버가 방과 게임 메시지를 중계하며 방장이 전투 판정을 맡습니다. 전송 방식이나 판정 주체를 바꾸는 작업은 일반 UI 수정과 분리해서 진행합니다.
- `server/local/`의 실행기는 로컬 통합 검사에만 사용합니다. 평소 친구 대전에서는 별도 서버 실행이나 포트포워딩을 요구하지 않습니다.
- 계정 기반 클라우드 덱을 수정할 때에도 로컬 덱을 대체 데이터로 유지합니다.

## 내보내기와 배포

- Windows판은 설정된 이름인 `최고의TCGidea.exe`로 내보내고, 배포 전에 실행 파일을 직접 열어 메인 화면이 나타나는지 확인합니다.
- `build/`의 자동 생성 결과와 실행 파일은 Git에 커밋하지 않습니다. Windows 배포판은 GitHub Release를 통해 배포합니다.
- Godot 4.7.2 콘솔 실행 파일과 일반 사용자 권한으로 내보냅니다. 제한된 실행 환경에서는 임시 `project.binary`를 쓰지 못해 종료 코드가 0이어도 `build/web/index.pck`가 손상될 수 있습니다.
- `Safe save failed`, `Can't open ... tmpproject.binary`, `Corrupted header in binary project.binary`가 나타나면 종료 코드가 0이어도 내보내기 실패로 처리합니다.
- 웹판을 내보낸 뒤에는 `build/web`을 실제로 실행하고 브라우저에서 최고의TCGidea 메인 화면이 나타나는지 확인합니다. 브라우저 콘솔에 `.pck` 또는 프로젝트 데이터 로딩 오류가 없어야 합니다.
- 로컬 서버와 공개 서버는 이미 `Cache-Control: no-store`를 사용합니다. 소스가 바뀌면 웹판을 새로 내보낸 뒤 브라우저를 새로고침하거나 `Ctrl+F5`를 사용합니다.
