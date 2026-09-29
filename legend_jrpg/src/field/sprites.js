// 캐릭터·NPC·오브젝트 픽셀아트 (fillRect로 그리고 자동 외곽선)
// 프레임 캔버스 크기 40x44. 타일 좌상단 (px,py)에 대해 (px-4, py-10)에 그린다.
// pose: 0=서기, 1=걸음A, 2=걸음B

export const SPRITE_W = 40;
export const SPRITE_H = 44;
const DX = -4, DY = -10;
const OUTLINE = '#1c1424';

// ---------------------------------------------------------------
// 색 도우미
// ---------------------------------------------------------------
function shade(hex, k) {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
  if (!m) return hex;
  const n = parseInt(m[1], 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  if (k >= 0) { r += (255 - r) * k; g += (255 - g) * k; b += (255 - b) * k; }
  else { r *= 1 + k; g *= 1 + k; b *= 1 + k; }
  const h = (v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0');
  return `#${h(r)}${h(g)}${h(b)}`;
}

function painter(g, ox, oy) {
  return (x, y, w, h, c) => { if (!c) return; g.fillStyle = c; g.fillRect(ox + x, oy + y, w, h); };
}

// ---------------------------------------------------------------
// 사람형 스프라이트 사양
// ---------------------------------------------------------------
// hairStyle: short|spiky|long|ponytail|bun|bald|none
// hat: {type:'witch'|'hood'|'helmet'|'bandana'|'turban'|'circlet'|'horns'|'hornHelm', color, band?, plume?}
const SPECS = {
  ren: { hair: '#7a4a24', hairStyle: 'spiky', top: '#3f7ee8', bottom: '#6b4a2e', shoe: '#4a2e17', belt: '#e8d8b0', scarf: '#e03131', backSword: true },
  mia: { hair: '#f5d36a', hairStyle: 'long', robe: '#f8f4ea', top: '#f8f4ea', trim: '#e0b040', eyes: '#2f6fb0', hat: { type: 'circlet', color: '#e0b040' } },
  garen: { hair: '#4a5568', hairStyle: 'short', top: '#c3c9d4', bottom: '#4a5060', shoe: '#2f3440', armor: '#e2e6ee', cape: '#3355aa', eyes: '#2a2a38' },
  sela: { hair: '#2e1f47', hairStyle: 'long', robe: '#7b3fc4', top: '#7b3fc4', trim: '#f0c14a', eyes: '#8a2be2', hat: { type: 'witch', color: '#5a2a9a', band: '#f0c14a' } },
  elder: { hair: '#e9ecef', hairStyle: 'bald', beard: '#f1f3f5', robe: '#8a6a4a', top: '#8a6a4a', trim: '#d9b36a', eyeStyle: 'closed' },
  lina: { hair: '#d9642b', hairStyle: 'ponytail', top: '#5fb86a', robe: '#5fb86a', trim: '#ffffff', eyes: '#3a7a3a', apron: '#fff9ef' },
  villager_m: { hair: '#6b4a2e', hairStyle: 'short', top: '#7aa65a', bottom: '#6b5a40' },
  villager_f: { hair: '#4a3020', hairStyle: 'bun', top: '#e38aa8', robe: '#e38aa8', trim: '#fff', apron: '#fff4e0' },
  child: { hair: '#c9822e', hairStyle: 'spiky', top: '#f0a030', bottom: '#4a6fa5', scale: 0.8 },
  merchant: { hair: '#3a2a1a', hairStyle: 'short', top: '#d9822b', bottom: '#5a4030', mustache: '#3a2a1a', hat: { type: 'turban', color: '#2f9e6e' } },
  innkeeper: { hair: '#b8452e', hairStyle: 'bun', top: '#8a5ab0', robe: '#8a5ab0', trim: '#fff', apron: '#ffffff' },
  blacksmith: { hair: '#3a2a20', hairStyle: 'bald', skin: '#e8b48a', beard: '#3a2a20', top: '#5a5a62', bottom: '#3f3a36', apron: '#7a4f28' },
  soldier: { hair: '#4a3020', hairStyle: 'none', top: '#b83a3a', bottom: '#5a4a3a', armor: '#b8bec8', hat: { type: 'helmet', color: '#b8bec8', plume: '#e03131' } },
  priest: { hair: '#8a8a8a', hairStyle: 'short', robe: '#ffffff', top: '#ffffff', trim: '#3a7bd5', hat: { type: 'hood', color: '#dfe6f5' } },
  sailor: { hair: '#3a2a1a', hairStyle: 'short', skin: '#e8b48a', top: '#f8f9fa', stripes: '#3a6fd5', bottom: '#2c4f85', hat: { type: 'bandana', color: '#3a6fd5' } },
  mage: { hair: '#8a8a9a', hairStyle: 'long', robe: '#2f5bb0', top: '#2f5bb0', trim: '#f0c14a', beard: '#d0d0da', hat: { type: 'witch', color: '#2a4a9a', band: '#f0c14a' } },
  old_man: { hair: '#bfc3c8', hairStyle: 'bald', beard: '#dfe3e8', top: '#8a8070', bottom: '#5a5448', eyeStyle: 'closed' },
  goblin: { skin: '#7cbf4a', hairStyle: 'none', top: '#8a6a3a', bottom: '#5a4028', ears: true, eyes: '#e03131', scale: 0.85 },
  lich: { skin: '#ebe6d6', face: 'skull', hairStyle: 'none', robe: '#3b2a5a', top: '#3b2a5a', trim: '#b197fc', hat: { type: 'hood', color: '#2b1d45' }, eyes: '#ff4040' },
  vorg: { skin: '#8a5a4a', hairStyle: 'none', top: '#6b2424', bottom: '#2f2f38', shoe: '#1f1f24', armor: '#4a4a56', cape: '#1f1f28', eyeStyle: 'glow', eyes: '#ffd43b', hat: { type: 'hornHelm', color: '#4a4a56' }, scale: 1.18 },
  demon_king: { skin: '#9aa0b8', hair: '#15121c', hairStyle: 'long', robe: '#1f1426', top: '#2a1a33', trim: '#e03131', cape: '#8a1020', eyeStyle: 'glow', eyes: '#ff3030', hat: { type: 'horns', color: '#e9e4d4' }, scale: 1.1 },
};
const FALLBACK = { hair: '#5a4030', hairStyle: 'short', top: '#9a8a6a', bottom: '#5a4a3a' };

// ---------------------------------------------------------------
// 사람형 그리기 (dir: down|up|left)
// ---------------------------------------------------------------
function humanoid(g, s, dir, pose) {
  const r = painter(g, 8, 12);
  const skin = s.skin || '#ffd9b3', skinD = shade(skin, -0.14);
  const hair = s.hair || '#6b4423', hairD = shade(hair, -0.28), hairL = shade(hair, 0.28);
  const top = s.top || '#7a8aa0', topD = shade(top, -0.25), topL = shade(top, 0.22);
  const bottom = s.bottom || '#5a4a3a', shoe = s.shoe || '#4a3020';
  const eye = s.eyes || '#2a2238';
  const robe = s.robe, robeD = robe && shade(robe, -0.2);
  const side = dir === 'left';

  // ---- 망토 (등 뒤) ----
  if (s.cape && dir === 'down') { r(5, 16, 1, 10, s.cape); r(18, 16, 1, 10, s.cape); }
  if (s.cape && side) { r(14, 15, 4, 12, s.cape); r(17, 17, 1, 10, shade(s.cape, -0.3)); }
  // 긴 머리(뒤)
  if (s.hairStyle === 'long' && dir === 'down') { r(4, 6, 3, 12, hair); r(17, 6, 3, 12, hair); r(4, 16, 3, 2, hairD); r(17, 16, 3, 2, hairD); }

  // ---- 다리 / 치마 ----
  if (robe) {
    const hem = s.trim || robeD;
    if (side) {
      const fx = pose === 1 ? 6 : pose === 2 ? 9 : 7;
      r(fx, 27, 4, 2, shoe); r(fx + 5, pose === 2 ? 26 : 27, 3, 2, shoe);
      r(7, 21, 10, 6, robe); r(13, 21, 4, 6, robeD); r(7 + (pose === 1 ? -1 : 0), 26, 10, 1, hem);
    } else {
      r(8, pose === 1 ? 26 : 27, 3, 2, shoe); r(13, pose === 2 ? 26 : 27, 3, 2, shoe);
      r(6, 21, 12, 6, robe); r(6, 21, 2, 6, robeD); r(16, 21, 2, 6, robeD);
      r(6 + (pose === 1 ? -1 : pose === 2 ? 1 : 0), 26, 12, 1, hem);
    }
  } else if (side) {
    let a = [9, 23, 4], b = [12, 23, 4];
    if (pose === 1) { a = [7, 23, 4]; b = [13, 23, 3]; }
    if (pose === 2) { a = [10, 23, 4]; b = [11, 23, 3]; }
    r(b[0], b[1], 3, b[2], shade(bottom, -0.2)); r(b[0] - 1, b[1] + b[2], 4, 2, shade(shoe, -0.2));
    r(a[0], a[1], 3, a[2], bottom); r(a[0] - 1, a[1] + a[2], 4, 2, shoe);
  } else {
    const lh = pose === 1 ? 3 : 4, rh = pose === 2 ? 3 : 4;
    r(8, 23, 3, lh, bottom); r(8, 23 + lh, 3, 2, shoe);
    r(13, 23, 3, rh, bottom); r(13, 23 + rh, 3, 2, shoe);
  }

  // ---- 몸통 ----
  if (side) {
    r(8, 15, 8, 8, top); r(13, 15, 3, 8, topD); r(8, 15, 8, 1, topL);
    if (s.stripes) { r(8, 17, 8, 1, s.stripes); r(8, 19, 8, 1, s.stripes); }
    if (!robe) r(8, 21, 8, 1, s.belt || shade(bottom, -0.3));
    if (s.apron) r(7, 17, 3, 8, s.apron);
    if (s.armor) { r(10, 15, 5, 3, s.armor); r(10, 15, 5, 1, '#ffffff'); }
    if (s.scarf) { r(8, 14, 7, 2, s.scarf); r(14, 15, 3, 3, s.scarf); }
  } else {
    r(7, 15, 10, 8, top); r(7, 15, 10, 1, topL); r(15, 16, 2, 7, topD);
    if (s.stripes) { r(7, 17, 10, 1, s.stripes); r(7, 19, 10, 1, s.stripes); }
    if (!robe) r(7, 21, 10, 1, s.belt || shade(bottom, -0.3));
    if (robe && s.trim && dir === 'down') { r(11, 15, 2, 6, s.trim); }
    if (s.apron && dir === 'down') { r(8, 17, 8, 8, s.apron); r(9, 15, 1, 2, s.apron); r(14, 15, 1, 2, s.apron); }
    if (s.armor) {
      r(4, 15, 4, 3, s.armor); r(16, 15, 4, 3, s.armor); r(4, 15, 4, 1, '#ffffff'); r(16, 15, 4, 1, '#ffffff');
      if (dir === 'down') { r(9, 16, 6, 4, s.armor); r(9, 16, 2, 1, '#ffffff'); }
    }
    if (s.scarf && dir === 'down') { r(7, 14, 10, 2, s.scarf); r(13, 16, 2, 3, s.scarf); }
    if (s.scarf && dir === 'up') { r(7, 14, 10, 2, s.scarf); }
    if (s.cape && dir === 'up') { r(6, 15, 12, 11, s.cape); r(6, 15, 12, 1, shade(s.cape, 0.2)); r(8, 18, 1, 7, shade(s.cape, -0.25)); r(15, 18, 1, 7, shade(s.cape, -0.25)); }
    if (s.backSword && dir === 'up') { r(14, 10, 2, 13, '#ced4da'); r(15, 10, 1, 13, '#8a94a0'); r(12, 13, 6, 2, '#ffd43b'); }
  }

  // ---- 팔 ----
  const sleeve = robe || top;
  if (side) {
    let ax = 11, ay = 16, hx = 11, hy = 21;
    if (pose === 1) { ax = 9; hx = 8; hy = 20; }
    if (pose === 2) { ax = 13; hx = 14; hy = 20; }
    r(ax, ay, 3, 5, shade(sleeve, -0.1)); r(hx, hy, 3, 2, skin);
  } else {
    const la = pose === 1 ? 5 : 6, ra = pose === 2 ? 5 : 6;
    r(5, 15, 2, la, sleeve); r(5, 15 + la, 2, 2, skin);
    r(17, 15, 2, ra, shade(sleeve, -0.12)); r(17, 15 + ra, 2, 2, skin);
    if (s.armor) { r(4, 15, 4, 3, s.armor); r(16, 15, 4, 3, s.armor); r(4, 15, 4, 1, '#fff'); r(16, 15, 4, 1, '#fff'); }
  }

  // ---- 머리 ----
  const st = s.hairStyle || 'short';
  if (dir === 'up') {
    if (st === 'bald' || st === 'none') {
      r(5, 2, 14, 12, skin); r(5, 12, 14, 2, skinD);
      if (st === 'bald') { r(5, 7, 2, 5, hair); r(17, 7, 2, 5, hair); r(6, 11, 12, 3, hair); }
    } else {
      r(5, 1, 14, 13, hair); r(6, 13, 12, 1, hairD); r(8, 2, 6, 1, hairL); r(10, 6, 1, 6, hairD);
      if (st === 'long') { r(4, 6, 16, 12, hair); r(5, 16, 14, 2, hairD); r(12, 8, 1, 8, hairD); }
      if (st === 'ponytail') { r(10, 12, 4, 7, hair); r(11, 18, 2, 1, hairD); r(10, 11, 4, 1, '#e03131'); }
    }
    if (s.ears) { r(3, 7, 2, 3, skin); r(19, 7, 2, 3, skin); }
  } else if (side) {
    r(5, 3, 11, 11, skin); r(6, 13, 9, 1, skinD); r(4, 9, 1, 2, skin);
    if (s.face === 'skull') {
      r(6, 8, 3, 3, '#1a1020'); r(7, 9, 1, 1, eye); r(5, 12, 4, 1, '#1a1020'); r(6, 12, 1, 1, skin);
    } else if (s.eyeStyle === 'glow') {
      r(6, 9, 3, 2, eye);
    } else if (s.eyeStyle === 'closed') {
      r(6, 10, 3, 1, '#3a2a2a');
    } else {
      r(6, 8, 2, 3, eye); r(6, 8, 1, 1, '#ffffff'); r(8, 12, 1, 1, '#f2a0a0');
    }
    if (s.ears) { r(12, 6, 4, 2, skin); r(15, 5, 2, 2, skin); }
    if (st === 'bald') { r(12, 7, 5, 5, hair); r(9, 3, 3, 1, '#ffffff'); }
    else if (st !== 'none') {
      r(6, 1, 12, 5, hair); r(12, 4, 7, 9, hair); r(5, 4, 4, 3, hair); r(8, 2, 5, 1, hairL); r(13, 12, 6, 1, hairD);
      r(12, 9, 2, 2, skin);
      if (st === 'spiky') { r(9, 0, 3, 1, hair); r(14, -1, 3, 2, hair); r(18, 2, 2, 3, hair); r(4, 3, 2, 2, hair); }
      if (st === 'long') { r(12, 4, 7, 14, hair); r(13, 17, 6, 1, hairD); r(12, 9, 2, 2, skin); }
      if (st === 'ponytail') { r(18, 4, 3, 10, hair); r(19, 13, 2, 2, hairD); r(17, 4, 2, 2, '#e03131'); }
      if (st === 'bun') { r(14, -1, 5, 4, hair); }
    }
    if (s.beard) { r(4, 11, 7, 4, s.beard); r(5, 15, 5, 3, s.beard); }
    if (s.mustache) r(4, 12, 4, 1, s.mustache);
  } else { // down
    r(6, 3, 12, 11, skin); r(7, 13, 10, 1, skinD);
    if (s.ears) { r(3, 7, 3, 2, skin); r(18, 7, 3, 2, skin); r(2, 6, 2, 1, skin); r(20, 6, 2, 1, skin); }
    if (s.face === 'skull') {
      r(8, 8, 3, 3, '#1a1020'); r(13, 8, 3, 3, '#1a1020'); r(9, 9, 1, 1, eye); r(14, 9, 1, 1, eye);
      r(11, 11, 2, 1, '#8a8474'); r(8, 12, 8, 1, '#1a1020'); r(9, 12, 1, 1, skin); r(11, 12, 1, 1, skin); r(13, 12, 1, 1, skin);
    } else if (s.eyeStyle === 'glow') {
      r(8, 9, 3, 2, eye); r(13, 9, 3, 2, eye);
    } else if (s.eyeStyle === 'closed') {
      r(8, 10, 3, 1, '#3a2a2a'); r(13, 10, 3, 1, '#3a2a2a'); r(11, 12, 2, 1, '#b35a5a');
    } else {
      r(8, 8, 2, 3, eye); r(14, 8, 2, 3, eye); r(8, 8, 1, 1, '#ffffff'); r(14, 8, 1, 1, '#ffffff');
      r(11, 12, 2, 1, '#b35a5a'); r(7, 11, 1, 1, '#f2a0a0'); r(16, 11, 1, 1, '#f2a0a0');
    }
    if (st === 'bald') { r(5, 6, 2, 6, hair); r(17, 6, 2, 6, hair); r(9, 4, 4, 1, '#ffffff'); }
    else if (st !== 'none') {
      r(5, 1, 14, 5, hair); r(5, 6, 2, 6, hair); r(17, 6, 2, 6, hair);
      r(7, 6, 3, 1, hair); r(11, 6, 2, 1, hair); r(14, 6, 3, 1, hair); r(8, 2, 5, 1, hairL); r(5, 5, 14, 1, hairD);
      r(7, 5, 3, 2, hair); r(14, 5, 3, 2, hair);
      if (st === 'spiky') { r(6, 0, 2, 1, hair); r(9, -1, 3, 2, hair); r(13, -1, 2, 2, hair); r(16, 0, 2, 1, hair); r(4, 3, 1, 3, hair); r(19, 3, 1, 3, hair); }
      if (st === 'bun') { r(9, -2, 6, 4, hair); r(10, -2, 3, 1, hairL); }
      if (st === 'ponytail') { r(4, 4, 1, 3, hair); r(19, 4, 1, 3, hair); r(18, 2, 2, 2, '#e03131'); }
    }
    if (s.beard) { r(7, 11, 10, 3, s.beard); r(8, 14, 8, 3, s.beard); r(10, 17, 4, 2, s.beard); r(9, 11, 6, 1, shade(s.beard, -0.15)); }
    if (s.mustache) { r(8, 12, 8, 1, s.mustache); r(8, 13, 1, 1, s.mustache); r(15, 13, 1, 1, s.mustache); }
  }

  // ---- 모자 ----
  const hat = s.hat;
  if (hat) {
    const c = hat.color, cD = shade(c, -0.28), cL = shade(c, 0.25);
    switch (hat.type) {
      case 'witch': {
        const tipX = side ? 17 : 15;
        r(1, 4, 22, 2, c); r(3, 6, 18, 1, cD);
        r(7, 0, 10, 4, c); r(8, -3, 8, 3, c); r(10, -6, 5, 3, c); r(12, -8, 4, 2, c); r(tipX, -9, 3, 2, c);
        r(8, -2, 2, 5, cL);
        if (hat.band) r(7, 2, 10, 2, hat.band);
        break;
      }
      case 'hood':
        if (dir === 'up') { r(4, 0, 16, 16, c); r(6, 14, 12, 2, cD); r(11, 2, 2, 12, cD); }
        else if (side) { r(5, 0, 13, 5, c); r(11, 4, 8, 12, c); r(5, 4, 3, 2, c); r(12, 14, 7, 2, cD); }
        else { r(4, 0, 16, 6, c); r(4, 6, 3, 10, c); r(17, 6, 3, 10, c); r(6, 5, 12, 1, cD); r(6, 1, 6, 1, cL); }
        break;
      case 'helmet':
      case 'hornHelm':
        if (dir === 'up') { r(5, 0, 14, 13, c); r(5, 11, 14, 2, cD); r(8, 1, 4, 1, cL); }
        else if (side) { r(5, 0, 14, 6, c); r(13, 5, 6, 8, c); r(5, 5, 8, 1, cD); r(7, 1, 5, 1, cL); }
        else { r(5, 0, 14, 6, c); r(5, 6, 2, 7, c); r(17, 6, 2, 7, c); r(5, 5, 14, 1, cD); r(7, 1, 5, 1, cL); r(11, 5, 2, 3, c); }
        if (hat.plume) { r(10, -4, 4, 5, hat.plume); r(11, -5, 2, 1, hat.plume); }
        if (hat.type === 'hornHelm') {
          const hc = '#e9e4d4';
          if (side) { r(14, -2, 2, 3, hc); r(15, -4, 2, 2, hc); r(16, -6, 2, 2, hc); }
          else { r(3, -1, 2, 3, hc); r(2, -3, 2, 2, hc); r(1, -5, 2, 2, hc); r(19, -1, 2, 3, hc); r(20, -3, 2, 2, hc); r(21, -5, 2, 2, hc); }
        }
        break;
      case 'horns':
        if (side) { r(12, -1, 2, 3, c); r(13, -3, 2, 2, c); r(14, -5, 2, 2, c); }
        else { r(4, -1, 2, 3, c); r(3, -3, 2, 2, c); r(2, -5, 2, 2, c); r(18, -1, 2, 3, c); r(19, -3, 2, 2, c); r(20, -5, 2, 2, c); }
        break;
      case 'bandana':
        if (side) { r(6, 1, 12, 4, c); r(17, 4, 3, 4, c); r(8, 2, 1, 1, '#fff'); r(12, 3, 1, 1, '#fff'); }
        else { r(5, 1, 14, 4, c); r(7, 2, 1, 1, '#fff'); r(11, 3, 1, 1, '#fff'); r(15, 2, 1, 1, '#fff'); if (dir === 'up') r(10, 5, 4, 3, c); else r(19, 3, 2, 3, c); }
        break;
      case 'turban':
        r(4, -1, 16, 6, c); r(6, -2, 12, 1, c); r(4, 2, 16, 1, cD); r(5, 0, 6, 1, cL);
        if (dir === 'down') { r(11, 0, 2, 2, '#e03131'); r(11, 0, 1, 1, '#ffc9c9'); }
        break;
      case 'circlet':
        if (side) r(5, 5, 7, 1, c);
        else if (dir === 'down') { r(6, 5, 12, 1, c); r(11, 4, 2, 2, '#74c0fc'); }
        break;
      default: break;
    }
  }
}

// ---------------------------------------------------------------
// 동물/마물
// ---------------------------------------------------------------
function cat(g, dir, pose) {
  const r = painter(g, 8, 12);
  const c = '#f08c3c', d = '#c96a24', l = '#ffd8a8';
  if (dir === 'left') {
    const k = pose === 1 ? 1 : pose === 2 ? -1 : 0;
    r(19, 13, 2, 9, c); r(20, 11, 2, 3, c);
    r(8, 20, 12, 6, c); r(8, 24, 12, 2, l); r(12, 20, 2, 3, d); r(16, 20, 2, 3, d);
    r(9 + k, 26, 2, 3, c); r(17 - k, 26, 2, 3, c);
    r(3, 14, 8, 8, c); r(3, 12, 2, 3, c); r(8, 12, 2, 3, c); r(4, 13, 1, 1, '#f7a'); r(3, 19, 4, 2, l);
    r(4, 16, 1, 2, '#2b8a3e'); r(2, 18, 1, 1, '#f783ac');
    return;
  }
  const back = dir === 'up';
  r(8, 19, 8, 8, c); r(9, 21, 6, 5, back ? d : l);
  const pl = pose === 1 ? 1 : 0, pr = pose === 2 ? 1 : 0;
  r(8, 27 - pl, 3, 2, c); r(13, 27 - pr, 3, 2, c);
  r(back ? 11 : 16, back ? 23 : 21, 2, back ? 6 : 3, c); if (!back) { r(18, 17, 2, 6, c); r(18, 17, 2, 1, d); }
  r(7, 12, 10, 8, c); r(7, 10, 3, 3, c); r(14, 10, 3, 3, c);
  r(8, 12, 1, 3, d); r(11, 12, 2, 2, d); r(15, 12, 1, 3, d);
  if (!back) {
    r(8, 11, 1, 1, '#f7a'); r(15, 11, 1, 1, '#f7a');
    r(9, 15, 2, 2, '#2b8a3e'); r(13, 15, 2, 2, '#2b8a3e'); r(9, 15, 1, 1, '#fff'); r(13, 15, 1, 1, '#fff');
    r(11, 17, 2, 1, '#f783ac'); r(9, 18, 6, 1, l);
  }
}

function wolf(g, dir, pose) {
  const r = painter(g, 8, 12);
  const c = '#7d8597', d = '#5c6373', l = '#d6dbe3';
  if (dir === 'left') {
    const k = pose === 1 ? 2 : pose === 2 ? -1 : 0;
    r(21, 13, 5, 3, c); r(24, 11, 3, 3, c); r(25, 10, 2, 1, l);
    r(6, 15, 16, 9, c); r(6, 15, 16, 2, d); r(8, 22, 12, 2, l);
    r(7 + k, 24, 3, 5, c); r(11 - k, 24, 2, 5, d); r(17 - k, 24, 3, 5, c); r(20 + k, 24, 2, 5, d);
    r(0, 10, 9, 8, c); r(-3, 14, 4, 4, c); r(-3, 17, 4, 1, l); r(-4, 14, 1, 2, '#1a1a1a');
    r(4, 7, 3, 4, c); r(5, 8, 1, 2, '#f7a'); r(2, 12, 2, 2, '#ffd43b'); r(2, 12, 1, 1, '#1a1a1a');
    r(6, 16, 3, 5, l);
    return;
  }
  if (dir === 'up') {
    r(7, 12, 10, 15, c); r(8, 13, 8, 12, d); r(10, 26, 4, 3, c); r(11, 28, 2, 1, l);
    r(7, 5, 10, 9, c); r(7, 2, 3, 4, c); r(14, 2, 3, 4, c);
    const pl = pose === 1 ? 1 : 0, pr = pose === 2 ? 1 : 0;
    r(6, 25 - pl, 3, 3, c); r(15, 25 - pr, 3, 3, c);
    return;
  }
  r(7, 17, 10, 9, c); r(9, 18, 6, 5, l);
  const pl = pose === 1 ? 1 : 0, pr = pose === 2 ? 1 : 0;
  r(8, 26 - pl, 3, 3, c); r(13, 26 - pr, 3, 3, c);
  r(6, 7, 12, 11, c); r(6, 4, 3, 4, c); r(15, 4, 3, 4, c); r(7, 5, 1, 2, '#f7a'); r(16, 5, 1, 2, '#f7a');
  r(8, 10, 2, 2, '#ffd43b'); r(14, 10, 2, 2, '#ffd43b'); r(9, 11, 1, 1, '#1a1a1a'); r(14, 11, 1, 1, '#1a1a1a');
  r(9, 13, 6, 5, l); r(11, 13, 2, 2, '#1a1a1a'); r(10, 17, 4, 1, d);
  r(6, 7, 12, 1, d);
}

function slime(g, dir, pose) {
  const r = painter(g, 8, 12);
  const c = '#4dabf7', d = '#1c7ed6', l = '#a5d8ff';
  const w = pose === 1 ? 18 : pose === 2 ? 13 : 16;
  const h = pose === 1 ? 10 : pose === 2 ? 14 : 12;
  const cx = 12, by = 29;
  for (let y = 0; y < h; y++) {
    const t = y / h;
    const hw = Math.round((w / 2) * Math.min(1, Math.sqrt(Math.max(0, 1 - Math.pow(1 - t * 1.25, 2)))));
    const yy = by - h + y;
    r(cx - hw, yy, hw * 2, 1, c);
    r(cx + hw - 2, yy, 2, 1, d);
  }
  r(cx - w / 2 + 1, by - 2, w - 2, 2, d);
  r(cx - 4, by - h + 2, 3, 2, l); r(cx - 5, by - h + 4, 1, 2, l);
  if (dir === 'up') return;
  const ex = dir === 'left' ? -3 : 0;
  r(cx - 4 + ex, by - h / 2 - 1, 2, 3, '#1a1a2e'); r(cx + 2 + ex, by - h / 2 - 1, 2, 3, '#1a1a2e');
  r(cx - 4 + ex, by - h / 2 - 1, 1, 1, '#fff'); r(cx + 2 + ex, by - h / 2 - 1, 1, 1, '#fff');
  r(cx - 1 + ex, by - h / 2 + 3, 3, 1, '#1a1a2e');
}

// ---------------------------------------------------------------
// 오브젝트 (타일 좌표계: 0..31)
// ---------------------------------------------------------------
function saveCrystal(g, frame) {
  const r = painter(g, 4, 10);
  r(7, 25, 18, 6, '#6c6f7d'); r(7, 25, 18, 2, '#b8bcc8'); r(9, 27, 14, 1, '#8e919e');
  const bob = [0, -1, -2, -1][frame % 4];
  const cy = 3 + bob;
  const rows = [1, 2, 3, 4, 5, 6, 6, 6, 6, 5, 5, 4, 3, 2, 1];
  rows.forEach((hw, i) => {
    const y = cy + i;
    r(16 - hw, y, hw, 1, '#74c0fc');
    r(16, y, hw, 1, '#339af0');
  });
  r(14, cy + 3, 2, 6, '#e7f5ff'); r(13, cy + 5, 1, 3, '#d0ebff');
  r(18, cy + 9, 1, 3, '#1c7ed6');
  if (frame % 2 === 0) { r(22, cy + 2, 1, 1, '#ffffff'); r(9, cy + 11, 1, 1, '#d0ebff'); }
}

function sign(g) {
  const r = painter(g, 4, 10);
  r(14, 18, 4, 12, '#6b4423'); r(14, 18, 2, 12, '#8b5a2b');
  r(4, 6, 24, 14, '#b07d4b'); r(4, 6, 24, 2, '#d2a06a'); r(4, 19, 24, 1, '#6e4724');
  r(8, 10, 16, 1, '#6e4724'); r(8, 13, 12, 1, '#6e4724'); r(8, 16, 14, 1, '#6e4724');
  r(5, 7, 1, 1, '#4a2e17'); r(26, 7, 1, 1, '#4a2e17');
}

function chest(g, open) {
  const r = painter(g, 4, 10);
  if (open) {
    r(5, 5, 22, 7, '#7a3e1a'); r(5, 5, 22, 2, '#9a5428'); r(5, 5, 2, 7, '#ffd43b'); r(25, 5, 2, 7, '#ffd43b');
    r(5, 12, 22, 16, '#a0522d'); r(7, 12, 18, 5, '#2b1608'); r(7, 12, 18, 1, '#120804');
    r(5, 18, 22, 2, '#6b3a1a'); r(5, 12, 2, 16, '#ffd43b'); r(25, 12, 2, 16, '#ffd43b'); r(5, 26, 22, 2, '#e0a82e');
    return;
  }
  r(5, 9, 22, 19, '#a0522d'); r(5, 9, 22, 7, '#bd6431'); r(7, 10, 18, 1, '#d98a4a');
  r(5, 16, 22, 2, '#6b3a1a');
  r(5, 9, 2, 19, '#ffd43b'); r(25, 9, 2, 19, '#ffd43b'); r(5, 26, 22, 2, '#e0a82e');
  r(14, 14, 4, 6, '#ffd43b'); r(15, 16, 2, 2, '#2b1608'); r(14, 14, 4, 1, '#fff3bf');
}

// ---------------------------------------------------------------
// 프레임 생성 + 외곽선 + 캐시
// ---------------------------------------------------------------
function makeCanvas() {
  const c = document.createElement('canvas');
  c.width = SPRITE_W; c.height = SPRITE_H;
  return c;
}

function outline(c) {
  const g = c.getContext('2d');
  const { width: w, height: h } = c;
  let img;
  try { img = g.getImageData(0, 0, w, h); } catch (e) { return; }
  const d = img.data;
  const src = new Uint8Array(w * h);
  for (let i = 0; i < w * h; i++) src[i] = d[i * 4 + 3] > 100 ? 1 : 0;
  const oc = [0x1c, 0x14, 0x24];
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      if (src[i]) continue;
      if ((x > 0 && src[i - 1]) || (x < w - 1 && src[i + 1]) || (y > 0 && src[i - w]) || (y < h - 1 && src[i + w])) {
        d[i * 4] = oc[0]; d[i * 4 + 1] = oc[1]; d[i * 4 + 2] = oc[2]; d[i * 4 + 3] = 255;
      }
    }
  }
  g.putImageData(img, 0, 0);
}

