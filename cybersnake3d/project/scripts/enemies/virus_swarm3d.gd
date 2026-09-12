# virus_swarm3d.gd — Tier 2: boid flock (3D)
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var units: Array[Dictionary] = []
var center_pos := Vector3.ZERO
var is_dead: bool = false
var scattering: bool = false
var scatter_timer: float = 0.0

var unit_mat: StandardMaterial3D

func _ready() -> void:
	unit_mat = StandardMaterial3D.new()
	unit_mat.albedo_color = Color(0.2, 1.0, 0.3, 1.0)
	unit_mat.emission_enabled = true
	unit_mat.emission = Color(0.2, 1.0, 0.3, 1.0)
	unit_mat.emission_energy_multiplier = 2.0

	var count := randi_range(4, 8)
	var edge := _random_edge()
	center_pos = _grid_to_world(edge)
	for i in range(count):
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		mesh.mesh = sphere
		mesh.material_override = unit_mat
		mesh.position = center_pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		add_child(mesh)
		units.append({"mesh": mesh, "pos": mesh.position, "alive": true})

func _process(delta: float) -> void:
	if is_dead:
		return

	var alive_count := 0
	for u in units:
		if u["alive"]:
			alive_count += 1
	if alive_count == 0:
		_all_dead()
		return

	if scattering:
		scatter_timer -= delta
		if scatter_timer <= 0.0:
			scattering = false

	# Move center toward snake
	var snake := get_node_or_null("../../Snake")
	if snake and snake.body.size() > 0 and not scattering:
		var target: Vector3 = snake.get_head_world_pos()
		var dir: Vector3 = (target - center_pos).normalized()
		center_pos += dir * 2.0 * delta

	_update_boids(delta)
	_check_snake_collision()

func _update_boids(delta: float) -> void:
	for i in range(units.size()):
		if not units[i]["alive"]:
			continue
		var pos: Vector3 = units[i]["pos"]
		var sep := Vector3.ZERO
		var coh := Vector3.ZERO
		var neighbors := 0

		for j in range(units.size()):
			if i == j or not units[j]["alive"]:
				continue
			var other: Vector3 = units[j]["pos"]
			var diff := pos - other
			var dist := diff.length()
			if dist < 4.0 and dist > 0.01:
				sep += diff.normalized() / dist
				coh += other
				neighbors += 1

		if neighbors > 0:
			coh = ((coh / float(neighbors)) - pos) * 0.02

		var to_center := (center_pos - pos) * 0.03
		var velocity := sep * 0.5 + coh + to_center

		if scattering:
			velocity = (pos - center_pos).normalized() * 3.0

		if velocity.length() > 3.0:
			velocity = velocity.normalized() * 3.0

		velocity.y = 0.0
		var new_pos := pos + velocity * delta * 5.0
		new_pos.y = 0.5
		new_pos.x = clampf(new_pos.x, -LevelSettings.grid_w * 0.5, LevelSettings.grid_w * 0.5)
		new_pos.z = clampf(new_pos.z, -LevelSettings.grid_h * 0.5, LevelSettings.grid_h * 0.5)

		units[i]["pos"] = new_pos
		(units[i]["mesh"] as MeshInstance3D).position = new_pos

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active:
			var head_world: Vector3 = snake.get_head_world_pos()
			for u in units:
				if not u["alive"]:
					continue
				if (u["pos"] as Vector3 - head_world).length() < 0.8:
					take_damage(1)
		return
	var head_world: Vector3 = snake.get_head_world_pos()
	for u in units:
		if not u["alive"]:
			continue
		if (u["pos"] as Vector3 - head_world).length() < 0.8:
			snake._die()
			return

func take_damage(_amount: int = 1) -> void:
	var alive_indices: Array[int] = []
	for i in range(units.size()):
		if units[i]["alive"]:
			alive_indices.append(i)
	if alive_indices.size() > 0:
		var idx := alive_indices[randi_range(0, alive_indices.size() - 1)]
		units[idx]["alive"] = false
		(units[idx]["mesh"] as MeshInstance3D).visible = false
		var alive_remaining := alive_indices.size() - 1
		if alive_remaining > 0 and alive_remaining <= units.size() / 2 and not scattering:
			scattering = true
			scatter_timer = 2.0
		if alive_remaining == 0:
			_all_dead()

func _all_dead() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 200
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(35)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for u in units:
		if u["alive"]:
			var p: Vector3 = u["pos"]
			positions.append(Vector2i(int(p.x + LevelSettings.grid_w * 0.5), int(p.z + LevelSettings.grid_h * 0.5)))
	return positions

func _grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) - LevelSettings.grid_w * 0.5 + 0.5, 0.5, float(gp.y) - LevelSettings.grid_h * 0.5 + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), 0)
		1: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), LevelSettings.grid_h - 1)
		2: return Vector2i(0, randi_range(0, LevelSettings.grid_h - 1))
		_: return Vector2i(LevelSettings.grid_w - 1, randi_range(0, LevelSettings.grid_h - 1))
