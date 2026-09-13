# blackwall_sentinel3d.gd — Boss (3D)
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i(18, 18)
var hp: int = sentinel_base_hp()
var max_hp: int = sentinel_base_hp()
var is_dead: bool = false
var is_boss: bool = true
var phase: int = 1
var enraged: bool = false
var drone_spawn_timer: float = 5.0
var pulse: float = 0.0
var flash_timer: float = 0.0

var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D

func _ready() -> void:
	# Scale boss HP from the current wave (EnemyManager sibling).
	# The Sentinel is spawned as a direct child of the EnemyManager, so the
	# manager is our parent (../../EnemyManager would miss it).
	var mgr := get_parent()
	if mgr:
		max_hp = boss_hp(mgr.wave)
		hp = max_hp
	grid_pos = Vector2i(int(LevelSettings.grid_w) / 2 - 1, LevelSettings.grid_h / 2 - 1)
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.0, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.0, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0

	mesh_inst = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 2.0, 3.0)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = _g2w_center()
	add_child(mesh_inst)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.0, 0.3)
	light.light_energy = 4.0
	light.omni_range = 8.0
	mesh_inst.add_child(light)

func boss_hp(wave: int) -> int:
	# Boss HP scales with wave (base 10, +1 every 5 waves past the first).
	# Pure mapping (no node access) so the logic is unit-testable.
	return 10 + maxi(wave - 10, 0) / 5

func enrage_threshold(max_hp: int) -> int:
	# The Sentinel enrages below half its max HP.
	# Pure mapping (no node access) so the logic is unit-testable.
	return maxi(max_hp / 2, 1)



func sentinel_base_hp() -> int:
	# Blackwall Sentinel base HP (pure mapping).
	return 10

func drone_swarm_size(phase: int) -> int:
	# Sentinel drone swarm scales with phase (phase 1 spawns 2, later phases 1).
	# Pure mapping (no node access) so the logic is unit-testable.
	return 2 if phase == 1 else 1
func _process(delta: float) -> void:
	if is_dead:
		return
	pulse += delta
	if hp > 7: phase = 1
	elif hp > 3: phase = 2
	else: phase = 3

	drone_spawn_timer -= delta
	if drone_spawn_timer <= 0.0:
		drone_spawn_timer = 5.0 if phase == 1 else 8.0
		_spawn_drones(drone_swarm_size(phase))

	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		mat.emission_energy_multiplier = 14.0
	else:
		mat.emission_energy_multiplier = (6.0 if enraged else 3.0) + sin(pulse * 2.0) * 1.0
	_check_snake_collision()

func _spawn_drones(count: int) -> void:
	var manager := get_parent()
	if not manager:
		return
	for i in range(count):
		var script := load("res://scripts/enemies/glitch_drone3d.gd")
		if script:
			var drone := Node3D.new()
			drone.set_script(script)
			if drone.has_method("set_owner_tag"):
				drone.set_owner_tag("sentinel")
			manager.add_child(drone)
			if "enemies" in manager:
				manager.enemies.append(drone)

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive or snake.body.size() == 0:
		return
	var head: Vector2i = snake.body[0]
	if snake.is_invulnerable():
		if snake.overcharge_active:
			for dy in range(3):
				for dx in range(3):
					if head == grid_pos + Vector2i(dx, dy):
						take_damage(1)
						return
		return
	for dy in range(3):
		for dx in range(3):
			if head == grid_pos + Vector2i(dx, dy):
				snake._die()

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		_die()
		return
	flash_timer = 0.25
	if hp <= enrage_threshold(max_hp) and not enraged:
		enraged = true
		drone_spawn_timer = 0.0

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 2000
		snake.score_changed.emit(snake.score)
		snake.boss_slain.emit(2000)
		if snake.has_method("add_xp"):
			snake.add_xp(200)
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.show_wave_announce(0)
		if hud.wave_announce:
			hud.wave_announce.text = ">>> FLATLINE COMPLETE <<<"
	# Boss death cleans up its spawned drones.
	var manager := get_parent()
	if manager and "enemies" in manager:
		for e in manager.enemies:
			if e and e.has_method("get_owner_tag") and e.get_owner_tag() == "sentinel" and e.has_method("take_damage"):
				e.take_damage(999)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	var p: Array[Vector2i] = []
	for dy in range(3):
		for dx in range(3):
			p.append(grid_pos + Vector2i(dx, dy))
	return p

func _g2w_center() -> Vector3:
	var cx := float(grid_pos.x) + 1.5
	var cz := float(grid_pos.y) + 1.5
	return Vector3(cx, 1.0, cz)
