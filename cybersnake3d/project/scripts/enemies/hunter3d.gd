# hunter3d.gd — Tier 7: a fast homing seeker that accelerates toward the snake.
# Unlike the net reaper (steady chase), the hunter ramps up its speed the longer
# it pursues, forcing the snake to break line of sight or double back.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = 3
var max_hp: int = 3
var base_speed: float = 5.0
var speed_steps: float = base_speed
var max_speed: float = 12.0
var move_timer: float = 0.0
var is_dead: bool = false
var chase_time: float = 0.0
var time_passed: float = 0.0

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D


func _ready() -> void:
	grid_pos = _random_edge()
	move_timer = randf() * 1.0
	time_passed = randf() * 100.0

	# Hot-orange hunter glow
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.1, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.roughness = 0.4

	mesh_inst = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 0.8, 0.6)
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.1)
	light.light_energy = 1.6
	light.omni_range = 3.0
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta

	# Acceleration feedback: faster chase = hotter, brighter glow.
	var accel := (speed_steps - base_speed) / (max_speed - base_speed)
	var heat := clampf(accel, 0.0, 1.0)
	var pulse := sin(time_passed * 6.0) * 0.25 + 0.75
	mat.emission = Color(1.0, 0.3, 0.1).lerp(Color(1.0, 1.0, 0.3), heat)
	mat.emission_energy_multiplier = 2.5 + heat * 4.0 + pulse
	light.light_energy = 1.6 + heat * 2.0 + pulse

	move_timer += delta
	if move_timer >= 1.0 / speed_steps:
		move_timer = 0.0
		_step_toward_snake()
		_update_position()

	_check_snake_collision()


func hunt_speed(base_speed: float, chase_time: float, max_speed: float) -> int:
	# Hunter ramps speed with chase time (base + 0.35/s), capped at max speed.
	# Pure mapping (no node access) so the logic is unit-testable.
	return mini(int(base_speed + chase_time * 0.35), int(max_speed))
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
	grid_pos = next
	# Ramps up speed while actively closing the gap.
	chase_time += 1.0 / speed_steps
	speed_steps = hunt_speed(base_speed, chase_time, max_speed)

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active:
			take_damage(1)
		return
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
		snake.score += 120
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(28)
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
