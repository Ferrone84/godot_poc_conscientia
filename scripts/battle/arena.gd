class_name Arena
extends RefCounted
## Construit le décor du combat : une place de Gavillon en ruine, la nuit,
## avec des cheminées d'usine au loin (époque de révolution industrielle).

static func build(root: Node3D) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.6)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.09, 0.16)
	env.fog_density = 0.025
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.72, 1.0)
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-52, -35, 0)
	root.add_child(moon)

	# Sol : dalle circulaire de pierre et cercles gravés.
	var floor_mat := _mat(Color(0.13, 0.12, 0.13), 0.95)
	_mesh(root, _cylinder(10.0, 10.0, 0.4), floor_mat, Vector3(0, -0.2, 0))
	var outer := _mesh(root, _cylinder(30.0, 30.0, 0.2), _mat(Color(0.05, 0.05, 0.06), 1.0), Vector3(0, -0.35, 0))
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rune := _emissive(Color(0.75, 0.6, 0.35), 0.6)
	for r in [4.6, 2.3]:
		var t := TorusMesh.new()
		t.inner_radius = r - 0.05
		t.outer_radius = r
		t.rings = 96
		t.ring_segments = 4
		var ring := _mesh(root, t, rune, Vector3(0.5, 0.01, 0))
		ring.scale = Vector3(1, 0.05, 1)

	# Piliers brisés autour de la place.
	var stone := _mat(Color(0.22, 0.2, 0.2), 0.9)
	for i in 10:
		var a := TAU * i / 10.0 + 0.2
		var h := [5.0, 2.2, 4.0, 1.4, 5.0, 3.1, 1.8, 5.0, 2.6, 4.4][i] as float
		var pos := Vector3(cos(a) * 10.5, h * 0.5, sin(a) * 9.0)
		if pos.x < -6.0 and pos.z > 2.0:
			continue  # dégage la vue de la caméra
		_mesh(root, _cylinder(0.55, 0.65, h), stone, pos)
		if h > 4.5:
			_mesh(root, _box(Vector3(1.6, 0.4, 1.6)), stone, pos + Vector3(0, h * 0.5 + 0.2, 0))

	# Réverbères au gaz.
	var lamp_mat := _emissive(Color(1.0, 0.62, 0.3), 3.0)
	for p in [Vector3(-2.0, 0, -6.5), Vector3(6.5, 0, -5.0), Vector3(7.5, 0, 4.5)]:
		var lp := p as Vector3
		_mesh(root, _cylinder(0.06, 0.08, 3.2), _mat(Color(0.1, 0.1, 0.1), 0.5), lp + Vector3(0, 1.6, 0))
		var bulb := SphereMesh.new()
		bulb.radius = 0.18
		bulb.height = 0.36
		_mesh(root, bulb, lamp_mat, lp + Vector3(0, 3.3, 0))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 2.2
		light.omni_range = 9.0
		light.position = lp + Vector3(0, 3.3, 0)
		root.add_child(light)

	# Lueur froide au centre (le Plan de la Conscience affleure).
	var center_light := OmniLight3D.new()
	center_light.light_color = Color(0.55, 0.45, 1.0)
	center_light.light_energy = 0.8
	center_light.omni_range = 7.0
	center_light.position = Vector3(0.5, 2.5, 0)
	root.add_child(center_light)

	# Silhouette industrielle au loin : cheminées d'usine rougeoyantes.
	var dark := _mat(Color(0.04, 0.04, 0.05), 1.0)
	var ember := _emissive(Color(1.0, 0.35, 0.1), 2.0)
	var chimneys := [Vector3(26, 0, -14), Vector3(30, 0, -4), Vector3(28, 0, 9), Vector3(18, 0, -24), Vector3(22, 0, 20), Vector3(34, 0, 2)]
	for i in chimneys.size():
		var c := chimneys[i] as Vector3
		var h := 12.0 + float(i % 3) * 5.0
		_mesh(root, _cylinder(0.9, 1.3, h), dark, c + Vector3(0, h * 0.5, 0))
		var top := TorusMesh.new()
		top.inner_radius = 0.7
		top.outer_radius = 1.0
		_mesh(root, top, ember, c + Vector3(0, h, 0))
		_mesh(root, _box(Vector3(6, h * 0.45, 5)), dark, c + Vector3(2.5, h * 0.22, 2.0))

	var moon_disc := SphereMesh.new()
	moon_disc.radius = 3.0
	moon_disc.height = 6.0
	_mesh(root, moon_disc, _emissive(Color(0.8, 0.85, 1.0), 1.6), Vector3(60, 30, -30))

	# Poussière en suspension.
	var dust := GPUParticles3D.new()
	var dm := ParticleProcessMaterial.new()
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dm.emission_box_extents = Vector3(9, 3, 7)
	dm.gravity = Vector3(0, 0.02, 0)
	dm.initial_velocity_min = 0.02
	dm.initial_velocity_max = 0.1
	dm.spread = 180.0
	dm.scale_min = 0.03
	dm.scale_max = 0.07
	dm.color = Color(1.4, 1.2, 1.6, 0.6)
	dust.process_material = dm
	dust.amount = 160
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.visibility_aabb = AABB(Vector3(-10, -1, -8), Vector3(20, 8, 16))
	var dq := QuadMesh.new()
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dmat.billboard_keep_scale = true
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dmat.vertex_color_use_as_albedo = true
	dmat.albedo_texture = CsFlux.soft_texture()
	dq.material = dmat
	dust.draw_pass_1 = dq
	dust.position = Vector3(0, 2.5, 0)
	root.add_child(dust)

	# Lumière d'appoint côté caméra pour détacher les silhouettes.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.75, 0.7, 0.9)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, -130, 0)
	root.add_child(fill)

	var cam := Camera3D.new()
	cam.fov = 42.0
	root.add_child(cam)
	cam.position = Vector3(-10.5, 5.2, 7.6)
	cam.look_at(Vector3(0.8, 0.2, -0.6))
	return {"camera": cam, "environment": env}


static func _mesh(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)
	mi.position = pos
	return mi


static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 32
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
