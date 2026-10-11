// 굽기 도구 공용: 모든 사람 종류(kind)의 차림(SPECS)을 한곳에서 — 고을 사람·이야기 인물·사건별 묶음.
// 공용 자세 굽기(?set=poses)가 쓴다. 각 굽기 파일의 표(PEOPLE·SETS)를 그대로 읽는다(차림을 두 번 적지 않는다).
// HUMAN_BANKS: Godot 프레임 파일 → 그 파일의 사람 종류(영혼·짐승·뱃사공 노 젓기 같은 특수 묶음은 뺀다).
import { SPECS } from '/src/chars/rigs.js';
import { PEOPLE as NPC } from '/__tools/export_npc_frames.js';
import { PEOPLE as STORY, SETS as STORY_SETS } from '/__tools/export_story_frames.js';
import { PEOPLE as GANGNEUNG } from '/__tools/export_gangneung_frames.js';
import { PEOPLE as GYEONGJU } from '/__tools/export_gyeongju_frames.js';
import { PEOPLE as PYONGYANG } from '/__tools/export_pyongyang_frames.js';
import { PEOPLE as HAMHUNG } from '/__tools/export_hamhung_frames.js';
import { PEOPLE as JEJU } from '/__tools/export_jeju_frames.js';
import { MABU } from '/__tools/export_stable_frames.js';

export const HUMAN_BANKS = {
  'frames.json': ['player'],
  'frames_npc.json': ['villager_m', 'villager_f', 'elder', 'child_boy', 'child_girl', 'hunter', 'innkeeper', 'miller', 'woodcutter'],
  'frames_amb.json': Object.keys(NPC),
  'frames_story.json': Object.keys(STORY),
  'frames_story_hanyang.json': Object.keys(STORY_SETS.hanyang),
  'frames_story_hwangju.json': Object.keys(STORY_SETS.hwangju),
  'frames_story_namwon_chunhyang.json': Object.keys(STORY_SETS.namwon_chunhyang),
  'frames_gangneung.json': ['wolsim', 'thief'],
  'frames_gyeongju.json': ['smuggler', 'smuggler_b', 'lantern_wife', 'charcoal_man'],
  'frames_pyongyang.json': Object.keys(PYONGYANG),
  'frames_story_hamhung.json': Object.keys(HAMHUNG),
  'frames_jeju.json': ['gwak', 'simbang', 'jj_child', 'jj_man', 'jj_woman'],
  'frames_stable.json': ['mabu'],
};
export const ALL_HUMANS = [...new Set(Object.values(HUMAN_BANKS).flat())];

const baseOver = (P) => {
  const sp = { ...SPECS[P.base] };
  for (const k in P.over) { if (P.over[k] === null) delete sp[k]; else sp[k] = P.over[k]; }
  return sp;
};
const flat = (P) => {
  const v = { ...P }; const sp = { ...SPECS[v.base] };
  delete v.base; delete v.talk;
  for (const k in v) { if (v[k] === null || v[k] === undefined) delete sp[k]; else sp[k] = v[k]; }
  return sp;
};

/** kind의 차림을 SPECS에 올린다(이미 있으면 그대로). 모르는 kind면 false */
export function ensureSpec(kind) {
  if (SPECS[kind]) return true;
  let sp = null;
  if (NPC[kind]) sp = flat(NPC[kind]);
  else if (kind === 'mabu') sp = flat(MABU);
  else if (STORY[kind]) sp = baseOver(STORY[kind]);
  else {
    for (const tbl of [STORY_SETS.hanyang, STORY_SETS.hwangju, STORY_SETS.namwon_chunhyang, GANGNEUNG, GYEONGJU, PYONGYANG, HAMHUNG, JEJU]) {
      if (tbl[kind] && tbl[kind].base) { sp = baseOver(tbl[kind]); break; }
    }
  }
  if (!sp) return false;
  SPECS[kind] = sp;
  return true;
}
