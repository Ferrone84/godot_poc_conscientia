class_name Combatant
extends Node3D
## Un participant au combat : statistiques, altérations, jauge propre et
## modèle 3D construit à partir de formes simples.

const MAX_PA := 9
const STATUS_NAMES := {
	"hate": "Hâte", "lent": "Ralenti", "ancre": "Ancré", "regen": "Hyperplasie",
	"effroi": "Effroi", "futur": "Dégâts futurs",
}

var id := ""
var display_name := ""
var title := ""
var gauge_name := ""
var is_ally := true
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var speed := 10.0
var emotion := "joie"
var pa := 2
var shield := 0.0
var next_time := 0.0
var dead := false
## name -> {"turns": int, "value": float}
var statuses := {}

## Jauge propre : Céran = Distorsion (0..100), Lucie = Empathie (-100..100),
## Nicolas = heure de l'horloge (0..11).
var gauge := 0.0
var tokens := 0
var clock_frozen := 0

var home_pos := Vector3.ZERO
var head_height := 1.55
var model: Node3D

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _spinners: Array[Node3D] = []
var _clock_hand: Node3D
var _bob_t := randf() * TAU
var _name_tag: Label3D


func setup(char_id: String, ally: bool, suffix := "") -> void:
	var data: Dictionary = Roster.CHARACTERS[char_id]
	id = char_id
	is_ally = ally
	display_name = data["name"] + suffix
	title = data.get("title", "")
	gauge_name = data.get("gauge_name", "")
	max_hp = data["max_hp"]
	hp = max_hp
	atk = data["atk"]
	speed = data["speed"]
	emotion = data["emotion"]
	next_time = 100.0 / speed
	model = Node3D.new()
	add_child(model)
	_build_ring()
	match id:
		"ceran": _build_ceran()
		"lucie": _build_lucie()
		"nicolas": _build_nicolas()
		"altere": _build_altere()
		"veilleur": _build_veilleur()
	if not is_ally:
		_name_tag = Label3D.new()
		_name_tag.text = display_name
		_name_tag.font_size = 40
		_name_tag.pixel_size = 0.006
		_name_tag.outline_size = 10
		_name_tag.no_depth_test = true
		_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_tag.modulate = Emotions.core(emotion)
		_name_tag.position = Vector3(0, head_height + 0.55, 0)
		add_child(_name_tag)


func _process(delta: float) -> void:
	_bob_t += delta
	if not dead:
		model.position.y = sin(_bob_t * 2.2) * 0.035 + (0.25 if id == "veilleur" else 0.0)
	for s in _spinners:
		s.rotate_y(delta * 1.6)
	if _clock_hand:
		var target_angle := -gauge / 12.0 * TAU
		_clock_hand.rotation.z = lerp_angle(_clock_hand.rotation.z, target_angle, delta * 8.0)


# --- Règles -----------------------------------------------------------------

func hp_ratio() -> float:
	return hp / max_hp


func eff_speed() -> float:
	var s := speed
	if statuses.has("hate"):
		s *= 1.5
	if statuses.has("lent"):
		s *= 0.6
	return s


func dmg_dealt_mult() -> float:
	var m := 1.0
	if statuses.has("effroi"):
		m *= 0.75
	if id == "lucie":
		m *= lucie_damage_mult()
	if id == "nicolas":
		m *= 1.0 + gauge * 0.04
	return m


func dmg_taken_mult() -> float:
	return 1.3 if statuses.has("ancre") else 1.0


## Empathie de Lucie : à gauche (-100) elle frappe fort, à droite (+100) elle soigne fort.
func lucie_damage_mult() -> float:
	return 1.0 - gauge / 200.0


func lucie_heal_mult() -> float:
	return 1.0 + gauge / 200.0


func add_gauge(amount: float) -> void:
	match id:
		"ceran":
			gauge = clampf(gauge + amount, 0.0, 100.0)
		"lucie":
			gauge = clampf(gauge + amount, -100.0, 100.0)


func add_status(status: String, turns: int, value := 0.0) -> void:
	statuses[status] = {"turns": turns, "value": value}


## Décrémente les altérations en fin de tour (sauf les dégâts futurs,
## gérés par le combat car ils explosent).
func tick_statuses() -> void:
	for k in statuses.keys():
		if k == "futur":
			continue
		statuses[k]["turns"] -= 1
		if statuses[k]["turns"] <= 0:
			statuses.erase(k)


