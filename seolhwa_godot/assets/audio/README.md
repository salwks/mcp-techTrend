# 소리 파일 목록 (assets/audio)

**여기 있는 소리는 모두 임시(placeholder) 합성 소리다 — 나중에 실제 녹음으로 바꾼다.**

- 만든 곳: `tools/audio/make_placeholders.py` (numpy만, 내려받기 없음, 씨앗 고정 — 다시 돌리면 같은 파일)
- 형식: 모노 16비트 22050Hz WAV. SFX 최고 -5 ~ -20 dBFS, BGM -16 ~ -17 dBFS (조용하게)
- 읽는 곳: `scripts/audio/sound.gd` — `Sound.play(id)` · `Sound.music(id)`. 임포트 없이 실행 중에 읽는다.

## 바꿔 넣는 법

같은 id로 파일을 넣으면 된다. `sfx/<id>.ogg`가 있으면 `sfx/<id>.wav`보다 먼저 읽힌다.
그러니 실제 녹음은 `.ogg`로 넣고, 임시 `.wav`는 지워도 되고 남겨 두어도 된다.
음악(`bgm/`)은 저절로 고리(loop)로 튼다. id별 기본 버스·높낮이 흔들기는 `sound.gd`의 `TUNE`.

## 효과음 (sfx/)

| id | 파일 | 설명 | 상태 |
|---|---|---|---|
| knock | sfx/knock.wav | 나무 문 두드림 두 번 | placeholder, replace later |
| footstep_heavy | sfx/footstep_heavy.wav | 무거운 발 디딤(범·큰 짐승) | placeholder, replace later |
| flour_rustle | sfx/flour_rustle.wav | 가루·자루 바스락 | placeholder, replace later |
| basket_roll | sfx/basket_roll.wav | 광주리 구르는 소리 | placeholder, replace later |
| tiger_growl | sfx/tiger_growl.wav | 범 그르렁(낮고 멀게) | placeholder, replace later |
| axe_hit | sfx/axe_hit.wav | 도끼가 나무에 박힘 | placeholder, replace later |
| rope_creak | sfx/rope_creak.wav | 동아줄 삐걱 | placeholder, replace later |
| rope_snap | sfx/rope_snap.wav | 줄 끊김 | placeholder, replace later |
| fall_impact | sfx/fall_impact.wav | 수수밭에 떨어짐(쿵 + 대 꺾임) | placeholder, replace later |
| wind | sfx/wind.wav | 바람 한 자락 6초(Ambient 버스) | placeholder, replace later |
| breath_gasp | sfx/breath_gasp.wav | 숨을 들이켬(놀람) | placeholder, replace later |
| journal_stamp | sfx/journal_stamp.wav | 기록책 도장(UI) | placeholder, replace later |
| page_turn | sfx/page_turn.wav | 종이 넘김(UI) | placeholder, replace later |
| ui_select | sfx/ui_select.wav | 고르기 똑(UI, 설정 메뉴 소리 크기 바꿀 때) | placeholder, replace later |

## 음악 (bgm/)

| id | 파일 | 설명 | 상태 |
|---|---|---|---|
| bgm_day_calm | bgm/bgm_day_calm.wav | 낮 잔잔한 고리 — 낮은 지속음 + 뜯는 5음, 24.5초 | placeholder, replace later |
| bgm_night_drone | bgm/bgm_night_drone.wav | 밤 긴장 지속음 — 55Hz와 어긋난 5도 맥놀이, 24초 | placeholder, replace later |
