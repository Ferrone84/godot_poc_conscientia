class_name GaugeWidget
extends Control
## Jauge propre à chaque personnage, dessinée à la main :
## Céran = anneau de Distorsion, Lucie = curseur d'Empathie, Nicolas = cadran d'horloge.

var unit: Combatant


func _init(c: Combatant) -> void:
	unit = c
	match c.id:
		"lucie": custom_minimum_size = Vector2(112, 80)
		"nicolas": custom_minimum_size = Vector2(80, 96)
		_: custom_minimum_size = Vector2(80, 80)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	match unit.id:
		"ceran": _draw_ceran()
		"lucie": _draw_lucie()
		"nicolas": _draw_nicolas()


func _draw_ceran() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.4
	var violet := Emotions.color("crainte")
	draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.12), 8, true)
	var ratio := unit.gauge / 100.0
	if ratio > 0.0:
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * ratio, 64, violet.lightened(0.2), 8, true)
	# Repères des seuils consommés par Ancrage (20) et Faille (30).
	for mark in [20.0, 30.0]:
		var a: float = -PI / 2 + TAU * mark / 100.0
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 6), c + Vector2(cos(a), sin(a)) * (r + 6), Color(1, 1, 1, 0.6), 2)
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-30, 6), str(int(unit.gauge)), HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Color.WHITE)


func _draw_lucie() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x - 10
	var y := size.y * 0.42
	var left := Vector2(5, y)
	var bar := Rect2(left - Vector2(0, 5), Vector2(w, 10))
	# Dégradé grossier : rouge (Frappe) -> rose (Soin).
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var col := Color(0.85, 0.2, 0.15).lerp(Emotions.color("amour"), t)
		draw_rect(Rect2(bar.position + Vector2(w * t, 0), Vector2(w / steps + 1, 10)), col)
	draw_line(Vector2(5 + w * 0.5, y - 9), Vector2(5 + w * 0.5, y + 9), Color(1, 1, 1, 0.5), 1)
	var cx := 5 + w * (unit.gauge + 100.0) / 200.0
	draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 6), Vector2(cx - 7, y - 16), Vector2(cx + 7, y - 16)]), Color.WHITE)
	draw_string(font, Vector2(5, y + 26), "Dégâts ×%.2f" % unit.lucie_damage_mult(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.6, 0.55))
	draw_string(font, Vector2(5, y + 42), "Soins ×%.2f" % unit.lucie_heal_mult(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.8, 0.9))


func _draw_nicolas() -> void:
	var font := ThemeDB.fallback_font
	var r := 33.0
	var c := Vector2(size.x * 0.5, r + 4)
	var gold := Emotions.color("joie")
	draw_circle(c, r, Color(0.12, 0.09, 0.05, 0.9))
	draw_arc(c, r, 0, TAU, 48, gold, 2, true)
	for i in 12:
		var a := -PI / 2 + TAU * i / 12.0
		var special := i % 3 == 0 and i != 0
		var inner := r - (9.0 if special else 5.0)
		draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * r, gold if special else Color(gold, 0.5), 3 if special else 1)
	var ha := -PI / 2 + TAU * unit.gauge / 12.0
	draw_line(c, c + Vector2(cos(ha), sin(ha)) * (r - 8), Color.WHITE, 3, true)
	draw_circle(c, 3, Color.WHITE)
	var hour := int(unit.gauge)
	var label := "%dh" % (12 if hour == 0 else hour)
	draw_string(font, c + Vector2(-20, r + 17), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, gold)
	for t in unit.tokens:
		draw_circle(Vector2(8 + t * 12, 8), 4, gold.lightened(0.3))
	if unit.clock_frozen > 0:
		draw_string(font, Vector2(0, size.y), "figée", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.85, 1))
