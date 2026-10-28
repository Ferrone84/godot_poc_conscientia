class_name HeroModel
extends Node3D
## Modèle articulé des personnages jouables (placeholder amélioré) :
## un petit squelette de pivots (bassin, torse, tête, bras, jambes, cape)
## habillé de formes simples, rendu en cel-shading avec contour, et animé
## par code (respiration, attaque, sort, coup reçu, parade).
## Le modèle regarde vers -Z (convention look_at de Godot) ; +Z est le dos.

const OUTLINE_COLOR := Color(0.03, 0.02, 0.06)

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var cape: Node3D
var clock_hand: Node3D
var spinners: Array[Node3D] = []
var head_height := 1.65

var _outline: StandardMaterial3D
var _t := randf() * TAU
var _pose_tw: Tween
var _caster := false


func build(char_id: String) -> void:
	_outline = StandardMaterial3D.new()
	_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline.grow = true
	_outline.grow_amount = 0.012
	_outline.albedo_color = OUTLINE_COLOR
	match char_id:
		"ceran": _build_ceran()
		"lucie": _build_lucie()
		"nicolas": _build_nicolas()


func _process(delta: float) -> void:
	_t += delta
	# Respiration et balancements légers (n'entrent pas en conflit avec les poses,
	# qui animent les rotations des bras et du torse).
	torso.scale = Vector3(1.0, 1.0 + sin(_t * 2.0) * 0.012, 1.0)
	head.rotation.y = sin(_t * 0.7) * 0.08
	if cape:
		cape.rotation.x = 0.12 + sin(_t * 1.6) * 0.05
	for s in spinners:
		s.rotate_y(delta * 1.6)


# --- Animations ---------------------------------------------------------------

func play(anim: String, duration := 0.0) -> void:
	match anim:
		"charge": _anim_charge(duration)
		"attack": _anim_attack()
		"cast": _anim_cast()
		"hit": _anim_hit()
		"parry": _anim_parry()


func _new_pose() -> Tween:
	if _pose_tw and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_tw = create_tween()
	return _pose_tw


## Retour à la pose de repos, en une nouvelle étape après tout ce qui précède.
## (Ne pas appeler set_parallel ici : il annulerait l'enchaînement des étapes.)
func _rest(tw: Tween, duration := 0.3) -> void:
	var first := true
	for p in [arm_l, arm_r, torso, head]:
		for prop in ["rotation:x", "rotation:z"]:
			var target := 0.0 if prop == "rotation:x" else _rest_z(p)
			var step := tw.chain() if first else tw.parallel()
			step.tween_property(p, prop, target, duration).set_trans(Tween.TRANS_SINE)
			first = false


func _rest_z(p: Node3D) -> float:
	if p == arm_l:
		return -0.12
	if p == arm_r:
		return 0.12
	return 0.0


