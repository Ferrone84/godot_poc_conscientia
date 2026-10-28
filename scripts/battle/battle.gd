extends Node3D
## Combat au tour par tour avec QTE (POC Conscientia).
## - L'ordre des tours dépend de la vitesse de chacun (chronologie prédictive).
## - Les alliés dépensent des PA en compétences ; l'attaque de base et la parade en rendent.
## - Pendant les attaques ennemies, chaque coup se pare [E] ou s'esquive [Espace] ;
##   parer tous les coups d'une attaque déclenche une contre-attaque.
## Lancer avec `-- --autotest` pour un combat joué automatiquement (validation) ;
## ajouter `--fast` pour accélérer et `--qte-miss` pour rater tous les QTE.
## `-- --demo` joue un combat scénarisé et sous-titré, à enregistrer en vidéo (voir DemoDirector).

const PA_PER_TURN := 1
const DEFAULT_LOOK := Vector3(0.8, 0.2, -0.6)  # doit correspondre au cadrage d'Arena
const GOLD := Color(1.0, 0.85, 0.45)

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var ui: BattleUI
var qte: QteOverlay
var camera: Camera3D
var env: Environment
var current_time := 0.0
var turn_count := 0
var autotest := false
var demo: DemoDirector

var _last_breath_used := false
var _over := false
var _cam_base_pos := Vector3.ZERO
var _cam_look := DEFAULT_LOOK
var _cam_focus := DEFAULT_LOOK
var _shake := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args
	if "--demo" in args:
		demo = DemoDirector.new()
		seed(DemoDirector.SEED)
	if "--fast" in args:
		Engine.time_scale = 3.0
	_setup_input()
	var world := Arena.build(self)
	camera = world["camera"]
	env = world["environment"]
	_cam_base_pos = camera.position
	_spawn()
	if demo:
		_find_ally("nicolas").tokens = DemoDirector.NICOLAS_TOKENS
	ui = BattleUI.new()
	add_child(ui)
	ui.setup(allies, enemies)
	ui.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	qte = ui.qte
	qte.autoplay = autotest or demo != null
	qte.autoplay_miss = "--qte-miss" in args
	qte.demo = demo != null
	_battle_loop()


func _process(delta: float) -> void:
	_cam_look = _cam_look.lerp(_cam_focus, minf(1.0, delta * 3.0))
	var drift := (_cam_look - DEFAULT_LOOK) * 0.3
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.12
	camera.position = _cam_base_pos + drift + shake
	camera.look_at(_cam_look)
	_shake = maxf(0.0, _shake - delta * 2.5)


func _setup_input() -> void:
	_bind_key("qte_attack", KEY_SPACE)
	_bind_key("qte_dodge", KEY_SPACE)
	_bind_key("qte_parry", KEY_E)


func _bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _spawn() -> void:
	var ally_setup := [["ceran", Vector3(-3.0, 0, 0.0)], ["lucie", Vector3(-3.7, 0, -2.0)], ["nicolas", Vector3(-3.7, 0, 2.0)]]
	for entry in ally_setup:
		var c := Combatant.new()
		c.setup(entry[0], true)
		add_child(c)
		c.position = entry[1]
		c.home_pos = c.position
		c.look_at(c.global_position + Vector3.RIGHT)
		allies.append(c)
	var enemy_setup := [["altere", Vector3(3.0, 0, -2.3), " A"], ["veilleur", Vector3(4.4, 0, 0.0), ""], ["altere", Vector3(3.0, 0, 2.3), " B"]]
	for entry in enemy_setup:
		var c := Combatant.new()
		c.setup(entry[0], false, entry[2])
		add_child(c)
		c.position = entry[1]
		c.home_pos = c.position
		c.look_at(c.global_position + Vector3.LEFT)
		enemies.append(c)


# --- Boucle de combat ---------------------------------------------------------

func _battle_loop() -> void:
	ui.set_timeline(_predict_order(9))
	if demo:
		await ui.title_card("CONSCIENTIA : APOSTOLI", "Proof of concept — combat au tour par tour avec QTE", 2.2)
	await _wait(0.6)
	ui.banner("Gavillon — un Médian de la Peur s'est éveillé", Emotions.core("peur"))
	await _wait(1.4)
	_demo_caption("intro")
	while not _over:
		var actor := _next_actor()
		current_time = actor.next_time
		turn_count += 1
		ui.set_timeline(_predict_order(9))
		await _start_turn(actor)
		if _check_end():
			break
		if not actor.dead:
			actor.set_highlight("active")
			if actor.is_ally:
				await _ally_turn(actor)
			else:
				await _enemy_turn(actor)
			actor.set_highlight("")
			actor.tick_statuses()
		actor.next_time = current_time + 100.0 / actor.eff_speed()
		if _check_end():
			break
		if (autotest or demo) and turn_count > 400:
			print("AUTOTEST: ABANDON (trop de tours)")
			get_tree().quit(1)
			return


