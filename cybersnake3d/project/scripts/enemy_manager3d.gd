# enemy_manager3d.gd — Wave system (3D version)
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var wave: int = 0
var wave_timer: float = 0.0
var enemies: Array[Node] = []
var between_waves: bool = true

signal wave_started(wave_num: int)
signal wave_cleared(wave_num: int)

func _ready() -> void:
	LevelSettings.grid_w = 40
	LevelSettings.grid_h = 40
	var floor_mesh := get_node_or_null("../GridFloor") as MeshInstance3D
	if floor_mesh and floor_mesh.mesh is PlaneMesh:
		(floor_mesh.mesh as PlaneMesh).size = Vector2(LevelSettings.grid_w, LevelSettings.grid_h)
		# Origin-fixed floor: it spans world 0..grid_w so existing entities
		# (snake, shards) stay at their world positions when the board grows.
		floor_mesh.position = Vector3(LevelSettings.grid_w / 2.0, 0.0, LevelSettings.grid_h / 2.0)
		var mat = floor_mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("grid_cells", float(LevelSettings.grid_w))
	call_deferred("_start_next_wave")


func wave_delay(wave: int) -> float:
	# Wave interval shrinks as waves progress: later waves start faster.
	# Pure mapping (no node access) so the logic is unit-testable.
	return maxf(1.0, 3.0 - wave * 0.1)
func _process(delta: float) -> void:
	var i := enemies.size() - 1
	while i >= 0:
		var e := enemies[i]
		if not is_instance_valid(e) or not e.is_inside_tree():
			enemies.remove_at(i)
		i -= 1

	if not between_waves and enemies.size() == 0:
		between_waves = true
		_pulse_floor()
		wave_cleared.emit(wave)
		var snake := get_node_or_null("../Snake")
		if snake:
			var bonus: int = clear_bonus(wave)
			snake.score += bonus
			snake.score_changed.emit(snake.score)
			if snake.has_method("add_xp"):
				snake.add_xp(30)
		wave_timer = 0.0

	if between_waves:
		wave_timer += delta
		if wave_timer >= wave_delay(wave):
			_start_next_wave()

func _start_next_wave() -> void:
	wave += 1
	between_waves = false
	wave_started.emit(wave)

	if wave > 1:
		LevelSettings.grid_w = int(LevelSettings.grid_w * 1.5)
		LevelSettings.grid_h = int(LevelSettings.grid_h * 1.5)
		if LevelSettings.grid_w > 640:
			LevelSettings.grid_w = 640
			LevelSettings.grid_h = 640
		
		var floor_mesh := get_node_or_null("../GridFloor") as MeshInstance3D
		if floor_mesh and floor_mesh.mesh is PlaneMesh:
			(floor_mesh.mesh as PlaneMesh).size = Vector2(LevelSettings.grid_w, LevelSettings.grid_h)
			# Origin-fixed floor: reposition so it spans world 0..grid_w as it grows.
			floor_mesh.position = Vector3(LevelSettings.grid_w / 2.0, 0.0, LevelSettings.grid_h / 2.0)
			var mat = floor_mesh.get_surface_override_material(0) as ShaderMaterial
			if mat:
				mat.set_shader_parameter("grid_cells", float(LevelSettings.grid_w))

	var hud := get_node_or_null("../HUD")
	if hud and hud.wave_label:
		hud.show_wave_announce(wave)
		hud.wave_label.text = "WAVE: %d" % wave

	_spawn_wave(wave)

