class_name OptionsMenu
extends PanelContainer
## Menu des options d'affichage. Met le jeu en pause tant qu'il est ouvert
## (les QTE et les animations sont figés) ; chaque changement est appliqué
## et sauvegardé immédiatement.

signal closed

var _mode: OptionButton
var _res: OptionButton
var _scale: HSlider
var _scale_label: Label
var _upscaler: OptionButton
var _msaa: OptionButton
var _vsync: CheckBox
var _ui: HSlider
var _ui_label: Label
var _info: Label
var _close: Button
var _refreshing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560, 0)
	visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	var title := Label.new()
	title.text = "OPTIONS D'AFFICHAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BattleUI.GOLD)
	vb.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)

	_mode = _option(grid, "Mode d'affichage", GameSettings.WINDOW_MODES)
	_mode.item_selected.connect(func(i: int) -> void: _apply_setting("window_mode", i))
	_res = _option(grid, "Résolution (fenêtré)", [])
	_res.item_selected.connect(func(i: int) -> void: _apply_setting("resolution", GameSettings.available_resolutions()[i]))
	var scale_row := _slider(grid, "Échelle de rendu 3D", 0.5, 1.0, 0.05)
	_scale = scale_row[0]
	_scale_label = scale_row[1]
	_scale.value_changed.connect(func(v: float) -> void: _apply_setting("render_scale", v))
	_upscaler = _option(grid, "Mise à l'échelle", GameSettings.UPSCALERS)
	_upscaler.item_selected.connect(func(i: int) -> void: _apply_setting("upscaler", i))
	_msaa = _option(grid, "Anticrénelage (MSAA)", GameSettings.MSAA_LEVELS)
	_msaa.item_selected.connect(func(i: int) -> void: _apply_setting("msaa", i))
	_label(grid, "Synchro verticale")
	_vsync = CheckBox.new()
	_vsync.text = "Activée"
	_vsync.toggled.connect(func(on: bool) -> void: _apply_setting("vsync", on))
	grid.add_child(_vsync)
	var ui_row := _slider(grid, "Taille de l'interface", 0.75, 1.5, 0.05)
	_ui = ui_row[0]
	_ui_label = ui_row[1]
	_ui.value_changed.connect(func(v: float) -> void: _apply_setting("ui_scale", v))

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 12)
	_info.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(540, 0)  # sans largeur, le retour à la ligne gonfle la hauteur
	vb.add_child(_info)
	_close = Button.new()
	_close.text = "Reprendre le combat"
	_close.custom_minimum_size = Vector2(0, 38)
	_close.pressed.connect(close)
	vb.add_child(_close)
	GameSettings.changed.connect(_refresh)


func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh()
	# Centrage recalculé à l'ouverture : la taille réelle n'est connue qu'une fois le contenu rempli.
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_mode.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _apply_setting(key: String, value: Variant) -> void:
	if _refreshing:
		return
	GameSettings.set(key, value)
	GameSettings.apply()
	GameSettings.save()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_refreshing = true
	_mode.select(GameSettings.window_mode)
	_res.clear()
	var resolutions := GameSettings.available_resolutions()
	var selected := 0
	for i in resolutions.size():
		var r := resolutions[i]
		_res.add_item("%d × %d" % [r.x, r.y])
		if r == GameSettings.resolution:
			selected = i
	_res.select(selected)
	_res.disabled = GameSettings.window_mode != 0
	_scale.value = GameSettings.render_scale
	_scale_label.text = "%d %%" % roundi(GameSettings.render_scale * 100.0)
	_upscaler.select(GameSettings.upscaler)
	_upscaler.disabled = GameSettings.render_scale >= 1.0
	_msaa.select(GameSettings.msaa)
	_vsync.button_pressed = GameSettings.vsync
	_ui.value = GameSettings.ui_scale
	_ui_label.text = "%d %%" % roundi(GameSettings.ui_scale * 100.0)
	var win := get_window().size
	var r3d := Vector2i(roundi(win.x * GameSettings.render_scale), roundi(win.y * GameSettings.render_scale))
	_info.text = "Fenêtre : %d × %d — rendu 3D : %d × %d. F11 bascule le plein écran à tout moment." % [win.x, win.y, r3d.x, r3d.y]
	_refreshing = false


func _label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	grid.add_child(l)


func _option(grid: GridContainer, text: String, items: Array) -> OptionButton:
	_label(grid, text)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(260, 32)
	for it in items:
		o.add_item(it)
	grid.add_child(o)
	return o


func _slider(grid: GridContainer, text: String, min_v: float, max_v: float, step: float) -> Array:
	_label(grid, text)
	var hb := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(200, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.custom_minimum_size = Vector2(50, 0)
	hb.add_child(s)
	hb.add_child(l)
	grid.add_child(hb)
	return [s, l]
