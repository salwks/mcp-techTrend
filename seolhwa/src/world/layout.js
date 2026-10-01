// 무대 배치 상수(좌표 1단위=1m, 카메라는 +z에서 -z를 본다)

// 산길 중심선 [x, z, 높이]
export const PATH = [
  [0, -20.8, 0.1],
  [-3, -26, 1.2],
  [7, -32, 3.0],
  [14, -38, 4.4],
  [5, -45, 6.2],
  [-6, -50, 8.0],
  [-1, -58, 10.2],
  [6, -64, 12.4],
  [8, -69.5, 14.0],
];
// 외딴집으로 갈라지는 오솔길
export const BRANCH = [
  [-3, -26, 1.2],
  [-11, -28.2, 1.6],
  [-18, -28.6, 1.9],
  [-22, -28.4, 1.9],
];
export const PASS = { x: 8, z: -69.5, h: 14, r: 5.5 };
export const HOUSE = { x: -22, z: -32, w: 6, d: 4.4, pad: 1.9, F: 0.4 };
export const BRIDGE = { x: 0, z0: -20.8, z1: -11.2, hw: 1.3 };
export const WATER_Y = -0.72;

// 개울 중심선
export function streamZ(x) {
  return -16 + 1.4 * Math.sin(x * 0.085) + 0.6 * Math.sin(x * 0.21);
}

// 논(사각형, 높이). 서쪽은 계단식 다랑논
export const PADDIES = [
  { minX: -29, maxX: -24.5, minZ: -1, maxZ: 8.5, h: 0.05 },
  { minX: -29, maxX: -24.5, minZ: 9, maxZ: 19, h: 0.12 },
  { minX: -34, maxX: -29.5, minZ: -1, maxZ: 8.5, h: 0.75 },
  { minX: -34, maxX: -29.5, minZ: 9, maxZ: 19, h: 0.82 },
  { minX: -39, maxX: -34.5, minZ: -1, maxZ: 19, h: 1.55 },
  { minX: 19.5, maxX: 26, minZ: 13.5, maxZ: 19, h: 0.02 },
  { minX: 26.5, maxX: 33, minZ: 13.5, maxZ: 19, h: 0.2 },
  { minX: 19.5, maxX: 26, minZ: 19.5, maxZ: 25, h: 0.1 },
  { minX: 26.5, maxX: 33, minZ: 19.5, maxZ: 25, h: 0.3 },
];

// 마을 길(흙색 칠하기용)
export const LANES = [
  { minX: -1.5, maxX: 1.5, minZ: -12, maxZ: 34 },
  { minX: -23, maxX: 23, minZ: 0.8, maxZ: 3.3 },
  { minX: 8.2, maxX: 9.8, minZ: -2, maxZ: 1 },
  { minX: -10, maxX: -8, minZ: -3, maxZ: 1 },
  { minX: -18, maxX: -16, minZ: 3, maxZ: 12 },
  { minX: 14, maxX: 16, minZ: 3, maxZ: 12 },
];

// 마을 건물
export const CHOGA = [
  { x: -9, z: -5, w: 6, d: 4, seed: 11 },
  { x: -17, z: 9, w: 6, d: 4, seed: 12 },
  { x: 15, z: 9, w: 6, d: 4, seed: 13 },
  { x: 22, z: -5, w: 5.4, d: 4, seed: 14 },
  { x: -21, z: -6, w: 5.4, d: 4, seed: 15 },
];
export const GIWA = { x: 9, z: -6, w: 9, d: 5.4 };
export const JEONGJA = { x: 7, z: 15, s: 3.4 };
export const ZELKOVA = { x: 11.8, z: 18 };
export const WELL = { x: -5, z: 8 };
export const JANGDOK = { x: -15, z: -6, w: 3.4, d: 2.4 };
export const SEONANG = { cairn: { x: 4.6, z: -72.6 }, tree: { x: 2.0, z: -74.2 } };

// 호랑이의 영역: 산길(P3) 동쪽 숲속 빈터
export const ARENA = { x: 28.5, z: -44, r: 11, h: 5.2 };
export const ARENA_TRAIL = [
  [14, -38, 4.4],
  [18.5, -40.2, 4.9],
  [21.5, -41.8, 5.2],
];

// ---- 3단계 「산길의 실종」 장소 ----
export const INN = { x: -8, z: 20, w: 6, d: 4 };
export const MILL = { x: -12, z: -23.8, w: 4.6, d: 3.4, pad: 0.8 };
export const BARN = { x: 23.5, z: 8.5, w: 4.2, d: 3 };
export const BIG_TREE = { x: -26.2, z: -25.6 };
export const YARD = { x: -22, z: -25, r: 7.5, pad: 1.75 };
// 나무·바위를 비워 둘 곳
export const CLEAR = [
  { x: YARD.x, z: YARD.z, r: YARD.r + 1.5 },
  { x: MILL.x - 1, z: MILL.z + 1, r: 5.5 },
];
export const isClear = (x, z, m = 0) => CLEAR.some((c) => Math.hypot(x - c.x, z - c.z) < c.r + m);
