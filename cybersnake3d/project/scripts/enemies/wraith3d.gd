# wraith3d.gd — Tier 12: a phasing enemy that slides through the snake's body.
# The wraith ignores body segments entirely and only cares about the head, so
# the snake can't hide behind its own tail — it must meet the wraith head-on or
# burn it during overcharge.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = wraith_base_hp()
var max_hp: int = wraith_base_hp()
var move_timer: float = 0.0
var is_dead: bool = false
var time_passed: float = 0.0

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D




func wraith_base_hp() -> int:
	# Wraith base HP (pure mapping).
	return 5

func wraith_speed() -> float:
	# Wraith glides across the grid at this speed (pure mapping).
	return 3.0
func _ready() -> void:
	grid_pos = _random_edge()
	move_timer = randf() * 1.0
	time_passed = randf() * 100.0

	# Ghostly violet phasing shroud
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.2, 1.0, 0.6)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.2, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.0

	mesh_inst = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 0.9, 0.6)
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.2, 1.0)
	light.light_energy = 1.8
	light.omni_range = 3.5
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta
	var pulse := sin(time_passed * 3.0) * 0.2 + 0.8
	mat.emission_energy_multiplier = 2.0 + pulse
	light.light_energy = 1.8 + pulse

	move_timer += delta
	if move_timer >= 1.0 / wraith_speed():
		move_timer = 0.0
		_step_toward_snake()
		_update_position()

	_check_head_collision()

func _step_toward_snake() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or snake.body.size() == 0:
		return
	var head: Vector2i = snake.body[0]
	var diff := head - grid_pos
	var step := Vector2i.ZERO
	if abs(diff.x) >= abs(diff.y):
		step.x = signi(diff.x)
	else:
		step.y = signi(diff.y)
	var next := grid_pos + step
	next.x = clampi(next.x, 0, LevelSettings.grid_w - 1)
	next.y = clampi(next.y, 0, LevelSettings.grid_h - 1)
	# Phasing: body segments never block the wraith, only the head does.
	grid_pos = next

func _check_head_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active:
			take_damage(1)
		return
	# Only the head matters — ignore the rest of the body.
	if snake.body[0] == grid_pos:
		snake._die()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 400
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(75)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _update_position() -> void:
	if mesh_inst:
		mesh_inst.position = _g2w(grid_pos)

func _g2w(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) + 0.5, 0.5, float(gp.y) + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(2, LevelSettings.grid_w - 3), 1)
		1: return Vector2i(randi_range(2, LevelSettings.grid_w - 3), LevelSettings.grid_h - 2)
		2: return Vector2i(1, randi_range(2, LevelSettings.grid_h - 3))
		_: return Vector2i(LevelSettings.grid_w - 2, randi_range(2, LevelSettings.grid_h - 3))
