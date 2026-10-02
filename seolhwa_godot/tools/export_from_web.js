// 웹 프로토타입(seolhwa/) → Godot 데이터(seolhwa_godot/data/) 내보내기.
// 사용: python3 seolhwa_godot/tools/web_export_server.py 8770 → 브라우저로 http://localhost:8770 열기
//       → 개발자 콘솔에서  await (await import('/__tools/export_from_web.js')).done
// 결과: village.glb(마을), world.json·heights.f32(월드 데이터), frames*.json·PNG(캐릭터 프레임), paper.png, ref/ref_*.png(비교 기준)
export const done = (async () => {
  for (let i = 0; i < 120 && !window.__seolhwa; i++) await new Promise((r) => setTimeout(r, 500));
  const S = window.__seolhwa, w = S.world, THREE = S.THREE;
  // 자동 화질 조절을 끄고 최고 단계로 고정(창이 가려져 느려지면 해상도를 낮춰 버린다). 탭이 보이는 상태에서 실행할 것.
  S.fx.setOption('level', 0);
  const put = (name, body) => fetch('/export/' + name, { method: 'PUT', body });
  const toPng = async (cv) => (cv.convertToBlob ? cv.convertToBlob({ type: 'image/png' }) : new Promise((r) => cv.toBlob(r, 'image/png')));

  // ---- 비교 기준 스크린샷(시점·시간을 Godot main.gd REFSET과 같게) ----
  const REFS = [['village_day', 0, 6, 10], ['village_dusk', 0, 6, 18.3], ['village_night', 0, 6, 22], ['bridge_day', 0, -14, 10],
    ['pass_day', 8, -70, 10], ['behind_house', -9, -8.5, 10], ['interior', -22, -32, 10]];
  for (const [name, x, z, h] of REFS) {
    S.teleport({ x, z }); S.fx.setOption('timeFlow', false); S.fx.setTime(h); S.rig.focus = null;
    for (let i = 0; i < 40; i++) await new Promise((r) => requestAnimationFrame(r));
    const p = S.player.pos;
    const interior = w.interiors.find((it) => p.x >= it.minX && p.x <= it.maxX && p.z >= it.minZ && p.z <= it.maxZ) || null;
    S.rig.update(0, p, S.player.facing, interior, true);
    S.fx.update(0.016, p); S.fx.render();
    const cv = S.renderer.domElement;
    if (cv.width !== 2048 || cv.height !== 1536) console.warn('[export] 기준 스크린샷 크기가 2048×1536이 아님:', cv.width, cv.height, '— 창 크기 1024×768, 화면 배율 2에서 실행');
    await put(`ref/ref_${name}.png`, await (await fetch(S.renderer.domElement.toDataURL('image/png'))).blob());
  }

  // ---- 마을 glTF + 월드 데이터 ----
  const { GLTFExporter } = await import('https://unpkg.com/three@0.170.0/examples/jsm/exporters/GLTFExporter.js');
  let n = 0;
  w.root.traverse((o) => { if (o === w.root) return; o.userData.__orig = o.name; o.name = (o.isMesh ? 'm' : 'g') + (n++); });
  const hidden = [], glow = [], meshes = {}, origNames = {};
  w.root.traverse((o) => {
    if (o.userData.__orig !== undefined) origNames[o.name] = o.userData.__orig;
    if (!o.visible) hidden.push(o.name);
    if (!o.isMesh) return;
    if (w.glowMaterials.includes(o.material)) glow.push(o.name);
    const m = o.material;
    meshes[o.name] = [o.castShadow ? 1 : 0, o.receiveShadow ? 1 : 0, m.type, m.side, m.transparent ? 1 : 0, +(m.opacity ?? 1).toFixed(3), m.alphaTest || 0];
  });
  const X0 = -64, X1 = 64, Z0 = -96, Z1 = 40, STEP = 0.25;
  const nx = Math.round((X1 - X0) / STEP) + 1, nz = Math.round((Z1 - Z0) / STEP) + 1;
  const H = new Float32Array(nx * nz);
  for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) H[j * nx + i] = w.heightAt(X0 + i * STEP, Z0 + j * STEP);
  await put('heights.f32', H.buffer);
  await put('world.json', JSON.stringify({
    heights: { file: 'heights.f32', x0: X0, z0: Z0, step: STEP, nx, nz },
    spawn: w.spawn, colliders: w.colliders, cameraZones: w.cameraZones,
    interiors: w.interiors.map((it) => ({ ...it, hide: it.hide.map((o) => o.name) })),
    arenas: w.arenas, anchors: w.anchors, lights: w.lights,
    labels: (w.labels || []).map((l) => ({ x: l.x, y: l.y, z: l.z, text: l.text })),
    npcs: w.npcs.map(({ id, kind, x, z, facing, wander, name, lines }) => ({ id, kind, x, z, facing, wander, name, lines })),
    occluders: w.occluders.map((o) => o.name), hidden, glow, meshes, origNames,
  }));
  const glb = await new GLTFExporter().parseAsync(w.root, { binary: true, onlyVisible: false });
  await put('village.glb', glb);
  w.root.traverse((o) => { if (o.userData.__orig !== undefined) { o.name = o.userData.__orig; delete o.userData.__orig; } });

  // ---- 한지 텍스처 ----
  const { createPaperTexture } = await import('/src/fx/paper.js');
  await put('paper.png', await toPng(createPaperTexture(512).image));

  // ---- 캐릭터 프레임: 주인공·호랑이(웹이 구운 것 그대로) ----
  const fr = await import('/src/chars/frames.js');
  const main = {};
  for (const kind of ['player', 'tiger']) {
    const s = fr.frameStore(kind);
    const pages = [];
    for (let i = 0; i < s.pages.length; i++) {
      const img = s.pages[i].tex.image;
      const cv = new OffscreenCanvas(img.width, img.height);
      cv.getContext('2d').drawImage(img, 0, 0);
      const name = `frames_${kind}_${i}.png`;
      await put(name, await toPng(cv)); pages.push(name);
    }
    const clips = {};
    for (const [k, c] of s.clips) clips[k] = { spec: c.spec, frames: c.frames.map((f) => ({ page: s.pages.indexOf(f.page), u0: f.u0, u1: f.u1, v0: f.v0, v1: f.v1, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, lift: f.lift })) };
    main[kind] = { pages, clips };
  }
  await put('frames.json', JSON.stringify(main));

  // ---- 마을 사람: 웹은 컷아웃으로 그리지만, 같은 굽기 엔진으로 대기·걷기·대화 프레임을 굽는다 ----
  const fc = await import('/src/chars/frameCore.js');
  const kinds = ['villager_m', 'villager_f', 'elder', 'child_boy', 'child_girl', 'hunter', 'innkeeper', 'miller', 'woodcutter'];
  for (const k of kinds) fc.TIERS.high[k] = fc.TIERS.high.player;
  const npc = {};
  for (const kind of kinds) {
    const b = new fc.BakeBank(kind, 'high');
    const clips = {};
    for (const v of ['front', 'side', 'back']) for (const a of ['idle', 'walk', 'talk']) {
      const key = fc.clipKey(fc.resolveView(kind, v, a), a, false, false);
      if (clips[key]) continue;
      const c = b.clip(key); if (!c) continue;
      let g = 0; while (!b.step(c) && g++ < 400);
      clips[key] = { spec: c.spec, frames: c.frames.map((f) => ({ page: typeof f.page === 'number' ? f.page : f.page.index, u0: f.u0, u1: f.u1, v0: f.v0, v1: f.v1, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, lift: f.lift })) };
    }
    const pages = [];
    for (let i = 0; i < b.pages.length; i++) { const name = `frames_${kind}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
    npc[kind] = { pages, clips };
  }
  await put('frames_npc.json', JSON.stringify(npc));
  console.log('[export] 완료', { glbMB: (glb.byteLength / 1e6).toFixed(1), nodes: n });
})();
