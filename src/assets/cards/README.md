# 카드 초상화

게임에서 실제 사용하는 카드별 초상화만 PNG 또는 JPG 파일로 추가하세요. 파일 이름은 카드 ID와 같아야 합니다.

예: `potato.png` 또는 `potato.jpg`, `tank.png`, `assassin.png`

게임은 `res://src/assets/cards/<카드 ID>.png`를 먼저 찾고, 없으면 같은 이름의 JPG를 찾아 카드 중앙의 그림 영역에 맞춰 표시합니다. 그림은 원본 비율을 유지하며, 빈 공간은 카드 배경으로 채웁니다. 아직 그림이 없는 카드는 카드별 색상 배경을 표시합니다.

편집 전 원본이나 사용하지 않는 시안은 `archive/assets/cards/`에 보관합니다.
