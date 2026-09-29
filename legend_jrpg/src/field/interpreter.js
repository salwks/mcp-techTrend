// 이벤트 스크립트 실행기 (docs/CONTRACTS.md §9)
// 필드 씬(scene)이 제공하는 메서드: say, ask, teleport, battle, moveNpc, movePlayer, faceNpc,
//   setBgm, refreshParty, restoreBgm, isDead
import { sfx, stopBgm } from '../engine/audio.js';
import { EVENTS, itemName, charName, CHARACTERS } from './data.js';
import { josa } from './util.js';

export const STOP = Symbol('stop'); // 게임오버/엔딩 등으로 스크립트 중단

export function resolveEvent(ref) {
  if (!ref) return null;
  if (Array.isArray(ref)) return ref;
  if (typeof ref === 'string') {
    const ev = EVENTS[ref];
    if (!ev) { console.warn(`[field] 이벤트 없음: ${ref}`); return null; }
    return Array.isArray(ev) ? ev : (ev.cmds || ev.commands || null);
  }
  if (typeof ref === 'object' && ref.cmd) return [ref];
  return null;
}

export class Interpreter {
  constructor(scene) {
    this.scene = scene;
  }

  get game() { return this.scene.game; }
  get state() { return this.scene.game.state; }

  // cmds 배열 또는 이벤트 ID 실행. STOP을 돌려주면 이후 명령도 중단해야 한다.
  async run(ref) {
    const cmds = resolveEvent(ref);
    if (!cmds) return;
    for (const c of cmds) {
      if (this.scene.isDead()) return STOP;
      if (!c || typeof c !== 'object') continue;
      let r;
      try {
        r = await this.exec(c);
      } catch (err) {
        console.error('[field] 이벤트 명령 실행 오류', c, err);
      }
      if (r === STOP || this.scene.isDead()) return STOP;
    }
  }

  cond(c) {
    const st = this.state;
    let ok = false;
    if (c.flag != null) {
      const v = st.getFlag(c.flag);
      ok = c.value !== undefined ? v === c.value : !!v;
    } else if (c.member != null) {
      ok = st.hasMember(c.member);
    } else if (c.item != null) {
      ok = st.itemCount(c.item) >= (c.count ?? 1);
    } else if (c.gold != null) {
      ok = st.gold >= c.gold;
    }
    return c.not ? !ok : ok;
  }

  async exec(c) {
    const s = this.scene, st = this.state, game = this.game;
    switch (c.cmd) {
      case 'text':
        await s.say(c.text ?? '', c.speaker || null);
        return;

      case 'choice': {
        const opts = c.options || [];
        const idx = await s.ask(opts, c.text, c.speaker);
        const br = (c.branches || [])[idx];
        if (br) return this.run(br);
        return;
      }

      case 'if':
        return this.run(this.cond(c) ? c.then : c.else);

      case 'setFlag':
        st.setFlag(c.flag, c.value === undefined ? true : c.value);
        return;

      case 'join': {
        if (!CHARACTERS[c.member]) { console.warn('[field] 알 수 없는 동료', c.member); return; }
        if (st.hasMember(c.member)) return;
        st.addMember(c.member, c.level || 1);
        s.refreshParty();
        sfx('levelup');
        await s.say(`${josa(charName(c.member), '이/가')} 동료가 되었다!`);
        return;
      }

      case 'battle': {
        const res = await s.battle({
          troop: c.troop,
          canEscape: c.canEscape ?? false,
          bg: c.bg,
          bgm: c.bgm,
        });
        if (s.isDead()) return STOP;
        if (res === 'lose') {
          if (c.onLose) {
            // 패배 후에도 이야기가 이어지는 전투: 쓰러진 동료를 HP 1로 일으킨다
            for (const m of st.partyMembers()) if (m.hp <= 0) m.hp = 1;
            return this.run(c.onLose);
          }
          s.gameOver();
          return STOP;
        }
        if (res === 'win' && c.onWin) return this.run(c.onWin);
        return;
      }

      case 'giveItem': {
        const n = c.count ?? 1;
        st.addItem(c.item, n);
        sfx('item');
        const name = itemName(c.item);
        if (c.silent) return;
        await s.say(n > 1 ? `${name} ${n}개를 손에 넣었다!` : `${josa(name, '을/를')} 손에 넣었다!`);
        return;
      }

      case 'takeItem':
        st.removeItem(c.item, Math.min(c.count ?? 1, st.itemCount(c.item)));
        return;

      case 'giveGold': {
        const n = c.amount || 0;
        st.gold = Math.max(0, st.gold + n);
        if (n > 0) {
          sfx('item');
          if (!c.silent) await s.say(`${n} 골드를 손에 넣었다!`);
        }
        return;
      }

      case 'equip':
        if (!st.forceEquip(c.member, c.item)) console.warn('[field] equip 실패', c.member, c.item);
        return;

      case 'heal':
        st.fullHeal();
        sfx('heal');
        return;

      case 'inn': return this.inn(c);

      case 'shop':
        await s.subScene('shop', { items: c.items || [], title: c.title });
        return;

      case 'teleport':
        await s.teleport(c.map, c.x, c.y, c.dir, { sound: c.sound });
        return;

      case 'wait':
        await game.wait(c.ms ?? 500);
        return;

      case 'shake':
        game.shake(c.ms ?? 400, c.power ?? 6);
        return;

      case 'flash':
        game.flash(c.color || '#fff', c.ms ?? 250);
        return;

      case 'bgm':
        s.setBgm(c.key);
        return;

      case 'sfx':
        sfx(c.name);
        return;

      case 'npcMove':
        await s.moveNpc(c.npc, c.path || '', c.speed);
        return;

      case 'playerMove':
        await s.movePlayer(c.path || '', c.speed);
        return;

      case 'face':
        if (c.npc) s.faceNpc(c.npc, c.dir);
        else if (c.dir) s.player.dir = c.dir;
        return;

      case 'save':
        await s.subScene('save', { mode: 'save' });
        return;

      case 'ending':
        stopBgm();
        await s.subScene('ending', {});
        return STOP;

      case 'fadeOut':
        await game.fadeOut(c.ms ?? 300);
        return;
      case 'fadeIn':
        await game.fadeIn(c.ms ?? 300);
        return;

      default:
        console.warn('[field] 알 수 없는 이벤트 명령:', c.cmd, c);
    }
  }

  async inn(c) {
    const s = this.scene, st = this.state, game = this.game;
    const price = c.price || 0;
    const speaker = c.speaker || '여관 주인';
    const idx = await s.ask(['묵는다', '그만둔다'], c.text || `하룻밤에 ${price} 골드입니다.\n묵고 가시겠어요?`, speaker);
    if (idx !== 0) {
      await s.say('또 오세요.', speaker);
      return;
    }
    if (st.gold < price) {
      sfx('buzzer');
      await s.say('골드가 부족하신 것 같네요.', speaker);
      return;
    }
    st.gold -= price;
    await s.say('편히 쉬세요.', speaker);
    await game.fadeOut(500);
    stopBgm();
    st.fullHeal();
    sfx('heal');
    await game.wait(900);
    if (s.isDead()) return STOP;
    s.restoreBgm();
    await game.fadeIn(500);
    await s.say('푹 쉬어서 모두 기운을 되찾았다!');
  }
}