func clear_debuffs() -> void:
	for k in ["lent", "ancre", "effroi"]:
		statuses.erase(k)


func status_text() -> String:
	var parts: PackedStringArray = []
	for k in statuses.keys():
		parts.append("%s (%d)" % [STATUS_NAMES.get(k, k), statuses[k]["turns"]])
	if shield > 0.0:
		parts.append("Bouclier %d" % int(shield))
	return " · ".join(parts)


## Applique des dégâts (après bouclier) et renvoie les dégâts réellement subis.
func take_damage(amount: float) -> float:
	amount = roundf(amount)
	var absorbed := minf(shield, amount)
	shield -= absorbed
	var dmg := minf(hp, amount - absorbed)
	hp -= dmg
	if hp <= 0.0:
		hp = 0.0
		die()
	return dmg


func heal(amount: float) -> float:
	amount = roundf(amount)
	if dead:
		return 0.0
	var h := minf(max_hp - hp, amount)
	hp += h
	return h


func die() -> void:
	dead = true
	statuses.clear()
	shield = 0.0
	set_highlight("")
	var tw := create_tween().set_parallel(true)
	if is_ally:
		tw.tween_property(model, "rotation_degrees:z", 80.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(model, "position:y", -0.2, 0.5)
	else:
		tw.tween_property(model, "scale", Vector3(1.3, 0.05, 1.3), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void: visible = false)
		if _name_tag:
			_name_tag.visible = false


func revive(ratio: float) -> void:
	dead = false
	hp = maxf(1.0, max_hp * ratio)
	visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "rotation_degrees:z", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.0, 0.4)


# --- Présentation -----------------------------------------------------------

## "" = caché, "active" = tour en cours, "target" = cible visée.
func set_highlight(mode: String) -> void:
	_ring.visible = mode != "" and not dead
	match mode:
		"active":
			_ring_mat.albedo_color = Color(2.0, 2.0, 2.2, 0.9)
		"target":
			_ring_mat.albedo_color = Color(2.5, 0.6, 0.3, 0.95) if not is_ally else Color(0.5, 2.5, 0.9, 0.95)


