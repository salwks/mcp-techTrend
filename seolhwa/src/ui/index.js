// 설화록 이야기 UI — 알림 띠, 조사 카드, 선택지, 사건 기록 책자, 자막, 레터박스, 종결 카드, 소지품
// 계약: docs/STORY.md §3.2. 스타일은 src/ui/ui.css (core/ui.css 토큰을 이어 씀)

const KIND = {
  clue: { label: '단서', seal: '證' },
  rule: { label: '규칙', seal: '理' },
  journal: { label: '기록', seal: '錄' },
  info: { label: '알림', seal: '告' },
};
const OUTCOME = {
  kill: '처치', win: '처치', slay: '처치', slain: '처치', killed: '처치', 처치: '처치',
  trap: '함정', trapped: '함정', 함정: '함정',
  repel: '물러나게 함', repelled: '물러나게 함', retreat: '물러나게 함', '물러나게 함': '물러나게 함',
};
const OUTCOME_KEY = { 처치: 'kill', 함정: 'trap', '물러나게 함': 'repel' };
const SOLVED = new Set(['solved', 'resolved', 'done', 'closed', 'complete', 'completed', '해결']);

const CONFIRM = new Set(['KeyE', 'Space', 'Enter', 'NumpadEnter', 'KeyZ']);
const CANCEL = new Set(['Escape', 'KeyX']);
const ARM_MS = 220;

// 작은 먹선 소지품 아이콘 (24×24, stroke = currentColor)
const ICONS = {
  cake: '<path d="M4 15.5c0-1.4 3.6-2.5 8-2.5s8 1.1 8 2.5v2c0 1.4-3.6 2.5-8 2.5s-8-1.1-8-2.5z" fill="#f6f0e2"/><path d="M4 15.5c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5"/><path d="M6.5 10.5c0-1.1 2.5-2 5.5-2s5.5.9 5.5 2v1.6c0 1.1-2.5 2-5.5 2s-5.5-.9-5.5-2z" fill="#f6f0e2"/><path d="M6.5 10.5c0 1.1 2.5 2 5.5 2s5.5-.9 5.5-2"/><circle cx="12" cy="6" r="1.1" fill="#a8372f" stroke="none"/>',
  oil: '<path d="M10 3.5h4M10.5 3.5v3.2c-2.8 1-4.5 3.4-4.5 6.6 0 4 2.6 7.2 6 7.2s6-3.2 6-7.2c0-3.2-1.7-5.6-4.5-6.6V3.5"/><path d="M7.4 14h9.2c-.3 3-2.2 5.2-4.6 5.2S7.7 17 7.4 14z" fill="#b8892e" stroke="none" opacity=".75"/>',
  torch: '<path d="M10.6 21l1.2-10.5h.8L13.8 21" /><path d="M10.2 10.6h4"/><path d="M12.2 9.6c-2.6-1.2-3.2-3.6-1.4-6.1.2 1.6 1 2 1.6 2.2-.1-1.3.6-2.6 1.6-3.2-.2 1.6 1.7 2.6 1.4 4.4-.3 1.6-1.6 2.5-3.2 2.7z" fill="#a8372f" stroke="#7a241e"/>',
  rope: '<ellipse cx="11" cy="13" rx="7" ry="4.6"/><ellipse cx="11" cy="13" rx="4.4" ry="2.6"/><ellipse cx="11" cy="13" rx="1.8" ry="1"/><path d="M17.6 14.6c1.3 1.2 1.8 2.6 1.6 4.4M19.2 19l-1.3 1.3M19.2 19l.5 1.6M19.2 19l1.4.4"/>',
  pouch: '<path d="M8.5 7.5h7l-1.4-3H9.9z"/><path d="M8.5 7.5C5 10 4.2 13.2 4.8 16c.6 2.6 3.3 4 7.2 4s6.6-1.4 7.2-4c.6-2.8-.2-6-3.7-8.5"/><path d="M9 7.5c1 .8 5 .8 6 0" stroke="#a8372f"/>',
};
function iconFor(it) {
  const s = `${it.id || ''} ${it.label || ''}`.toLowerCase();
  if (/떡|cake|tteok/.test(s)) return 'cake';
  if (/기름|oil/.test(s)) return 'oil';
  if (/횃불|torch/.test(s)) return 'torch';
  if (/줄|rope/.test(s)) return 'rope';
  return 'pouch';
}
const svg = (inner, cls = '') => `<svg class="${cls}" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${inner}</svg>`;

