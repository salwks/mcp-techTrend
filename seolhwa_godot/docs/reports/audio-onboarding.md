# audio-onboarding 보고 — 공용 소리 기반 + 안내(onboarding) 고침 (남원 v3.2 착수 순서 1·2)

기준 문서는 `seolhwa/docs/scenario/seolhwarok_NAMWON_v3.2_DECISIONS.md`(확정 1·8)와 `seolhwarok_NAMWON_v3.2_scenario.md`(§4·§26·§70)다.
남원 ACT 내용(착수 순서 3 이후)은 건드리지 않았다.

## 1. 실행·시험

| 하고 싶은 것 | 명령 (`seolhwa_godot/`에서) |
|---|---|
| 소리 기반 시험 | `godot --headless --path . -s res://tests/audio/sound_test.gd` → `SOUNDTEST PASS 37` |
| 안내 규칙 시험 | `godot --headless --path . -s res://tests/onboarding/onboarding_rule_test.gd` → `ONBOARDRULE PASS 35` |
| 임시 소리 다시 만들기 | `python3 tools/audio/make_placeholders.py` (numpy, 씨앗 고정 — 같은 파일이 나온다) |
| 대본 시험 전부 | `tools/run_story_tests.sh` |

두 시험 모두 사용자 저장(`progress.json`)과 설정(`settings.json`)을 건드리지 않는다(`user://st_onboard_rule.json`, `GameSettings.test_override`).

## 2. 소리 기반 — `scripts/audio/sound.gd`

Godot `AudioStreamPlayer` / `AudioStreamPlayer3D`만 쓴다. 프로젝트에 자동 로드가 없어서 그 방식을 따랐다.
`Sound`는 static 입구이고, 처음 부를 때 root 아래 `Sound` 노드가 하나 생긴다.
그래서 공간을 넘어가며 장면을 다시 열어도 음악이 끊기지 않는다. 장면 `_ready` 도중에 불려도 괜찮다. 붙는 것과 그 사이 부른 것을 함께 미뤄서 차례대로 한다.

```gdscript
const Sound := preload("res://scripts/audio/sound.gd")
Sound.play("knock")                                   # 효과음. 같은 id 겹침(id당 4, 전체 12 — 넘으면 가장 오래된 것을 끊음)
Sound.play_at("tiger_growl", pos, main.scene_vp)      # 자리 있는 소리(3D, 끝나면 사라짐). 부모가 없으면 play()
Sound.music("bgm_night_drone", 2.0)                   # 음악 맞바꿈(crossfade). music_stop(초) · music_level(0~1, 초)
Sound.duck(-10.0, 1.5)                                # 잠시 음악 낮춤 → 되돌림(db, 머묾, 내려감, 올라옴)
Sound.hush(2.0)                                       # 갑자기 고요: 음악·환경음을 0.12초에 거의 끄고 2초 머문 뒤 1.2초에 돌아옴
Sound.hush(-1); …; Sound.hush_end(1.5)                # 직접 끝낼 때까지 고요
Sound.has(id) · Sound.stop_sfx() · Sound.apply_settings() · Sound.state()(시험용)
```

- **버스**: Master → BGM · SFX · Ambient. 없으면 실행 중에 만든다(`default_bus_layout.tres`를 따로 두지 않았다). `wind`는 Ambient로 간다.
- **페이드는 실제 시간으로 잰다.** `Engine.time_scale`(대본 시험 2.5배, 첫 조우 느린 화면 0.3배)과 상관없다. 멈춤 메뉴 중에도 페이드는 흐르고, 효과음은 멈춘다.
- **파일**: `assets/audio/sfx/<id>.(ogg|wav)`, `assets/audio/bgm/<id>.(ogg|wav)`. `.ogg`를 먼저 읽는다. 프로젝트 방식대로(`*.import`는 git 밖) 임포트 없이 실행 중에 바이트로 읽는다. 에디터가 임포트해 두었으면 그것을 쓴다. 음악은 저절로 고리로 튼다. 없는 id는 `SOUND 없음 …` 한 줄만 찍고 지나간다.
- **헤드리스**: Dummy 드라이버에서 그대로 돈다. 재생·끝 신호·버스가 모두 움직인다(시험으로 확인). 소리만 안 난다.
- **설정**: `game_settings.gd`에 `vol_master / vol_bgm / vol_sfx / vol_ambient`("0"~"10", 기본 10/7/9/8)를 두었다. 설정 메뉴에는 **소리 — 전체·음악·효과음** 세 줄을 더했고, 바꾸면 `ui_select`가 한 번 난다. 줄이 늘어서 768 높이에 들도록 메뉴 줄 글자를 26→24, 줄 간격을 10→6으로 줄였다. 환경음은 설정 키만 있고 메뉴에는 없다.

