class_name QteOverlay
extends Control
## QTE de timing : un anneau se resserre sur la cible ; il faut appuyer
## au moment où il recouvre le cercle fixe.
## - attaque : [Espace] -> "perfect" | "good" | "miss"
## - défense : [E] parer (fenêtre étroite) / [Espace] esquiver (fenêtre large)
##             -> "parry" | "dodge" | "hit"
## Appuyer trop tôt ou avec la mauvaise touche verrouille l'essai (pas de spam).

signal resolved(result: String)

const PERFECT_WIN := 0.07
const GOOD_WIN := 0.16
const PARRY_WIN := 0.11
const DODGE_EARLY := 0.22
const DODGE_LATE := 0.09
const TARGET_RADIUS := 34.0
const START_RADIUS := 150.0

## En autotest, le QTE se joue tout seul (avec une précision imparfaite).
var autoplay := false
## En autotest, ne jamais réussir les QTE (pour tester les KO et la défaite).
var autoplay_miss := false
## Mode démo : attaques presque toujours parfaites, défense imposée par le
## scénario ("parry", "dodge" ou "hit" pour encaisser).
var demo := false
var demo_defense := "parry"

var _active := false
var _mode := ""
var _t := 0.0
var _dur := 1.0
var _anchor := Vector2.ZERO
var _color := Color.WHITE
var _result := ""
var _auto_time := 0.0
var _auto_action := ""
var _popups: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func run_attack(anchor: Vector2, duration: float, color: Color) -> String:
	_start("attack", anchor, duration, color)
	var r: String = await resolved
	return r


func run_defend(anchor: Vector2, duration: float, color: Color) -> String:
	_start("defend", anchor, duration, color)
	var r: String = await resolved
	return r


func popup(text: String, anchor: Vector2, color: Color, font_size := 30) -> void:
	_popups.append({"text": text, "pos": anchor, "t": 0.0, "color": color, "size": font_size})


func _start(mode: String, anchor: Vector2, duration: float, color: Color) -> void:
	_mode = mode
	_anchor = anchor
	_dur = duration
	_color = color
	_t = 0.0
	_result = ""
	_active = true
	if autoplay and demo:
		_auto_action = "attack" if mode == "attack" else demo_defense
		_auto_time = duration + randf_range(-0.05, 0.09)
		if _auto_action == "dodge":
			_auto_time = duration + randf_range(-0.16, 0.0)
	elif autoplay:
		_auto_time = duration + randf_range(-0.14, 0.1)
		if mode == "attack":
			_auto_action = "attack"
		else:
			_auto_action = "parry" if randf() < 0.5 else "dodge"


func _process(delta: float) -> void:
	if _active:
		_t += delta
		if autoplay and not autoplay_miss and _auto_action != "hit" and _result == "" and _t >= _auto_time:
			_register(_auto_action)
		var late := GOOD_WIN if _mode == "attack" else maxf(PARRY_WIN, DODGE_LATE)
		if _t >= _dur + late or (_result != "" and _t >= _dur):
			_finish()
	for p in _popups:
		p["t"] += delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["t"] < 0.9)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _result != "" or autoplay:
		return
	if _mode == "attack" and event.is_action_pressed("qte_attack"):
		_register("attack")
	elif _mode == "defend" and event.is_action_pressed("qte_parry"):
		_register("parry")
	elif _mode == "defend" and event.is_action_pressed("qte_dodge"):
		_register("dodge")
	else:
		return
	get_viewport().set_input_as_handled()


func _register(action: String) -> void:
	var dt := _t - _dur
	if _mode == "attack":
		if absf(dt) <= PERFECT_WIN:
			_result = "perfect"
		elif absf(dt) <= GOOD_WIN:
			_result = "good"
		else:
			_result = "miss"
	else:
		if action == "parry" and absf(dt) <= PARRY_WIN:
			_result = "parry"
		elif action == "dodge" and dt >= -DODGE_EARLY and dt <= DODGE_LATE:
			_result = "dodge"
		else:
			_result = "fail"


func _finish() -> void:
	_active = false
	var r := _result
	if r == "":
		r = "miss" if _mode == "attack" else "hit"
	if r == "fail":
		r = "hit"
	match r:
		"perfect": popup("PARFAIT !", _anchor, Color(1, 0.9, 0.4), 34)
		"good": popup("Réussi", _anchor, Color(0.7, 1, 0.8))
		"miss": popup("Raté", _anchor, Color(0.8, 0.8, 0.8))
		"parry": popup("PARADE !", _anchor, Color(1, 0.95, 0.5), 36)
		"dodge": popup("Esquive", _anchor, Color(0.6, 0.9, 1))
	resolved.emit(r)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if _active:
		var k := clampf(_t / _dur, 0.0, 1.0)
		var r := lerpf(START_RADIUS, TARGET_RADIUS, k)
		if _t > _dur:
			r = TARGET_RADIUS - (_t - _dur) * 120.0
		var in_window := absf(_t - _dur) <= (GOOD_WIN if _mode == "attack" else PARRY_WIN)
		draw_circle(_anchor, TARGET_RADIUS, Color(0, 0, 0, 0.35))
		draw_arc(_anchor, TARGET_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.9), 3, true)
		var ring_col := Color(1, 1, 1) if in_window else _color.lightened(0.3)
		draw_arc(_anchor, maxf(r, 2.0), 0, TAU, 64, ring_col, 5, true)
		var hint := "[ESPACE]" if _mode == "attack" else "[E] Parer    [ESPACE] Esquiver"
		draw_string(font, _anchor + Vector2(-160, TARGET_RADIUS + 34), hint, HORIZONTAL_ALIGNMENT_CENTER, 320, 18, Color(1, 1, 1, 0.95))
	for p in _popups:
		var t: float = p["t"]
		var col: Color = p["color"]
		col.a = 1.0 - t / 0.9
		var pos: Vector2 = p["pos"] + Vector2(0, -50 - t * 40)
		draw_string_outline(font, pos + Vector2(-150, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 300, p["size"], 6, Color(0, 0, 0, col.a))
		draw_string(font, pos + Vector2(-150, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 300, p["size"], col)