func _next_actor() -> Combatant:
	var best: Combatant = null
	for c in allies + enemies:
		if not c.dead and (best == null or c.next_time < best.next_time):
			best = c
	return best


func _predict_order(n: int) -> Array:
	var sim := {}
	for c in allies + enemies:
		if not c.dead:
			sim[c] = c.next_time
	var out: Array = []
	for i in n:
		var best: Combatant = null
		var best_t := INF
		for c in sim:
			if sim[c] < best_t:
				best_t = sim[c]
				best = c
		if best == null:
			break
		out.append(best)
		sim[best] = best_t + 100.0 / best.eff_speed()
	return out


func _start_turn(c: Combatant) -> void:
	if c.statuses.has("regen"):
		_heal(c, c.statuses["regen"]["value"])
		CsFlux.burst(self, c.body_pos(), "amour", 0.4)
	if c.is_ally:
		c.pa = mini(c.pa + PA_PER_TURN, Combatant.MAX_PA)
	if c.id == "nicolas":
		if c.clock_frozen > 0:
			c.clock_frozen -= 1
		else:
			_clock_shift(c, 1)
	if c.statuses.has("futur"):
		c.statuses["futur"]["turns"] -= 1
		if c.statuses["futur"]["turns"] <= 0:
			var dmg: float = c.statuses["futur"]["value"]
			c.statuses.erase("futur")
			ui.banner("Dégâts futurs : le temps rattrape %s !" % c.display_name, Emotions.core("joie"))
			CsFlux.burst(self, c.body_pos(), "joie", 1.6)
			CsFlux.distortion(self, c.body_pos(), "joie", 1.5, 0.7, true)
			await _wait(0.3)
			var dealt := _apply_damage(c, dmg * c.dmg_taken_mult())
			c.flinch(Vector3.RIGHT)
			_float_text(c.head_pos(), str(int(dealt)), Color(1, 0.85, 0.3), 90)
			_shake = 0.8
			await _wait(0.6)


func _check_end() -> bool:
	if _over:
		return true
	if enemies.all(func(c: Combatant) -> bool: return c.dead):
		_finish(true)
		return true
	if allies.all(func(c: Combatant) -> bool: return c.dead):
		_finish(false)
		return true
	return false


func _finish(victory: bool) -> void:
	_over = true
	ui.hide_actions()
	ui.show_end(victory, turn_count)
	if autotest:
		var summary: PackedStringArray = []
		for c in allies + enemies:
			summary.append("%s=%.1f/%d%s" % [c.display_name, c.hp, int(c.max_hp), " KO" if c.dead else ""])
		print("AUTOTEST: %s en %d tours | %s" % ["VICTOIRE" if victory else "DEFAITE", turn_count, ", ".join(summary)])
		if victory and allies.all(func(c: Combatant) -> bool: return c.dead or c.hp < 1.0):
			print("AUTOTEST: ANOMALIE victoire sans allié debout")
		await _wait(2.0)
		get_tree().quit()
	elif demo:
		print("DEMO: %s en %d tours" % ["VICTOIRE" if victory else "DEFAITE", turn_count])
		await _wait(1.5)
		_demo_caption("outro")
		await _wait(4.5)
		get_tree().quit()


func _demo_caption(key: String) -> void:
	if demo:
		var text := demo.caption_once(key)
		if text != "":
			ui.caption(text)


# --- Tour des alliés ----------------------------------------------------------

func _ally_turn(a: Combatant) -> void:
	var choice: Dictionary
	if demo:
		_demo_caption("hero_" + a.id)
		var planned := demo.choose(a, allies, enemies)
		print("DEMO: tour %d %s -> %s (%s)" % [turn_count, a.display_name, planned["skill"], (planned["target"] as Combatant).display_name])
		if planned["skill"] == SkillDB.basic_attack(a.id):
			_demo_caption("basic")
		ui.show_actions(a)
		ui.play_choice(planned["skill"], planned["target"])
		choice = await ui.action_selected
	elif autotest:
		await _wait(0.4)
		choice = _auto_choice(a)
	else:
		ui.show_actions(a)
		choice = await ui.action_selected
	await _execute(a, choice["skill"], choice["target"])


