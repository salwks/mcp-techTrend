# 설화록 — 비주얼 프로토타입 (1단계)

한국 전래설화 기반 이야기 중심 RPG 《설화록》의 스타일 검증용 웹 프로토타입입니다.
고정 시점(HD-2D 방식) 3D 조선 산골 마을 + 민화풍 2D 컷아웃 캐릭터.

```bash
cd seolhwa && python3 -m http.server 8000   # http://localhost:8000
```

- 이동 WASD/방향키, 달리기 Shift, 대화 E/Space, 검증 패널 Tab, 시간대 전환 N
- 모바일: 왼쪽 가상 조이스틱, 오른쪽 조사·달리기 버튼
- `docs/PROTOTYPE.md`: 검증 목표와 체크리스트 · `docs/CONTRACTS.md`: 에이전트 간 모듈 계약
- three.js r170 (MIT)은 `vendor/three/`에 포함되어 있어 네트워크 없이 동작합니다.
