// 해/달 방향광 + 반구광 + 안개(높이 안개 포함) + 그림자 카메라 추적
import * as THREE from 'three';

let fogPatched = false;
// three의 fog 청크를 전역 교체: 거리 안개(FogExp2) + 낮은 곳에 고이는 산안개.
// 산안개 세기는 fogDensity에 비례(새벽·밤에 더 짙음). 가까운 곳(플레이어 주변)은 깨끗하게 유지.
// 월드 y는 viewMatrix의 회전 열에서 싸게 복원(모든 셰이더에 존재하는 mvPosition/viewMatrix만 사용).
export function patchFogChunks() {
  if (fogPatched) return;
  fogPatched = true;
  const C = THREE.ShaderChunk;
  C.fog_pars_vertex = `
#ifdef USE_FOG
  varying float vFogDepth;
  varying float vFogHeight;
#endif`;
  C.fog_vertex = `
#ifdef USE_FOG
  vFogDepth = - mvPosition.z;
  vFogHeight = dot( viewMatrix[1].xyz, mvPosition.xyz - viewMatrix[3].xyz );
#endif`;
  C.fog_pars_fragment = `
#ifdef USE_FOG
  uniform vec3 fogColor;
  varying float vFogDepth;
  varying float vFogHeight;
  #ifdef FOG_EXP2
    uniform float fogDensity;
  #else
    uniform float fogNear;
    uniform float fogFar;
  #endif
#endif`;
  C.fog_fragment = `
#ifdef USE_FOG
  #ifdef FOG_EXP2
    float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
    float fogMist = fogDensity * 24.0 * ( 1.0 - smoothstep( -2.0, 7.0, vFogHeight ) ) * smoothstep( 14.0, 48.0, vFogDepth );
    fogFactor = 1.0 - ( 1.0 - fogFactor ) * ( 1.0 - clamp( fogMist, 0.0, 0.8 ) );
  #else
    float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
  #endif
  gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`;
}

export function createLighting(scene, { shadowSize = 2048, shadowExtent = 20 } = {}) {
  const sun = new THREE.DirectionalLight(0xffffff, 2.5);
  sun.name = 'fx-sun';
  sun.castShadow = true;
  const sc = sun.shadow.camera;
  sc.left = -shadowExtent; sc.right = shadowExtent; sc.top = shadowExtent; sc.bottom = -shadowExtent;
  sc.near = 1; sc.far = 160;
  sun.shadow.mapSize.set(shadowSize, shadowSize);
  sun.shadow.bias = -0.0004;
  sun.shadow.normalBias = 0.03;
  sun.shadow.radius = 3;
  scene.add(sun);
  scene.add(sun.target);

  const hemi = new THREE.HemisphereLight(0xffffff, 0x444444, 1);
  hemi.name = 'fx-hemi';
  scene.add(hemi);

  const fog = new THREE.FogExp2(0xcccccc, 0.01);

  const dir = new THREE.Vector3(0, 1, 1).normalize();
  const _basis = new THREE.Matrix4();
  const _inv = new THREE.Matrix4();
  const _p = new THREE.Vector3();
  const _zero = new THREE.Vector3();
  const _up = new THREE.Vector3(0, 1, 0);
  const DIST = 70;

  function setShadowSize(n) {
    if (sun.shadow.mapSize.x === n) return;
    sun.shadow.mapSize.set(n, n);
    if (sun.shadow.map) { sun.shadow.map.dispose(); sun.shadow.map = null; }
  }

  return {
    sun, hemi, fog, dir,
    setShadowSize,
    apply(state, lightDir, fogOn) {
      dir.copy(lightDir);
      sun.color.copy(state.sun);
      sun.intensity = state.sunI;
      hemi.color.copy(state.hemiS);
      hemi.groundColor.copy(state.hemiG);
      hemi.intensity = state.hemiI;
      fog.color.copy(state.fog);
      fog.density = state.dens;
      scene.fog = fogOn ? fog : null;
    },
    // 그림자 카메라가 focus를 따라가되 텍셀 단위로 스냅(떨림 방지)
    follow(focus) {
      _basis.lookAt(dir, _zero, _up);            // 회전만 (light 공간 → 월드)
      _inv.copy(_basis).transpose();
      _p.copy(focus); _p.z -= 5; // 화면에 보이는 쪽(북쪽)으로 치우쳐 덮기
      _p.applyMatrix4(_inv);
      const texel = (2 * shadowExtent) / sun.shadow.mapSize.x;
      _p.x = Math.round(_p.x / texel) * texel;
      _p.y = Math.round(_p.y / texel) * texel;
      _p.applyMatrix4(_basis);
      sun.target.position.copy(_p);
      sun.position.copy(_p).addScaledVector(dir, DIST);
      sun.target.updateMatrixWorld();
      sun.updateMatrixWorld();
    },
  };
}
