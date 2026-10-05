# 화면 위 큰 창(기록책 · 지도 · Esc 멈춤 · 저장 창 · 역마 창 · 문서 · 시작 메뉴)이 열려 있는 동안 HUD(지명 · 건물 이름 · 호신물 칸 ·
# 아래 안내 · 조사 안내 · 알림)를 감추고, 닫히면 되돌린다.
#   창:   add_to_group(HudGate.OVERLAY) — CanvasLayer면 visible, Control이면 is_visible_in_tree()로 '열림'을 본다
#   HUD:  add_to_group(HudGate.HIDE)    — CanvasLayer는 visible을, 그 밖의 CanvasItem은 modulate.a를 끈다(제 코드가 visible을 따로 쓰므로)
# place_title(늘 있는 지명 층, PROCESS_MODE_ALWAYS)이 매 프레임 apply()를 부른다 — 멈춤(paused) 중에도 돈다.
extends RefCounted

const OVERLAY := "ui_overlay"
const HIDE := "hud_hideable"

static func overlay_open(tree: SceneTree) -> bool:
	if tree == null: return false
	for n in tree.get_nodes_in_group(OVERLAY):
		if not is_instance_valid(n) or not n.is_inside_tree() or n.is_queued_for_deletion(): continue
		if n is CanvasLayer and not (n as CanvasLayer).visible: continue
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree(): continue
		return true
	return false

static func apply(tree: SceneTree) -> bool:
	var hide := overlay_open(tree)
	for n in tree.get_nodes_in_group(HIDE):
		if not is_instance_valid(n): continue
		if n is CanvasLayer:
			if (n as CanvasLayer).visible == hide: (n as CanvasLayer).visible = not hide
		elif n is CanvasItem:
			# 제 코드가 modulate를 트윈하는 것(조사 안내 판 등)은 meta hud_gate_self — self_modulate만 끈다(글은 자식 Label을 따로 넣는다)
			var ci := n as CanvasItem
			var prop := "self_modulate" if ci.has_meta("hud_gate_self") else "modulate"
			var hid := ci.has_meta("hud_gate_a")
			if hide and not hid:
				var c: Color = ci.get(prop)
				ci.set_meta("hud_gate_a", c.a); c.a = 0.0; ci.set(prop, c)
			elif not hide and hid:
				var c: Color = ci.get(prop)
				c.a = float(ci.get_meta("hud_gate_a")); ci.set(prop, c); ci.remove_meta("hud_gate_a")
	return hide