func _auto_choice(a: Combatant) -> Dictionary:
	var usable: Array = []
	for sid in SkillDB.KITS[a.id]:
		if SkillDB.can_use(sid, a, allies, enemies):
			usable.append(sid)
	var sid: String = SkillDB.basic_attack(a.id)
	if not usable.is_empty() and randf() < 0.7:
		sid = usable.pick_random()
	var target := a
	if SkillDB.needs_target(sid):
		target = SkillDB.valid_targets(sid, a, allies, enemies).pick_random()
	return {"skill": sid, "target": target}


func _execute(user: Combatant, sid: String, target: Combatant) -> void:
	var sk: Dictionary = SkillDB.SKILLS[sid]
	user.pa -= int(sk["cost"])
	user.tokens -= int(sk.get("tokens", 0))
	ui.banner("%s — %s" % [user.display_name, sk["name"]], Emotions.core(user.emotion))
	match sid:
		# --- Céran ---
		"ceran_frappe":
			await _blink_to(user, target)
			await _strike(user, target, 1.0)
			user.add_gauge(10)
			_gain_pa(user)
			await _blink_home(user)
		"ceran_faille":
			await _blink_to(user, target)
			var r := await _attack_qte(user, target)
			var power := 1.6 * (1.1 if r == "perfect" else 1.0)
			var big := _qte_ok(r) and user.gauge >= 30.0
			if big:
				user.gauge -= 30.0
				power *= 2.0
				qte.popup("Faille béante", _screen(target.head_pos()) + Vector2(0, -40), Emotions.core("crainte"))
			CsFlux.distortion(self, target.body_pos(), "crainte", 1.8 if big else 1.0, 0.7)
			await _strike(user, target, power, big)
			user.add_gauge(20)
			await _blink_home(user)
		"ceran_ancrage":
			var r := await _attack_qte(user, target)
			var turns := 2
			if _qte_ok(r) and user.gauge >= 20.0:
				user.gauge -= 20.0
				turns = 3
				target.next_time += 4.0
				qte.popup("Repoussé dans le temps", _screen(target.head_pos()) + Vector2(0, -40), Emotions.core("crainte"), 22)
			CsFlux.distortion(self, target.body_pos(), "crainte", 1.4, 0.8, true)
			for i in 3:
				CsFlux.ring_wave(self, Vector3(target.global_position.x, 0.06, target.global_position.z), "crainte", 1.2, i * 0.15)
			await _strike(user, target, 0.5)
			_give_status(user, target, "ancre", turns)
			user.add_gauge(15)
		"ceran_effondrement":
			await _blink_to(user, target)
			var r := await _attack_qte(user, target)
			var power := 2.5 * (1.1 if r == "perfect" else 1.0)
			if _qte_ok(r) and user.gauge > 0.0:
				qte.popup("Distorsion %d consommée" % int(user.gauge), _screen(target.head_pos()) + Vector2(0, -40), Emotions.core("crainte"), 22)
				power *= 1.0 + user.gauge / 100.0
				user.gauge = 0.0
			CsFlux.distortion(self, target.body_pos(), "crainte", 3.2, 0.9, true)
			CsFlux.burst(self, target.body_pos(), "crainte", 1.5)
			await _wait(0.55)
			await _strike(user, target, power, true)
			_shake = 1.2
			await _blink_home(user)
		# --- Lucie ---
		"lucie_frappe":
			await _move(user, _front_of(user, target), 0.35)
			await _strike(user, target, 1.0)
			user.add_gauge(-10)
			_gain_pa(user)
			await _move(user, user.home_pos, 0.35)
		"lucie_suture":
			await _move(user, _front_of(user, target), 0.35)
			var r := await _attack_qte(user, target)
			var power := 1.4 * _qte_mult(r)
			if target.hp_ratio() < 0.5:
				power *= 1.5
			await _strike(user, target, power, target.hp_ratio() < 0.5)
			user.add_gauge(-20)
			await _move(user, user.home_pos, 0.35)
		"lucie_hyperplasie":
			var r := await _attack_qte(user, target)
			var per_turn := target.max_hp * 0.09 * user.lucie_heal_mult() * _qte_mult(r)
			await _projectile(user, target, "amour")
			CsFlux.burst(self, target.body_pos(), "amour", 0.9)
			_give_status(user, target, "regen", 3, per_turn)
			_float_text(target.head_pos(), "+%d / tour" % int(per_turn), Color(1, 0.7, 0.85), 48)
			user.add_gauge(15)
		"lucie_greffe":
			var donors := allies.filter(func(c: Combatant) -> bool: return not c.dead and c != target)
			if donors.is_empty():
				qte.popup("Aucun donneur", _screen(target.head_pos()), Color(0.8, 0.8, 0.8))
			else:
				donors.sort_custom(func(x: Combatant, y: Combatant) -> bool: return x.hp_ratio() > y.hp_ratio())
				var donor: Combatant = donors[0]
				var amount := donor.hp * 0.25
				donor.take_damage(amount)
				_float_text(donor.head_pos(), "-%d" % int(amount), Color(1, 0.6, 0.6), 48)
				await _projectile(donor, target, "amour")
				_heal(target, amount * user.lucie_heal_mult())
				CsFlux.burst(self, target.body_pos(), "amour", 0.7)
			user.add_gauge(10)
		"lucie_appel":
			CsFlux.burst(self, target.body_pos(), "amour", 1.5)
			CsFlux.distortion(self, target.body_pos(), "amour", 1.4, 1.0)
			await _wait(0.4)
			target.revive(clampf(0.35 * user.lucie_heal_mult(), 0.1, 0.7))
			_float_text(target.head_pos(), "Relevé", Color(1, 0.8, 0.9), 56)
			target.next_time = maxf(target.next_time, current_time + 1.0)
			user.add_gauge(20)
		"lucie_retour":
			user.gauge = 0.0
			CsFlux.ring_wave(self, Vector3(user.global_position.x, 0.06, user.global_position.z), "amour", 1.5)
		"lucie_exces":
			var center := _party_center()
			var r := await _attack_qte(user, user, center)
			var mult := user.lucie_heal_mult() * _qte_mult(r)
			CsFlux.distortion(self, center + Vector3(0, 1, 0), "amour", 3.5, 1.2)
			for i in 3:
				CsFlux.ring_wave(self, Vector3(center.x, 0.06, center.z), "amour", 3.0, i * 0.2)
			await _wait(0.4)
			for a in allies:
				if not a.dead:
					_heal(a, a.max_hp * 0.6 * mult)
					a.shield += a.max_hp * 0.25
					CsFlux.burst(self, a.body_pos(), "amour", 1.0)
			user.add_gauge(30)
		# --- Nicolas ---
		"nicolas_frappe":
			await _projectile(user, target, "joie")
			await _strike(user, target, 1.0)
			_gain_pa(user)
		"nicolas_onde":
			var aoe := _clock_special(user)
			var r := await _attack_qte(user, target)
			var targets := _living(enemies) if aoe else [target]
			if aoe:
				qte.popup("%dh : onde sur tous !" % int(user.gauge), _screen(target.head_pos()) + Vector2(0, -40), Emotions.core("joie"), 22)
			for t in targets:
				CsFlux.projectile(self, user.body_pos(), (t as Combatant).body_pos(), "joie", 0.3)
			await _wait(0.3)
			for t in targets:
				await _strike(user, t, 1.3 * _qte_mult(r), false)
		"nicolas_ralenti":
			var targets := _living(enemies) if _clock_special(user) else [target]
			for t in targets:
				var u := t as Combatant
				CsFlux.distortion(self, u.body_pos(), "joie", 1.3, 0.9)
				_give_status(user, u, "lent", 2)
				u.next_time += 3.0
				_float_text(u.head_pos(), "Ralenti", Color(0.7, 0.85, 1.0), 44)
			await _wait(0.6)
		"nicolas_hate":
			CsFlux.burst(self, target.body_pos(), "joie", 0.9)
			_give_status(user, target, "hate", 2)
			target.next_time = current_time + (target.next_time - current_time) * 0.6
			_float_text(target.head_pos(), "Hâte", GOLD, 44)
			await _wait(0.5)
		"nicolas_futur":
			var r := await _attack_qte(user, target)
			var dmg := user.atk * 1.8 * user.dmg_dealt_mult() * _qte_mult(r)
			await _projectile(user, target, "joie")
			if target.statuses.has("futur"):
				target.statuses["futur"]["value"] *= 2.0
				_float_text(target.head_pos(), "Dégâts futurs ×2", GOLD, 44)
			else:
				target.add_status("futur", 3, dmg)
				_float_text(target.head_pos(), "Dans 3 tours…", GOLD, 44)
			for i in 2:
				CsFlux.ring_wave(self, Vector3(target.global_position.x, 0.06, target.global_position.z), "joie", 1.0, i * 0.2)
			await _wait(0.4)
		"nicolas_retour":
			CsFlux.burst(self, target.body_pos(), "joie", 1.2)
			target.next_time = current_time + 0.001
			if int(user.gauge) == 6:
				target.clear_debuffs()
				_float_text(target.head_pos(), "Altérations retirées", Color(0.7, 1, 0.8), 40)
			_float_text(target.head_pos() + Vector3(0, 0.3, 0), "À toi !", GOLD, 56)
			await _wait(0.5)
		"nicolas_arret":
			user.clock_frozen = 2
			var tw := create_tween()
			tw.tween_property(env, "adjustment_saturation", 0.08, 0.3)
			tw.tween_interval(1.0)
			tw.tween_property(env, "adjustment_saturation", 1.0, 0.7)
			for e in _living(enemies):
				var u := e as Combatant
				u.next_time += 100.0 / u.eff_speed()
				CsFlux.distortion(self, u.body_pos(), "joie", 1.6, 1.4)
			for i in 4:
				CsFlux.ring_wave(self, Vector3(0.5, 0.06, 0), "joie", 6.0, i * 0.25)
			_shake = 0.5
			await _wait(1.6)
	if user.id == "nicolas":
		_clock_skill_shift(user, int(sk.get("clock", 0)))
	await _wait(0.25)