## Prise d'élan pendant le QTE : arme levée (ou mains tendues pour un lanceur).
func _anim_charge(hold: float) -> void:
	var tw := _new_pose()
	tw.set_parallel(true)
	if _caster:
		tw.tween_property(arm_r, "rotation:x", 1.35, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(arm_l, "rotation:x", 1.1, 0.25)
		tw.tween_property(arm_l, "rotation:z", -0.5, 0.25)
	else:
		tw.tween_property(arm_r, "rotation:x", 2.7, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(arm_l, "rotation:x", 0.6, 0.25)
		tw.tween_property(torso, "rotation:x", 0.12, 0.25)
	tw.chain().tween_interval(maxf(hold, 0.1))
	_rest(tw)


## Frappe : l'arme s'abat vers l'avant, le torse accompagne.
func _anim_attack() -> void:
	var tw := _new_pose()
	if arm_r.rotation.x < 1.5:
		tw.tween_property(arm_r, "rotation:x", 2.5, 0.08)
	tw.tween_property(arm_r, "rotation:x", 0.45, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(torso, "rotation:x", -0.22, 0.08)
	tw.parallel().tween_property(arm_l, "rotation:x", -0.4, 0.08)
	tw.tween_interval(0.16)
	_rest(tw, 0.3)


## Sort : mains projetées vers l'avant.
func _anim_cast() -> void:
	var tw := _new_pose()
	tw.set_parallel(true)
	tw.tween_property(arm_r, "rotation:x", 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(arm_l, "rotation:x", 1.3, 0.12)
	tw.tween_property(torso, "rotation:x", -0.1, 0.12)
	tw.chain().tween_interval(0.25)
	_rest(tw, 0.35)


## Coup reçu : recul du buste, bras qui partent en arrière.
func _anim_hit() -> void:
	var tw := _new_pose()
	tw.set_parallel(true)
	tw.tween_property(torso, "rotation:x", 0.35, 0.06)
	tw.tween_property(head, "rotation:x", 0.3, 0.06)
	tw.tween_property(arm_l, "rotation:x", -0.5, 0.06)
	tw.tween_property(arm_r, "rotation:x", -0.5, 0.06)
	tw.chain().tween_interval(0.08)
	_rest(tw, 0.35)


## Parade : arme (ou bras) en travers devant le corps.
func _anim_parry() -> void:
	var tw := _new_pose()
	tw.set_parallel(true)
	tw.tween_property(arm_r, "rotation:x", 1.6, 0.05)
	tw.tween_property(arm_r, "rotation:z", -0.75, 0.05)
	tw.tween_property(torso, "rotation:x", 0.1, 0.05)
	tw.chain().tween_interval(0.18)
	_rest(tw, 0.3)


# --- Squelette commun ---------------------------------------------------------

## Crée la hiérarchie de pivots. `h` = échelle de taille (1.0 = adulte ~1,75 m).
func _skeleton(h: float, shoulder_w: float) -> void:
	hips = _pivot(self, Vector3(0, 0.95 * h, 0))
	torso = _pivot(hips, Vector3(0, 0.02 * h, 0))
	head = _pivot(torso, Vector3(0, 0.6 * h, 0))
	arm_l = _pivot(torso, Vector3(-shoulder_w, 0.5 * h, 0))
	arm_r = _pivot(torso, Vector3(shoulder_w, 0.5 * h, 0))
	arm_l.rotation.z = -0.12
	arm_r.rotation.z = 0.12
	hand_l = _pivot(arm_l, Vector3(0, -0.6 * h, -0.03))
	hand_r = _pivot(arm_r, Vector3(0, -0.6 * h, -0.03))
	leg_l = _pivot(hips, Vector3(-0.1 * h, 0, 0))
	leg_r = _pivot(hips, Vector3(0.1 * h, 0, 0))
	head_height = 1.72 * h


## Bras : haut du bras + avant-bras légèrement fléchi + main.
func _arms(sleeve: Color, skin: Color, h: float, cuff := Color.TRANSPARENT) -> void:
	for arm in [arm_l, arm_r]:
		var a := arm as Node3D
		_part(a, _capsule(0.06 * h, 0.36 * h), _toon(sleeve), Vector3(0, -0.15 * h, 0))
		_part(a, _capsule(0.052 * h, 0.32 * h), _toon(sleeve), Vector3(0, -0.42 * h, -0.02), Vector3(-8, 0, 0))
		if cuff.a > 0.0:
			_part(a, _cylinder(0.058 * h, 0.058 * h, 0.05 * h), _toon(cuff), Vector3(0, -0.54 * h, -0.025))
		_part(a, _sphere(0.048 * h), _toon(skin), Vector3(0, -0.6 * h, -0.03), Vector3.ZERO, Vector3(0.9, 1.1, 0.9))


## Jambes : cuisse/tibia + botte.
func _legs(pants: Color, boots: Color, h: float) -> void:
	for leg in [leg_l, leg_r]:
		var l := leg as Node3D
		_part(l, _capsule(0.075 * h, 0.82 * h), _toon(pants), Vector3(0, -0.44 * h, 0))
		_part(l, _box(Vector3(0.13, 0.13, 0.25) * h), _toon(boots), Vector3(0, -0.88 * h, -0.04))
		_part(l, _cylinder(0.08 * h, 0.085 * h, 0.22 * h), _toon(boots), Vector3(0, -0.75 * h, 0))


## Visage : yeux, sourcils, oreilles.
func _face(skin: Color, brows: Color, h: float, eye := Color(0.08, 0.06, 0.1)) -> void:
	_part(head, _sphere(0.135 * h), _toon(skin), Vector3(0, 0.13 * h, 0), Vector3.ZERO, Vector3(0.95, 1.08, 1.0))
	_part(head, _cylinder(0.05 * h, 0.055 * h, 0.1 * h), _toon(skin), Vector3(0, 0.0, 0))
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.019 * h), _flat(eye), Vector3(0.048 * side * h, 0.14 * h, -0.118 * h), Vector3.ZERO, Vector3(1, 1.3, 0.6), false)
		_part(head, _box(Vector3(0.05, 0.012, 0.015) * h), _flat(brows), Vector3(0.05 * side * h, 0.185 * h, -0.122 * h), Vector3(0, 0, -8 * side), Vector3.ONE, false)
		_part(head, _sphere(0.028 * h), _toon(skin), Vector3(0.13 * side * h, 0.12 * h, 0), Vector3.ZERO, Vector3(0.5, 1.0, 0.8), false)
	_part(head, _sphere(0.02 * h), _toon(skin.darkened(0.05)), Vector3(0, 0.11 * h, -0.13 * h), Vector3.ZERO, Vector3(0.8, 1.0, 1.0), false)


# --- Céran : inquisiteur de 16 ans, l'Espace ---------------------------------

func _build_ceran() -> void:
	var h := 0.95
	var navy := Color(0.11, 0.14, 0.3)
	var navy_dark := Color(0.06, 0.07, 0.17)
	var gold := Color(0.85, 0.68, 0.3)
	var skin := Color(0.92, 0.76, 0.66)
	var hair := Color(0.16, 0.1, 0.07)
	var violet := Emotions.color("crainte")
	_skeleton(h, 0.23)
	_legs(Color(0.08, 0.08, 0.1), Color(0.22, 0.14, 0.08), h)
	# Manteau d'inquisiteur : buste, pans longs, ceinture, col montant.
	_part(torso, _cylinder(0.19, 0.16, 0.56 * h), _toon(navy), Vector3(0, 0.29 * h, 0))
	_part(torso, _box(Vector3(0.05, 0.5 * h, 0.02)), _toon(gold, 0.4), Vector3(0, 0.29 * h, -0.17), Vector3(4, 0, 0), Vector3.ONE, false)
	_part(hips, _cylinder(0.17, 0.33, 0.62 * h), _toon(navy), Vector3(0, -0.28 * h, 0))
	_part(hips, _torus(0.165, 0.2), _toon(Color(0.2, 0.12, 0.07)), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
	_part(hips, _box(Vector3(0.07, 0.06, 0.03)), _toon(gold, 0.3), Vector3(0, 0.02, -0.19), Vector3.ZERO, Vector3.ONE, false)
	_part(torso, _cylinder(0.12, 0.16, 0.1 * h), _toon(Color(0.9, 0.88, 0.82)), Vector3(0, 0.58 * h, 0))
	# Épaulettes dorées.
	for arm in [arm_l, arm_r]:
		_part(arm, _sphere(0.1), _toon(navy_dark), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.1, 0.7, 1.15))
		_part(arm, _torus(0.07, 0.1), _toon(gold, 0.4), Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	_arms(navy, skin, h, gold)
	_face(skin, hair, h, Color(0.25, 0.12, 0.4))
	# Cheveux en bataille : calotte + mèches.
	_part(head, _sphere(0.145 * h), _toon(hair), Vector3(0, 0.18 * h, 0.015), Vector3.ZERO, Vector3(1.02, 0.78, 1.05))
	var spikes := [Vector3(-0.07, 0.25, -0.08), Vector3(0.05, 0.27, -0.09), Vector3(-0.1, 0.2, 0.06), Vector3(0.09, 0.22, 0.07), Vector3(0.0, 0.27, 0.09), Vector3(0.12, 0.16, -0.02)]
	for i in spikes.size():
		var p := (spikes[i] as Vector3) * h
		_part(head, _cylinder(0.0, 0.045, 0.14), _toon(hair), p, Vector3(-35 if p.z < 0 else 35, 0, -p.x * 300.0))
	# Cape bleu nuit frappée de l'emblème d'Estréde.
	cape = _pivot(torso, Vector3(0, 0.56 * h, 0.13))
	_part(cape, _curved_panel(0.4, 0.62, 1.0 * h, 0.12), _toon(navy_dark, 0.8, false, true), Vector3.ZERO)
	_part(cape, _torus(0.06, 0.08), _glow(gold, 1.5), Vector3(0, -0.36 * h, 0.13), Vector3(90, 0, 0), Vector3.ONE, false)
	_part(cape, _box(Vector3(0.025, 0.2, 0.01)), _glow(gold, 1.5), Vector3(0, -0.36 * h, 0.135), Vector3.ZERO, Vector3.ONE, false)
	# Épée : lame tenue vers l'avant, fil violet (le flux d'espace).
	var sword := _pivot(hand_r, Vector3.ZERO)
	sword.rotation.x = 1.25
	_part(sword, _cylinder(0.018, 0.018, 0.14), _toon(Color(0.25, 0.15, 0.08)), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3.ONE, false)
	_part(sword, _box(Vector3(0.18, 0.025, 0.04)), _toon(gold, 0.3), Vector3(0, -0.08, 0))
	_part(sword, _sphere(0.025), _toon(gold, 0.3), Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, false)
	_part(sword, _box(Vector3(0.045, 0.82, 0.012)), _metal(Color(0.82, 0.84, 0.9)), Vector3(0, -0.5, 0))
	_part(sword, _box(Vector3(0.008, 0.78, 0.014)), _glow(violet, 3.0), Vector3(0.024, -0.5, 0), Vector3.ZERO, Vector3.ONE, false)
	# Fragments d'espace en orbite.
	var orbit := _pivot(self, Vector3(0, 1.05, 0))
	for i in 3:
		var a := TAU * i / 3.0
		_part(orbit, _box(Vector3(0.08, 0.08, 0.08)), _glow(violet, 4.0), Vector3(cos(a) * 0.6, 0.15 * i - 0.1, sin(a) * 0.6), Vector3(45, 45, 0), Vector3.ONE, false)
	spinners.append(orbit)


# --- Lucie : médecin du temple, la Chair ---------------------------------------

func _build_lucie() -> void:
	var h := 0.97
	var white := Color(0.93, 0.92, 0.88)
	var red := Color(0.72, 0.1, 0.14)
	var skin := Color(0.95, 0.8, 0.7)
	var hair := Color(0.55, 0.2, 0.09)
	var leather := Color(0.36, 0.22, 0.12)
	var rose := Emotions.color("amour")
	_skeleton(h, 0.21)
	_legs(Color(0.25, 0.2, 0.2), Color(0.3, 0.18, 0.1), h)
	# Blouse longue de médecin, croix rouge dans le dos et sur le brassard.
	_part(torso, _cylinder(0.17, 0.15, 0.56 * h), _toon(white), Vector3(0, 0.29 * h, 0))
	_part(hips, _cylinder(0.16, 0.36, 0.78 * h), _toon(white), Vector3(0, -0.37 * h, 0))
	_part(torso, _box(Vector3(0.05, 0.2, 0.02)), _flat(red), Vector3(0, 0.33 * h, 0.165), Vector3(-4, 0, 0), Vector3.ONE, false)
	_part(torso, _box(Vector3(0.16, 0.05, 0.02)), _flat(red), Vector3(0, 0.36 * h, 0.165), Vector3(-4, 0, 0), Vector3.ONE, false)
	_part(hips, _torus(0.155, 0.19), _toon(leather), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
	_part(hips, _box(Vector3(0.1, 0.09, 0.06)), _toon(leather), Vector3(-0.16, -0.04, -0.06), Vector3(0, 30, 0))
	_part(hips, _box(Vector3(0.18, 0.16, 0.08)), _toon(leather.darkened(0.15)), Vector3(0.2, -0.12, 0.08), Vector3(0, -20, 0))
	_part(torso, _torus(0.1, 0.17), _toon(red), Vector3(0, 0.56 * h, 0), Vector3(-10, 0, 0), Vector3(1, 1.3, 1))
	_part(torso, _box(Vector3(0.06, 0.22, 0.03)), _toon(red), Vector3(0.05, 0.42 * h, -0.17), Vector3(10, 0, 8))
	_arms(white, skin, h, red)
	_face(skin, hair, h, Color(0.2, 0.35, 0.25))
	# Chevelure auburn : calotte, chignon, mèches tombantes.
	_part(head, _sphere(0.148 * h), _toon(hair), Vector3(0, 0.17 * h, 0.02), Vector3.ZERO, Vector3(1.04, 0.85, 1.06))
	_part(head, _sphere(0.08 * h), _toon(hair), Vector3(0, 0.2 * h, 0.15 * h))
	for side in [-1.0, 1.0]:
		_part(head, _capsule(0.035 * h, 0.26 * h), _toon(hair), Vector3(0.11 * side * h, 0.04 * h, -0.05 * h), Vector3(8, 0, 6 * side))
	# Orbe de chair rose au creux de la main.
	var orb := _part(hand_r, _sphere(0.07), _glow(rose, 4.0), Vector3(0, -0.06, -0.05), Vector3.ZERO, Vector3.ONE, false)
	var wisps := CsFlux.aura(orb, Vector3.ZERO, "amour", 0.25)
	var pm := wisps.process_material as ParticleProcessMaterial
	pm.scale_min *= 0.25  # volutes discrètes autour de l'orbe
	pm.scale_max *= 0.25
	pm.gravity = Vector3(0, 0.4, 0)


# --- Nicolas : disciple de Fradiel, le Temps ------------------------------------

func _build_nicolas() -> void:
	_caster = true
	var h := 1.02
	var brown := Color(0.36, 0.22, 0.12)
	var mustard := Color(0.72, 0.55, 0.2)
	var brass := Color(0.88, 0.66, 0.28)
	var skin := Color(0.88, 0.72, 0.6)
	var hair := Color(0.2, 0.14, 0.1)
	var gold := Emotions.color("joie")
	_skeleton(h, 0.24)
	_legs(Color(0.3, 0.3, 0.32), Color(0.07, 0.06, 0.06), h)
	# Redingote, gilet moutarde à boutons de laiton, queue-de-pie.
	_part(torso, _cylinder(0.2, 0.17, 0.56 * h), _toon(brown), Vector3(0, 0.29 * h, 0))
	_part(torso, _box(Vector3(0.18, 0.4 * h, 0.04)), _toon(mustard), Vector3(0, 0.27 * h, -0.17), Vector3(4, 0, 0))
	for i in 3:
		_part(torso, _sphere(0.018), _metal(brass), Vector3(0, (0.16 + 0.1 * i) * h, -0.195), Vector3.ZERO, Vector3.ONE, false)
	_part(torso, _torus(0.12, 0.17), _toon(brown.darkened(0.25)), Vector3(0, 0.56 * h, 0), Vector3.ZERO, Vector3(1, 1.2, 1))
	_part(hips, _cylinder(0.18, 0.2, 0.18 * h), _toon(brown), Vector3(0, -0.05 * h, 0))
	var tails := _pivot(hips, Vector3(0, -0.05 * h, 0.13))
	_part(tails, _curved_panel(0.34, 0.26, 0.6 * h, 0.08), _toon(brown, 0.8, false, true), Vector3.ZERO)
	# Chaîne de montre à gousset.
	_part(torso, _torus(0.05, 0.06), _metal(brass), Vector3(0.08, 0.15 * h, -0.19), Vector3(70, 0, 30), Vector3.ONE, false)
	_arms(brown, skin, h, brown.darkened(0.3))
	_face(skin, hair, h)
	# Barbe courte, monocle, haut-de-forme à lunettes de laboratoire.
	_part(head, _sphere(0.1 * h), _toon(hair), Vector3(0, 0.06 * h, -0.05 * h), Vector3.ZERO, Vector3(1.15, 0.8, 1.0))
	_part(head, _sphere(0.142 * h), _toon(hair), Vector3(0, 0.16 * h, 0.03), Vector3.ZERO, Vector3(1.02, 0.7, 1.0))
	_part(head, _torus(0.022, 0.03), _metal(brass), Vector3(0.048 * h, 0.14 * h, -0.13 * h), Vector3(90, 0, 0), Vector3.ONE, false)
	var hat := _pivot(head, Vector3(0, 0.26 * h, 0))
	_part(hat, _cylinder(0.2, 0.2, 0.02), _toon(Color(0.08, 0.07, 0.07)), Vector3.ZERO)
	_part(hat, _cylinder(0.12, 0.13, 0.24), _toon(Color(0.08, 0.07, 0.07)), Vector3(0, 0.12, 0))
	_part(hat, _cylinder(0.133, 0.133, 0.045), _toon(Color(0.4, 0.25, 0.12)), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3.ONE, false)
	for side in [-1.0, 1.0]:
		_part(hat, _torus(0.03, 0.045), _metal(brass), Vector3(0.05 * side, 0.05, -0.125), Vector3(90, 0, 0), Vector3.ONE, false)
	# Canne à pommeau de laiton.
	var cane := _pivot(hand_r, Vector3.ZERO)
	cane.rotation.x = 0.15
	_part(cane, _cylinder(0.014, 0.014, 0.95), _toon(Color(0.12, 0.08, 0.05)), Vector3(0, -0.42, 0), Vector3.ZERO, Vector3.ONE, false)
	_part(cane, _sphere(0.035), _metal(brass), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3.ONE, false)
	# Cadran flottant au-dessus de lui : l'aiguille suit sa jauge (pilotée par Combatant).
	var dial := _pivot(self, Vector3(0, 2.2, 0.25))
	dial.scale = Vector3.ONE * 0.6
	_part(dial, _torus(0.42, 0.47), _glow(gold, 2.2), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	for i in 12:
		var a := TAU * i / 12.0
		var tick := _part(dial, _box(Vector3(0.03, 0.08 if i % 3 == 0 else 0.04, 0.02)), _glow(gold, 3.0 if i % 3 == 0 else 1.5),
			Vector3(sin(a) * 0.36, cos(a) * 0.36, 0), Vector3.ZERO, Vector3.ONE, false)
		tick.rotation.z = -a
	clock_hand = _pivot(dial, Vector3.ZERO)
	_part(clock_hand, _box(Vector3(0.035, 0.3, 0.02)), _glow(Color(1, 0.95, 0.8), 4.0), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, false)
	head_height = 1.75


# --- Fabriques ----------------------------------------------------------------

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## `outline = false` retire le contour (trop épais sur les petites pièces).
func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE, outline := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if not outline and mat.next_pass:
		mat = mat.duplicate()
		mat.next_pass = null
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Matériau cel-shading avec liseré de lumière et contour noir (coque inversée).
func _toon(color: Color, roughness := 0.75, outline := true, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.45
	m.rim_tint = 0.6
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if outline:
		m.next_pass = _outline
	return m


func _metal(color: Color) -> StandardMaterial3D:
	var m := _toon(color, 0.3, false)
	m.metallic = 0.85
	return m


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Panneau de tissu incurvé (cape, pans de manteau), suspendu par son bord haut
## et bombé vers l'arrière (+Z).
func _curved_panel(top_w: float, bottom_w: float, height: float, bulge: float, cols := 10, rows := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows + 1:
		var t := float(r) / rows
		var w := lerpf(top_w, bottom_w, t)
		for c in cols + 1:
			var u := float(c) / cols
			var z := bulge * sin(u * PI) * (0.5 + 0.5 * t) + t * 0.06
			st.set_uv(Vector2(u, t))
			st.add_vertex(Vector3((u - 0.5) * w, -t * height, z))
	for r in rows:
		for c in cols:
			var i := r * (cols + 1) + c
			st.add_index(i)
			st.add_index(i + cols + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + cols + 1)
			st.add_index(i + cols + 2)
	st.generate_normals()
	return st.commit()


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(height, radius * 2.0)
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