### 이야기 쪽 연결

- `story_director.sfx(id[, at])`: 예전 `sfx_cue` 신호는 그대로 내고 실제로 튼다. `at`이 있으면(자리 이름·인물 id·`"player"`·Vector2·Vector3) 그 자리에서 3D로 튼다. 기존 남원 호출(rope_creak·rope_snap·fall_impact·wind)은 고치지 않아도 이제 소리가 난다.
- `story_director.bgm(id, fade)` · `duck(db, sec)` · `hush(sec)`.
- 대본 명령: `{ "sfx": id, "at": 자리 }` · `{ "bgm": id, "fade": 초 }`(""이면 멈춤) · `{ "duck": db, "sec": 초 }` · `{ "hush": 초 }`.
- 기록책 쪽 넘김은 `page_turn`, 자동 기록 도장은 `journal_stamp`. spirits의 `audio` 이름도 공용 소리 파일이 있으면 `Sound.play_at`으로 튼다.
- `--storytest`·`--storylog`이면 `SOUND sfx knock` 같은 줄을 찍는다. 다음 단계 시험에서 "이 순간 이 소리가 났나"를 볼 수 있다.
- 말 타기(`horse_ride.gd`의 `audio_cue`)는 아직 잇지 않았다. 말발굽 소리가 없기 때문이다.

## 3. 임시 소리 — `assets/audio/` (모두 placeholder, 나중에 바꾼다)

`tools/audio/make_placeholders.py`가 numpy만으로 합성한다. 내려받은 것은 없다. 모노 16비트 22050Hz WAV이고, 전부 3MB 남짓이다. 일부러 조용하게 만들었다(SFX 최고 -5 ~ -20 dBFS, BGM -16 ~ -17 dBFS).
목록과 설명은 `assets/audio/README.md`에 있다(id → 파일 → 설명 → "placeholder, replace later"). 실제 녹음은 **같은 id의 `.ogg`를 넣기만 하면** 바뀐다.

| 효과음 | | 음악 | |
|---|---|---|---|
| knock | 나무 문 두 번 | bgm_day_calm | 낮 — 지속음 + 뜯는 5음, 24.5초 고리 |
| footstep_heavy | 무거운 발 디딤 | bgm_night_drone | 밤 — 55Hz 맥놀이 지속음, 24초 고리 |
| flour_rustle | 가루·자루 바스락 | | |
| basket_roll | 광주리 구름 | | |
| tiger_growl | 범 그르렁 | | |
| axe_hit | 도끼 박힘 | | |
| rope_creak · rope_snap | 줄 삐걱 · 끊김 | | |
| fall_impact | 수수밭 추락 | | |
| wind | 바람 6초(Ambient) | | |
| breath_gasp | 숨 들이켬 | | |
| journal_stamp · page_turn · ui_select | UI | | |

## 4. 안내(onboarding) 고침 — `scripts/story/onboarding.gd`

**고친 문제.** `once()`가 안내를 띄우자마자 `ONBOARD_*_SEEN`을 적었고(저장은 다음 저장 때), 시간이 다 돼도 SEEN을 적었다. 그래서 플레이어가 행동하지 않아도 튜토리얼이 끝난 것으로 처리됐다.

**새 규칙**

| | 핵심 안내 (`CORE`) | 정보 안내 (그 밖) |
|---|---|---|
| 대상 | MOVE · RUN · INSPECT · TALK · JOURNAL · MAP (§4 "핵심 튜토리얼은 시간으로 완료 처리하지 않는다") | RIDE · KNOT 등 |
| SEEN이 되는 때 | 행동했을 때만: `seen_now(key)`(이동·대화·기록책·지도를 연 곳) 또는 `until`이 참 | `until`이 참이거나, 제 시간(`sec`)을 **실제로 다 보였을 때** |
| 시간이 다 되면 | 사라지지 않는다. 다른 안내가 기다리면 그 안내에 자리를 내주고 줄 뒤로 갔다가 다시 뜬다(SEEN 아님) | 끝나고 SEEN |
| 대화창·기록책·컷신 동안 | 감췄다가 다시 보인다 | 감췄다가 이어 보인다. 감춘 동안은 시간을 세지 않는다 |
| 끊겼을 때(장면이 닫힘·전투 안내가 끼어듦) | `ONBOARD_PENDING`에 남는다 | `MIN_SHOWN`(2.5초) 넘게 보였으면 SEEN. 아니면 부른 곳이 다음에 다시 띄운다 |
| 저장·이어 하기 | 기다리던 핵심 안내(`onboard.ONBOARD_PENDING {key: 글}`)가 다시 뜬다 | 남기지 않는다 |