# --- Tour des ennemis ---------------------------------------------------------

func _enemy_turn(e: Combatant) -> void:
	var options: Array = Roster.ENEMY_PATTERNS[e.id].filter(
		func(p: Dictionary) -> bool: return not p.has("below_hp") or e.hp_ratio() < float(p["below_hp"]))
	var pat: Dictionary = options.pick_random()
	ui.banner("%s — %s" % [e.display_name, pat["name"]], Emotions.core(e.emotion))
	if demo:
		qte.demo_defense = demo.next_defense()
	await _wait(0.5)
	if pat.get("aoe", false):
		_demo_caption("aoe")
		await _enemy_aoe(e, pat)
	else:
		_demo_caption("defend")
		var target: Combatant = _living(allies).pick_random()
		await _enemy_combo(e, target, pat)


func _enemy_combo(e: Combatant, target: Combatant, pat: Dictionary) -> void:
	target.set_highlight("target")
	_cam_focus = DEFAULT_LOOK.lerp(target.body_pos(), 0.5)
	await _move(e, _front_of(e, target), 0.45)
	var all_parried := true
	var power: float = pat["power"]
	for w in pat["hits"]:
		if target.dead or e.dead:
			break
		var windup: float = float(w) * randf_range(0.9, 1.15)
		var lean := e.create_tween()
		lean.tween_property(e.model, "rotation_degrees:x", 22.0, windup * 0.9).set_trans(Tween.TRANS_SINE)
		var res := await qte.run_defend(_screen(target.body_pos()), windup, Emotions.color(e.emotion))
		var lunge := e.create_tween()
		lunge.tween_property(e.model, "rotation_degrees:x", -25.0, 0.06)
		lunge.parallel().tween_property(e.model, "position:z", -0.5, 0.06)
		lunge.tween_property(e.model, "rotation_degrees:x", 0.0, 0.2)
		lunge.parallel().tween_property(e.model, "position:z", 0.0, 0.2)
		match res:
			"parry":
				_on_parry(target, e)
			"dodge":
				all_parried = false
				var side := target.create_tween()
				side.tween_property(target.model, "position:x", 0.6, 0.08)
				side.tween_property(target.model, "position:x", 0.0, 0.25)
			_:
				all_parried = false
				var raw := e.atk * power * e.dmg_dealt_mult() * randf_range(0.9, 1.1)
				var dealt := _apply_damage(target, raw * target.dmg_taken_mult())
				CsFlux.burst(self, target.body_pos(), e.emotion, 0.8)
				target.flinch(target.global_position - e.global_position)
				_float_text(target.head_pos(), str(int(dealt)), Color(1, 0.4, 0.35), 64)
				_shake = maxf(_shake, 0.4)
		await _wait(0.15)
	target.set_highlight("")
	if all_parried and not target.dead and not e.dead:
		await _counter(target, e)
	_cam_focus = DEFAULT_LOOK
	await _move(e, e.home_pos, 0.4)


