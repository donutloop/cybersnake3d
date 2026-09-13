# hive_queen3d.gd — Tier-5 boss: spawns virus swarms and dashes (3D)
#
# The Hive Queen is a mobile boss that periodically hatches Virus Swarm minions
# around itself and dashes toward the snake's head. It shares the overcharge
# burn contract: when the snake's head overlaps it while overcharged, the queen
# takes damage instead of killing the snake.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i(19, 19)
var hp: int = queen_base_hp()
var max_hp: int = queen_base_hp()
var is_dead: bool = false
var is_boss: bool = true
var swarm_timer: float = 6.0
var enraged: bool = false
var move_timer: float = 0.0
var pulse: float = 0.0
var flash_timer: float = 0.0

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D


func _ready() -> void:
	# Boss HP scales with the current wave (mirrors the Blackwall Sentinel).
	# Read the parent EnemyManager's wave; bosses are spawned as its children.
	var mgr := get_parent()
	if mgr and "wave" in mgr:
		max_hp = queen_hp(mgr.wave)
		hp = max_hp
	grid_pos = Vector2i(int(LevelSettings.grid_w) / 2 - 1, LevelSettings.grid_h / 2 - 1)

	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.1, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1, 1.0)
	mat.emission_energy_multiplier = 3.0

	mesh_inst = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 2.2, 2.2)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = _g2w_center()
	add_child(mesh_inst)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	pulse += delta
	_hatch_swarms(delta)
	_dash(delta)
	_update_visual(delta)
	_check_snake_collision()

# ── swarm hatching ──────────────────────────────────────────────────


func queen_base_hp() -> int:
	# Hive Queen base HP (pure mapping).
	return 16


func queen_hp(wave: int) -> int:
	# Boss HP scales with wave (base 16, +1 every 5 waves past wave 10).
	return queen_base_hp() + maxi(wave - 10, 0) / 5
func hatch_size(wave: int) -> int:
	# Hive swarm size scales with wave (base 2, +1 per 3 waves, capped 6).
	# Pure mapping (no node access) so the logic is unit-testable.
	return clampi(2 + wave / 3, 2, 6)
func _hatch_swarms(delta: float) -> void:
	swarm_timer -= delta
	if swarm_timer > 0.0:
		return
	swarm_timer = 6.0
	# The queen is spawned as a direct child of the EnemyManager node, so its
	# parent IS the manager (the "../EnemyManager" path never resolves).
	var manager := get_parent()
	if not manager:
		return
	# Cap active swarm minions spawned by this queen.
	var active := 0
	if "enemies" in manager:
		for e in manager.enemies:
			if e and e.has_method("get_owner_tag") and e.get_owner_tag() == "hive_queen":
				active += 1
	if active >= 3:
		return
	var script := load("res://scripts/enemies/virus_swarm3d.gd")
	if not script:
		return
	var wave: int = int(manager.wave) if "wave" in manager else 1
	for i in range(hatch_size(wave)):
		var swarm := Node3D.new()
		swarm.set_script(script)
		if swarm.has_method("set_owner_tag"):
			swarm.set_owner_tag("hive_queen")
		manager.add_child(swarm)
		if "enemies" in manager:
			manager.enemies.append(swarm)

# ── dash toward snake head ─────────────────────────────────────────
func _dash(delta: float) -> void:
	move_timer += delta
	if move_timer < 1.0:
		return
	move_timer = 0.0
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
	if next.x < 0 or next.x >= LevelSettings.grid_w or next.y < 0 or next.y >= LevelSettings.grid_h:
		return
	grid_pos = next
	_update_position()

# ── visuals / hit flash ────────────────────────────────────────────
func _update_visual(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		mat.emission_energy_multiplier = 14.0
	else:
		mat.emission_energy_multiplier = (6.0 if enraged else 3.0) + sin(pulse * 2.0) * 1.0

# ── collision / overcharge burn ────────────────────────────────────
func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	var head: Vector2i = snake.body[0]
	if head != grid_pos:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active:
			take_damage(1)
		return
	snake._die()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	flash_timer = 0.25
	if hp <= max_hp / 2 and not enraged:
		enraged = true
		swarm_timer = 0.0
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 2500
		snake.score_changed.emit(snake.score)
		snake.boss_slain.emit(2500)
		if snake.has_method("add_xp"):
			snake.add_xp(250)
	# Boss death cleans up its hatched minions.
	var manager := get_parent()
	if manager and "enemies" in manager:
		for e in manager.enemies:
			if e and e.has_method("get_owner_tag") and e.get_owner_tag() == "hive_queen" and e.has_method("take_damage"):
				e.take_damage(999)
	queue_free()

func set_owner_tag(_t: String) -> void:
	pass

func get_owner_tag() -> String:
	return "hive_queen"

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _g2w_center() -> Vector3:
	var cx := float(grid_pos.x) + 0.5
	var cz := float(grid_pos.y) + 0.5
	return Vector3(cx, 1.0, cz)

func _update_position() -> void:
	if mesh_inst:
		mesh_inst.position = _g2w_center()
