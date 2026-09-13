# static_web3d.gd — Tier 4: area-denial crawler that leaves damaging residue (3D)
#
# The Static Web skulks toward the snake at a slow pace and marks every cell
# it visits with lingering residue. A vulnerable snake that steps onto a
# residue cell is killed (area denial); an overcharged snake instead burns
# the residue away as it passes. Residue fades over time.
#
# Shared enemy contract:
#   - checks snake.is_invulnerable() before snake._die()
#   - exposes take_damage / get_grid_positions / is_dead
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = web_base_hp()
var max_hp: int = web_base_hp()
var move_speed: float = 1.6
var move_timer: float = 0.0
var is_dead: bool = false
var residue: Dictionary = {}   # Vector2i -> float (remaining life)

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D
var time_passed: float = 0.0
var flash_timer: float = 0.0




func web_base_hp() -> int:
	# Static Web base HP (pure mapping).
	return 4

func residue_life() -> float:
	# Static web residue persists for this many seconds (pure mapping).
	return 6.0
func _ready() -> void:
	grid_pos = _random_edge()

	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.5

	mesh_inst = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 0.6, 0.7)
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.0
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta
	_update_visual(delta)

	var snake := get_node_or_null("../../Snake")
	if snake and snake.body.size() > 0:
		_step_chase(snake.body[0], delta)

	# Leave residue at the current cell.
	mark_residue(grid_pos, residue_life())

	_update_position()
	_check_residue_collision(snake)
	_check_snake_collision()
	_fade_residue(delta)

# ── movement ─────────────────────────────────────────────────────────
func _step_chase(target: Vector2i, delta: float) -> void:
	move_timer += delta
	if move_timer < 1.0 / move_speed:
		return
	move_timer = 0.0
	var diff := target - grid_pos
	var step := Vector2i.ZERO
	if abs(diff.x) >= abs(diff.y):
		step.x = signi(diff.x)
	else:
		step.y = signi(diff.y)
	var next := grid_pos + step
	if _is_wall(next):
		return
	grid_pos = next

# ── residue / combat / contract ──────────────────────────────────────
func mark_residue(cell: Vector2i, life: float) -> void:
	residue[cell] = life

func _fade_residue(delta: float) -> void:
	var expired: Array[Vector2i] = []
	for cell in residue.keys():
		var life: float = float(residue[cell]) - delta
		residue[cell] = life
		if life <= 0.0:
			expired.append(cell)
	for cell in expired:
		residue.erase(cell)

func _check_residue_collision(snake: Node) -> void:
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	var head: Vector2i = snake.body[0]
	if snake.is_invulnerable():
		# Overcharge burns the web away instead of hurting the snake.
		if snake.overcharge_active and residue.has(head):
			residue.erase(head)
		return
	if residue.has(head):
		snake._die()

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active and snake.body[0] == grid_pos:
			take_damage(1)
		return
	if snake.body[0] == grid_pos:
		snake._die()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()
		return
	flash_timer = 0.25

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 350
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(70)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

# ── visuals / helpers ────────────────────────────────────────────────
func _update_visual(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		mat.emission_energy_multiplier = 12.0
		light.light_energy = 9.0
		return
	var pulse := sin(time_passed * 5.0) * 0.15 + 0.85
	mat.emission_energy_multiplier = 2.5 * pulse
	light.light_energy = 2.0 * pulse

func _update_position() -> void:
	if mesh_inst:
		var wx: float = float(grid_pos.x) + 0.5
		var wz: float = float(grid_pos.y) + 0.5
		mesh_inst.position = Vector3(wx, 0.4, wz)

func _is_wall(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.x >= LevelSettings.grid_w \
		or cell.y < 0 or cell.y >= LevelSettings.grid_h

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), 0)
		1: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), LevelSettings.grid_h - 1)
		2: return Vector2i(0, randi_range(0, LevelSettings.grid_h - 1))
		_: return Vector2i(LevelSettings.grid_w - 1, randi_range(0, LevelSettings.grid_h - 1))