function paint(key, dir, pose) {
  let c = makeCanvas();
  let g = c.getContext('2d');
  const baseDir = dir === 'right' ? 'left' : dir;
  let scale = 1;
  if (key === 'save_crystal') saveCrystal(g, pose);
  else if (key === 'sign') sign(g);
  else if (key === 'chest') chest(g, false);
  else if (key === 'chest_open') chest(g, true);
  else if (key === 'cat') cat(g, baseDir, pose);
  else if (key === 'wolf') wolf(g, baseDir, pose);
  else if (key === 'monster' || key === 'slime') slime(g, baseDir, pose);
  else {
    const spec = SPECS[key] || FALLBACK;
    scale = spec.scale || 1;
    humanoid(g, spec, baseDir, pose);
  }
  if (scale !== 1) {
    const s = makeCanvas();
    const sg = s.getContext('2d');
    sg.imageSmoothingEnabled = false;
    const w = Math.round(SPRITE_W * scale), h = Math.round(SPRITE_H * scale);
    // 발 기준(아래 가운데) 고정: 발바닥은 캔버스 y=41
    sg.drawImage(c, 0, 0, SPRITE_W, SPRITE_H, Math.round(20 - 20 * scale), Math.round(41 - 41 * scale), w, h);
    c = s; g = sg;
  }
  if (dir === 'right') {
    const m = makeCanvas();
    const mg = m.getContext('2d');
    mg.translate(SPRITE_W, 0); mg.scale(-1, 1);
    mg.drawImage(c, 0, 0);
    c = m;
  }
  outline(c);
  return c;
}

