# compiler_worm3d.gd — Tier 3: snake-like trail (3D)
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var body: Array[Vector2i] = []
var direction := Vector2i(1, 0)
var speed_steps: float = 4.0
var move_timer: float = 0.0
var is_dead: bool = false
var segments: Array[MeshInstance3D] = []
var worm_mat: StandardMaterial3D

func _ready() -> void:
	var start := _random_edge()
	body = [start]
	for i in range(1, randi_range(5, 8)):
		body.append(start - Vector2i(i, 0))

	worm_mat = StandardMaterial3D.new()
	worm_mat.albedo_color = Color(1.0, 0.15, 0.1, 1.0)
	worm_mat.emission_enabled = true
	worm_mat.emission = Color(0.9, 0.15, 0.1, 1.0)
	worm_mat.emission_energy_multiplier = 2.0
	_rebuild_meshes()

func _process(delta: float) -> void:
	if is_dead:
		return
	move_timer += delta
	if move_timer >= 1.0 / speed_steps:
		move_timer = 0.0
		_step()
	_check_snake_collision()

func _step() -> void:
	if body.size() == 0:
		return
	var head := body[0]
	var snake := get_node_or_null("../../Snake")
	var target := head + direction
	if snake and snake.body.size() > 0:
		var diff := snake.body[0] - head
		if abs(diff.x) >= abs(diff.y):
			target = head + Vector2i(signi(diff.x), 0)
		else:
			target = head + Vector2i(0, signi(diff.y))
	target.x = clampi(target.x, 0, LevelSettings.grid_w - 1)
	target.y = clampi(target.y, 0, LevelSettings.grid_h - 1)
	direction = target - head
	body.push_front(target)

	var spawner := get_node_or_null("../../ICEShardSpawner")
	if spawner and spawner.try_eat(target):
		speed_steps = minf(speed_steps + 0.3, 8.0)
	else:
		body.pop_back()
	_rebuild_meshes()

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active:
			for cell in body:
				if cell == snake.body[0]:
					take_damage(1)
					return
		return
	for cell in body:
		if cell == snake.body[0]:
			snake._die()
			return

func take_damage(_amount: int = 1) -> void:
	if body.size() > 1:
		body.pop_back()
		_rebuild_meshes()
	else:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 250 + body.size() * 30
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(50)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return body

func _rebuild_meshes() -> void:
	while segments.size() > body.size():
		segments.pop_back().queue_free()
	while segments.size() < body.size():
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.7, 0.7, 0.7)
		m.mesh = b
		m.material_override = worm_mat
		add_child(m)
		segments.append(m)
	for i in range(body.size()):
		segments[i].position = _g2w(body[i])

func _g2w(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) - LevelSettings.grid_w * 0.5 + 0.5, 0.5, float(gp.y) - LevelSettings.grid_h * 0.5 + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(5, LevelSettings.grid_w - 6), 1)
		1: return Vector2i(randi_range(5, LevelSettings.grid_w - 6), LevelSettings.grid_h - 2)
		2: return Vector2i(1, randi_range(5, LevelSettings.grid_h - 6))
		_: return Vector2i(LevelSettings.grid_w - 2, randi_range(5, LevelSettings.grid_h - 6))
