class_name BattleUI
extends CanvasLayer
## Interface du combat : ordre des tours, cartes de l'équipe, ennemis,
## menu d'actions (clavier ou souris), QTE et écran de fin.

signal action_selected(choice: Dictionary)
signal restart_requested

const GOLD := Color(0.86, 0.72, 0.42)

var qte: QteOverlay

var _root: Control
var _timeline: HBoxContainer
var _enemy_box: VBoxContainer
var _party_box: HBoxContainer
var _action_panel: PanelContainer
var _action_title: Label
var _menu: VBoxContainer
var _desc: Label
var _banner: Label
var _end_panel: PanelContainer
var _end_title: Label
var _end_sub: Label

var _allies: Array = []
var _enemies: Array = []
var _actor: Combatant
var _back: Callable
var _party_rows := {}
var _enemy_rows := {}


func setup(allies: Array, enemies: Array) -> void:
	_allies = allies
	_enemies = enemies
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_timeline()
	_build_enemies()
	_build_party()
	_build_actions()
	_build_banner_and_hint()
	qte = QteOverlay.new()
	_root.add_child(qte)
	_build_end()


func _process(_delta: float) -> void:
	for c in _party_rows:
		var row: Dictionary = _party_rows[c]
		var u := c as Combatant
		(row["hp"] as ProgressBar).value = u.hp
		(row["hp_label"] as Label).text = "PV %d / %d" % [ceili(u.hp), int(u.max_hp)] + ("   KO" if u.dead else "")
		(row["pa"] as Label).text = "PA " + "◆".repeat(u.pa) + "◇".repeat(maxi(0, 6 - u.pa))
		(row["status"] as Label).text = u.status_text()
		(row["panel"] as Control).modulate = Color(1, 1, 1, 0.45) if u.dead else Color.WHITE
	for c in _enemy_rows:
		var row: Dictionary = _enemy_rows[c]
		var u := c as Combatant
		(row["hp"] as ProgressBar).value = u.hp
		(row["status"] as Label).text = u.status_text() if not u.dead else "Vaincu"
		(row["panel"] as Control).modulate = Color(1, 1, 1, 0.35) if u.dead else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if _action_panel.visible and event.is_action_pressed("ui_cancel") and _back.is_valid():
		_back.call()
		get_viewport().set_input_as_handled()


# --- API utilisée par le combat ---------------------------------------------

func set_timeline(order: Array) -> void:
	for ch in _timeline.get_children():
		ch.queue_free()
	for i in order.size():
		var u := order[i] as Combatant
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		var col := Emotions.color(u.emotion)
		sb.bg_color = Color(0.06, 0.06, 0.1, 0.9) if u.is_ally else Color(0.14, 0.05, 0.05, 0.9)
		sb.border_color = col
		sb.set_border_width_all(3 if i == 0 else 1)
		sb.border_width_bottom = 4
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = u.display_name
		l.add_theme_font_size_override("font_size", 16 if i == 0 else 13)
		l.add_theme_color_override("font_color", Color.WHITE if i == 0 else Color(0.8, 0.8, 0.8))
		chip.add_child(l)
		_timeline.add_child(chip)