const cache = new Map();
export function spriteFrame(key, dir = 'down', pose = 0) {
  const k = `${key}|${dir}|${pose}`;
  let c = cache.get(k);
  if (!c) {
    try { c = paint(key, dir, pose); } catch (e) { console.warn('[field] 스프라이트 실패', key, e); c = paint('villager_m', dir, pose); }
    cache.set(k, c);
  }
  return c;
}

const NO_SHADOW = new Set(['sign']);
export function drawShadow(ctx, px, py, key) {
  if (NO_SHADOW.has(key)) return;
  const big = key === 'vorg' || key === 'demon_king';
  ctx.fillStyle = 'rgba(0,0,0,0.28)';
  ctx.beginPath();
  ctx.ellipse(px + 16, py + 29, big ? 12 : 9, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();
}

// 스프라이트 그리기 (px,py = 타일 좌상단 화면 좌표)
export function drawSprite(ctx, key, dir, pose, px, py, t = 0) {
  if (key === 'save_crystal') {
    const f = Math.floor(t * 4) % 4;
    const glow = 0.35 + 0.15 * Math.sin(t * 3);
    const gr = ctx.createRadialGradient(px + 16, py + 12, 2, px + 16, py + 12, 26);
    gr.addColorStop(0, `rgba(165,216,255,${glow})`);
    gr.addColorStop(1, 'rgba(165,216,255,0)');
    ctx.fillStyle = gr;
    ctx.fillRect(px - 12, py - 16, 56, 56);
    ctx.drawImage(spriteFrame(key, 'down', f), px + DX, py + DY);
    return;
  }
  drawShadow(ctx, px, py, key);
  ctx.drawImage(spriteFrame(key, dir, pose), Math.round(px + DX), Math.round(py + DY));
}

export function drawChest(ctx, open, px, py) {
  ctx.drawImage(spriteFrame(open ? 'chest_open' : 'chest', 'down', 0), px + DX, py + DY);
}

export function knownSprite(key) {
  return !!SPECS[key] || ['save_crystal', 'sign', 'chest', 'cat', 'wolf', 'monster', 'slime'].includes(key);
}
