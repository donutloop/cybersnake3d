# score_leech3d.gd — Tier 14: an enemy that drains score instead of killing.
# Rather than ending the run, the leech latches onto the snake and siphons a
# chunk of the accumulated score, punishing greed without forcing a reset.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = leech_base_hp()
var max_hp: int = leech_base_hp()
var speed_steps: float = 4.0
var move_timer: float = 0.0
var is_dead: bool = false
var time_passed: float = 0.0

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D


func _ready() -> void:
	grid_pos = _random_edge()
	move_timer = randf() * 1.0
	time_passed = randf() * 100.0

	# Sickly green siphoning glow
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 1.0, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 1.0, 0.2, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.35

	mesh_inst = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 0.7, 0.6)
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.2)
	light.light_energy = 1.6
	light.omni_range = 3.0
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta
	var pulse := sin(time_passed * 5.0) * 0.2 + 0.8
	mat.emission_energy_multiplier = 2.2 + pulse
	light.light_energy = 1.6 + pulse

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

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active:
			take_damage(1)
		return
	if snake.body[0] == grid_pos:
		_drain_score(snake)



func leech_base_hp() -> int:
	# Score Leech base HP (pure mapping).
	return 4
func drain_ratio() -> float:
	# Score Leech siphons this fraction of the snake's score per drain (pure mapping).
	return 0.25
func _drain_score(snake: Node) -> void:
	# Siphon a fraction of the accumulated score instead of ending the run.
	var lost := int(snake.score * drain_ratio())
	snake.score = maxi(0, snake.score - lost)
	snake.score_changed.emit(snake.score)
	# The leech feeds and retreats a couple cells so it can strike again.
	var retreat := Vector2i.ZERO
	var head: Vector2i = snake.body[0]
	var diff := grid_pos - head
	if abs(diff.x) >= abs(diff.y):
		retreat.x = signi(diff.x)
	else:
		retreat.y = signi(diff.y)
	var next := grid_pos + retreat
	next.x = clampi(next.x, 0, LevelSettings.grid_w - 1)
	next.y = clampi(next.y, 0, LevelSettings.grid_h - 1)
	grid_pos = next
	_update_position()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 350
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(65)
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
