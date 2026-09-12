# net_reaper3d.gd — Tier 2: A* hunter (3D) - STUB with basic chase AI
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = 2
var speed_steps: float = 5.0
var move_timer: float = 0.0
var is_dead: bool = false
var frenzy: bool = false
var frenzy_timer: float = 0.0
var base_speed: float = 5.0

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D

func _ready() -> void:
	grid_pos = _random_edge()

	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.1, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.5

	mesh_inst = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 0.9, 0.7)
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.1, 1.0)
	light.light_energy = 1.5
	light.omni_range = 3.0
	mesh_inst.add_child(light)
	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return

	if frenzy:
		frenzy_timer -= delta
		if frenzy_timer <= 0.0:
			frenzy = false
			speed_steps = base_speed
			mat.emission_energy_multiplier = 2.5

	move_timer += delta
	if move_timer >= 1.0 / speed_steps:
		move_timer = 0.0
		_step_toward_snake()
		_update_position()

	_check_snake_collision()

func _step_toward_snake() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or snake.body.size() == 0:
		return
	var target := snake.body[0]
	var diff := target - grid_pos
	if abs(diff.x) >= abs(diff.y):
		grid_pos.x += signi(diff.x)
	else:
		grid_pos.y += signi(diff.y)
	grid_pos.x = clampi(grid_pos.x, 0, LevelSettings.grid_w - 1)
	grid_pos.y = clampi(grid_pos.y, 0, LevelSettings.grid_h - 1)

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active and snake.body.size() > 0 and snake.body[0] == grid_pos:
			take_damage(1)
		return
	if snake.body.size() > 0 and snake.body[0] == grid_pos:
		snake._die()

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp == 1 and not frenzy:
		frenzy = true
		frenzy_timer = 2.0
		speed_steps = base_speed * 2.0
		mat.emission = Color(1.0, 0.0, 0.3, 1.0)
		mat.emission_energy_multiplier = 5.0
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 150
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(45)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _update_position() -> void:
	if mesh_inst:
		mesh_inst.position = _grid_to_world(grid_pos)

func _grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) - LevelSettings.grid_w * 0.5 + 0.5, 0.5, float(gp.y) - LevelSettings.grid_h * 0.5 + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), 0)
		1: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), LevelSettings.grid_h - 1)
		2: return Vector2i(0, randi_range(0, LevelSettings.grid_h - 1))
		_: return Vector2i(LevelSettings.grid_w - 1, randi_range(0, LevelSettings.grid_h - 1))