func banner(text: String, color := Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	var tw := _banner.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func show_actions(actor: Combatant) -> void:
	_actor = actor
	_action_panel.visible = true
	_menu_root()


func hide_actions() -> void:
	_action_panel.visible = false
	get_viewport().gui_release_focus()


func show_end(victory: bool, turns: int) -> void:
	_end_title.text = "VICTOIRE" if victory else "DÉFAITE"
	_end_title.add_theme_color_override("font_color", GOLD if victory else Color(0.9, 0.3, 0.3))
	_end_sub.text = ("Le Médian de Gavillon se dissout dans le bruit de fond du Plan de la Conscience." if victory
		else "La peur de Gavillon a eu raison de l'équipe.") + "\n%d tours joués." % turns
	_end_panel.visible = true
	var btn := _end_panel.find_child("Rejouer", true, false) as Button
	btn.grab_focus()


# --- Menu d'actions -----------------------------------------------------------

func _menu_root() -> void:
	_clear_menu()
	_action_title.text = "%s — à toi de jouer" % _actor.display_name
	var basic := SkillDB.basic_attack(_actor.id)
	_add_button("Attaque", SkillDB.SKILLS[basic]["desc"], func() -> void: _choose(basic))
	_add_button("Compétences  ▸", "Techniques de Credo Sum. Elles coûtent des PA (points d'action).\nOn gagne 1 PA par tour et 1 PA par attaque de base ou parade réussie.", _menu_skills)
	_back = Callable()
	_focus_first()


func _menu_skills() -> void:
	_clear_menu()
	_action_title.text = "%s — compétences" % _actor.display_name
	for sid in SkillDB.KITS[_actor.id]:
		var sk: Dictionary = SkillDB.SKILLS[sid]
		var cost := "%d PA" % sk["cost"]
		if sk.has("tokens"):
			cost += " + %d jeton" % sk["tokens"]
		var label := ("★ " if sk.get("ultimate", false) else "") + "%s   [%s]" % [sk["name"], cost]
		var desc: String = sk["desc"]
		if sk.has("clock") and int(sk["clock"]) > 0:
			desc += "\nHorloge : ±%dh (avance si l'heure est paire, recule sinon)." % sk["clock"]
		var skill_id: String = sid
		var b := _add_button(label, desc, func() -> void: _choose(skill_id))
		b.disabled = not SkillDB.can_use(sid, _actor, _allies, _enemies)
	_add_button("◂ Retour", "", _menu_root)
	_back = _menu_root
	_focus_first()


func _choose(skill_id: String) -> void:
	if not SkillDB.needs_target(skill_id):
		_emit(skill_id, _actor)
		return
	_clear_menu()
	var sk: Dictionary = SkillDB.SKILLS[skill_id]
	_action_title.text = "%s — choisir la cible" % sk["name"]
	_desc.text = sk["desc"]
	for t in SkillDB.valid_targets(skill_id, _actor, _allies, _enemies):
		var u := t as Combatant
		var b := _add_button("%s   %d/%d PV" % [u.display_name, ceili(u.hp), int(u.max_hp)], sk["desc"], func() -> void: _emit(skill_id, u))
		b.focus_entered.connect(_hover_target.bind(u))
		b.mouse_entered.connect(_hover_target.bind(u))
	var previous := _menu_root if skill_id == SkillDB.basic_attack(_actor.id) else _menu_skills
	var go_back := func() -> void:
		_clear_target_highlights()
		previous.call()
	_add_button("◂ Retour", "", go_back)
	_back = go_back
	_focus_first()


func _emit(skill_id: String, target: Combatant) -> void:
	_clear_target_highlights()
	hide_actions()
	action_selected.emit({"skill": skill_id, "target": target})


func _hover_target(u: Combatant) -> void:
	_clear_target_highlights()
	u.set_highlight("target")


func _clear_target_highlights() -> void:
	for c in _allies + _enemies:
		var u := c as Combatant
		u.set_highlight("active" if u == _actor else "")


func _clear_menu() -> void:
	for ch in _menu.get_children():
		_menu.remove_child(ch)
		ch.queue_free()
	_desc.text = ""


func _add_button(text: String, desc: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: _desc.text = desc)
	b.mouse_entered.connect(func() -> void: _desc.text = desc)
	_menu.add_child(b)
	return b


func _focus_first() -> void:
	for ch in _menu.get_children():
		var b := ch as Button
		if b and not b.disabled:
			b.grab_focus()
			return


# --- Construction ---------------------------------------------------------------

func _build_timeline() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	var title := Label.new()
	title.text = "ORDRE DES TOURS"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	_timeline = HBoxContainer.new()
	_timeline.add_theme_constant_override("separation", 4)
	box.add_child(_timeline)
	_root.add_child(box)


func _build_enemies() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_right = -16
	panel.offset_left = -16
	panel.offset_top = 16
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(300, 0)
	_enemy_box = VBoxContainer.new()
	panel.add_child(_enemy_box)
	_root.add_child(panel)
	for c in _enemies:
		var u := c as Combatant
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var name_l := Label.new()
		name_l.text = "%s  —  %s" % [u.display_name, u.title]
		name_l.add_theme_font_size_override("font_size", 13)
		name_l.add_theme_color_override("font_color", Emotions.core(u.emotion))
		row.add_child(name_l)
		var bar := _make_bar(u.max_hp, Color(0.75, 0.2, 0.15))
		row.add_child(bar)
		var st := Label.new()
		st.add_theme_font_size_override("font_size", 11)
		st.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		row.add_child(st)
		_enemy_box.add_child(row)
		_enemy_rows[u] = {"hp": bar, "status": st, "panel": row}


func _build_party() -> void:
	_party_box = HBoxContainer.new()
	_party_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_party_box.offset_left = 16
	_party_box.offset_bottom = -30
	_party_box.offset_top = -30
	_party_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_party_box.add_theme_constant_override("separation", 6)
	_root.add_child(_party_box)
	for c in _allies:
		var u := c as Combatant
		var panel := PanelContainer.new()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		panel.add_child(hb)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(150, 0)
		info.add_theme_constant_override("separation", 1)
		hb.add_child(info)
		var name_l := Label.new()
		name_l.text = u.display_name
		name_l.add_theme_font_size_override("font_size", 18)
		name_l.add_theme_color_override("font_color", Emotions.core(u.emotion))
		info.add_child(name_l)
		var title_l := Label.new()
		title_l.text = u.title
		title_l.add_theme_font_size_override("font_size", 10)
		title_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		info.add_child(title_l)
		var bar := _make_bar(u.max_hp, Color(0.3, 0.75, 0.4))
		info.add_child(bar)
		var hp_l := Label.new()
		hp_l.add_theme_font_size_override("font_size", 12)
		info.add_child(hp_l)
		var pa_l := Label.new()
		pa_l.add_theme_font_size_override("font_size", 14)
		pa_l.add_theme_color_override("font_color", GOLD)
		info.add_child(pa_l)
		var st := Label.new()
		st.add_theme_font_size_override("font_size", 10)
		st.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.custom_minimum_size = Vector2(150, 26)
		info.add_child(st)
		var gauge_box := VBoxContainer.new()
		var gl := Label.new()
		gl.text = u.gauge_name
		gl.add_theme_font_size_override("font_size", 11)
		gl.add_theme_color_override("font_color", Emotions.core(u.emotion))
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gauge_box.add_child(gl)
		gauge_box.add_child(GaugeWidget.new(u))
		hb.add_child(gauge_box)
		_party_box.add_child(panel)
		_party_rows[u] = {"hp": bar, "hp_label": hp_l, "pa": pa_l, "status": st, "panel": panel}


func _build_actions() -> void:
	_action_panel = PanelContainer.new()
	_action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_panel.offset_right = -16
	_action_panel.offset_left = -16
	_action_panel.offset_bottom = -16
	_action_panel.offset_top = -16
	_action_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_action_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_action_panel.custom_minimum_size = Vector2(360, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_action_panel.add_child(vb)
	_action_title = Label.new()
	_action_title.add_theme_color_override("font_color", GOLD)
	_action_title.add_theme_font_size_override("font_size", 16)
	vb.add_child(_action_title)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 3)
	vb.add_child(_menu)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(340, 70)
	_desc.add_theme_font_size_override("font_size", 12)
	_desc.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
	vb.add_child(_desc)
	_action_panel.visible = false
	_root.add_child(_action_panel)


func _build_banner_and_hint() -> void:
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 66
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 18
	hint.offset_right = 860
	hint.offset_top = -26
	hint.offset_bottom = -6
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.text = "Défense : [E] Parer · [Espace] Esquiver     Attaque : [Espace] au bon moment     Menu : flèches, Entrée, Échap"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 0.8))
	_root.add_child(hint)