func _enemy_aoe(e: Combatant, pat: Dictionary) -> void:
	var center := _party_center()
	_cam_focus = DEFAULT_LOOK.lerp(center, 0.4)
	var windup: float = float(pat["hits"][0]) * randf_range(0.9, 1.15)
	CsFlux.distortion(self, e.body_pos(), e.emotion, 2.2, windup)
	var res := await qte.run_defend(_screen(center + Vector3(0, 1.0, 0)), windup, Emotions.color(e.emotion))
	CsFlux.burst(self, e.body_pos(), e.emotion, 2.0)
	for i in 3:
		CsFlux.ring_wave(self, Vector3(e.global_position.x, 0.06, e.global_position.z), e.emotion, 9.0, i * 0.12)
	_shake = 0.7
	await _wait(0.3)
	for a in _living(allies):
		var u := a as Combatant
		match res:
			"parry":
				_on_parry(u, e)
			"dodge":
				pass
			_:
				var raw := e.atk * float(pat["power"]) * e.dmg_dealt_mult() * randf_range(0.9, 1.1)
				var dealt := _apply_damage(u, raw * u.dmg_taken_mult())
				CsFlux.burst(self, u.body_pos(), e.emotion, 0.6)
				u.flinch(u.global_position - e.global_position)
				_float_text(u.head_pos(), str(int(dealt)), Color(1, 0.4, 0.35), 60)
				if pat.has("status") and not u.dead:
					u.add_status(pat["status"], 2)
	_cam_focus = DEFAULT_LOOK
	await _wait(0.5)