func flinch(from_dir: Vector3) -> void:
	var back := from_dir.normalized() * 0.25
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.12, 0.88, 1.12), 0.06)
	tw.parallel().tween_property(model, "position:x", back.x, 0.06)
	tw.parallel().tween_property(model, "position:z", back.z, 0.06)
	tw.tween_property(model, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(model, "position:x", 0.0, 0.2)
	tw.parallel().tween_property(model, "position:z", 0.0, 0.2)


func head_pos() -> Vector3:
	return global_position + Vector3(0, head_height, 0)


func body_pos() -> Vector3:
	return global_position + Vector3(0, head_height * 0.6, 0)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.62
	t.outer_radius = 0.7
	t.rings = 48
	t.ring_segments = 4
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.mesh = t
	_ring.material_override = _ring_mat
	_ring.scale = Vector3(1, 0.05, 1) * (1.6 if id == "veilleur" else 1.0)
	_ring.position.y = 0.03
	_ring.visible = false
	add_child(_ring)


# Les modèles regardent vers -Z (convention look_at de Godot).

func _build_ceran() -> void:
	var navy := Color(0.09, 0.11, 0.2)
	var violet := Emotions.color("crainte")
	_part(_capsule(0.17, 0.9), _mat(Color(0.06, 0.06, 0.08)), Vector3(0, 0.45, 0))
	_part(_cylinder(0.2, 0.34, 0.95), _mat(navy), Vector3(0, 0.78, 0))
	_part(_cylinder(0.24, 0.2, 0.32), _mat(navy.lightened(0.1)), Vector3(0, 1.22, 0))
	_part(_torus(0.12, 0.2), _mat(Color(0.85, 0.82, 0.75)), Vector3(0, 1.38, 0))
	_part(_torus(0.25, 0.3), _glow(violet, 2.5), Vector3(0, 0.95, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	_part(_sphere(0.16), _mat(Color(0.88, 0.72, 0.62)), Vector3(0, 1.55, 0))
	_part(_sphere(0.17), _mat(Color(0.18, 0.12, 0.08)), Vector3(0, 1.62, 0.03), Vector3.ZERO, Vector3(1.05, 0.75, 1.05))
	_part(_box(Vector3(0.03, 0.95, 0.07)), _mat(Color(0.8, 0.82, 0.88), 0.25, 0.9), Vector3(0.3, 0.78, -0.2), Vector3(-25, 0, 8))
	_part(_box(Vector3(0.2, 0.03, 0.06)), _mat(Color(0.7, 0.55, 0.25), 0.4, 0.8), Vector3(0.28, 0.36, -0.03), Vector3(-25, 0, 8))
	# Fragments d'espace en orbite.
	var orbit := Node3D.new()
	orbit.position.y = 1.0
	model.add_child(orbit)
	for i in 3:
		var a := TAU * i / 3.0
		var cube := _part(_box(Vector3(0.09, 0.09, 0.09)), _glow(violet, 4.0), Vector3(cos(a) * 0.55, 0.15 * i, sin(a) * 0.55), Vector3(45, 45, 0))
		model.remove_child(cube)
		orbit.add_child(cube)
	_spinners.append(orbit)
	head_height = 1.6


func _build_lucie() -> void:
	var white := Color(0.88, 0.87, 0.84)
	var rose := Emotions.color("amour")
	_part(_capsule(0.16, 0.85), _mat(Color(0.2, 0.16, 0.16)), Vector3(0, 0.43, 0))
	_part(_cylinder(0.19, 0.38, 1.0), _mat(white), Vector3(0, 0.75, 0))
	_part(_cylinder(0.22, 0.19, 0.3), _mat(white.darkened(0.05)), Vector3(0, 1.2, 0))
	_part(_box(Vector3(0.05, 0.22, 0.02)), _glow(Color(0.9, 0.15, 0.2), 1.5), Vector3(0, 1.2, -0.21))
	_part(_box(Vector3(0.18, 0.05, 0.02)), _glow(Color(0.9, 0.15, 0.2), 1.5), Vector3(0, 1.23, -0.21))
	_part(_torus(0.14, 0.22), _mat(Color(0.55, 0.12, 0.18)), Vector3(0, 1.36, 0))
	_part(_sphere(0.15), _mat(Color(0.92, 0.76, 0.66)), Vector3(0, 1.52, 0))
	_part(_capsule(0.16, 0.6), _mat(Color(0.5, 0.2, 0.1)), Vector3(0, 1.42, 0.08), Vector3(12, 0, 0))
	_part(_sphere(0.17), _mat(Color(0.5, 0.2, 0.1)), Vector3(0, 1.6, 0.02), Vector3.ZERO, Vector3(1.05, 0.8, 1.05))
	var orb := _part(_sphere(0.09), _glow(rose, 4.0), Vector3(0.32, 0.95, -0.22))
	CsFlux.aura(orb, Vector3.ZERO, "amour", 0.25)
	head_height = 1.55


func _build_nicolas() -> void:
	var brown := Color(0.32, 0.2, 0.11)
	var brass := Color(0.85, 0.62, 0.25)
	var gold := Emotions.color("joie")
	_part(_capsule(0.17, 0.9), _mat(Color(0.12, 0.1, 0.09)), Vector3(0, 0.45, 0))
	_part(_cylinder(0.21, 0.36, 1.0), _mat(brown), Vector3(0, 0.78, 0))
	_part(_cylinder(0.25, 0.21, 0.3), _mat(brown.darkened(0.15)), Vector3(0, 1.24, 0))
	_part(_box(Vector3(0.3, 0.06, 0.02)), _mat(brass, 0.3, 0.9), Vector3(0, 1.05, -0.3))
	_part(_sphere(0.16), _mat(Color(0.85, 0.7, 0.58)), Vector3(0, 1.55, 0))
	_part(_cylinder(0.17, 0.18, 0.08), _mat(Color(0.1, 0.08, 0.06)), Vector3(0, 1.66, 0))
	_part(_cylinder(0.11, 0.13, 0.26), _mat(Color(0.1, 0.08, 0.06)), Vector3(0, 1.8, 0))
	_part(_torus(0.06, 0.09), _mat(brass, 0.3, 0.9), Vector3(-0.07, 1.6, -0.14), Vector3(90, 0, 0))
	_part(_torus(0.06, 0.09), _mat(brass, 0.3, 0.9), Vector3(0.07, 1.6, -0.14), Vector3(90, 0, 0))
	_part(_cylinder(0.02, 0.02, 1.0), _mat(Color(0.15, 0.1, 0.06)), Vector3(0.32, 0.55, -0.1), Vector3(0, 0, -6))
	# Cadran d'horloge flottant dans son dos : l'aiguille suit sa jauge.
	var dial := Node3D.new()
	dial.position = Vector3(0, 2.05, 0.3)
	dial.scale = Vector3.ONE * 0.6
	model.add_child(dial)
	var ring := MeshInstance3D.new()
	ring.mesh = _torus(0.42, 0.47)
	ring.material_override = _glow(gold, 2.2)
	ring.rotation_degrees = Vector3(90, 0, 0)
	dial.add_child(ring)
	for i in 12:
		var a := TAU * i / 12.0
		var tick := MeshInstance3D.new()
		tick.mesh = _box(Vector3(0.03, 0.08 if i % 3 == 0 else 0.04, 0.02))
		tick.material_override = _glow(gold, 3.0 if i % 3 == 0 else 1.5)
		tick.position = Vector3(sin(a) * 0.36, cos(a) * 0.36, 0)
		tick.rotation.z = -a
		dial.add_child(tick)
	_clock_hand = Node3D.new()
	dial.add_child(_clock_hand)
	var hand := MeshInstance3D.new()
	hand.mesh = _box(Vector3(0.035, 0.3, 0.02))
	hand.material_override = _glow(Color(1, 0.95, 0.8), 4.0)
	hand.position = Vector3(0, 0.15, 0)
	_clock_hand.add_child(hand)
	head_height = 1.6


func _build_altere() -> void:
	var skin := Color(0.45, 0.37, 0.33)
	var anger := Emotions.color("colere")
	_part(_capsule(0.3, 1.2), _mat(skin), Vector3(0, 0.75, -0.1), Vector3(-25, 0, 0))
	_part(_sphere(0.2), _mat(skin.darkened(0.2)), Vector3(0, 1.3, -0.45))
	_part(_capsule(0.09, 0.9), _mat(skin), Vector3(-0.38, 0.75, -0.3), Vector3(-30, 0, 15))
	_part(_capsule(0.09, 0.9), _mat(skin), Vector3(0.38, 0.75, -0.3), Vector3(-30, 0, -15))
	_part(_cylinder(0.32, 0.42, 0.5), _mat(Color(0.18, 0.15, 0.13)), Vector3(0, 0.3, 0))
	for i in 9:
		var crack := _part(_box(Vector3(0.03, randf_range(0.15, 0.35), 0.03)), _glow(anger, 4.0),
			Vector3(randf_range(-0.25, 0.25), randf_range(0.5, 1.2), randf_range(-0.4, -0.15)),
			Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)))
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_part(_sphere(0.04), _glow(anger, 8.0), Vector3(-0.07, 1.33, -0.62))
	_part(_sphere(0.04), _glow(anger, 8.0), Vector3(0.07, 1.33, -0.62))
	head_height = 1.45


func _build_veilleur() -> void:
	var fear := Emotions.color("peur")
	var robe := Color(0.11, 0.12, 0.1)
	_part(_cylinder(0.25, 1.1, 2.6), _mat(robe), Vector3(0, 1.3, 0))
	_part(_cylinder(0.5, 0.3, 0.5), _mat(robe.lightened(0.05)), Vector3(0, 2.6, 0))
	_part(_capsule(0.12, 1.6), _mat(robe), Vector3(-0.75, 1.9, -0.2), Vector3(-20, 0, 35))
	_part(_capsule(0.12, 1.6), _mat(robe), Vector3(0.75, 1.9, -0.2), Vector3(-20, 0, -35))
	# Tête-lanterne : un feu de terreur dans une cage.
	_part(_sphere(0.32), _glow(fear, 5.0), Vector3(0, 3.15, 0))
	for i in 6:
		var bar := _part(_capsule(0.025, 0.85), _mat(Color(0.2, 0.18, 0.12), 0.5, 0.8), Vector3.ZERO)
		var a := TAU * i / 6.0
		bar.position = Vector3(cos(a) * 0.36, 3.15, sin(a) * 0.36)
	_part(_cylinder(0.05, 0.4, 0.25), _mat(Color(0.2, 0.18, 0.12), 0.5, 0.8), Vector3(0, 3.62, 0))
	var light := OmniLight3D.new()
	light.light_color = fear
	light.light_energy = 2.5
	light.omni_range = 6.0
	light.position = Vector3(0, 3.15, 0)
	model.add_child(light)
	CsFlux.aura(model, Vector3(0, 1.0, 0), "peur", 0.5)
	head_height = 3.4


# --- Petites fabriques de formes --------------------------------------------

func _part(mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	model.add_child(mi)
	return mi


func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	return c


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	return c


func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
