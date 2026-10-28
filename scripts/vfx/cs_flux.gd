class_name CsFlux
extends RefCounted
## Fabrique d'effets visuels de Credo Sum.
## D'après le Lore : matière translucide qui distord la lumière, lumière blanche
## teintée par l'émotion, mouvements fractals, dynamiques concentriques autour
## du Réceptacle traversé.

const DISTORTION_SHADER := preload("res://shaders/cs_distortion.gdshader")

static var _soft_tex: Texture2D


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft_tex = t
	return _soft_tex


## Explosion ponctuelle de flux : particules + ondes concentriques (+ éclairs pour la Colère).
static func burst(parent: Node, pos: Vector3, emotion: String, intensity := 1.0) -> void:
	var p := make_particles(emotion, intensity, true)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, p.lifetime + 0.6)
	ring_wave(parent, Vector3(pos.x, 0.06, pos.z), emotion, 1.6 * intensity, 0.0)
	if intensity >= 1.0:
		ring_wave(parent, Vector3(pos.x, 0.06, pos.z), emotion, 2.4 * intensity, 0.12)
	if Emotions.style(emotion) == "eclair":
		for i in int(2 + intensity * 2):
			var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
			lightning(parent, pos, pos + dir * randf_range(0.8, 1.6) * intensity, Emotions.color(emotion), 0.35)


## Émission continue (aura d'un Foyer de CS ou d'un personnage qui canalise).
static func aura(parent: Node3D, offset: Vector3, emotion: String, intensity := 0.6) -> GPUParticles3D:
	var p := make_particles(emotion, intensity, false)
	parent.add_child(p)
	p.position = offset
	p.emitting = true
	return p


static func make_particles(emotion: String, intensity: float, one_shot: bool) -> GPUParticles3D:
	var col := Emotions.color(emotion)
	var core := Emotions.core(emotion)
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	var additive := true
	var glow := 2.2
	p.amount = 48
	p.lifetime = 1.0
	p.one_shot = one_shot
	p.explosiveness = 0.85 if one_shot else 0.0
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.3
	m.direction = Vector3.UP
	m.spread = 180.0
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.2
	m.turbulence_noise_scale = 1.6
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.25
	match Emotions.style(emotion):
		"etincelle":  # Joie : étincelles
			p.amount = 90
			p.lifetime = 0.9
			m.initial_velocity_min = 2.0
			m.initial_velocity_max = 5.0
			m.gravity = Vector3(0, -5.0, 0)
			m.damping_min = 1.5
			m.damping_max = 3.0
			m.scale_min = 0.05
			m.scale_max = 0.13
			glow = 3.0
		"plasma":  # Crainte et Adoration : plasma tourbillonnant
			p.amount = 70
			p.lifetime = 1.2
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			m.emission_ring_axis = Vector3.UP
			m.emission_ring_radius = 0.9
			m.emission_ring_inner_radius = 0.5
			m.emission_ring_height = 0.2
			m.initial_velocity_min = 0.4
			m.initial_velocity_max = 1.4
			m.gravity = Vector3(0, 0.8, 0)
			m.tangential_accel_min = 3.0
			m.tangential_accel_max = 6.0
			m.radial_accel_min = -1.5
			m.radial_accel_max = -0.5
			m.turbulence_influence_max = 0.4
			m.scale_min = 0.12
			m.scale_max = 0.32
		"fumee":  # Amour : fumée légère
			p.amount = 40
			p.lifetime = 1.8
			m.initial_velocity_min = 0.3
			m.initial_velocity_max = 1.0
			m.gravity = Vector3(0, 0.9, 0)
			m.damping_min = 0.5
			m.damping_max = 1.0
			m.scale_min = 0.35
			m.scale_max = 0.8
			glow = 1.4
		"vapeur":  # Peur et Dégoût : vapeur lourde
			p.amount = 46
			p.lifetime = 2.2
			m.initial_velocity_min = 0.3
			m.initial_velocity_max = 1.1
			m.gravity = Vector3(0, -0.35, 0)
			m.damping_min = 0.4
			m.damping_max = 0.9
			m.scale_min = 0.5
			m.scale_max = 1.2
			additive = false
			glow = 1.3
		"liquide":  # Tristesse : liquide
			p.amount = 60
			p.lifetime = 1.1
			m.direction = Vector3.UP
			m.spread = 40.0
			m.initial_velocity_min = 2.0
			m.initial_velocity_max = 4.0
			m.gravity = Vector3(0, -9.0, 0)
			m.scale_min = 0.07
			m.scale_max = 0.15
		"flamme":  # Haine : flamme
			p.amount = 70
			p.lifetime = 0.9
			m.direction = Vector3.UP
			m.spread = 25.0
			m.initial_velocity_min = 1.5
			m.initial_velocity_max = 3.0
			m.gravity = Vector3(0, 1.5, 0)
			m.scale_min = 0.2
			m.scale_max = 0.45
		"eclair":  # Colère : éclats rapides (les éclairs sont ajoutés à part)
			p.amount = 60
			p.lifetime = 0.5
			m.initial_velocity_min = 3.0
			m.initial_velocity_max = 7.0
			m.gravity = Vector3(0, -3.0, 0)
			m.damping_min = 4.0
			m.damping_max = 6.0
			m.scale_min = 0.05
			m.scale_max = 0.12
			glow = 3.0
	p.amount = maxi(8, int(p.amount * clampf(intensity, 0.3, 2.0)))

	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.25, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = shrink
	m.scale_curve = curve_tex

	var g := Gradient.new()
	g.set_color(0, Color(core.r * glow, core.g * glow, core.b * glow, 1.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.3, Color(col.r * glow, col.g * glow, col.b * glow, 0.85))
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	m.color_ramp = ramp
	p.process_material = m

	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true  # sinon l'échelle des particules est ignorée
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft_texture()
	quad.material = mat
	p.draw_pass_1 = quad
	return p


## Onde concentrique au sol, qui s'élargit et s'efface.
static func ring_wave(parent: Node, pos: Vector3, emotion: String, radius := 2.0, delay := 0.0) -> void:
	var col := Emotions.color(emotion)
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.r * 2.5, col.g * 2.5, col.b * 2.5, 0.9)
	mi.mesh = torus
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.05, 0.05, 0.05)
	var tw := mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mi, "scale", Vector3(radius, 0.15, radius), 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(mi.queue_free)