func _build_end() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end_panel.custom_minimum_size = Vector2(520, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_end_panel.add_child(vb)
	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 44)
	vb.add_child(_end_title)
	_end_sub = Label.new()
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_end_sub)
	var btn := Button.new()
	btn.name = "Rejouer"
	btn.text = "Rejouer"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(func() -> void: restart_requested.emit())
	vb.add_child(btn)
	_end_panel.visible = false
	_root.add_child(_end_panel)


func _make_bar(max_value: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar


func _make_theme() -> Theme:
	var th := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04, 0.04, 0.08, 0.84)
	panel.border_color = Color(GOLD, 0.45)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(10)
	th.set_stylebox("panel", "PanelContainer", panel)
	var states := {
		"normal": Color(0.1, 0.1, 0.16, 0.95),
		"hover": Color(0.2, 0.17, 0.3, 0.95),
		"pressed": Color(0.28, 0.22, 0.12, 0.95),
		"disabled": Color(0.07, 0.07, 0.09, 0.8),
		"focus": Color(0, 0, 0, 0),
	}
	for s in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[s]
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		if s == "focus":
			sb.draw_center = false
			sb.border_color = GOLD
			sb.set_border_width_all(2)
		th.set_stylebox(s, "Button", sb)
	th.set_color("font_color", "Button", Color(0.93, 0.9, 0.84))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	th.set_font_size("font_size", "Button", 15)
	th.set_font_size("font_size", "Label", 14)
	return th
