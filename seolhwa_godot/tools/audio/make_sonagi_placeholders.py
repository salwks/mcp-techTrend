#!/usr/bin/env python3
"""여는 사건 A 「소나기」 시험(claude/opening-a-sonagi-trial — 메인에 합치지 않음)의 **임시** 소리 둘.

    /opt/homebrew/bin/python3 tools/audio/make_sonagi_placeholders.py      # seolhwa_godot/ 에서

numpy 없이 표준 라이브러리만 쓴다(이 맥의 Homebrew 파이썬에 numpy가 없다). 씨앗 고정 — 다시 돌려도 같은 파일.
결과(모노 16비트 22050Hz, assets/audio/sfx/):
  rain_patter.wav  — 후드득: 한지·멍석에 떨어지는 굵은 빗방울 서너 개(1.2초). 검은 화면 첫 소리(E1 자리)
  rain_shower.wav  — 소나기(8초, 고리로 돌림). 굵은 빗줄기 쏴 + 잦은 빗방울
모두 임시다. 실제 녹음은 같은 id의 .ogg를 같은 폴더에 넣으면 그것이 먼저 읽힌다.
"""
import math
import os
import random
import struct
import wave

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")


def lowpass(x, fc):
    a = math.exp(-2 * math.pi * fc / SR)
    y = []
    s = 0.0
    for v in x:
        s = (1 - a) * v + a * s
        y.append(s)
    return y


def highpass(x, fc):
    lp = lowpass(x, fc)
    return [v - w for v, w in zip(x, lp)]


def norm(x, peak_db):
    m = max(abs(v) for v in x) or 1.0
    g = 10 ** (peak_db / 20.0) / m
    return [v * g for v in x]


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name + ".wav")
    with wave.open(p, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in x))
    print("wrote", p, "%.2fs" % (len(x) / SR))


def drop(rng, big):
    """빗방울 하나: 낮은 '툭'(종이·멍석) + 짧은 튐."""
    n = int(SR * (0.16 if big else 0.05))
    f0 = rng.uniform(160, 260) if big else rng.uniform(900, 2400)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / (0.035 if big else 0.008))
        tone = math.sin(2 * math.pi * f0 * t * (1 - 0.4 * t / (n / SR)))
        out.append((tone * 0.7 + rng.uniform(-1, 1) * 0.6) * env)
    return out


def place(buf, x, at):
    s = int(SR * at)
    for i, v in enumerate(x):
        if s + i < len(buf):
            buf[s + i] += v


def rain_patter():
    rng = random.Random(5101)
    buf = [0.0] * int(SR * 1.2)
    for at, big in [(0.02, True), (0.21, True), (0.33, False), (0.47, True), (0.62, False), (0.71, True), (0.86, False)]:
        place(buf, [v * rng.uniform(0.6, 1.0) for v in drop(rng, big)], at)
    buf = lowpass(buf, 5200)
    n = len(buf)
    buf = [v * min(1.0, (n - i) / (SR * 0.25)) for i, v in enumerate(buf)]
    return norm(buf, -6)


def rain_shower():
    rng = random.Random(5102)
    sec = 8.0
    n = int(SR * sec)
    hiss = highpass(lowpass([rng.uniform(-1, 1) for _ in range(n)], 6000), 500)
    body = lowpass([rng.uniform(-1, 1) for _ in range(n)], 900)
    buf = [h * 0.55 + b * 0.35 for h, b in zip(hiss, body)]
    for _ in range(420):
        place(buf, [v * rng.uniform(0.15, 0.5) for v in drop(rng, rng.random() < 0.18)], rng.uniform(0.0, sec - 0.2))
    # 고리 이음: 끝 0.4초를 앞 0.4초에 겹쳐 섞는다
    xf = int(SR * 0.4)
    head = buf[:xf]
    tail = buf[-xf:]
    for i in range(xf):
        k = i / xf
        buf[i] = head[i] * k + tail[i] * (1 - k)
    buf = buf[: n - xf]
    return norm(buf, -10)


if __name__ == "__main__":
    write("rain_patter", rain_patter())
    write("rain_shower", rain_shower())
