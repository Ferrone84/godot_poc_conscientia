extends Node3D
## Vitrine des héros : les trois modèles côte à côte, de face puis de dos,
## qui enchaînent leurs animations. À enregistrer avec --write-movie.

var heroes: Array[Combatant] = []
var cam: Camera3D


func _ready() -> void:
	var world := Arena.build(self)
	cam = world["camera"]
	var xs := [-1.4, 0.0, 1.4]
	var ids := ["lucie", "ceran", "nicolas"]
	for i in 3:
		var c := Combatant.new()
		c.setup(ids[i], true)
		add_child(c)
		c.position = Vector3(xs[i], 0, 0)
		c.look_at(c.global_position + Vector3.BACK)
		heroes.append(c)
	_run()


func _run() -> void:
	_view(Vector3(0, 1.4, -4.6))
	await _wait(1.0)
	for anim in ["charge", "attack", "cast", "parry", "hit"]:
		for h in heroes:
			h.anim(anim, 0.6)
		await _wait(1.0)
	_view(Vector3(0.8, 1.6, 4.4))
	await _wait(1.0)
	for anim in ["charge", "attack"]:
		for h in heroes:
			h.anim(anim, 0.6)
		await _wait(1.0)
	get_tree().quit()


func _view(pos: Vector3) -> void:
	cam.position = pos
	cam.look_at(Vector3(0, 1.0, 0))


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
