# cascade_shredder3d.gd — Tier 3: straight-line lunge dasher (3D)
#
# The Shredder skulks toward the snake at a modest pace, then telegraphs a
# glowing charge and dashes in a straight grid line (row or column) at high
# speed. Getting hit knocks it out of its lunge, giving the player a tool to
# break a charge. It respects the shared enemy contract:
#   - checks snake.is_invulnerable() before snake._die()
#   - exposes take_damage / get_grid_positions / is_dead
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = shredder_base_hp()
var max_hp: int = shredder_base_hp()
var move_speed: float = 2.5        # chase steps/sec
var lunge_speed: float = 12.0      # cells/sec during a lunge
var move_timer: float = 0.0
var is_dead: bool = false

# Lunge state machine
var charging: bool = false
var telegraphing: bool = false
var lunge_dir := Vector2i.ZERO
var lunge_cells: int = 6
var charge_cooldown: float = 4.0
var charge_timer: float = 0.0
var telegraph_timer: float = 0.35

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D
var time_passed: float = 0.0
var flash_timer: float = 0.0



func shredder_base_hp() -> int:
	# Cascade Shredder base HP (pure mapping).
	return 3

func _ready() -> void:
	grid_pos = _random_edge()

	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.05, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.05, 1.0)
	mat.emission_energy_multiplier = 3.0

	mesh_inst = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 1.0, 0.6)
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.05)
	light.light_energy = 2.0
	light.omni_range = 3.0
	mesh_inst.add_child(light)

	_update_position()


func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta
	_update_visual(delta)

	if charging:
		_advance_lunge(delta)
	elif telegraphing:
		telegraph_timer -= delta
		if telegraph_timer <= 0.0:
			_begin_lunge()
	else:
		var snake := get_node_or_null("../../Snake")
		if snake and snake.body.size() > 0:
			_step_chase(snake.body[0], delta)
		charge_timer -= delta
		if charge_timer <= 0.0:
			_begin_telegraph(snake)

	_update_position()
	_check_snake_collision()

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

func _begin_telegraph(snake: Node) -> void:
	if snake == null or snake.body.size() == 0:
		return
	var head: Vector2i = snake.body[0]
	var diff := head - grid_pos
	if abs(diff.x) >= abs(diff.y):
		lunge_dir = Vector2i(signi(diff.x), 0)
	else:
		lunge_dir = Vector2i(0, signi(diff.y))
	if lunge_dir == Vector2i.ZERO:
		return
	telegraphing = true
	charging = false
	telegraph_timer = 0.35

func _begin_lunge() -> void:
	telegraphing = false
	charging = true
	lunge_cells = 6

func _advance_lunge(delta: float) -> void:
	move_timer += delta * lunge_speed
	while move_timer >= 1.0:
		move_timer -= 1.0
		var next := grid_pos + lunge_dir
		if _is_wall(next):
			_stop_charge()
			return
		grid_pos = next
		lunge_cells -= 1
		if lunge_cells <= 0:
			_stop_charge()
			return
		_check_snake_collision()
		if is_dead:
			return

func _stop_charge() -> void:
	charging = false
	telegraphing = false
	charge_timer = charge_cooldown

# ── combat / contract ────────────────────────────────────────────────
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
	# A hit interrupts any charge or telegraph (knockback).
	charging = false
	telegraphing = false

func _die() -> void:
	if is_dead: return
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

# ── visuals / helpers ────────────────────────────────────────────────
func _update_visual(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		mat.emission_energy_multiplier = 12.0
		light.light_energy = 9.0
		return
	if charging:
		mat.emission_energy_multiplier = 8.0
		light.light_energy = 6.0
	elif telegraphing:
		mat.emission_energy_multiplier = 5.0 + sin(time_passed * 30.0) * 3.0
		light.light_energy = 4.0 + sin(time_passed * 30.0) * 2.0
	else:
		var pulse := sin(time_passed * 6.0) * 0.15 + 0.85
		mat.emission_energy_multiplier = 3.0 * pulse
		light.light_energy = 2.0 * pulse

func _update_position() -> void:
	if mesh_inst:
		var wx: float = float(grid_pos.x) + 0.5
		var wz: float = float(grid_pos.y) + 0.5
		mesh_inst.position = Vector3(wx, 0.5, wz)

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
