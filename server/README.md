# 멀티플레이 서버

- `room_server.js`: Render와 로컬 점검에서 사용하는 방·메시지 중계 서버
- `battle/`: Render 권위 서버용으로 새로 작성하는 전투 엔진. 기존 Godot `battle.gd`를 실행하거나 분해하지 않습니다.
- `test/`: 새 서버 전투 엔진의 Node.js 자동검사
- `package.json`: Node.js 실행 설정과 의존성
- `local/서버-열기.bat`: Render를 거치지 않고 이 컴퓨터에서 서버를 점검할 때만 사용

평소 온라인 플레이에는 로컬 실행기를 사용할 필요가 없습니다.

현재 `battle/`에는 카드 효과 없이 한 턴의 `생산 → 공개 → 행동 → 종료` 상태 전환만 구현되어 있으며, 아직 `room_server.js`나 Godot 클라이언트와 연결하지 않았습니다.
