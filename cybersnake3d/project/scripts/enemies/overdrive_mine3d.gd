# overdrive_mine3d.gd — Tier 13: a stationary detonation hazard.
#
# The Overdrive Mine sits inert on a cell. It never moves. When a vulnerable
# snake's head steps onto its cell the mine DETONATES: it deals exactly 1 HP
# of damage (via snake._hit(), which breaks the combo and grants the usual
# brief invulnerability window) instead of ending the run, then self-destructs.
#
# It respects the shared enemy invariants:
#   - never kills the snake outright; it wounds
#   - an overcharged (invulnerable) snake burns the mine away instead
#   - a normal head strike (snake attacks enemy) destroys the mine and awards XP
#
# Shared enemy contract:
#   - exposes grid_pos / get_grid_positions / take_damage / is_dead
#   - reads the Snake sibling at ../../Snake
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = 2
var max_hp: int = 2
var is_dead: bool = false
var armed: bool = true

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D
var time_passed: float = 0.0
var flash_timer: float = 0.0
var pulse: float = 0.0


func _ready() -> void:
	grid_pos = _random_edge()

	mat = StandardMaterial3D.new()
	# Amber warning glow — reads as a "live mine".
	mat.albedo_color = Color(1.0, 0.55, 0.1, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.1, 1.0)
	mat.emission_energy_multiplier = 2.4
	mat.roughness = 0.4

	mesh_inst = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.4
	mesh_inst.mesh = sphere
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.1)
	light.light_energy = 2.2
	light.omni_range = 3.0
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta
	pulse = sin(time_passed * 6.0) * 0.15 + 0.85
	mat.emission_energy_multiplier = 2.4 + pulse
	light.light_energy = 2.2 + pulse
	if flash_timer > 0.0:
		flash_timer -= delta

	_check_snake_collision()
	_update_position()

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive:
		return
	# The snake's own attack pass runs first (sets just_attacked), so by the
	# time we see the head here the snake is already invulnerable if it struck
	# us — burn the mine instead of detonating.
	if snake.is_invulnerable():
		if snake.overcharge_active and snake.body[0] == grid_pos:
			burn()
		return
	if snake.body[0] == grid_pos:
		_detonate(snake)

func _detonate(snake: Node) -> void:
	# Wound, not kill: 1 HP, combo broken, brief invulnerability, then the
	# mine is consumed. A snake already at 1 HP would lose its last point.
	armed = false
	is_dead = true
	flash_timer = 0.35
	var survived: bool = snake._hit()
	# Mine is consumed regardless — it detonated.
	queue_free()
	_update_position()

func burn() -> void:
	# Overcharge burns the mine away like residue; no snake damage.
	is_dead = true
	queue_free()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	flash_timer = 0.25
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 80
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(20)
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
