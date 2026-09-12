# enemy_manager3d.gd — Wave system (3D version)
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var wave: int = 0
var wave_timer: float = 0.0
var wave_delay: float = 3.0
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
		var mat = floor_mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("grid_cells", float(LevelSettings.grid_w))
	call_deferred("_start_next_wave")

func _process(delta: float) -> void:
	var i := enemies.size() - 1
	while i >= 0:
		var e := enemies[i]
		if not is_instance_valid(e) or not e.is_inside_tree():
			enemies.remove_at(i)
		i -= 1

	if not between_waves and enemies.size() == 0:
		between_waves = true
		wave_cleared.emit(wave)
		wave_timer = 0.0

	if between_waves:
		wave_timer += delta
		if wave_timer >= wave_delay:
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

	if w >= 5:
		for i in range(w - 3):
			_spawn_enemy("res://scripts/enemies/phantom_protocol3d.gd")

	if w >= 10:
		for i in range(w - 9):
			_spawn_enemy("res://scripts/enemies/blackwall_sentinel3d.gd")

func _spawn_enemy(script_path: String) -> void:
	var script := load(script_path) as GDScript
	if not script:
		return
	var enemy := Node3D.new()
	enemy.set_script(script)
	add_child(enemy)
	enemies.append(enemy)

func get_enemy_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for e in enemies:
		if e.has_method("get_grid_positions"):
			positions.append_array(e.get_grid_positions())
	return positions