// 결이 거친 한지 가장자리: 결정적 난수로 clip-path polygon 생성
function deckle(seed = 7, n = 34, amp = 0.55) {
  let s = seed >>> 0;
  const rnd = () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
  const j = () => (rnd() * amp).toFixed(2);
  const pts = [];
  for (let i = 0; i < n; i++) pts.push(`${(i / n * 100).toFixed(2)}% ${j()}%`);
  for (let i = 0; i < n; i++) pts.push(`${(100 - j()).toFixed(2)}% ${(i / n * 100).toFixed(2)}%`);
  for (let i = 0; i < n; i++) pts.push(`${(100 - i / n * 100).toFixed(2)}% ${(100 - j()).toFixed(2)}%`);
  for (let i = 0; i < n; i++) pts.push(`${j()}% ${(100 - i / n * 100).toFixed(2)}%`);
  return `polygon(${pts.join(',')})`;
}

const el = (tag, cls, html) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html != null) e.innerHTML = html;
  return e;
};
const esc = (t) => String(t ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const paras = (t) => String(t ?? '').split(/\n{1,}/).filter(Boolean).map((p) => `<p>${esc(p)}</p>`).join('');
const reduced = () => window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

export function createUI(root) {
  const layer = el('div', 'sui');
  layer.innerHTML = `
    <div class="sui-lb" aria-hidden="true"><i class="sui-lb-top"></i><i class="sui-lb-bot"></i></div>
    <div class="sui-caption" aria-live="polite"><span></span></div>
    <div class="sui-toasts" role="status" aria-live="polite"></div>
    <ul class="sui-items" aria-label="소지품" hidden></ul>
    <button type="button" class="sui-jbtn" aria-label="사건 기록 열기">기록</button>`;
  root.appendChild(layer);
  const $ = (s) => layer.querySelector(s);
  const toastsEl = $('.sui-toasts');
  const itemsEl = $('.sui-items');
  const capEl = $('.sui-caption');
  const capText = capEl.firstElementChild;
  const jbtn = $('.sui-jbtn');

  const stack = []; // 열린 모달 { kind, el, onKey(e) → bool, close() }
  let journal = null; // 열린 사건 기록 모달
  let provider = null;

  // ---- 공통 모달 ----
  function pushModal(m) {
    m.prevFocus = document.activeElement;
    m.armedAt = performance.now() + ARM_MS;
    stack.push(m);
    layer.appendChild(m.el);
    layer.classList.add('modal');
    requestAnimationFrame(() => m.el.classList.add('in'));
  }
  function popModal(m) {
    const i = stack.indexOf(m);
    if (i < 0) return;
    stack.splice(i, 1);
    m.el.classList.remove('in');
    m.el.classList.add('out');
    const rm = () => m.el.remove();
    if (reduced()) rm(); else setTimeout(rm, 220);
    layer.classList.toggle('modal', stack.length > 0);
    const top = stack[stack.length - 1];
    if (top?.focus) top.focus();
    else if (m.prevFocus && m.prevFocus.isConnected && m.prevFocus !== document.body) m.prevFocus.focus?.({ preventScroll: true });
    else document.activeElement?.blur?.();
  }

  // 모달이 열려 있으면 키를 먼저 가로채 코어 입력으로 새지 않게 한다(캡처 단계)
  window.addEventListener('keydown', (e) => {
    const top = stack[stack.length - 1];
    if (!top) return;
    if (e.target?.closest?.('.panel')) return; // 검증 패널 조작은 그대로
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    const handled = top.onKey(e);
    // 모달 중에는 이동/행동 키가 코어로 가지 않게 막는다
    e.stopImmediatePropagation();
    if (handled !== false) e.preventDefault();
  }, true);

  const armed = (m, e) => !e.repeat && performance.now() >= m.armedAt;

  // ---- 알림 띠 ----
  function toast(text, kind = 'info') {
    const k = KIND[kind] || KIND.info;
    const t = el('div', `sui-toast k-${KIND[kind] ? kind : 'info'}`,
      `<span class="sui-seal" aria-hidden="true">${k.seal}</span><span class="sui-toast-kind">${k.label}</span><span class="sui-toast-text">${esc(text)}</span>`);
    toastsEl.appendChild(t);
    const all = [...toastsEl.querySelectorAll('.sui-toast:not(.out)')];
    while (all.length > 3) hide(all.shift());
    requestAnimationFrame(() => t.classList.add('in'));
    const ms = Math.min(6500, 2600 + String(text).length * 45);
    t._timer = setTimeout(() => hide(t), ms);
    t.addEventListener('click', () => hide(t));
    function hide(n) {
      if (n.classList.contains('out')) return;
      clearTimeout(n._timer);
      n.classList.add('out');
      setTimeout(() => n.remove(), reduced() ? 0 : 320);
    }
  }

  // ---- 조사 카드 ----
  function examine({ title = '', text = '', kind = 'clue' } = {}) {
    return new Promise((resolve) => {
      const k = KIND[kind] || KIND.clue;
      const wrap = el('div', 'sui-scrim sui-examine', `
        <div class="sx-shadow">
          <article class="sx-card" role="dialog" aria-modal="true" aria-labelledby="sx-title">
            <span class="sx-frame" aria-hidden="true"></span>
            <span class="sx-corner tl" aria-hidden="true"></span><span class="sx-corner br" aria-hidden="true"></span>
            <header class="sx-head"><span class="sui-seal k-${KIND[kind] ? kind : 'clue'}" aria-hidden="true">${k.seal}</span><span class="sx-kind">${k.label}</span></header>
            <h2 class="sx-title" id="sx-title">${esc(title)}</h2>
            <div class="sx-text">${paras(text)}</div>
            <button type="button" class="sui-btn sx-ok">확인</button>
          </article>
        </div>`);
      const card = wrap.querySelector('.sx-card');
      card.style.clipPath = deckle(title.length * 31 + 11);
      const ok = wrap.querySelector('.sx-ok');
      const m = {
        kind: 'examine', el: wrap,
        focus: () => ok.focus({ preventScroll: true }),
        onKey: (e) => {
          if ((CONFIRM.has(e.code) || CANCEL.has(e.code)) && armed(m, e)) { done(); return true; }
          if (e.code === 'Tab') return true;
          return true;
        },
      };
      const done = () => { popModal(m); resolve(); };
      wrap.addEventListener('click', () => { if (performance.now() >= m.armedAt) done(); });
      pushModal(m);
      m.focus();
    });
  }

  // ---- 선택지 ----
  function choice(prompt, options = []) {
    return new Promise((resolve) => {
      const opts = options.map((o) => (typeof o === 'string' ? { label: o } : o || {}));
      const wrap = el('div', 'sui-scrim sui-choice');
      const box = el('div', 'sc-box');
      box.setAttribute('role', 'dialog');
      box.setAttribute('aria-modal', 'true');
      box.innerHTML = `${prompt ? `<p class="sc-prompt" id="sc-prompt">${esc(prompt)}</p>` : ''}<ol class="sc-list" role="listbox" ${prompt ? 'aria-labelledby="sc-prompt"' : 'aria-label="선택"'}></ol>
        <p class="sc-keys" aria-hidden="true">↑↓ 고르기 · E 결정${opts.some((o) => o.cancel) ? ' · Esc 그만두기' : ''}</p>`;
      wrap.appendChild(box);
      const list = box.querySelector('.sc-list');
      const btns = opts.map((o, i) => {
        const li = el('li');
        const b = el('button', `sc-opt${o.disabled ? ' off' : ''}`,
          `<span class="sc-mark" aria-hidden="true"></span><span class="sc-label">${esc(o.label)}</span>${o.disabled && o.hint ? `<small class="sc-hint">${esc(o.hint)}</small>` : ''}`);
        b.type = 'button';
        b.setAttribute('role', 'option');
        if (o.disabled) b.setAttribute('aria-disabled', 'true');
        b.addEventListener('click', (e) => { e.stopPropagation(); if (!o.disabled && performance.now() >= m.armedAt) pick(i); });
        b.addEventListener('pointerenter', () => { if (!o.disabled) sel(i); });
        li.appendChild(b);
        list.appendChild(li);
        return b;
      });
      let cur = opts.findIndex((o) => !o.disabled);
      const sel = (i) => {
        cur = i;
        btns.forEach((b, j) => { b.classList.toggle('cur', j === i); b.setAttribute('aria-selected', j === i ? 'true' : 'false'); });
        btns[i]?.focus({ preventScroll: false });
      };
      const step = (d) => {
        if (!btns.length) return;
        let i = cur;
        for (let n = 0; n < btns.length; n++) {
          i = (i + d + btns.length) % btns.length;
          if (!opts[i].disabled) { sel(i); return; }
        }
      };
      const cancelIdx = opts.findIndex((o) => o.cancel);
      const m = {
        kind: 'choice', el: wrap,
        focus: () => btns[cur]?.focus({ preventScroll: true }),
        onKey: (e) => {
          const c = e.code;
          if (c === 'ArrowUp' || c === 'KeyW' || (c === 'Tab' && e.shiftKey)) step(-1);
          else if (c === 'ArrowDown' || c === 'KeyS' || c === 'Tab') step(1);
          else if (CONFIRM.has(c)) { if (armed(m, e) && cur >= 0) pick(cur); }
          else if (CANCEL.has(c)) { if (cancelIdx >= 0 && armed(m, e)) pick(cancelIdx); }
          else if (/^(Digit|Numpad)[1-9]$/.test(c)) {
            const i = +c.slice(-1) - 1;
            if (opts[i] && !opts[i].disabled && armed(m, e)) pick(i);
          }
          return true;
        },
      };
      const pick = (i) => { popModal(m); resolve(i); };
      wrap.addEventListener('click', (e) => { if (e.target === wrap && cancelIdx >= 0 && performance.now() >= m.armedAt) pick(cancelIdx); });
      pushModal(m);
      if (cur >= 0) sel(cur);
      else box.tabIndex = -1, box.focus();
    });
  }

  // ---- 사건 기록 ----
  const statusOf = (c) => (SOLVED.has(String(c.status || '').toLowerCase()) || SOLVED.has(c.status) ? 'solved' : 'active');
  function journalOpen(data) {
    const cases = (data && data.cases) || [];
    if (journal) { journal.render(cases); return; }
    const wrap = el('div', 'sui-scrim sui-journal');
    wrap.innerHTML = `
      <div class="sj-book" role="dialog" aria-modal="true" aria-label="사건 기록">
        <span class="sj-stitch" aria-hidden="true"><i></i><i></i><i></i><i></i></span>
        <nav class="sj-page sj-left" aria-label="사건 목록">
          <h2 class="sj-head"><span class="sj-head-seal" aria-hidden="true">錄</span>사건 기록</h2>
          <ul class="sj-cases" data-sec="0" tabindex="-1"></ul>
          <p class="sj-keys" aria-hidden="true">←→ 쪽 넘기기 · ↑↓ 읽기 · R / Esc 닫기</p>
        </nav>
        <div class="sj-page sj-right" tabindex="-1"><div class="sj-content"></div></div>
        <button type="button" class="sj-close" aria-label="사건 기록 닫기">닫기</button>
      </div>`;
    const casesEl = wrap.querySelector('.sj-cases');
    const right = wrap.querySelector('.sj-right');
    const content = wrap.querySelector('.sj-content');
    let list = [];
    let curId = null;
    let sec = 0; // 0 = 사건 목록, 1.. = 오른쪽 쪽의 절
    const secs = () => [casesEl, ...content.querySelectorAll('.sj-sec')];

    function renderCase() {
      const c = list.find((x) => x.id === curId);
      if (!c) { content.innerHTML = '<p class="sj-empty">아직 기록된 사건이 없다.</p>'; return; }
      const st = statusOf(c);
      const clues = c.clues || [], rules = c.rules || [], sols = c.solutions || [];
      const known = sols.filter((s) => s.available).length;
      content.innerHTML = `
        <header class="sj-case-head">
          <h3 class="sj-title">「${esc(c.title)}」</h3>
          <span class="sj-status s-${st}">${st === 'solved' ? '해결' : '진행 중'}</span>
        </header>
        <section class="sj-sec sj-summary" tabindex="0" aria-label="경위">${(c.summary || []).map((p, i, a) => `<p${i === a.length - 1 ? ' class="new"' : ''}>${esc(p)}</p>`).join('') || '<p class="sj-empty">—</p>'}</section>
        <section class="sj-sec" tabindex="0" aria-labelledby="sj-h-clue">
          <h4 id="sj-h-clue"><span class="sui-seal k-clue" aria-hidden="true">證</span>단서 <small>${clues.length}</small></h4>
          ${clues.length ? `<ul class="sj-list">${clues.map((x) => `<li><b>${esc(x.title)}</b>${x.text ? `<span>${esc(x.text)}</span>` : ''}</li>`).join('')}</ul>` : '<p class="sj-empty">아직 찾은 단서가 없다.</p>'}
        </section>
        <section class="sj-sec" tabindex="0" aria-labelledby="sj-h-rule">
          <h4 id="sj-h-rule"><span class="sui-seal k-rule" aria-hidden="true">理</span>알아낸 규칙 <small>${rules.length}</small></h4>
          ${rules.length ? `<ul class="sj-list">${rules.map((x) => `<li><b>${esc(x.title)}</b>${x.text ? `<span>${esc(x.text)}</span>` : ''}</li>`).join('')}</ul>` : '<p class="sj-empty">아직 알아낸 규칙이 없다.</p>'}
        </section>
        <section class="sj-sec" tabindex="0" aria-labelledby="sj-h-sol">
          <h4 id="sj-h-sol"><span class="sui-seal k-journal" aria-hidden="true">策</span>가능한 해결 방법 <small>${known} / ${sols.length}</small></h4>
          ${sols.length ? `<ul class="sj-list sj-sols">${sols.map((x) => (x.available
            ? `<li class="ok"><b>${esc(x.title)}</b>${x.text ? `<span>${esc(x.text)}</span>` : ''}</li>`
            : `<li class="unknown"><b>아직 모른다</b>${x.hint ? `<span>${esc(x.hint)}</span>` : ''}</li>`)).join('')}</ul>` : '<p class="sj-empty">아직 모른다.</p>'}
        </section>`;
    }
    function renderList() {
      casesEl.innerHTML = list.map((c) => {
        const st = statusOf(c);
        return `<li><button type="button" class="sj-case${c.id === curId ? ' cur' : ''}" data-id="${esc(c.id)}" aria-current="${c.id === curId}">
          <span class="sj-case-t">${esc(c.title)}</span><span class="sj-mini s-${st}">${st === 'solved' ? '해결' : '진행 중'}</span></button></li>`;
      }).join('') || '<li class="sj-empty">—</li>';
      casesEl.querySelectorAll('.sj-case').forEach((b) => b.addEventListener('click', () => { choose(b.dataset.id); }));
    }
    function choose(id) {
      curId = id;
      renderList();
      renderCase();
      right.scrollTop = 0;
      if (sec === 0) casesEl.querySelector('.sj-case.cur')?.focus({ preventScroll: true });
    }
    function render(cs) {
      list = cs;
      if (!list.some((c) => c.id === curId)) curId = (list.find((c) => statusOf(c) === 'active') || list[0])?.id ?? null;
      const top = right.scrollTop;
      renderList();
      renderCase();
      right.scrollTop = top;
    }
    function focusSec(i) {
      const s = secs();
      sec = (i + s.length) % s.length;
      if (sec === 0) (casesEl.querySelector('.sj-case.cur') || casesEl).focus({ preventScroll: true });
      else {
        const t = s[sec];
        t.focus({ preventScroll: true });
        const top = t.offsetTop - 12;
        right.scrollTo({ top, behavior: reduced() ? 'auto' : 'smooth' });
        // 한 쪽 보기(휴대폰)에서는 바깥 책 전체가 스크롤된다
        if (right.scrollHeight <= right.clientHeight + 2) t.scrollIntoView({ block: 'start', behavior: reduced() ? 'auto' : 'smooth' });
      }
    }
    function moveCase(d) {
      const i = list.findIndex((c) => c.id === curId);
      const n = list[(i + d + list.length) % list.length];
      if (n) choose(n.id);
    }
    const scroller = () => (right.scrollHeight > right.clientHeight + 2 ? right : wrap.querySelector('.sj-book'));
    const m = {
      kind: 'journal', el: wrap, render,
      focus: () => focusSec(sec),
      onKey: (e) => {
        const c = e.code;
        if (c === 'Escape' || c === 'KeyX' || c === 'KeyR') { if (!e.repeat) journalClose(); return true; }
        if (c === 'ArrowRight' || c === 'KeyD' || (c === 'Tab' && !e.shiftKey)) focusSec(sec + 1);
        else if (c === 'ArrowLeft' || c === 'KeyA' || (c === 'Tab' && e.shiftKey)) focusSec(sec - 1);
        else if (c === 'ArrowUp' || c === 'KeyW' || c === 'ArrowDown' || c === 'KeyS') {
          const d = (c === 'ArrowUp' || c === 'KeyW') ? -1 : 1;
          if (sec === 0) moveCase(d);
          else scroller().scrollBy({ top: d * 80, behavior: reduced() ? 'auto' : 'smooth' });
        } else if (c === 'PageDown' || c === 'PageUp') {
          const s = scroller();
          s.scrollBy({ top: (c === 'PageDown' ? 1 : -1) * s.clientHeight * 0.85 });
        } else if (CONFIRM.has(c)) {
          if (document.activeElement?.classList.contains('sj-close')) journalClose();
          else if (sec === 0) focusSec(1);
        }
        return true;
      },
    };
    wrap.querySelector('.sj-close').addEventListener('click', () => journalClose());
    wrap.addEventListener('click', (e) => { if (e.target === wrap) journalClose(); });
    content.addEventListener('focusin', (e) => {
      const s = secs().indexOf(e.target.closest('.sj-sec'));
      if (s > 0) sec = s;
    });
    casesEl.addEventListener('focusin', () => { sec = 0; });
    journal = m;
    render(cases);
    pushModal(m);
    focusSec(0);
  }
  function journalClose() {
    if (!journal) return;
    const m = journal;
    journal = null;
    popModal(m);
  }
  function journalToggle(dataProvider) {
    if (dataProvider) provider = dataProvider;
    if (journal) { journalClose(); return false; }
    const data = typeof provider === 'function' ? provider() : provider;
    journalOpen(data || { cases: [] });
    return true;
  }
  jbtn.addEventListener('click', () => {
    if (provider) journalToggle();
    else root.dispatchEvent(new CustomEvent('ui:journal', { bubbles: true }));
  });

  // ---- 자막 ----
  let capTimer = null, capResolve = null;
  function caption(text, ms = 3200) {
    if (capResolve) { clearTimeout(capTimer); capResolve(); capResolve = null; }
    return new Promise((resolve) => {
      capResolve = resolve;
      capText.textContent = text || '';
      capEl.classList.remove('show');
      void capEl.offsetWidth;
      capEl.classList.add('show');
      capTimer = setTimeout(() => {
        capEl.classList.remove('show');
        capTimer = setTimeout(() => { if (capResolve === resolve) { capResolve = null; resolve(); } }, reduced() ? 0 : 380);
      }, Math.max(400, ms));
    });
  }

  // ---- 레터박스 ----
  function letterbox(on) {
    layer.classList.toggle('lb', !!on);
    document.body.classList.toggle('ui-letterbox', !!on);
    return new Promise((r) => setTimeout(r, reduced() ? 0 : 600));
  }

  // ---- 종결 카드 ----
  function ending({ title = '', paragraphs = [], outcome = '', record } = {}) {
    return new Promise((resolve) => {
      const label = OUTCOME[outcome] || OUTCOME[String(outcome).toLowerCase()] || outcome || '종결';
      const key = OUTCOME_KEY[label] || 'other';
      const ps = [...(paragraphs || [])];
      // 마지막 사건 기록 한 줄: record 필드, 없으면 문단이 둘 이상일 때 마지막 문단
      const last = record ?? (ps.length > 1 ? ps.pop() : null);
      const wrap = el('div', 'sui-scrim sui-ending');
      wrap.dataset.outcome = key;
      wrap.innerHTML = `
        <div class="se-page" role="dialog" aria-modal="true" aria-labelledby="se-title">
          <div class="se-inner">
            <p class="se-case">사건 종결</p>
            <span class="se-seal" aria-label="결말: ${esc(label)}">${esc(label)}</span>
            <h2 class="se-title" id="se-title">${esc(title)}</h2>
            <div class="se-text">${ps.map((p) => `<p>${esc(p)}</p>`).join('')}</div>
            ${last ? `<div class="se-record"><span class="se-record-k"><span class="sui-seal k-journal" aria-hidden="true">錄</span>사건 기록</span><p>${esc(last)}</p></div>` : ''}
            <button type="button" class="sui-btn se-retry">다시 하기</button>
          </div>
        </div>`;
      const btn = wrap.querySelector('.se-retry');
      const m = {
        kind: 'ending', el: wrap,
        focus: () => btn.focus({ preventScroll: true }),
        onKey: (e) => {
          if (CONFIRM.has(e.code) && armed(m, e)) { done(); return true; }
          const page = wrap.querySelector('.se-page');
          if (e.code === 'ArrowDown' || e.code === 'ArrowUp') page.scrollBy({ top: (e.code === 'ArrowDown' ? 80 : -80) });
          return true;
        },
      };
      const done = () => { popModal(m); resolve('restart'); };
      btn.addEventListener('click', () => { if (performance.now() >= m.armedAt) done(); });
      pushModal(m);
      m.armedAt = performance.now() + 900; // 결말을 실수로 건너뛰지 않게
      m.focus();
    });
  }

  // ---- 소지품 ----
  let lastItems = {};
  function items(list = []) {
    const vis = (list || []).filter((it) => it && (it.count == null || it.count > 0));
    itemsEl.hidden = vis.length === 0;
    const next = {};
    itemsEl.innerHTML = vis.map((it) => {
      const id = it.id ?? it.label;
      const n = it.count ?? 1;
      next[id] = n;
      const changed = lastItems[id] !== n ? ' pop' : '';
      return `<li class="sui-item${changed}" title="${esc(it.label)}${n > 1 ? ` ×${n}` : ''}">${svg(ICONS[iconFor(it)], 'sui-ico')}<span class="sui-item-l">${esc(it.label)}</span>${n > 1 ? `<span class="sui-item-n">×${n}</span>` : ''}</li>`;
    }).join('');
    lastItems = next;
  }

  return {
    toast, examine, choice, journalOpen, journalClose, journalToggle, caption, letterbox, ending, items,
    setJournalProvider(fn) { provider = fn; },
    get isModal() { return stack.length > 0; },
    get journalOpenNow() { return !!journal; },
    el: layer,
  };
}
