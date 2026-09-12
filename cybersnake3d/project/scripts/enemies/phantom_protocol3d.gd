# phantom_protocol3d.gd — Tier 4: phase-shifting teleport hunter (3D)
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = 3
var max_hp: int = 3
var speed_steps: float = 6.0
var move_timer: float = 0.0
var is_dead: bool = false

# Phase/teleport timing
var phase_interval: float = 3.0
var phase_timer: float = 0.0
var teleport_timer: float = 0.0
var is_phased: bool = false
var phase_flash: float = 0.0

var mesh_inst: MeshInstance3D
var light: OmniLight3D
var mat: StandardMaterial3D
var time_passed: float = 0.0


func _ready() -> void:
	grid_pos = _random_edge()
	phase_interval = randf_range(2.5, 4.5)
	phase_timer = randf_range(1.0, phase_interval)
	time_passed = randf() * 100.0

	# Ghostly translucent phantom material
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.2, 1.0, 0.55)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = StandardMaterial3D.CULL_DISABLED
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.25, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.5

	# Base pivot mesh instance
	mesh_inst = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh_inst.mesh = sphere
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Flicker point light
	light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.25, 1.0)
	light.light_energy = 1.8
	light.omni_range = 3.5
	light.omni_attenuation = 2.0
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return

	time_passed += delta

	# Phase window: when phased, flicker in/out and teleport near the snake
	if is_phased:
		teleport_timer -= delta
		phase_flash -= delta
		var flicker := sin(time_passed * 40.0) * 0.35 + 0.35
		mesh_inst.visible = phase_flash > 0.0 or flicker > 0.3
		mat.emission_energy_multiplier = 2.5 + flicker * 6.0
		light.light_energy = 1.8 + flicker * 3.0
		if teleport_timer <= 0.0:
			_teleport_near_snake()
			teleport_timer = 0.25
		if phase_flash <= 0.0:
			_finish_phase()
			return
		_check_snake_collision()
		return

	# Not phased: solid ghost chasing the snake
	mesh_inst.visible = true
	mat.emission_energy_multiplier = 2.5 + sin(time_passed * 3.0) * 0.3
	light.light_energy = 1.8 + sin(time_passed * 3.0) * 0.4

	phase_timer -= delta
	if phase_timer <= 0.0:
		_begin_phase()

	move_timer += delta
	if move_timer >= 1.0 / speed_steps:
		move_timer = 0.0
		_step_toward_snake()

	_check_snake_collision()

func _begin_phase() -> void:
	is_phased = true
	phase_flash = 0.35
	teleport_timer = 0.0
	phase_timer = phase_interval

func _finish_phase() -> void:
	is_phased = false
	mesh_inst.visible = true

func _teleport_near_snake() -> void:
	var snake := get_node_or_null("../../Snake")
	var anchor := grid_pos
	if snake and snake.body.size() > 0:
		anchor = snake.body[0]
	var target: Vector2i = anchor + Vector2i(randi_range(-6, 6), randi_range(-6, 6))
	target.x = clampi(target.x, 1, LevelSettings.grid_w - 2)
	target.y = clampi(target.y, 1, LevelSettings.grid_h - 2)
	grid_pos = target
	_update_position()

func _step_toward_snake() -> void:
	var snake := get_node_or_null("../../Snake")
	if snake and snake.body.size() > 0:
		var head := snake.body[0]
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
	_update_position()

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
	hp -= amount
	if hp <= 0:
		_die()
		return
	# Defensive teleport away from the snake when struck
	_teleport_near_snake()
	_begin_phase()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 300
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(60)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _update_position() -> void:
	if mesh_inst:
		mesh_inst.position = _g2w(grid_pos)

func _g2w(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) - LevelSettings.grid_w * 0.5 + 0.5, 0.5, float(gp.y) - LevelSettings.grid_h * 0.5 + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(2, LevelSettings.grid_w - 3), 1)
		1: return Vector2i(randi_range(2, LevelSettings.grid_w - 3), LevelSettings.grid_h - 2)
		2: return Vector2i(1, randi_range(2, LevelSettings.grid_h - 3))
		_: return Vector2i(LevelSettings.grid_w - 2, randi_range(2, LevelSettings.grid_h - 3))