func _on_parry(a: Combatant, e: Combatant) -> void:
	var mid := a.body_pos().lerp(e.body_pos(), 0.35)
	a.anim("parry")
	CsFlux.burst(self, mid, "joie", 0.5)
	CsFlux.burst(self, mid, a.emotion, 0.4)
	_gain_pa(a)
	if a.id == "ceran":
		a.add_gauge(5)
	_shake = maxf(_shake, 0.3)


func _counter(a: Combatant, e: Combatant) -> void:
	ui.banner("Contre-attaque de %s !" % a.display_name, GOLD)
	qte.popup("CONTRE !", _screen(a.head_pos()), GOLD, 38)
	_demo_caption("counter")
	await _wait(0.25)
	await _strike(a, e, 1.5, true)
	if a.id == "ceran":
		a.add_gauge(10)


# --- Effets de règles -----------------------------------------------------------

func _strike(user: Combatant, target: Combatant, power: float, heavy := false) -> float:
	if target.dead:
		return 0.0
	var raw := user.atk * power * user.dmg_dealt_mult() * randf_range(0.92, 1.08)
	user.anim("attack")
	var lunge := user.create_tween()
	lunge.tween_property(user.model, "position:z", -0.35, 0.06)
	lunge.tween_property(user.model, "position:z", 0.0, 0.18)
	if user.is_ally:
		await _wait(0.1)  # l'arme s'abat avant l'impact
	var dealt := _apply_damage(target, raw * target.dmg_taken_mult())
	CsFlux.burst(self, target.body_pos(), user.emotion, 1.4 if heavy else 0.8)
	target.flinch(target.global_position - user.global_position)
	_float_text(target.head_pos(), str(int(dealt)), Color(1, 0.9, 0.6) if heavy else Color.WHITE, 90 if heavy else 64)
	_shake = maxf(_shake, 0.6 if heavy else 0.25)
	await _wait(0.3)
	return dealt


## Passif de Lucie "Dernier souffle" : le premier allié qui devrait mourir reste à 1 PV.
func _apply_damage(target: Combatant, amount: float) -> float:
	if target.is_ally and not _last_breath_used and target.hp > 1.0 and amount >= target.hp + target.shield:
		var lucie := _find_ally("lucie")
		if lucie and not lucie.dead:
			_last_breath_used = true
			amount = target.hp + target.shield - 1.0
			_float_text(target.head_pos() + Vector3(0, 0.4, 0), "Dernier souffle", Emotions.core("amour"), 50)
	return target.take_damage(amount)


