extends Node
## Test manuel de l'affichage : charge le combat, essaie plusieurs résolutions
## et le plein écran, ouvre le menu Options et enregistre des captures.
## Ne sauvegarde pas les réglages du joueur.
## Lancer : godot --path . res://tests/display_test.tscn -- <dossier_captures>

var _out_dir := "user://display_test"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	await _frames(90)
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		GameSettings.window_mode = 0
		GameSettings.resolution = res
		GameSettings.apply()
		await _frames(30)
		await _shot("windowed_%dx%d" % [res.x, res.y])
	GameSettings.window_mode = 1
	GameSettings.apply()
	await _frames(40)
	await _shot("fullscreen")
	GameSettings.render_scale = 0.6
	GameSettings.upscaler = 2
	GameSettings.apply()
	await _frames(30)
	await _shot("fullscreen_fsr2_60")
	for n in battle.get_children():
		if n is BattleUI:
			(n as BattleUI)._options.open()
	await _frames(10)
	await _shot("options")
	print("DISPLAY_TEST: OK -> ", ProjectSettings.globalize_path(_out_dir))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(name + ".png")
	img.save_png(path)
	print("DISPLAY_TEST: %s fenêtre=%s image=%s mode=%d" % [name, get_window().size, img.get_size(), get_window().mode])