## Bulle de distorsion translucide (le flux rendu visible autour du Réceptacle).
static func distortion(parent: Node, pos: Vector3, emotion: String, radius := 1.2, duration := 0.8, implode := false) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var mat := ShaderMaterial.new()
	mat.shader = DISTORTION_SHADER
	mat.set_shader_parameter("tint", Emotions.color(emotion))
	mat.set_shader_parameter("intensity", 0.0)
	mi.mesh = sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var start := radius if implode else radius * 0.3
	var end := radius * 0.15 if implode else radius
	mi.scale = Vector3.ONE * start
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * end, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT if implode else Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 0.0, 1.0, duration * 0.3)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 1.0, 0.0, duration * 0.5).set_delay(duration * 0.5)
	tw.chain().tween_callback(mi.queue_free)


static func lightning(parent: Node, from: Vector3, to: Vector3, color: Color, duration := 0.4) -> void:
	var l := CsLightning.new()
	l.from = from
	l.to = to
	l.color = color
	l.duration = duration
	parent.add_child(l)


## Orbe lumineux qui voyage d'un point à un autre (sorts à distance).
static func projectile(parent: Node, from: Vector3, to: Vector3, emotion: String, duration := 0.35) -> Tween:
	var col := Emotions.color(emotion)
	var orb := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.28
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r * 4.0, col.g * 4.0, col.b * 4.0)
	orb.mesh = s
	orb.material_override = mat
	parent.add_child(orb)
	orb.global_position = from
	var trail := make_particles(emotion, 0.5, false)
	trail.lifetime = 0.4
	orb.add_child(trail)
	trail.emitting = true
	var tw := orb.create_tween()
	tw.tween_property(orb, "global_position", to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(orb.queue_free)
	return tw


static func _free_later(node: Node, delay: float) -> void:
	node.get_tree().create_timer(delay).timeout.connect(node.queue_free)
