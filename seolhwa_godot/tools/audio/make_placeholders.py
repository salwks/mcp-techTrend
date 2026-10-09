#!/usr/bin/env python3
"""설화록 임시 소리(placeholder) 합성기 — 내려받기 없이 numpy로만 만든다.

    python3 tools/audio/make_placeholders.py          # seolhwa_godot/ 에서
    python3 tools/audio/make_placeholders.py --list   # 목록만

결과: assets/audio/sfx/<id>.wav · assets/audio/bgm/<id>.wav (모노 16비트 22050Hz)
모두 임시 소리다 — 실제 녹음은 같은 id의 .ogg 또는 .wav를 같은 폴더에 넣으면 된다(.ogg가 먼저 읽힌다).
씨앗(seed)이 고정이라 다시 돌려도 같은 파일이 나온다. 크기는 작게, 소리는 조용하게(SFX 최고 -6 dBFS, BGM -16 dBFS 언저리).
"""
import os
import sys
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio")


# ---------------------------------------------------------------- 바탕 도구
def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec, rng):
    return rng.standard_normal(int(SR * sec))


def band(x, lo, hi, soft=0.15):
    """FFT 띠 거르개(lo~hi Hz, 가장자리를 부드럽게)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    X = np.fft.rfft(x)
    g = np.ones_like(f)
    np.seterr(over="ignore")   # 띠 밖 끝자락 exp 넘침은 0으로 수렴 — 경고만 끈다
    if lo > 0:
        g *= 1.0 / (1.0 + np.exp(-(f - lo) / max(lo * soft, 1.0)))
    if hi < SR / 2:
        g *= 1.0 / (1.0 + np.exp((f - hi) / max(hi * soft, 1.0)))
    return np.fft.irfft(X * g, n)


def env_exp(sec, decay, attack=0.002):
    t = t_axis(sec)
    a = np.clip(t / attack, 0, 1) if attack > 0 else 1.0
    return a * np.exp(-t / decay)


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    i = min(int(SR * fin), n // 2)
    o = min(int(SR * fout), n // 2)
    y = x.copy()
    if i > 0:
        y[:i] *= np.linspace(0, 1, i)
    if o > 0:
        y[-o:] *= np.linspace(1, 0, o)
    return y


def place(buf, x, at):
    s = int(SR * at)
    e = min(len(buf), s + len(x))
    buf[s:e] += x[: e - s]
    return buf


def norm(x, peak_db):
    m = np.max(np.abs(x)) or 1.0
    return x / m * (10 ** (peak_db / 20.0))


def write(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    y = np.clip(x, -1, 1)
    data = (y * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def pluck(freq, sec, rng, bright=0.5):
    """Karplus-Strong 뜯는 줄(가야금 비슷한 임시 소리)."""
    n = int(SR * sec)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p) * bright + band(rng.uniform(-1, 1, p * 8), 0, freq * 4)[:p] * (1 - bright)
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % p]
        out[i] = v
        buf[i % p] = 0.5 * (v + buf[(i + 1) % p]) * 0.996
    return out * env_exp(sec, sec * 0.45, 0.003)


# ---------------------------------------------------------------- 효과음
def knock(rng):
    # 나무 문 두드림 두 번: 짧은 마른 잡음 + 낮은 울림(180Hz·410Hz)
    out = np.zeros(int(SR * 0.9))
    for at, g in [(0.02, 1.0), (0.28, 0.85)]:
        sec = 0.22
        t = t_axis(sec)
        body = (np.sin(2 * np.pi * 180 * t) * 0.7 + np.sin(2 * np.pi * 410 * t) * 0.3) * env_exp(sec, 0.045)
        click = band(noise(sec, rng), 600, 3500) * env_exp(sec, 0.008)
        place(out, (body + click * 0.6) * g, at)
    return norm(fade(out), -7)


def footstep_heavy(rng):
    # 무거운 발 디딤: 낮은 쿵(55Hz) + 흙 바스락
    sec = 0.6
    t = t_axis(sec)
    thump = np.sin(2 * np.pi * (55 + 25 * np.exp(-t / 0.03)) * t) * env_exp(sec, 0.12, 0.004)
    dirt = band(noise(sec, rng), 300, 2200) * env_exp(sec, 0.06, 0.01)
    return norm(fade(thump + dirt * 0.35), -7)


def flour_rustle(rng):
    # 가루·자루 바스락: 높은 잡음에 느린 떨림
    sec = 1.3
    t = t_axis(sec)
    x = band(noise(sec, rng), 1500, 7000)
    flutter = 0.55 + 0.45 * np.abs(np.sin(2 * np.pi * 5.5 * t + rng.uniform(0, 6)))
    shape = np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 1.5
    return norm(fade(x * flutter * shape, 0.03, 0.15), -14)


def basket_roll(rng):
    # 광주리 구르는 소리: 점점 느려지는 짚 부딪힘 + 낮은 울림
    sec = 1.7
    out = np.zeros(int(SR * sec))
    at, gap = 0.0, 0.07
    while at < sec - 0.1:
        c = band(noise(0.06, rng), 900, 4500) * env_exp(0.06, 0.012)
        place(out, c * (1.0 - at / sec * 0.6), at)
        at += gap
        gap *= 1.12
    t = t_axis(sec)
    rumble = band(noise(sec, rng), 80, 260) * np.exp(-t / 0.8) * 0.5
    return norm(fade(out + rumble, 0.01, 0.2), -10)


def tiger_growl(rng):
    # 낮은 그르렁: 70~90Hz 톱니에 거친 진폭 떨림, 걸러서 멀게
    sec = 2.2
    t = t_axis(sec)
    f = 78 + 10 * np.sin(2 * np.pi * 0.7 * t) - 8 * (t / sec)
    ph = np.cumsum(2 * np.pi * f / SR)
    saw = sum(np.sin(k * ph) / k for k in range(1, 12))
    rough = 0.6 + 0.4 * band(noise(sec, rng), 12, 40) * 3
    breath = band(noise(sec, rng), 150, 900) * 0.25
    shape = np.clip(t / 0.35, 0, 1) * np.clip((sec - t) / 0.6, 0, 1)
    x = band(saw * rough + breath, 40, 700) * shape
    return norm(fade(x, 0.02, 0.2), -10)


def brush_rustle(rng):
    # 덤불·나뭇가지 스침(무언가 큰 것이 숲 사이를 지나감): 중간 띠 잡음 두 번 쓸림 + 잔가지 똑
    sec = 1.4
    t = t_axis(sec)
    x = band(noise(sec, rng), 500, 3800)
    sweep = np.exp(-((t - 0.32) / 0.16) ** 2) + 0.7 * np.exp(-((t - 0.78) / 0.2) ** 2)
    out = x * sweep
    for at in (0.27, 0.41, 0.83):
        c = band(noise(0.03, rng), 1800, 6000) * env_exp(0.03, 0.006)
        place(out, c * 0.9, at)
    return norm(fade(out, 0.02, 0.25), -13)


def axe_hit(rng):
    # 도끼가 나무에 박힘: 날카로운 시작 + 나무 울림(320·760Hz)
    sec = 0.7
    t = t_axis(sec)
    crack = band(noise(sec, rng), 1200, 8000) * env_exp(sec, 0.01, 0.0005)
    wood = (np.sin(2 * np.pi * 320 * t) + 0.6 * np.sin(2 * np.pi * 760 * t + 1.0)) * env_exp(sec, 0.09, 0.001)
    thud = np.sin(2 * np.pi * 95 * t) * env_exp(sec, 0.06, 0.002)
    return norm(fade(crack * 0.8 + wood * 0.5 + thud * 0.6), -6)


def rope_creak(rng):
    # 동아줄 삐걱: 들쭉날쭉한 마찰 펄스열(40→75Hz)을 공명에 통과
    sec = 1.0
    t = t_axis(sec)
    f = 40 + 35 * np.sin(np.pi * t / sec) + 6 * band(noise(sec, rng), 2, 9) * 4
    ph = np.cumsum(f / SR)
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
    x = band(pulses + noise(sec, rng) * 0.02, 500, 1800, 0.08)
    shape = np.sin(np.pi * np.clip(t / sec, 0, 1))
    return norm(fade(x * shape, 0.02, 0.1), -10)


def rope_snap(rng):
    # 줄 끊김: 아주 짧은 딱 + 휙 풀리는 바람
    sec = 0.8
    t = t_axis(sec)
    snap = band(noise(sec, rng), 1500, 9000) * env_exp(sec, 0.006, 0.0003)
    twang = np.sin(2 * np.pi * (220 * np.exp(-t / 0.15) + 60) * t) * env_exp(sec, 0.08)
    whip = band(noise(sec, rng), 400, 2500) * np.exp(-((t - 0.12) / 0.08) ** 2) * 0.4
    return norm(fade(snap + twang * 0.4 + whip), -5)


def fall_impact(rng):
    # 수수밭에 떨어짐: 둔한 쿵(45Hz) + 대가 꺾이는 바스락
    sec = 1.6
    t = t_axis(sec)
    boom = np.sin(2 * np.pi * (45 + 30 * np.exp(-t / 0.05)) * t) * env_exp(sec, 0.25, 0.003)
    stalks = np.zeros(len(t))
    for i in range(14):
        at = 0.02 + rng.uniform(0, 0.7) ** 1.5
        c = band(noise(0.08, rng), 900, 5000) * env_exp(0.08, 0.015)
        place(stalks, c * rng.uniform(0.3, 1.0), at)
    return norm(fade(boom + stalks * 0.5, 0.003, 0.3), -5)


def wind(rng):
    # 바람: 걸러진 잡음이 천천히 부풀었다 잦아든다(앞뒤 부드럽게 — 겹쳐 틀 수 있게)
    sec = 6.0
    t = t_axis(sec)
    low = band(noise(sec, rng), 120, 700)
    high = band(noise(sec, rng), 900, 2400) * 0.25
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / sec * 1.5 - 1.2) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.37 * t))
    shape = np.sin(np.pi * t / sec) ** 0.8
    return norm((low + high * swell) * swell * shape, -14)


def breath_gasp(rng):
    # 숨을 들이켬: 숨결 띠 잡음이 빠르게 부풀었다 끊김
    sec = 0.7
    t = t_axis(sec)
    x = band(noise(sec, rng), 700, 3200) + band(noise(sec, rng), 1800, 2600, 0.05) * 0.6
    shape = np.clip(t / 0.25, 0, 1) ** 2 * np.clip((0.42 - t) / 0.05, 0, 1)
    tail = band(noise(sec, rng), 300, 1200) * np.exp(-np.clip(t - 0.42, 0, None) / 0.08) * (t > 0.42) * 0.25
    return norm(fade(x * shape + tail, 0.005, 0.05), -12)


def journal_stamp(rng):
    # 붓 도장: 부드러운 눌림 + 종이
    sec = 0.45
    t = t_axis(sec)
    press = np.sin(2 * np.pi * 140 * t) * env_exp(sec, 0.04, 0.003)
    paper = band(noise(sec, rng), 1500, 6000) * env_exp(sec, 0.03, 0.002)
    return norm(fade(press + paper * 0.5), -14)


def page_turn(rng):
    # 종이 넘김: 휙 하는 띠 잡음(높이가 올라감)
    sec = 0.5
    t = t_axis(sec)
    a = band(noise(sec, rng), 1200, 3000)
    b = band(noise(sec, rng), 3000, 7000)
    mix = np.clip(t / sec, 0, 1)
    shape = np.sin(np.pi * np.clip(t / 0.42, 0, 1)) ** 2
    return norm(fade((a * (1 - mix) + b * mix) * shape, 0.005, 0.05), -16)


def ui_select(rng):
    # 고르기: 아주 작은 나무 똑
    sec = 0.12
    t = t_axis(sec)
    x = np.sin(2 * np.pi * 880 * t) * env_exp(sec, 0.018) + band(noise(sec, rng), 2000, 6000) * env_exp(sec, 0.004) * 0.3
    return norm(fade(x), -20)


# ---------------------------------------------------------------- 음악(고리)
def _loop_safe(x, xf=1.0):
    """끝 xf초를 앞머리와 섞어 이음매 없는 고리로(길이는 xf만큼 짧아진다)."""
    n = int(SR * xf)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    start = tail * (1 - w) + head * w   # 끝에서 앞머리로 넘어가는 이음매
    return np.concatenate([start, x[n:-n]])


def bgm_day_calm(rng):
    # 낮 — 잔잔한 고리: 낮은 지속음 위에 평조 5음(솔라도레미) 뜯는 소리가 드문드문
    sec = 26.0
    t = t_axis(sec)
    drone = (np.sin(2 * np.pi * 98 * t) * 0.5 + np.sin(2 * np.pi * 147 * t) * 0.25) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 13.0))
    drone = band(drone + band(noise(sec, rng), 100, 400) * 0.05, 60, 600)
    scale = [196.0, 220.0, 261.6, 293.7, 329.6, 392.0]
    mel = np.zeros(len(t))
    at = 0.6
    while at < sec - 3.5:
        f = scale[int(rng.integers(0, len(scale)))]
        place(mel, pluck(f, 2.8, rng, 0.35) * rng.uniform(0.5, 0.9), at)
        at += float(rng.choice([1.2, 1.8, 2.4, 3.0]))
    x = drone * 0.35 + mel * 0.6
    return norm(_loop_safe(x, 1.5), -16)


def bgm_night_drone(rng):
    # 밤 — 긴장 지속음: 55Hz와 그 위 어긋난 5도(맥놀이), 숨결 같은 잡음이 천천히
    sec = 26.0
    t = t_axis(sec)
    d1 = np.sin(2 * np.pi * 55 * t)
    d2 = np.sin(2 * np.pi * 82.0 * t) * 0.5 + np.sin(2 * np.pi * 82.6 * t) * 0.5
    d3 = np.sin(2 * np.pi * 116.5 * t) * 0.18 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.7))
    air = band(noise(sec, rng), 200, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 6.5 + 1.0)) * 0.12
    x = band(d1 * 0.6 + d2 * 0.35 + d3 + air, 35, 1200) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 13.0))
    return norm(_loop_safe(x, 2.0), -17)


SFX = {
    "knock": (knock, "문 두드림 두 번(나무 문)"),
    "footstep_heavy": (footstep_heavy, "무거운 발 디딤(범·큰 짐승)"),
    "flour_rustle": (flour_rustle, "가루·자루 바스락"),
    "basket_roll": (basket_roll, "광주리 구르는 소리"),
    "tiger_growl": (tiger_growl, "범 그르렁(낮고 멀게)"),
    "axe_hit": (axe_hit, "도끼가 나무에 박힘"),
    "rope_creak": (rope_creak, "동아줄 삐걱"),
    "rope_snap": (rope_snap, "줄 끊김"),
    "fall_impact": (fall_impact, "수수밭에 떨어짐(쿵 + 대 꺾임)"),
    "wind": (wind, "바람 한 자락(6초, 앞뒤 부드럽게)"),
    "breath_gasp": (breath_gasp, "숨을 들이켬(놀람)"),
    "journal_stamp": (journal_stamp, "기록책 도장(UI)"),
    "page_turn": (page_turn, "종이 넘김(UI)"),
    "ui_select": (ui_select, "고르기 똑(UI)"),
    "brush_rustle": (brush_rustle, "덤불·가지 스침(큰 것이 숲 사이로 지나감)"),
}
# 처음 판(14개) 뒤에 더한 소리 — 씨앗 순서를 뒤에 붙여 예전 파일이 다시 돌려도 바뀌지 않게
LATE = ["brush_rustle"]
BGM = {
    "bgm_day_calm": (bgm_day_calm, "낮 잔잔한 고리(지속음 + 뜯는 5음, 24.5초)"),
    "bgm_night_drone": (bgm_night_drone, "밤 긴장 지속음(맥놀이, 24초)"),
}


def main():
    if "--list" in sys.argv:
        for k, (_, d) in {**SFX, **BGM}.items():
            print(f"{k:16s} {d}")
        return
    order = sorted(k for k in SFX if k not in LATE) + LATE
    for i, k in enumerate(order):
        fn = SFX[k][0]
        x = fn(np.random.default_rng(1000 + i))
        write(os.path.join(OUT, "sfx", k + ".wav"), x)
        print(f"sfx/{k}.wav  {len(x) / SR:.2f}s")
    for i, (k, (fn, _)) in enumerate(sorted(BGM.items())):
        x = fn(np.random.default_rng(2000 + i))
        write(os.path.join(OUT, "bgm", k + ".wav"), x)
        print(f"bgm/{k}.wav  {len(x) / SR:.2f}s")


if __name__ == "__main__":
    main()
