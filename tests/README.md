# 자동 검사

- `rules/`: 전투 규칙, 카드와 주문 처리
- `ui/`: 화면 표시, 입력과 연출
- `ai/`: 쉬움·강함 AI 판단
- `online/`: 클라우드 덱과 방 중계
- `manual/`: 화면 캡처와 AI 비교처럼 사람이 결과를 확인하는 도구

검사 결과로 생성되는 이미지와 로그는 Git에 포함하지 않습니다.

구조를 이동하거나 경로를 바꾼 뒤에는 다음 현행 검사를 모두 실행합니다.

```powershell
godot --headless --path . --script res://tests/rules/test_card_auto.gd
godot --headless --path . --script res://tests/rules/test_card_rework.gd
godot --headless --path . --script res://tests/rules/test_rulebook.gd
godot --headless --path . --script res://tests/ai/test_ai_modes.gd
godot --headless --path . --script res://tests/ui/test_drag.gd
godot --headless --path . --script res://tests/ui/test_rulebook_ui.gd
```

금지되어 후순위로 미룬 갬블의 악마 전용 검사와 현행 규칙에 맞지 않는 구버전 검사는 `archive/tests/`에 보존합니다. 이 파일들은 현재 변경의 합격 여부를 판단하는 검사로 사용하지 않습니다.

`online/`의 검사는 로컬 Node 서버나 가짜 API 서버를 함께 실행해야 하는 통합 검사입니다. 네트워크 코드를 바꾸었을 때 별도로 실행합니다.
