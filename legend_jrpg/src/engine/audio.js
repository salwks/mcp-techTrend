// 오디오 엔진 — WebAudio 칩튠 합성 (오디오 파일 없음).
// API: unlockAudio(), sfx(name), playBgm(key), stopBgm()  (docs/CONTRACTS.md §3)
// 추가: setVolume(bgm, sfx), toggleMute(), isMuted(), renderOffline(kind, key, sec)
// 원칙: 어떤 상황(미지원 브라우저, suspended, 알 수 없는 키)에서도 예외를 던지지 않는다.

// ───────────────────────── 기본 유틸 ─────────────────────────
const NOTE_PC = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
const midiFreq = (m) => 440 * Math.pow(2, (m - 69) / 12);

// "C#5" → MIDI 번호
function noteMidi(s) {
  const m = /^([A-G])([#b]?)(-?\d)$/.exec(s);
  if (!m) return null;
  return 12 * (Number(m[3]) + 1) + NOTE_PC[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);
}

// 음표 문자열 → [[midi|null, 길이(step)], ...]. 형식: "E5:4 G5 r:2" (길이 생략 시 직전 길이)
function parseNotes(str) {
  const out = [];
  let len = 4;
  for (const tok of str.trim().split(/\s+/)) {
    if (!tok) continue;
    const [n, l] = tok.split(':');
    if (l) len = Number(l);
    out.push([n === 'r' ? null : noteMidi(n), len]);
  }
  return out;
}

// 코드 진행 "Am F:8 G:8" → [{root(pc), iv:[반음들], len}]
const CHORD_IV = {
  '': [0, 4, 7], m: [0, 3, 7], '7': [0, 4, 7, 10], m7: [0, 3, 7, 10],
  maj7: [0, 4, 7, 11], dim: [0, 3, 6], aug: [0, 4, 8], sus4: [0, 5, 7],
};
function parseProg(str, bar) {
  return str.trim().split(/\s+/).map((tok) => {
    const [c, l] = tok.split(':');
    const m = /^([A-G])([#b]?)(maj7|m7|m|7|dim|aug|sus4)?$/.exec(c);
    const root = NOTE_PC[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);
    return { root: (root + 12) % 12, iv: CHORD_IV[m[3] || ''], len: l ? Number(l) : bar };
  });
}

// 아르페지오: 코드 구성음을 rate step 간격으로 순환 (shape: up / updown)
function arpLine(prog, oct, rate, shape) {
  const ev = [];
  for (const ch of prog) {
    let tones = [...ch.iv.slice(0, 3), 12].map((i) => 12 * (oct + 1) + ch.root + i);
    if (shape === 'updown') tones = tones.concat(tones.slice(1, -1).reverse());
    for (let s = 0, k = 0; s < ch.len; s += rate, k++) ev.push([tones[k % tones.length], Math.min(rate, ch.len - s)]);
  }
  return ev;
}

// 베이스: 코드 루트 기준 반음 패턴("0:4 7:4 12:4")을 코드 길이만큼 반복
function bassLine(prog, pattern, oct) {
  const pat = parseNotesRel(pattern);
  const ev = [];
  for (const ch of prog) {
    let s = 0, k = 0;
    while (s < ch.len) {
      const [off, l] = pat[k++ % pat.length];
      const len = Math.min(l, ch.len - s);
      ev.push([off === null ? null : 12 * (oct + 1) + ch.root + off, len]);
      s += len;
    }
  }
  return ev;
}
function parseNotesRel(str) {
  return str.trim().split(/\s+/).map((tok) => {
    const [n, l] = tok.split(':');
    return [n === 'r' ? null : Number(n), Number(l || 4)];
  });
}

// ───────────────────────── 곡 데이터 ─────────────────────────
// 모두 오리지널 작곡. bar = 한 마디의 step 수, div = 한 박의 step 수.
// mel: 멜로디, prog: 코드 진행, bass: 베이스 패턴, arp: 아르페지오 설정, drums: k(킥) s(스네어) h(하이햇) o(오픈햇)
const SONGS = {
  title: {
    bpm: 104, prog: 'C G Am Em F C F G', lead: 'p25', double: -12, drums: 'k...s...k.k.s..h',
    bass: '0:4 7:4 12:4 7:4', arp: { oct: 4, rate: 2, shape: 'up' },
    mel: `G4:4 C5 E5:6 D5:2 | D5:4 B4 G4:8 | A4:4 C5 E5 A5 | G5:8 E5 |
          F5:4 E5 D5 C5 | E5:6 D5:2 C5:8 | A4:4 C5 F5 A5 | G5:8 D5:4 B4`,
  },
  village: {
    bpm: 66, div: 3, bar: 6, prog: 'F C Dm Bb F C Bb:3 C:3 F', lead: 'p50', drums: 'k..h..',
    bass: '0:3 7:3', arp: { oct: 4, rate: 1, shape: 'updown' },
    mel: `C5:2 A4:1 C5:2 F5:1 | E5:3 D5:2 C5:1 | D5:2 F5:1 A5:2 G5:1 | F5:3 D5 |
          C5:2 F5:1 A5:2 G5:1 | G5:2 E5:1 C5:3 | D5:2 F5:1 E5:2 D5:1 | F5:6 |
          A5:2 G5:1 F5:2 C5:1 | E5:3 G5 | F5:2 E5:1 D5:2 A4:1 | Bb4:3 D5 |
          C5:2 A4:1 F5:2 A5:1 | G5:2 E5:1 C5:3 | D5:2 Bb4:1 E5:2 G5:1 | F5:6`,
    progFull: 'F C Dm Bb F C Bb:3 C:3 F F C Dm Bb F C Bb:3 C:3 F',
  },
  town: {
    bpm: 132, prog: 'G C D G Em C D G', lead: 'p25', drums: 'k.h.s.h.k.h.s.hh',
    bass: '0:2 12:2 7:2 12:2',
    mel: `D5:2 G5 B5 G5 A5 G5 E5 D5 | E5:2 C5 E5 G5 E5:6 r:2 | F#5:2 A5 F#5 D5 E5 F#5 A5:4 |
          G5:8 r:4 D5:2 E5 | G5:2 E5 B4 E5 G5 A5 B5:4 | C6:4 B5:2 A5 G5:4 E5 |
          D5:2 E5 F#5 G5 A5:4 F#5 | G5:4 D5:2 B4 G4:8`,
  },
  field: {
    bpm: 120, prog: 'D Bm G A D G Em:8 A:8 D', lead: 'p25', double: -12, drums: 'k...s.h.k.k.s.hh',
    bass: '0:4 7:4', arp: { oct: 4, rate: 2, shape: 'up', vol: 0.05 },
    mel: `A4:4 D5:3 E5:1 F#5:4 A5 | B5:6 A5:2 F#5:8 | G5:4 F#5:2 E5 D5:4 B4 | C#5:4 E5 A5:8 |
          A5:3 G5:1 F#5:4 D5 F#5 | G5:4 B5 D6 B5 | A5:3 G5:1 E5:4 C#5 E5 | D5:12 r:4`,
  },
  forest: {
    bpm: 84, prog: 'Am7 Fmaj7 Am7 Fmaj7 Dm7 Em Fmaj7 E', lead: 'p50', vib: true, drums: 'k.......h.....h.',
    bass: '0:8 7:8', arp: { oct: 4, rate: 1, shape: 'updown', wave: 'tri', vol: 0.09 },
    mel: `E5:8 D5:4 C5 | A4:12 r:4 | E5:4 G5 A5 G5 | E5:12 r:4 |
          F5:6 E5:2 D5:4 C5 | B4:8 G4 | A4:4 C5 E5 F5 | G#5:8 E5`,
  },
  dungeon: {
    bpm: 96, prog: 'Dm Dm Bb A Dm Dm Gm A', lead: 'p25', leadVol: 0.1, drums: 'k.....k.s.......',
    bass: '0:2 0:2 12:2 0:2 7:2 0:2 12:2 1:2',
    mel: `D5:6 E5:2 F5:4 E5 | D5:4 A4 C#5:8 | D5:4 F5 Bb5 A5 | A5:8 G5:4 E5 |
          F5:6 G5:2 A5:4 F5 | D5:4 F5 E5 D5 | Bb4:4 D5 G5 F5 | E5:8 C#5`,
  },
  tower: {
    bpm: 90, prog: 'Cmaj7 D Cmaj7 D Am7 Bm Cmaj7 D', lead: 'tri', leadVol: 0.2, vib: true, drums: '',
    bass: '0:16', arp: { oct: 5, rate: 1, shape: 'up', wave: 'tri', vol: 0.08, echo: 3 },
    mel: `E5:8 G5 | F#5:12 A5:4 | B5:8 G5 | A5:16 |
          C6:8 B5:4 A5 | F#5:8 D5 | E5:4 G5 B5 C6 | D6:8 A5`,
  },
  castle: {
    bpm: 80, prog: 'Cm Cm Ab G Cm Fm Ab G', lead: 'p50', double: -12, bassWave: 'saw', drums: 'k.......k...k...',
    bass: '0:4 0:4 7:4 0:4',
    mel: `C5:4 Eb5 G5 C6 | B5:8 G5 | Ab5:4 G5 F5 Eb5 | D5:8 B4 |
          Eb5:4 D5 C5 G5 | Ab5:8 F5 | Eb5:4 F5 G5 Ab5 | B4:8 D5:4 G5`,
  },
  battle: {
    bpm: 160, prog: 'Am F G Am Am F G E', lead: 'p25', drums: 'k.h.s.h.k.k.s.hs',
    bass: '0:2 12:2', arp: { oct: 4, rate: 1, shape: 'up', vol: 0.045 },
    mel: `A5:2 E5 A5 B5 C6:4 B5:2 A5 | C6:2 A5 F5 A5 C6:4 D6 | B5:2 G5 D5 G5 B5:4 A5:2 G5 | A5:6 E5:2 A4:8 |
          C6:2 B5 A5 G5 A5:4 E5 | F5:2 G5 A5 C6 F6:4 E6 | D6:2 C6 B5 A5 G5:4 B5 | G#5:4 B5 E6:8`,
  },
  boss: {
    bpm: 172, prog: 'Em Em C D Em Em C B', lead: 'p25', double: -12, drums: 'kkh.s.h.kkh.s.hs',
    bass: '0:2 0:2 12:2 0:2', arp: { oct: 4, rate: 1, shape: 'updown', wave: 'saw', vol: 0.035 },
    mel: `E5:4 B5 A5:2 G5 F#5 G5 | E5:8 r:2 E5 G5 B5 | C6:4 B5:2 A5 G5:4 E5 | F#5:4 A5 D6:8 |
          B5:2 A5 G5 F#5 E5:4 G5 | B5:4 E6 D6 B5 | C6:2 D6 E6:4 D6:2 C6 B5:4 | D#6:8 B5`,
  },
  final_boss: {
    bpm: 150, prog: 'Dm Dm Bb C Dm Dm Gm A Bb C Am Dm Gm A Bb A', lead: 'p25', double: -12,
    drums: 'k.h.s.hkk.h.s.hs', bassWave: 'saw',
    bass: '0:2 0:2 12:2 0:2 0:2 12:2 7:2 12:2', arp: { oct: 4, rate: 1, shape: 'up', vol: 0.04 },
    mel: `D5:4 A5 F5:2 E5 D5 E5 | F5:4 G5 A5:8 | Bb5:4 A5:2 G5 F5:4 D5 | E5:4 G5 C6:8 |
          D6:4 C6:2 A5 F5:4 A5 | D6:6 E6:2 F6:8 | D6:4 Bb5 G5 Bb5 | A5:8 C#6 |
          D6:8 F6 | E6:4 D6:2 C6 G5:8 | A5:4 C6 E6 C6 | D6:12 A5:4 |
          Bb5:4 A5 G5 D6 | C#6:8 E6 | F6:4 E6 D6 Bb5 | A5:8 C#6:4 E6`,
  },
  victory: {
    bpm: 140, prog: 'C F G:8 C:8 C Am F G', loopBar: 3, lead: 'p50', double: -12, drums: 'k...h...k.k.h...',
    bass: '0:4 7:4', arp: { oct: 4, rate: 2, shape: 'up', vol: 0.05 },
    mel: `G4:2 C5 E5 G5:6 E5:2 G5 | A5:4 F5 C6:8 | B5:2 G5 D5 B5 C6:8 |
          E5:4 G5 C6 G5 | A5:6 G5:2 E5:8 | F5:4 A5 C6 A5 | G5:6 F5:2 D5:8`,
  },
  sad: {
    bpm: 66, prog: 'Am F C G Dm Am E Am', lead: 'p50', leadVol: 0.13, vib: true, drums: '',
    bass: '0:8 7:8', arp: { oct: 4, rate: 2, shape: 'updown', wave: 'tri', vol: 0.08 },
    mel: `E5:6 D5:2 C5:4 B4 | A4:8 C5 | G5:6 F5:2 E5:4 D5 | D5:12 r:4 |
          F5:6 E5:2 D5:4 C5 | C5:4 B4 A4:8 | B4:4 G#4 B4 D5 | C5:12 r:4`,
  },
  ending: {
    bpm: 88, prog: 'F C Dm Bb F C Bb C Dm Am Bb F Gm C F C', lead: 'p50', vib: true,
    drums: 'k...h...s...h...', bass: '0:4 7:4 12:4 7:4', arp: { oct: 4, rate: 2, shape: 'updown', wave: 'tri', vol: 0.08 },
    mel: `A5:6 G5:2 F5:4 C5 | E5:8 G5 | F5:6 E5:2 D5:4 A4 | Bb4:8 D5 |
          C5:4 F5 A5 C6 | Bb5:6 A5:2 G5:8 | F5:4 G5 A5 Bb5 | C6:12 r:4 |
          D6:6 C6:2 A5:8 | C6:6 A5:2 E5:8 | F5:4 G5 A5 D6 | C6:12 A5:4 |
          Bb5:6 A5:2 G5:4 D5 | E5:4 G5 C6 E6 | F6:8 C6 | E5:4 G5 Bb5:8`,
  },
};

// 곡 정의 → 연주용 트랙(음표를 step 인덱스로 펼친 형태)
const trackCache = {};
function getTrack(key) {
  if (trackCache[key]) return trackCache[key];
  const d = SONGS[key];
  const bar = d.bar || 16, div = d.div || 4;
  const prog = parseProg(d.progFull || d.prog, bar);
  const mel = parseNotes(d.mel.replace(/\|/g, ' '));
  const voices = [];
  const lead = { wave: d.lead || 'p25', vol: d.leadVol || 0.15, gate: 0.88, vib: !!d.vib, sus: 0.7 };
  voices.push({ ...lead, ev: mel });
  if (d.double) voices.push({ ...lead, wave: 'p50', vol: lead.vol * 0.45, ev: mel.map(([m, l]) => [m === null ? null : m + d.double, l]) });
  voices.push({ wave: d.bassWave || 'tri', vol: d.bassWave === 'saw' ? 0.07 : 0.26, gate: 0.9, sus: 0.8, ev: bassLine(prog, d.bass, 2) });
  if (d.arp) {
    const a = d.arp, ev = arpLine(prog, a.oct, a.rate, a.shape);
    const v = { wave: a.wave || 'p125', vol: a.vol || 0.06, gate: 0.6, sus: 0.4 };
    voices.push({ ...v, ev });
    // 에코: 몇 step 늦게 작게 한 번 더 (탑의 몽환적인 울림)
    if (a.echo) voices.push({ ...v, vol: v.vol * 0.4, ev: [[null, a.echo], ...ev].slice(0, -1) });
  }
  const total = prog.reduce((s, c) => s + c.len, 0);
  const tr = { key, bpm: d.bpm, div, len: total, loopStart: (d.loopBar || 0) * bar, voices: [], drums: d.drums || '' };
  for (const v of voices) {
    const steps = new Array(total);
    let s = 0;
    for (const [m, l] of v.ev) { if (m !== null && s < total) steps[s] = [m, l]; s += l; }
    tr.voices.push({ ...v, steps, len: Math.max(1, Math.min(s, total)) });
  }
  return (trackCache[key] = tr);
}

// ───────────────────────── 합성 도구 ─────────────────────────
const waveCache = new WeakMap(); // ctx → { p125, p25, p50 }
const noiseCache = new WeakMap(); // ctx → AudioBuffer

// 펄스파(듀티비 12.5/25/50%)를 PeriodicWave로 생성
function pulseWave(ctx, duty) {
  let c = waveCache.get(ctx);
  if (!c) waveCache.set(ctx, (c = {}));
  if (c[duty]) return c[duty];
  const N = 32, re = new Float32Array(N), im = new Float32Array(N);
  for (let n = 1; n < N; n++) re[n] = (2 * Math.sin(n * Math.PI * duty)) / (n * Math.PI);
  return (c[duty] = ctx.createPeriodicWave(re, im));
}
function noiseBuf(ctx) {
  let b = noiseCache.get(ctx);
  if (b) return b;
  b = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
  const d = b.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  noiseCache.set(ctx, b);
  return b;
}
function makeOsc(ctx, wave) {
  const o = ctx.createOscillator();
  if (wave === 'p125') o.setPeriodicWave(pulseWave(ctx, 0.125));
  else if (wave === 'p25') o.setPeriodicWave(pulseWave(ctx, 0.25));
  else if (wave === 'p50') o.type = 'square';
  else if (wave === 'tri') o.type = 'triangle';
  else if (wave === 'saw') o.type = 'sawtooth';
  else o.type = 'sine';
  return o;
}

// 음 하나: 선택적 피치 슬라이드(f2), 짧은 어택/릴리즈 엔벨로프
function tone(ctx, out, t, { w = 'p50', f, f2, dur = 0.1, vol = 0.2, att = 0.004, sus = 1, vib = false }) {
  const o = makeOsc(ctx, w), g = ctx.createGain();
  o.frequency.setValueAtTime(f, t);
  if (f2) o.frequency.exponentialRampToValueAtTime(Math.max(20, f2), t + dur);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(vol, t + att);
  if (sus < 1) g.gain.linearRampToValueAtTime(vol * sus, t + Math.min(dur, att + 0.12));
  g.gain.setValueAtTime(vol * sus, t + dur);
  g.gain.linearRampToValueAtTime(0.0001, t + dur + 0.04);
  if (vib && dur > 0.35) { // 긴 음에만 살짝 비브라토
    const l = ctx.createOscillator(), lg = ctx.createGain();
    l.frequency.value = 5.5;
    lg.gain.setValueAtTime(0, t);
    lg.gain.linearRampToValueAtTime(f * 0.007, t + 0.3);
    l.connect(lg).connect(o.frequency);
    l.start(t); l.stop(t + dur + 0.05);
  }
  o.connect(g).connect(out);
  o.start(t); o.stop(t + dur + 0.06);
}

// 노이즈 버스트: 필터 주파수 f → f2 로 변화
function noise(ctx, out, t, { dur = 0.1, vol = 0.2, type = 'lowpass', f = 3000, f2, q = 0.8 }) {
  const s = ctx.createBufferSource(), fl = ctx.createBiquadFilter(), g = ctx.createGain();
  s.buffer = noiseBuf(ctx);
  fl.type = type; fl.Q.value = q;
  fl.frequency.setValueAtTime(f, t);
  if (f2) fl.frequency.exponentialRampToValueAtTime(f2, t + dur);
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  s.connect(fl).connect(g).connect(out);
  s.start(t, Math.random() * 0.5); s.stop(t + dur + 0.02);
}

// 음 이름 목록을 일정 간격으로 연주
function seq(ctx, out, t, names, gap, opts) {
  names.forEach((n, i) => { if (n) tone(ctx, out, t + i * gap, { ...opts, f: midiFreq(noteMidi(n)) }); });
}

// 드럼 한 타
function drum(ctx, out, t, ch) {
  if (ch === 'k') tone(ctx, out, t, { w: 'sine', f: 150, f2: 42, dur: 0.12, vol: 0.5, att: 0.002 });
  else if (ch === 's') { noise(ctx, out, t, { dur: 0.12, vol: 0.22, type: 'bandpass', f: 1800, q: 0.7 }); tone(ctx, out, t, { w: 'tri', f: 190, f2: 120, dur: 0.05, vol: 0.15 }); }
  else if (ch === 'h') noise(ctx, out, t, { dur: 0.03, vol: 0.08, type: 'highpass', f: 7000 });
  else if (ch === 'o') noise(ctx, out, t, { dur: 0.15, vol: 0.07, type: 'highpass', f: 6000 });
}

// ───────────────────────── 효과음 ─────────────────────────
const SFX = {
  cursor: (c, o, t) => tone(c, o, t, { w: 'p25', f: 1320, dur: 0.03, vol: 0.12 }),
  confirm: (c, o, t) => seq(c, o, t, ['A5', 'E6'], 0.05, { w: 'p25', dur: 0.05, vol: 0.14 }),
  cancel: (c, o, t) => seq(c, o, t, ['E5', 'A4'], 0.05, { w: 'p25', dur: 0.05, vol: 0.13 }),
  buzzer: (c, o, t) => { tone(c, o, t, { w: 'p50', f: 110, dur: 0.18, vol: 0.12 }); tone(c, o, t, { w: 'p50', f: 117, dur: 0.18, vol: 0.1 }); },
  hit: (c, o, t) => { noise(c, o, t, { dur: 0.12, vol: 0.45, f: 2500, f2: 300 }); tone(c, o, t, { w: 'p50', f: 220, f2: 55, dur: 0.1, vol: 0.18 }); },
  crit: (c, o, t) => {
    noise(c, o, t, { dur: 0.05, vol: 0.4, type: 'highpass', f: 3000 });
    noise(c, o, t + 0.03, { dur: 0.25, vol: 0.55, f: 4000, f2: 200 });
    tone(c, o, t + 0.03, { w: 'p25', f: 500, f2: 45, dur: 0.22, vol: 0.22 });
  },
  miss: (c, o, t) => noise(c, o, t, { dur: 0.18, vol: 0.6, type: 'bandpass', f: 600, f2: 3500, q: 2 }),
  magic: (c, o, t) => seq(c, o, t, ['C6', 'E6', 'G6', 'B6', 'D7', 'G7'], 0.035, { w: 'p125', dur: 0.08, vol: 0.1 }),
  fire: (c, o, t) => {
    noise(c, o, t, { dur: 0.25, vol: 0.4, f: 400, f2: 3000 });
    noise(c, o, t + 0.2, { dur: 0.35, vol: 0.35, f: 3000, f2: 250 });
    tone(c, o, t, { w: 'saw', f: 90, f2: 50, dur: 0.45, vol: 0.12 });
  },
  ice: (c, o, t) => {
    noise(c, o, t, { dur: 0.4, vol: 0.18, type: 'highpass', f: 5000 });
    seq(c, o, t, ['E7', 'B6', 'G7', 'D7', 'A7'], 0.05, { w: 'tri', dur: 0.12, vol: 0.14 });
  },
  thunder: (c, o, t) => {
    noise(c, o, t, { dur: 0.08, vol: 0.5, type: 'highpass', f: 2000 });
    noise(c, o, t + 0.05, { dur: 0.7, vol: 0.6, f: 1500, f2: 80 });
    tone(c, o, t, { w: 'p50', f: 70, f2: 35, dur: 0.5, vol: 0.18 });
    tone(c, o, t + 0.12, { w: 'p25', f: 900, f2: 120, dur: 0.1, vol: 0.12 });
  },
  holy: (c, o, t) => ['C6', 'E6', 'G6', 'C7', 'E7'].forEach((n, i) =>
    tone(c, o, t + i * 0.06, { w: 'tri', f: midiFreq(noteMidi(n)), dur: 0.5 - i * 0.05, vol: 0.12, vib: true })),
  heal: (c, o, t) => seq(c, o, t, ['C5', 'E5', 'G5', 'C6', 'E6', 'G6'], 0.06, { w: 'tri', dur: 0.14, vol: 0.2 }),
  levelup: (c, o, t) => {
    seq(c, o, t, ['G5', 'C6', 'E6'], 0.09, { w: 'p50', dur: 0.08, vol: 0.12 });
    tone(c, o, t + 0.27, { w: 'p50', f: midiFreq(noteMidi('G6')), dur: 0.4, vol: 0.12, sus: 0.6 });
    tone(c, o, t + 0.27, { w: 'p25', f: midiFreq(noteMidi('C6')), dur: 0.4, vol: 0.08, sus: 0.6 });
  },
  encounter: (c, o, t) => {
    for (let i = 0; i < 3; i++) tone(c, o, t + i * 0.1, { w: 'p50', f: 200 + i * 150, f2: 1600, dur: 0.1, vol: 0.1 });
    noise(c, o, t, { dur: 0.45, vol: 0.25, type: 'bandpass', f: 300, f2: 5000, q: 1.5 });
  },
  escape: (c, o, t) => { for (let i = 0; i < 4; i++) tone(c, o, t + i * 0.06, { w: 'p25', f: 900 - i * 150, f2: 300 - i * 50, dur: 0.06, vol: 0.12 }); },
  chest: (c, o, t) => {
    noise(c, o, t, { dur: 0.08, vol: 0.2, f: 800 });
    seq(c, o, t + 0.08, ['G5', 'B5', 'D6', 'G6'], 0.05, { w: 'p50', dur: 0.07, vol: 0.1 });
  },
  door: (c, o, t) => { noise(c, o, t, { dur: 0.2, vol: 0.35, f: 600, f2: 120 }); tone(c, o, t, { w: 'p50', f: 150, f2: 70, dur: 0.12, vol: 0.12 }); },
  step: (c, o, t) => noise(c, o, t, { dur: 0.035, vol: 0.12, type: 'bandpass', f: 1200, q: 1 }),
  item: (c, o, t) => seq(c, o, t, ['E6', 'B6'], 0.07, { w: 'p50', dur: 0.1, vol: 0.1 }),
  enemy_die: (c, o, t) => { noise(c, o, t, { dur: 0.4, vol: 0.3, f: 3000, f2: 100 }); tone(c, o, t, { w: 'p25', f: 700, f2: 40, dur: 0.35, vol: 0.14 }); },
  victory: (c, o, t) => {
    seq(c, o, t, ['C5', 'E5', 'G5'], 0.08, { w: 'p50', dur: 0.07, vol: 0.12 });
    tone(c, o, t + 0.24, { w: 'p50', f: midiFreq(noteMidi('C6')), dur: 0.45, vol: 0.12, sus: 0.6 });
  },
};

// ───────────────────────── 시퀀서 ─────────────────────────
// 한 곡의 재생 상태. ctx(실시간/오프라인 모두 가능)의 시간축에 음표를 미리 예약한다.
class Sequencer {
  constructor(ctx, dest, track, fadeIn = 0.02) {
    this.ctx = ctx; this.tr = track;
    this.stepDur = 60 / track.bpm / track.div;
    this.step = 0;
    this.next = ctx.currentTime + 0.06;
    this.out = ctx.createGain();
    this.out.gain.setValueAtTime(0.0001, ctx.currentTime);
    this.out.gain.linearRampToValueAtTime(1, ctx.currentTime + Math.max(0.02, fadeIn));
    this.out.connect(dest);
  }
  // t(초)까지의 음표 예약
  scheduleUntil(t) {
    const tr = this.tr, ctx = this.ctx;
    while (this.next < t) {
      const s = this.step, at = this.next;
      for (const v of tr.voices) {
        const e = v.steps[s % v.len];
        if (e) tone(ctx, this.out, at, { w: v.wave, f: midiFreq(e[0]), dur: e[1] * this.stepDur * v.gate, vol: v.vol, sus: v.sus, att: 0.006, vib: v.vib });
      }
      if (tr.drums) drum(ctx, this.out, at, tr.drums[s % tr.drums.length]);
      this.next += this.stepDur;
      this.step = s + 1 >= tr.len ? tr.loopStart : s + 1;
    }
  }
  // 탭 비활성 등으로 예약 시각이 뒤처지면 현재 시각으로 맞춤(밀린 음을 몰아서 치지 않음)
  resync(now) {
    if (this.next < now - 0.05) {
      const missed = Math.floor((now - this.next) / this.stepDur);
      const L = this.tr.len - this.tr.loopStart;
      this.step = this.tr.loopStart + ((this.step - this.tr.loopStart + missed) % L + L) % L;
      if (this.step >= this.tr.len) this.step = this.tr.loopStart;
      this.next = now + 0.05;
    }
  }
  fadeOut(sec) {
    const g = this.out.gain, now = this.ctx.currentTime;
    try {
      g.cancelScheduledValues(now);
      g.setValueAtTime(g.value, now);
      g.linearRampToValueAtTime(0.0001, now + sec);
    } catch (e) { /* 무시 */ }
    const out = this.out;
    setTimeout(() => { try { out.disconnect(); } catch (e) { /* 무시 */ } }, (sec + 0.3) * 1000);
  }
}

// ───────────────────────── 출력 그래프 ─────────────────────────
// master → lowpass(거친 고음 완화) → compressor → destination, bgm/sfx 버스 분리
function buildGraph(ctx) {
  const master = ctx.createGain(), lp = ctx.createBiquadFilter(), comp = ctx.createDynamicsCompressor();
  lp.type = 'lowpass'; lp.frequency.value = 7000; lp.Q.value = 0.5;
  comp.threshold.value = -12; comp.ratio.value = 4;
  const bgm = ctx.createGain(), sfxBus = ctx.createGain();
  bgm.gain.value = vol.bgm; sfxBus.gain.value = vol.sfx; master.gain.value = muted ? 0 : 0.8;
  bgm.connect(master); sfxBus.connect(master);
  master.connect(lp).connect(comp).connect(ctx.destination);
  return { master, bgm, sfx: sfxBus };
}

// ───────────────────────── 전역 상태 ─────────────────────────
let ctx = null, graph = null, timer = null, failed = false;
let cur = null, curKey = null, pendingKey = null;
let muted = false;
const vol = { bgm: 0.55, sfx: 0.8 };
const lastSfx = {};

function tick() {
  try {
    if (!ctx || !cur) return;
    const now = ctx.currentTime;
    cur.resync(now);
    const hidden = typeof document !== 'undefined' && document.hidden;
    cur.scheduleUntil(now + (hidden ? 1.2 : 0.12)); // 백그라운드에선 타이머가 느려지므로 길게 예약
  } catch (e) { /* 무시 */ }
}

export function unlockAudio() {
  try {
    if (failed) return;
    if (!ctx) {
      const AC = typeof window !== 'undefined' && (window.AudioContext || window.webkitAudioContext);
      if (!AC) { failed = true; return; }
      ctx = new AC();
      graph = buildGraph(ctx);
      timer = setInterval(tick, 25);
      // iOS 등: 무음 버퍼를 한 번 재생해 잠금 해제
      const b = ctx.createBufferSource();
      b.buffer = ctx.createBuffer(1, 1, 22050);
      b.connect(ctx.destination); b.start(0);
    }
    if (ctx.state === 'suspended' && ctx.resume) ctx.resume().catch(() => {});
    if (pendingKey) { const k = pendingKey; pendingKey = null; playBgm(k); }
  } catch (e) { failed = true; }
}

export function sfx(name) {
  try {
    const fn = SFX[name];
    if (!fn || !ctx || ctx.state !== 'running') return;
    const now = ctx.currentTime;
    if (lastSfx[name] && now - lastSfx[name] < 0.03) return; // 같은 효과음 과다 중첩 방지
    lastSfx[name] = now;
    fn(ctx, graph.sfx, now + 0.005);
  } catch (e) { /* 무시 */ }
}

export function playBgm(key) {
  try {
    if (!SONGS[key]) return;
    if (!ctx) { pendingKey = key; return; }
    if (curKey === key && cur) return; // 같은 곡이면 이어서 재생
    const had = !!cur;
    if (cur) cur.fadeOut(0.3);
    cur = new Sequencer(ctx, graph.bgm, getTrack(key), had ? 0.3 : 0.05);
    curKey = key;
    tick();
  } catch (e) { /* 무시 */ }
}

export function stopBgm() {
  try {
    pendingKey = null;
    if (cur) cur.fadeOut(0.5);
    cur = null; curKey = null;
  } catch (e) { /* 무시 */ }
}

// 볼륨(0~1). 인자를 생략하면 유지.
export function setVolume(bgm, sfxVol) {
  if (typeof bgm === 'number') vol.bgm = Math.max(0, Math.min(1, bgm));
  if (typeof sfxVol === 'number') vol.sfx = Math.max(0, Math.min(1, sfxVol));
  try { if (graph) { graph.bgm.gain.value = vol.bgm; graph.sfx.gain.value = vol.sfx; } } catch (e) { /* 무시 */ }
}
export function isMuted() { return muted; }
export function toggleMute() {
  muted = !muted;
  try { if (graph) graph.master.gain.setTargetAtTime(muted ? 0 : 0.8, ctx.currentTime, 0.02); } catch (e) { /* 무시 */ }
  return muted;
}

// 검증용: OfflineAudioContext로 BGM/효과음을 렌더링해 AudioBuffer 반환 (kind: 'bgm' | 'sfx')
export async function renderOffline(kind, key, seconds = 3, sampleRate = 22050) {
  const OAC = typeof window !== 'undefined' && (window.OfflineAudioContext || window.webkitOfflineAudioContext);
  if (!OAC) return null;
  const oc = new OAC(1, Math.ceil(seconds * sampleRate), sampleRate);
  const g = buildGraph(oc);
  if (kind === 'bgm' && SONGS[key]) new Sequencer(oc, g.bgm, getTrack(key)).scheduleUntil(seconds);
  else if (kind === 'sfx' && SFX[key]) SFX[key](oc, g.sfx, 0.01);
  return oc.startRendering();
}

// 검증용: 각 곡의 멜로디/코드 길이(step) 정보
export function _trackInfo(key) {
  const t = getTrack(key);
  return { len: t.len, voices: t.voices.map((v) => v.len) };
}
