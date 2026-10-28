class_name CsLightning
extends MeshInstance3D
## Éclair fractal (flux de Colère) : une ligne brisée qui se ramifie,
## régénérée plusieurs fois par seconde pour scintiller.

var from := Vector3.ZERO
var to := Vector3.UP
var color := Color(1.0, 0.4, 0.1)
var duration := 0.5
var _t := 0.0
var _regen := 0.0
var _im := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	mesh = _im
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_build()


func _process(delta: float) -> void:
	_t += delta
	_regen -= delta
	if _t >= duration:
		queue_free()
		return
	if _regen <= 0.0:
		_regen = 0.05
		_build()


func _build() -> void:
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES, _mat)
	var fade := 1.0 - _t / duration
	var c := Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, fade)
	# Plusieurs passes décalées pour épaissir le trait (les lignes font 1 px).
	for pass_i in 3:
		var jitter := Vector3(0, 0.012 * pass_i, 0.012 * pass_i)
		_bolt(to_local(from) + jitter, to_local(to) + jitter, 0.45, 5, c)
	_im.surface_end()


func _bolt(a: Vector3, b: Vector3, disp: float, depth: int, c: Color) -> void:
	if depth == 0:
		_im.surface_set_color(c)
		_im.surface_add_vertex(a)
		_im.surface_set_color(c)
		_im.surface_add_vertex(b)
		return
	var mid := (a + b) * 0.5 + Vector3(randf_range(-disp, disp), randf_range(-disp, disp), randf_range(-disp, disp))
	_bolt(a, mid, disp * 0.5, depth - 1, c)
	_bolt(mid, b, disp * 0.5, depth - 1, c)
	# Ramification occasionnelle : la structure fractale "en éclair".
	if depth >= 3 and randf() < 0.35:
		var branch := mid + (mid - a).rotated(Vector3.UP, randf_range(-0.8, 0.8)) * 0.7
		_bolt(mid, branch, disp * 0.4, depth - 2, Color(c.r, c.g, c.b, c.a * 0.6))
