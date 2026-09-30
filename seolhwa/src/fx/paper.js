// 한지 텍스처(절차 생성, 이음매 없는 512² 캔버스)
// R: 섬유(0.5 기준 ±), G: 얼룩(저주파 번짐)
import * as THREE from 'three';

function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }

export function createPaperTexture(size = 512) {
  const cv = document.createElement('canvas');
  cv.width = cv.height = size;
  const g = cv.getContext('2d');
  const R = rng(7);
  // 두 개 채널을 따로 그린 뒤 합친다
  const layer = (draw) => {
    const c = document.createElement('canvas'); c.width = c.height = size;
    const x = c.getContext('2d');
    x.fillStyle = 'rgb(128,128,128)'; x.fillRect(0, 0, size, size);
    draw(x);
    return x.getImageData(0, 0, size, size).data;
  };
  const wrap = (x, fn) => { for (const ox of [-size, 0, size]) for (const oy of [-size, 0, size]) fn(ox, oy); };
  // 섬유: 가늘고 긴 곡선, 밝은 것·어두운 것
  const fib = layer((x) => {
    x.lineCap = 'round';
    for (let i = 0; i < 900; i++) {
      const px = R() * size, py = R() * size;
      const ang = R() * Math.PI * 2, len = 8 + R() * R() * 70;
      const bend = (R() - 0.5) * 0.8;
      const light = R() < 0.55;
      const a = 0.05 + R() * 0.16;
      x.strokeStyle = light ? `rgba(255,255,255,${a})` : `rgba(0,0,0,${a * 0.8})`;
      x.lineWidth = 0.4 + R() * 1.1;
      const ex = Math.cos(ang) * len, ey = Math.sin(ang) * len;
      const cx = ex * 0.5 - ey * bend, cy = ey * 0.5 + ex * bend;
      wrap(0, (ox, oy) => {
        x.beginPath(); x.moveTo(px + ox, py + oy);
        x.quadraticCurveTo(px + ox + cx, py + oy + cy, px + ox + ex, py + oy + ey);
        x.stroke();
      });
    }
    // 미세 입자
    for (let i = 0; i < 5000; i++) {
      const v = R() < 0.5 ? 0 : 255;
      x.fillStyle = `rgba(${v},${v},${v},${0.05 + R() * 0.08})`;
      x.fillRect(R() * size, R() * size, 1, 1);
    }
  });
  // 얼룩: 부드러운 방사형 번짐
  const mot = layer((x) => {
    for (let i = 0; i < 140; i++) {
      const px = R() * size, py = R() * size, r = 20 + R() * 90;
      const v = R() < 0.5 ? 0 : 255, a = 0.04 + R() * 0.07;
      wrap(0, (ox, oy) => {
        const gr = x.createRadialGradient(px + ox, py + oy, 0, px + ox, py + oy, r);
        gr.addColorStop(0, `rgba(${v},${v},${v},${a})`);
        gr.addColorStop(1, `rgba(${v},${v},${v},0)`);
        x.fillStyle = gr; x.fillRect(px + ox - r, py + oy - r, r * 2, r * 2);
      });
    }
  });
  const img = g.createImageData(size, size);
  for (let i = 0; i < size * size; i++) {
    img.data[i * 4] = fib[i * 4];
    img.data[i * 4 + 1] = mot[i * 4];
    img.data[i * 4 + 2] = 128;
    img.data[i * 4 + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const tex = new THREE.CanvasTexture(cv);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.colorSpace = THREE.NoColorSpace;
  tex.generateMipmaps = false;
  tex.minFilter = THREE.LinearFilter;
  tex.magFilter = THREE.LinearFilter;
  return tex;
}
