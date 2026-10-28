extends Node
## Réglages d'affichage (autoload "GameSettings") : mode de fenêtre, résolution,
## échelle de rendu 3D (FSR), anticrénelage, VSync et taille de l'interface.
## Sauvegardés dans user://settings.cfg et appliqués au lancement.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const WINDOW_MODES := ["Fenêtré", "Plein écran", "Plein écran exclusif"]
const UPSCALERS := ["Bilinéaire", "AMD FSR 1", "AMD FSR 2"]
const MSAA_LEVELS := ["Désactivé", "2×", "4×", "8×"]

var window_mode := 0
var resolution := Vector2i(1600, 900)
var render_scale := 1.0
var upscaler := 1
var msaa := 1
var vsync := true
var ui_scale := 1.0


func _ready() -> void:
	_load()
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		window_mode = 0 if window_mode != 0 else 1
		apply()
		save()


## Résolutions proposées : celles qui tiennent dans l'écran courant.
func available_resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size()
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	if out.is_empty():
		out.append(RESOLUTIONS[0])
	return out


func apply() -> void:
	var root := get_tree().root
	root.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2][upscaler]
	root.scaling_3d_scale = render_scale
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][msaa]
	root.content_scale_factor = ui_scale
	if _window_locked():
		changed.emit()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var win := get_window()
	match window_mode:
		0:
			win.mode = Window.MODE_WINDOWED
			var res := resolution
			var screen := DisplayServer.screen_get_size()
			res = Vector2i(mini(res.x, screen.x), mini(res.y, screen.y))
			win.size = res
			win.move_to_center()
		1:
			win.mode = Window.MODE_FULLSCREEN
		2:
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "render_scale", render_scale)
	cfg.set_value("display", "upscaler", upscaler)
	cfg.set_value("display", "msaa", msaa)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		# Premier lancement : la plus grande résolution 16:9 qui laisse de la marge à l'écran.
		var screen := DisplayServer.screen_get_size()
		for r in RESOLUTIONS:
			if r.x <= screen.x * 0.85 and r.y <= screen.y * 0.85:
				resolution = r
		return
	window_mode = cfg.get_value("display", "window_mode", window_mode)
	resolution = cfg.get_value("display", "resolution", resolution)
	render_scale = cfg.get_value("display", "render_scale", render_scale)
	upscaler = cfg.get_value("display", "upscaler", upscaler)
	msaa = cfg.get_value("display", "msaa", msaa)
	vsync = cfg.get_value("display", "vsync", vsync)
	ui_scale = cfg.get_value("display", "ui_scale", ui_scale)


## Pas de gestion de fenêtre en headless ni pendant un enregistrement vidéo
## (--write-movie / --resolution imposent leur propre taille).
func _window_locked() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var args := OS.get_cmdline_args()
	return "--write-movie" in args or "--resolution" in args
