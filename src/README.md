# 소스 코드

- `scenes/main.tscn`: 게임의 유일한 루트 장면
- `scenes/main.gd`: 현재 화면 선택과 전체 갱신
- `scenes/screens/`: 메인, 계정, 덱, 온라인, 전투 등 독립 화면 장면
- `scenes/overlays/`: 전투 결과처럼 화면 위에 표시하는 장면
- `scenes/controllers/`: 공통 상태와 화면 영역별 동작 코드
- `battle/`: 카드 종류와 관계없는 전투 진행 규칙
- `cards/`: 카드 목록과 카드별 효과 코드
- `ui/components/`: 여러 화면에서 재사용하는 UI 노드
- `ui/screens/`: 화면에서 공유하는 표시 코드와 패치노트 데이터
- `effects/visual/`: 일반 전투 시각 연출
- `effects/gamble/`: 갬블의 악마 전용 연출
- `effects/sound/`: 소리 연출
- `ai/`: 컴퓨터 상대의 행동 판단
- `online/`: 계정, 클라우드 덱과 온라인 방 연결
- `assets/`: 카드·UI 그림, 글꼴, 아이콘과 앞으로 추가할 소리 파일

이미지·소리·글꼴·아이콘은 `assets/`에, 게임을 작동시키는 코드와 장면은 담당 기능 폴더에 둡니다.

새 화면 장면은 `scenes/screens/<화면 이름>/`에 둡니다. 화면 전환과 상태 처리는 역할에 맞는 `scenes/controllers/` 파일에 둡니다. 카드처럼 여러 화면에서 반복 사용하는 시각 요소는 `ui/components/`에 둡니다. 전투 규칙, 카드 데이터와 AI처럼 화면에 직접 배치되지 않는 코드는 씬으로 만들지 않습니다.

전체 장면 흐름과 컨트롤러 상속 순서는 [`docs/SCENE_MAP.md`](../docs/SCENE_MAP.md)를 기준으로 합니다.