정보 안내를 이렇게 정한 까닭이 있다. 정보 안내는 읽으면 끝인 글이라 행동을 기다릴 까닭이 없다. 다만 대화창 뒤에 가려 있었거나 장면이 바뀌어 잘린 것까지 "보았다"고 치면 안 된다. 그래서 실제로 보인 시간만 센다.

- 이동(MOVE)은 실제로 0.6m 넘게 걸으면 SEEN이다. 안내가 떠 있지 않아도 그렇다. 여는 장면의 순간이동은 세지 않는다(예전처럼 조작이 막혀 있으면 기준점을 다시 잡는다).
- 전투 중에는 떠 있는 안내를 감추거나 다시 띄우지 않는다. K·L 안내가 같은 자리를 쓰기 때문이다.
- **새 안내 붙이기.** `CORE`에 key를 넣고 `once(key, 글[, until])`를 부른다. 또는 `hold(key, 글[, until])`를 쓴다(CORE 밖 key도 행동까지 남는다). 행동하는 곳에서는 `seen_now(key)`를 부른다. v3.2의 새 안내(Shift 달리기, s0000_sandal 살펴보기, 전투 K·L, H 역마)는 착수 순서 3·4에서 붙인다. 이번에는 붙이지 않았다.
- **시험용**: `hint_key()` 지금 떠 있는 안내.

## 5. 시험 결과

| 시험 | 결과 |
|---|---|
| `tests/audio/sound_test.gd` | SOUNDTEST PASS 37 (exit 0) |
| `tests/onboarding/onboarding_rule_test.gd` | ONBOARDRULE PASS 35 (exit 0) |
| `tests/registry/case_registry_test.gd` | REGTEST PASS 47 (exit 0) |
| `tools/run_story_tests.sh` (마지막 한 번) | 44/44 모두 PASS, SCRIPT ERROR 0, exit 0 |

**continue:new의 흔들림.** 첫 전체 실행에서 `continue:new` 하나가 "E로 jumo와 말이 열림"에서 실패했다.
이번 변경 전 커밋(807c718)을 같은 자리에서 6번 돌렸더니 3번 같은 자리에서 실패했다. 그러니 이번 변경 때문에 생긴 문제가 아니다.
진단을 넣어 보니 실패할 때도 E 대상은 jumo였고, busy와 modal도 아니었다. 그런데 첫 E가 먹지 않았다.
시험은 최대 3번 다시 누르고, 실패하면 `CONTTEST retry` 줄을 남기게 고쳤다(`scripts/story/continue_test.gd`). 그 뒤로는 6번 연속, 전체 실행에서도 통과했다.

## 6. 정할 것

1. **첫 조우 K·L 안내는 아직 "보이면 SEEN"이다.** `_update_combat`이 느린 화면과 함께 띄우는 순간 `COMBAT_DODGE/GUARD_SEEN`을 적는다. v3.2 §26의 "실제로 회피·막기를 하면 완료"는 착수 순서 4(ACT 3~5 전투 튜토리얼)에서 전투 흐름과 함께 고치는 것이 맞다고 보았다. 그때 `CORE`에 넣고 `seen_now`를 회피·막기 순간에 부르면 된다.
2. **핵심 안내가 오래 남는다.** 예를 들어 지도를 끝내 열지 않으면 "M 지도"가 계속 떠 있다(다른 안내가 오면 번갈아 뜬다). 원문 그대로의 동작이다. 너무 끈질기면 "N분 지나면 작게" 같은 완화를 넣을 수 있다.
3. **음악을 언제 틀지는 정하지 않았다.** 지금은 아무도 `music()`을 부르지 않는다. 낮/밤 고리를 시간대나 사건 국면에 붙이는 일은 남원 ACT 작업에서 정한다.
4. **설정 메뉴 줄 크기.** 소리 줄 셋을 넣느라 메뉴 줄을 조금 줄였다. 화면으로 확인하지는 않았다.
5. **새 게임 직후 첫 E가 가끔 무시된다**(위 continue:new). 시험은 다시 누르게 했지만, 실제 놀이에서도 같은 일이 생기는지는 따로 봐야 한다. `story_ui._cooldown`이나 입력 처리 순서가 의심된다.
6. **환경음 크기**를 메뉴에 둘지(지금은 설정 키만 있다), 말발굽 소리(`horse_ride.audio_cue`)를 언제 이을지.
