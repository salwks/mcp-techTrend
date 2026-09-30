// 검증 패널: 시간대·효과 토글·스프라이트 방식·카메라·순간이동·체크리스트
const CHECKS = [
  '3D 공간 속 2D 캐릭터가 자연스러운가',
  '4방향 전환이 고정 시점에서 충분한가 (방식 A와 비교)',
  '사람·아이·호랑이·집·나무의 크기감',
  '화면 위아래(깊이) 방향 거리 판단',
  '건물·나무에 가려져도 읽기 쉬운가',
  '실내에서도 자연스러운가',
  '조명·그림자가 캐릭터와 어울리는가 (낮·해질녘·밤)',
  '산길 높낮이가 읽히는가',
  '틸트시프트·한지 질감이 이야기책 분위기를 만드는가',
];
const STORE = 'seolhwa_checks_v1';

function load() { try { return JSON.parse(localStorage.getItem(STORE)) || {}; } catch { return {}; } }
function save(v) { try { localStorage.setItem(STORE, JSON.stringify(v)); } catch { /* 저장 불가 환경 */ } }

export class Panel {
  constructor(root, api) {
    this.api = api;
    const el = document.createElement('aside');
    el.className = 'panel collapsed';
    el.innerHTML = `
      <button class="p-toggle" type="button" aria-expanded="false">검증 패널</button>
      <div class="p-body">
        <section>
          <h3>시간</h3>
          <div class="p-row"><input id="p-time" type="range" min="0" max="24" step="0.25"><output id="p-time-out"></output></div>
          <div class="p-chips">
            <button type="button" data-time="6">새벽</button><button type="button" data-time="12">낮</button>
            <button type="button" data-time="18">해질녘</button><button type="button" data-time="22">밤</button>
          </div>
          <label class="p-check"><input id="p-timeFlow" type="checkbox"> 시간 자동 흐름</label>
        </section>
        <section>
          <h3>화면 효과</h3>
          <label class="p-check"><input id="p-tiltShift" type="checkbox"> 틸트시프트</label>
          <label class="p-check"><input id="p-bloom" type="checkbox"> 빛 번짐</label>
          <label class="p-check"><input id="p-paper" type="checkbox"> 한지 질감</label>
          <label class="p-check"><input id="p-fog" type="checkbox"> 안개</label>
          <label class="p-check"><input id="p-lowq" type="checkbox"> 저사양 모드</label>
        </section>
        <section>
          <h3>캐릭터 · 카메라</h3>
          <div class="p-seg" id="p-mode">
            <button type="button" data-mode="4dir">방식 B · 4방향</button><button type="button" data-mode="front">방식 A · 정면</button>
          </div>
          <label class="p-check"><input id="p-silhouette" type="checkbox"> 가려질 때 실루엣</label>
          <label class="p-check"><input id="p-occ" type="checkbox"> 가리는 물체 반투명</label>
          <label class="p-check"><input id="p-camzones" type="checkbox"> 구역별 카메라 연출</label>
        </section>
        <section>
          <h3>이동</h3>
          <div class="p-chips" id="p-warps"></div>
        </section>
        <section>
          <h3>검증 체크리스트</h3>
          <ul class="p-list" id="p-list"></ul>
        </section>
        <p class="p-help">이동 WASD·방향키 · 달리기 Shift · 조사/대화 E·Space · 패널 Tab · 시간 N</p>
      </div>`;
    root.appendChild(el);
    this.el = el;
    const $ = (s) => el.querySelector(s);
    const toggle = $('.p-toggle');
    toggle.addEventListener('click', () => this.setOpen(el.classList.contains('collapsed')));

    const time = $('#p-time'), out = $('#p-time-out');
    this.syncTime = () => { const t = api.getTime(); time.value = t; out.textContent = fmt(t); };
    time.addEventListener('input', () => { api.setTime(Number(time.value)); out.textContent = fmt(Number(time.value)); });
    el.querySelectorAll('[data-time]').forEach((b) => b.addEventListener('click', () => { api.setTime(Number(b.dataset.time)); this.syncTime(); }));

    const opts = api.getOptions();
    for (const k of ['timeFlow', 'tiltShift', 'bloom', 'paper', 'fog']) {
      const c = $('#p-' + k);
      if (!(k in opts)) { c.closest('label').hidden = true; continue; }
      c.checked = !!opts[k];
      c.addEventListener('change', () => api.setOption(k, c.checked));
    }
    const lowq = $('#p-lowq');
    if (!('quality' in opts)) lowq.closest('label').hidden = true;
    lowq.checked = opts.quality === 'low';
    lowq.addEventListener('change', () => api.setOption('quality', lowq.checked ? 'low' : 'high'));

    const segBtns = el.querySelectorAll('#p-mode button');
    const setMode = (m) => { segBtns.forEach((b) => b.classList.toggle('on', b.dataset.mode === m)); api.setSpriteMode(m); };
    segBtns.forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));
    setMode('4dir');

    const sil = $('#p-silhouette'); sil.checked = true; sil.addEventListener('change', () => api.setSilhouette(sil.checked));
    const occ = $('#p-occ'); occ.checked = true; occ.addEventListener('change', () => api.setOccluderFade(occ.checked));
    const cz = $('#p-camzones'); cz.checked = true; cz.addEventListener('change', () => api.setCameraZones(cz.checked));

    const warps = $('#p-warps');
    for (const w of api.warps()) {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = w.name;
      b.addEventListener('click', () => api.warp(w));
      warps.appendChild(b);
    }

    const state = load();
    const list = $('#p-list');
    CHECKS.forEach((text, i) => {
      const li = document.createElement('li');
      li.innerHTML = `<label class="p-check"><input id="p-chk-${i}" type="checkbox"> <span></span></label>`;
      li.querySelector('span').textContent = text;
      const c = li.querySelector('input');
      c.checked = !!state[i];
      c.addEventListener('change', () => { state[i] = c.checked; save(state); });
      list.appendChild(li);
    });
    this.syncTime();
  }

  // 추가 섹션: items = [{ id, label, checked, onChange }] 또는 [{ label, onClick }] (버튼)
  addSection(title, items) {
    const sec = document.createElement('section');
    const h = document.createElement('h3');
    h.textContent = title;
    sec.appendChild(h);
    const chips = document.createElement('div');
    chips.className = 'p-chips';
    for (const it of items) {
      if (it.onClick) {
        const b = document.createElement('button');
        b.type = 'button';
        b.textContent = it.label;
        b.addEventListener('click', it.onClick);
        chips.appendChild(b);
        continue;
      }
      const l = document.createElement('label');
      l.className = 'p-check';
      l.innerHTML = `<input id="p-x-${it.id}" type="checkbox"> <span></span>`;
      l.querySelector('span').textContent = it.label;
      const c = l.querySelector('input');
      c.checked = !!it.checked;
      c.addEventListener('change', () => it.onChange(c.checked));
      sec.appendChild(l);
    }
    if (chips.children.length) sec.appendChild(chips);
    const body = this.el.querySelector('.p-body');
    body.insertBefore(sec, body.querySelector('section:nth-of-type(4)'));
  }

  setOpen(open) {
    this.el.classList.toggle('collapsed', !open);
    this.el.querySelector('.p-toggle').setAttribute('aria-expanded', String(open));
    if (open) this.syncTime();
  }
  toggle() { this.setOpen(this.el.classList.contains('collapsed')); }
}

function fmt(t) {
  const h = Math.floor(t) % 24, m = Math.round((t - Math.floor(t)) * 60);
  const name = h < 5 ? '밤' : h < 7 ? '새벽' : h < 17 ? '낮' : h < 20 ? '해질녘' : '밤';
  return `${name} ${String(h).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
}