func _spawn_wave(w: int) -> void:
	var drone_count := w * 2
	for i in range(drone_count):
		_spawn_enemy("res://scripts/enemies/glitch_drone3d.gd")

	if w >= 2:
		for i in range(w - 1):
			_spawn_enemy("res://scripts/enemies/virus_swarm3d.gd")

	if w >= 3:
		var reaper_count := w - 1
		for i in range(reaper_count):
			_spawn_enemy("res://scripts/enemies/net_reaper3d.gd")

	if w >= 4:
		for i in range(w - 2):
			_spawn_enemy("res://scripts/enemies/compiler_worm3d.gd")
			_spawn_enemy("res://scripts/enemies/cascade_shredder3d.gd")

	if w >= 5:
		for i in range(w - 3):
			_spawn_enemy("res://scripts/enemies/phantom_protocol3d.gd")

	if w >= 6:
		for i in range(w - 4):
			_spawn_enemy("res://scripts/enemies/static_web3d.gd")

	if w >= 7:
		for i in range(spawn_count(w, 5)):
			_spawn_enemy("res://scripts/enemies/hunter3d.gd")

	if w >= 8:
		for i in range(spawn_count(w, 6)):
			_spawn_enemy("res://scripts/enemies/split_echo3d.gd")

	if w >= 9:
		for i in range(spawn_count(w, 8)):
			_spawn_enemy("res://scripts/enemies/warp_shard3d.gd")

	if w >= 10:
		for i in range(spawn_count(w, 9)):
			_spawn_enemy_capped("res://scripts/enemies/blackwall_sentinel3d.gd", 2)

	if w >= 11:
		for i in range(spawn_count(w, 10)):
			_spawn_enemy("res://scripts/enemies/chrono_anchor3d.gd")

	if w >= 12:
		for i in range(spawn_count(w, 11)):
			_spawn_enemy("res://scripts/enemies/wraith3d.gd")

	if w >= 13:
		for i in range(spawn_count(w, 12)):
			_spawn_enemy("res://scripts/enemies/overdrive_mine3d.gd")

	if w >= 14:
		for i in range(spawn_count(w, 13)):
			_spawn_enemy("res://scripts/enemies/score_leech3d.gd")

	if w >= 15:
		for i in range(spawn_count(w, 14)):
			_spawn_enemy_capped("res://scripts/enemies/hive_queen3d.gd", 2)

func _pulse_floor() -> void:
	var floor := get_node_or_null("../GridFloor")
	if not floor:
		return
	# GridFloor is a MeshInstance3D; its grid shader lives on the surface
	# material override (floor.get_material() does not exist in Godot 4).
	var mat := floor.get_surface_override_material(0) as ShaderMaterial
	if mat:
		mat.set_shader_parameter("grid_energy", 1.0)
		var tw := create_tween()
		tw.tween_method(func(v): mat.set_shader_parameter("grid_energy", v), 1.0, 0.0, 0.6)



func clear_bonus(wave: int) -> int:
	# Wave-clear score bonus scales with the wave (base 100, +20/wave).
	# Pure mapping (no node access) so the logic is unit-testable.
	return 100 + wave * 20
func spawn_count(wave: int, unlock_wave: int) -> int:
	# Enemy spawn count scales with waves past unlock, capped to avoid crowding.
	# Pure mapping (no node access) so the logic is unit-testable.
	return clampi(wave - unlock_wave, 1, 6)
func _spawn_enemy_capped(script_path: String, cap: int) -> void:
	# Only spawn if fewer than `cap` enemies of this script type are active.
	var active := 0
	for e in enemies:
		if e and e.get_script() and e.get_script().resource_path == script_path:
			active += 1
	if active >= cap:
		return
	_spawn_enemy(script_path)

func _spawn_enemy(script_path: String) -> void:
	var script := load(script_path) as GDScript
	if not script:
		return
	var enemy := Node3D.new()
	enemy.set_script(script)
	add_child(enemy)
	# Spawn far from the snake head so enemies don't appear on top of it.
	var snake := get_node_or_null("../Snake")
	if snake and snake.body.size() > 0 and enemy.has_method("_update_position"):
		var head: Vector2i = snake.body[0]
		var gw: int = LevelSettings.grid_w
		var gh: int = LevelSettings.grid_h
		for attempt in range(60):
			var cell := Vector2i(randi() % gw, randi() % gh)
			if abs(cell.x - head.x) >= 5 or abs(cell.y - head.y) >= 5:
				enemy.grid_pos = cell
				enemy._update_position()
				break
	# Wave scaling: later waves spawn tougher, faster enemies.
	var hpv: Variant = enemy.get("hp")
	if hpv != null:
		enemy.set("hp", int(hpv) + wave - 1)
	var spv: Variant = enemy.get("speed_steps")
	if spv != null:
		enemy.set("speed_steps", float(spv) + float(wave) * 0.15)
	enemies.append(enemy)

func get_enemy_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for e in enemies:
		if e.has_method("get_grid_positions"):
			positions.append_array(e.get_grid_positions())
	return positions