func _heal(target: Combatant, amount: float) -> void:
	var h := target.heal(amount)
	if h > 0.0:
		_float_text(target.head_pos(), "+%d" % int(h), Color(0.5, 1.0, 0.6), 60)


func _give_status(source: Combatant, target: Combatant, status: String, turns: int, value := 0.0) -> void:
	# Les altérations se décomptent en fin de tour de leur porteur : on compense
	# quand le lanceur se cible lui-même pendant son propre tour.
	target.add_status(status, turns + (1 if source == target else 0), value)


func _gain_pa(a: Combatant) -> void:
	a.pa = mini(a.pa + 1, Combatant.MAX_PA)


func _qte_ok(r: String) -> bool:
	return r == "perfect" or r == "good"


func _qte_mult(r: String) -> float:
	match r:
		"perfect": return 1.25
		"good": return 1.1
	return 0.9


func _clock_special(n: Combatant) -> bool:
	return int(n.gauge) in [3, 6, 9]


func _clock_shift(n: Combatant, amount: int) -> void:
	if amount == 0 or n.clock_frozen > 0:
		return
	var h := int(n.gauge) + amount
	while h >= 12:
		h -= 12
		if n.tokens < 3:
			n.tokens += 1
			_float_text(n.head_pos() + Vector3(0, 0.4, 0), "+1 jeton", GOLD, 44)
	while h < 0:
		h += 12
	n.gauge = h


## Règle de l'horloge : heure paire -> l'aiguille avance, heure impaire -> elle recule.
func _clock_skill_shift(n: Combatant, amount: int) -> void:
	if amount == 0:
		return
	_clock_shift(n, amount if int(n.gauge) % 2 == 0 else -amount)


# --- Mise en scène --------------------------------------------------------------

func _attack_qte(user: Combatant, target: Combatant, world_anchor := Vector3.INF) -> String:
	CsFlux.burst(self, user.body_pos(), user.emotion, 0.5)
	var anchor := target.body_pos() if world_anchor == Vector3.INF else world_anchor + Vector3(0, 1.0, 0)
	var duration := randf_range(0.75, 0.95)
	user.anim("charge", duration)
	_demo_caption("qte_attack")
	var r := await qte.run_attack(_screen(anchor), duration, Emotions.color(user.emotion))
	return r


## Céran se déplace en repliant l'espace : il disparaît et réapparaît.
func _blink_to(user: Combatant, target: Combatant) -> void:
	await _blink(user, _front_of(user, target))


func _blink_home(user: Combatant) -> void:
	await _blink(user, user.home_pos)


func _blink(user: Combatant, dest: Vector3) -> void:
	CsFlux.burst(self, user.body_pos(), "crainte", 0.6)
	CsFlux.distortion(self, user.body_pos(), "crainte", 0.9, 0.4, true)
	user.model.visible = false
	await _wait(0.14)
	user.global_position = dest
	user.model.visible = true
	CsFlux.burst(self, user.body_pos(), "crainte", 0.6)
	CsFlux.distortion(self, user.body_pos(), "crainte", 0.9, 0.4)
	await _wait(0.12)


func _move(c: Combatant, dest: Vector3, duration: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", dest, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _projectile(from: Combatant, to: Combatant, emotion: String) -> void:
	from.anim("cast")
	var tw := CsFlux.projectile(self, from.body_pos(), to.body_pos(), emotion, 0.32)
	await tw.finished


func _front_of(mover: Combatant, target: Combatant) -> Vector3:
	var dir := mover.home_pos - target.global_position
	dir.y = 0.0
	dir = dir.normalized()
	var dist := 1.4 + (0.8 if target.id == "veilleur" else 0.0) + (0.6 if mover.id == "veilleur" else 0.0)
	return target.global_position + dir * dist


func _party_center() -> Vector3:
	var sum := Vector3.ZERO
	for a in allies:
		sum += a.home_pos
	return sum / allies.size()


func _float_text(pos: Vector3, text: String, color: Color, font_size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0045
	l.outline_size = 14
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	add_child(l)
	l.position = pos + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.8, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func _screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


func _living(list: Array) -> Array:
	return list.filter(func(c: Combatant) -> bool: return not c.dead)


func _find_ally(char_id: String) -> Combatant:
	for a in allies:
		if a.id == char_id:
			return a
	return null


func _wait(seconds: float) -> void:
	# process_always = false : les attentes se figent quand le menu Options met le jeu en pause.
	await get_tree().create_timer(seconds, false).timeout
