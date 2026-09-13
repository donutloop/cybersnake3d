# chrono_anchor3d.gd — Tier 11: a stationary time-manipulation hazard.
#
# The Chrono Anchor sits inert and never moves. When a vulnerable snake's head
# steps onto its cell the anchor REWINDS the snake: it shunts the head back one
# cell (onto the neck segment) so the snake loses its forward step — no HP is
# lost and the run is never ended. The anchor persists as a temporal obstacle.
#
# Shared enemy invariants:
#   - never kills; it rewinds instead
#   - an overcharged (invulnerable) snake burns the anchor away
#   - a normal head strike (snake attacks enemy) destroys the anchor and awards XP
#
# Shared enemy contract:
#   - exposes grid_pos / get_grid_positions / take_damage / is_dead
#   - reads the Snake sibling at ../../Snake
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = 3
var max_hp: int = 3
var is_dead: bool = false

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D
var time_passed: float = 0.0
var flash_timer: float = 0.0


func _ready() -> void:
	grid_pos = _random_edge()

	mat = StandardMaterial3D.new()
	# Cool cyan "chrono" glow.
	mat.albedo_color = Color(0.2, 0.9, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.4

	mesh_inst = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.9, 0.7)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(0.2, 0.9, 1.0)
	light.light_energy = 1.8
	light.omni_range = 3.0
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta
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
	# us — burn the anchor instead of rewinding.
	if snake.is_invulnerable():
		if snake.overcharge_active and snake.body[0] == grid_pos:
			burn()
		return
	if snake.body[0] == grid_pos and snake.body.size() >= 2:
		rewind(snake)

func rewind(snake: Node) -> void:
	# Shunt the head back onto the neck segment: the snake loses its forward
	# step but keeps its HP. No kill, no damage.
	if snake.body.size() >= 2:
		snake.body[0] = snake.body[1]
	flash_timer = anchor_flash_time()

func burn() -> void:
	# Overcharge erases the anchor like residue; no snake effect.
	is_dead = true
	queue_free()


func anchor_flash_time() -> float:
	# Chrono Anchor flash after warping (pure mapping).
	return 0.35

func anchor_hit_flash_time() -> float:
	# Chrono Anchor flash after a hit (pure mapping).
	return 0.25
func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	flash_timer = anchor_hit_flash_time()
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 90
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(22)
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
