# net_reaper3d.gd — Wave 03 monster: the Net Reaper.
#
# 2026-style neon hologram:
#   - a bright teal reaper-core dot (virus_dot.gdshader, teal override);
#   - a procedural neon wireframe net sphere wrapping the core
#     (reaper_net.gdshader);
#   - 4 glowing teal thread tips extending from the net at cardinal angles;
#   - a teal ember particle field + flickering teal OmniLight3D.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = base_hp()
var speed_steps: float = 2.0
var move_timer: float = 0.0
var ticks_until_turn: int = 4
var tick_count: int = 0
var is_dead: bool = false

var core_mesh: MeshInstance3D
var net_mesh: MeshInstance3D
var threads: Node3D
var embers: GPUParticles3D
var light: OmniLight3D
var core_mat: ShaderMaterial
var net_mat: ShaderMaterial
var time_passed: float = 0.0

# Every 30s the reaper swells 5x for 3s, then shrinks back to normal.
var grow_cooldown: float = 30.0
var grow_duration: float = 3.0
var grow_scale: float = 5.0
var grow_timer: float = 0.0
var is_growing: bool = false

const THREADS := 4
const DIRECTIONS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]


func base_hp() -> int:
	# Net Reaper base HP (pure mapping).
	return 3

func _ready() -> void:
	grid_pos = _random_edge()
	ticks_until_turn = randi_range(3, 6)
	time_passed = randf() * 100.0
	_build_visuals()
	_update_position()

func _build_visuals() -> void:
	# ── reaper core (teal hologram dot) ────────────────────────────────
	core_mat = ShaderMaterial.new()
	core_mat.shader = load("res://shaders/virus_dot.gdshader")
	core_mat.set_shader_parameter("dot_color", Color(0.0, 1.0, 0.8))
	core_mat.set_shader_parameter("emissive_power", 3.5)
	core_mat.set_shader_parameter("rim_power", 2.2)

	var core := SphereMesh.new()
	core.radius = 0.30
	core.height = 0.6
	core.radial_segments = 28
	core.rings = 14
	core_mesh = MeshInstance3D.new()
	core_mesh.mesh = core
	core_mesh.material_override = core_mat
	core_mesh.position = Vector3(0.0, 0.6, 0.0)
	add_child(core_mesh)

	# ── neon wireframe net sphere ──────────────────────────────────────
	net_mat = ShaderMaterial.new()
	net_mat.shader = load("res://shaders/reaper_net.gdshader")
	net_mat.set_shader_parameter("net_color", Color(0.0, 1.0, 0.8))
	net_mat.set_shader_parameter("emissive_power", 3.0)
	net_mat.set_shader_parameter("line_width", 0.06)
	net_mat.set_shader_parameter("grid_u", 10.0)

	var net := SphereMesh.new()
	net.radius = 0.95
	net.height = 1.9
	net.radial_segments = 64
	net.rings = 40
	net_mesh = MeshInstance3D.new()
	net_mesh.mesh = net
	net_mesh.material_override = net_mat
	core_mesh.add_child(net_mesh)

	# ── glowing thread tips ────────────────────────────────────────────
	threads = Node3D.new()
	core_mesh.add_child(threads)
	var tip := SphereMesh.new()
	tip.radius = 0.10
	tip.height = 0.20
	tip.radial_segments = 12
	tip.rings = 6
	for i in range(THREADS):
		var th := MeshInstance3D.new()
		th.mesh = tip
		th.material_override = core_mat
		var angle := TAU * float(i) / float(THREADS)
		th.position = Vector3(cos(angle) * 1.35, sin(angle * 0.7) * 0.35, sin(angle) * 1.35)
		threads.add_child(th)

	# ── teal ember field ───────────────────────────────────────────────
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.3
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.color = Color(0.0, 1.0, 0.8, 0.6)

	embers = GPUParticles3D.new()
	embers.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	embers.draw_pass_1 = quad
	embers.amount = 120
	embers.lifetime = 1.3
	embers.preprocess = 1.0
	embers.emitting = true
	core_mesh.add_child(embers)

	# ── flicker light ──────────────────────────────────────────────────
	light = OmniLight3D.new()
	light.light_color = Color(0.0, 1.0, 0.8)
	light.light_energy = 1.1
	light.omni_range = 3.5
	core_mesh.add_child(light)

func _process(delta: float) -> void:
	time_passed += delta

	# ── grow phase ────────────────────────────────────────────────────
	# Every 30s the Net Reaper swells to 5x its size for 3s, then shrinks
	# back to normal. Scaling core_mesh grows the whole reaper (net,
	# threads, embers, light all follow) centered on its grid cell.
	if is_growing:
		grow_timer -= delta
		if core_mesh:
			var s := lerpf(core_mesh.scale.x, grow_scale, 0.2)
			core_mesh.scale = Vector3(s, s, s)
		if light:
			light.light_energy = 1.1 + 3.0 * grow_timer / grow_duration
		if grow_timer <= 0.0:
			is_growing = false
			if core_mesh:
				core_mesh.scale = Vector3.ONE
			if light:
				light.light_energy = 1.1
	else:
		grow_cooldown -= delta
		if grow_cooldown <= 0.0:
			is_growing = true
			grow_timer = grow_duration
			grow_cooldown = 30.0

	# Traveling pulse sweeps the net; the whole reaper breathes.
	if net_mat:
		net_mat.set_shader_parameter("emissive_power", 3.0 + sin(time_passed * 3.0) * 0.8)
		net_mat.set_shader_parameter("line_width", 0.06 + 0.02 * sin(time_passed * 4.0))
	if threads:
		threads.rotation.y += delta * 0.9
	if core_mat:
		core_mat.set_shader_parameter("emissive_power", 3.5 + sin(time_passed * 4.0) * 0.6)
	if light:
		light.light_energy = 1.1 + sin(time_passed * 5.0) * 0.25
	if embers:
		embers.emitting = true

	move_timer += delta
	if move_timer >= 1.0 / speed_steps:
		move_timer = 0.0
		_step()
		_update_position()

	_check_snake_collision()

func _step() -> void:
	tick_count += 1
	if tick_count >= ticks_until_turn:
		tick_count = 0
		ticks_until_turn = randi_range(3, 6)
		var d: Vector2i = DIRECTIONS[randi_range(0, 3)]
		var next: Vector2i = grid_pos + d
		if next.x >= 0 and next.x < LevelSettings.grid_w and next.y >= 0 and next.y < LevelSettings.grid_h:
			grid_pos = next
		return

	var dirs: Array = DIRECTIONS.duplicate()
	dirs.shuffle()
	for i in range(dirs.size()):
		var d: Vector2i = dirs[i]
		var next: Vector2i = grid_pos + d
		if next.x >= 0 and next.x < LevelSettings.grid_w and next.y >= 0 and next.y < LevelSettings.grid_h:
			grid_pos = next
			return

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake:
		return
	if snake.body and snake.body.size() > 0 and snake.body[0] == grid_pos:
		snake._die()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if light:
		light.light_energy = 0.0
	if embers:
		embers.emitting = false
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _update_position() -> void:
	if core_mesh:
		core_mesh.position = _grid_to_world(grid_pos)

func _grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) + 0.5, 0.5, float(gp.y) + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), 0)
		1: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), LevelSettings.grid_h - 1)
		2: return Vector2i(0, randi_range(0, LevelSettings.grid_h - 1))
		_: return Vector2i(LevelSettings.grid_w - 1, randi_range(0, LevelSettings.grid_h - 1))
