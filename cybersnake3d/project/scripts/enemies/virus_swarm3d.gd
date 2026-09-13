# virus_swarm3d.gd — Wave 02 monster: the Green Dot Swarm.
#
# 2026-style neon hologram swarm:
#   - a bright green hive-core dot (virus_dot.gdshader) at the center;
#   - 10 green hologram dots orbiting the core on a rotating ring;
#   - a dense GPUParticles3D green-dot cloud (draw_pass quads) as the swarm;
#   - a flickering green OmniLight3D for glow.
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
var orbit: Node3D
var cloud: GPUParticles3D
var light: OmniLight3D
var dot_mat: ShaderMaterial
var time_passed: float = 0.0

const ORBIT_DOTS := 10
const DIRECTIONS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]


func base_hp() -> int:
	# Green Dot Swarm base HP (pure mapping).
	return 3

func _ready() -> void:
	grid_pos = _random_edge()
	ticks_until_turn = randi_range(3, 6)
	time_passed = randf() * 100.0
	_build_visuals()
	_update_position()

func _build_visuals() -> void:
	dot_mat = ShaderMaterial.new()
	dot_mat.shader = load("res://shaders/virus_dot.gdshader")
	dot_mat.set_shader_parameter("dot_color", Color(0.10, 1.0, 0.40))
	dot_mat.set_shader_parameter("emissive_power", 3.0)
	dot_mat.set_shader_parameter("rim_power", 2.0)

	# ── hive core ──────────────────────────────────────────────────────
	var core := SphereMesh.new()
	core.radius = 0.35
	core.height = 0.7
	core.radial_segments = 32
	core.rings = 16
	core_mesh = MeshInstance3D.new()
	core_mesh.mesh = core
	core_mesh.material_override = dot_mat
	core_mesh.scale = Vector3(1.2, 1.2, 1.2)
	core_mesh.position = Vector3(0.0, 0.6, 0.0)
	add_child(core_mesh)

	# ── orbiting hologram dots ─────────────────────────────────────────
	orbit = Node3D.new()
	core_mesh.add_child(orbit)
	var dot := SphereMesh.new()
	dot.radius = 0.12
	dot.height = 0.24
	dot.radial_segments = 16
	dot.rings = 8
	for i in range(ORBIT_DOTS):
		var d := MeshInstance3D.new()
		d.mesh = dot
		d.material_override = dot_mat
		var angle := TAU * float(i) / float(ORBIT_DOTS)
		var r := 0.9 + (float(i % 3) * 0.15)
		d.position = Vector3(cos(angle) * r, sin(angle * 0.5) * 0.25, sin(angle) * r)
		d.scale = Vector3(1.0, 1.0, 1.0) * (0.8 + float(i % 2) * 0.4)
		orbit.add_child(d)

	# ── dense green-dot cloud (the swarm) ──────────────────────────────
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.6
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.1
	pm.color = Color(0.10, 1.0, 0.40, 0.75)

	cloud = GPUParticles3D.new()
	cloud.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	cloud.draw_pass_1 = quad
	cloud.amount = 160
	cloud.lifetime = 1.4
	cloud.preprocess = 1.0
	cloud.emitting = true
	core_mesh.add_child(cloud)

	# ── flicker light ──────────────────────────────────────────────────
	light = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.4)
	light.light_energy = 1.1
	light.omni_range = 3.5
	core_mesh.add_child(light)

func _process(delta: float) -> void:
	time_passed += delta
	# Orbit the hologram dots around the core.
	if orbit:
		orbit.rotation.y += delta * 1.2
		orbit.rotation.z = 0.35 * sin(time_passed * 0.6)
	if dot_mat:
		dot_mat.set_shader_parameter("emissive_power", 3.0 + sin(time_passed * 4.0) * 0.6)
	if light:
		light.light_energy = 1.1 + sin(time_passed * 5.0) * 0.25
	if cloud:
		cloud.emitting = true

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
	if cloud:
		cloud.emitting = false
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
