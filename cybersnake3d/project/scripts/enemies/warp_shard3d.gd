# warp_shard3d.gd — Tier 9: a teleporting shard that warps far away when struck.
# Unlike the phantom (which phases near the snake), the warp shard responds to
# damage by warping to a distant edge cell, forcing the snake to hunt it down.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = shard_base_hp()
var max_hp: int = shard_base_hp()
var speed_steps: float = 7.0
var move_timer: float = 0.0
var is_dead: bool = false
var warps_used: int = 0
var warp_flash: float = 0.0
var time_passed: float = 0.0

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var light: OmniLight3D


func _ready() -> void:
	grid_pos = _random_edge()
	move_timer = randf() * 1.0
	time_passed = randf() * 100.0

	# Cyan fractured-shard material
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.9, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.9, 1.0, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.roughness = 0.25

	mesh_inst = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 0.9, 0.6)
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	light = OmniLight3D.new()
	light.light_color = Color(0.1, 0.9, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.0
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta

	# Warp flash: after a teleport, glow bright and flicker while settling.
	if warp_flash > 0.0:
		warp_flash -= delta
		var f := warp_flash / 0.35
		mat.emission = Color(0.1, 0.9, 1.0).lerp(Color(1.0, 1.0, 1.0), f)
		mat.emission_energy_multiplier = 3.0 + f * 6.0
		light.light_energy = 2.0 + f * 3.0
	else:
		var pulse := sin(time_passed * 4.0) * 0.3 + 0.7
		mat.emission = Color(0.1, 0.9, 1.0, 1.0)
		mat.emission_energy_multiplier = 3.0 + pulse
		light.light_energy = 2.0 + pulse

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
	# Defensive warp: flee to a distant edge cell each time we're struck.
	_teleport_away()




func score_award() -> int:
	# Kill score awarded when a warp shard dies (pure mapping).
	return 250

func xp_award() -> int:
	# XP awarded when a warp shard dies (pure mapping).
	return 55

func shard_base_hp() -> int:
	# Warp Shard base HP (pure mapping).
	return 4
func warp_flash_time() -> float:
	# Warp flash duration after teleporting (pure mapping).
	return 0.35
func _teleport_away() -> void:
	warps_used += 1
	var snake := get_node_or_null("../../Snake")
	var anchor := grid_pos
	if snake and snake.body.size() > 0:
		anchor = snake.body[0]
	for attempt in range(60):
		var cell := _random_edge()
		var gw: int = LevelSettings.grid_w
		var gh: int = LevelSettings.grid_h
		if abs(cell.x - anchor.x) >= gw / 2 or abs(cell.y - anchor.y) >= gh / 2:
			grid_pos = cell
			break
	_update_position()
	warp_flash = warp_flash_time()

func _die() -> void:
	if is_dead: return
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += score_award()
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(xp_award())
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
