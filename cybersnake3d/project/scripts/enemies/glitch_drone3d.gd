# glitch_drone3d.gd — Tier 1 monster: the Glitch Drone.
#
# 2026-style neon hologram upgrade:
#   - demon-face core driven by glitch_drone.gdshader (emissive hologram,
#     animated glitch bands, rim fringe, scanline shimmer).
#   - additive flame/distortion aura via glitch_aura.gdshader.
#   - GPUParticles3D spark trail + flickering OmniLight3D for extra juice.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = drone_base_hp()
var speed_steps: float = 3.0
var move_timer: float = 0.0
var ticks_until_turn: int = 4
var tick_count: int = 0
var is_glitching: bool = false
var glitch_timer: float = 0.0
var glitch_cooldown: float = 0.0
var is_dead: bool = false

var face_mesh: MeshInstance3D
var aura_mesh: MeshInstance3D
var light: OmniLight3D
var sparks: GPUParticles3D
var face_mat: ShaderMaterial
var aura_mat: ShaderMaterial
var time_passed: float = 0.0

const DIRECTIONS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]


func drone_base_hp() -> int:
	# Glitch Drone base HP (pure mapping).
	return 1

func _ready() -> void:
	grid_pos = _random_edge()
	ticks_until_turn = randi_range(3, 6)
	glitch_cooldown = randf_range(2.0, 5.0)
	time_passed = randf() * 100.0

	_build_visuals()
	_update_position()

func _build_visuals() -> void:
	# ── demon-face hologram core ───────────────────────────────────────
	var demon := Mesh.new()
	if ResourceLoader.exists("res://assets/demon_face.obj", "Mesh"):
		demon = load("res://assets/demon_face.obj")
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.9, 0.9)
		demon = box

	face_mat = ShaderMaterial.new()
	face_mat.shader = load("res://shaders/glitch_drone.gdshader")
	face_mat.set_shader_parameter("core_color", Color(1.0, 0.05, 0.15))
	face_mat.set_shader_parameter("rim_color", Color(1.0, 0.30, 0.10))
	face_mat.set_shader_parameter("emissive_power", 3.0)
	face_mat.set_shader_parameter("rim_power", 2.0)
	face_mat.set_shader_parameter("glitch_amount", 0.0)

	face_mesh = MeshInstance3D.new()
	face_mesh.mesh = demon
	face_mesh.material_override = face_mat
	face_mesh.scale = Vector3(1.2, 1.2, 1.2)
	face_mesh.position = Vector3(0.0, 0.4, 0.0)
	add_child(face_mesh)

	# ── additive flame/distortion aura ────────────────────────────────
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.9
	sphere.radial_segments = 48
	sphere.rings = 24

	aura_mat = ShaderMaterial.new()
	aura_mat.shader = load("res://shaders/glitch_aura.gdshader")
	aura_mat.set_shader_parameter("flame_color", Color(1.0, 0.35, 0.10))
	aura_mat.set_shader_parameter("intensity", 1.6)
	aura_mat.set_shader_parameter("noise_scale", 5.0)
	aura_mat.set_shader_parameter("speed", 2.0)

	aura_mesh = MeshInstance3D.new()
	aura_mesh.mesh = sphere
	aura_mesh.material_override = aura_mat
	aura_mesh.scale = Vector3(1.5, 1.5, 1.5)
	face_mesh.add_child(aura_mesh)

	# ── spark trail ───────────────────────────────────────────────────
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.color = Color(1.0, 0.45, 0.15, 0.9)

	sparks = GPUParticles3D.new()
	sparks.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	sparks.draw_pass_1 = quad
	sparks.amount = 96
	sparks.lifetime = 1.2
	sparks.preprocess = 1.0
	sparks.emitting = true
	face_mesh.add_child(sparks)

	# ── flicker light ─────────────────────────────────────────────────
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.25, 0.1)
	light.light_energy = 1.2
	light.omni_range = 3.5
	face_mesh.add_child(light)

func _process(delta: float) -> void:
	time_passed += delta
	glitch_cooldown -= delta
	if glitch_cooldown <= 0.0 and not is_glitching:
		is_glitching = true
		glitch_timer = randf_range(0.15, 0.35)

	if is_glitching:
		glitch_timer -= delta
		var g := clampf(1.0 - glitch_timer / 0.35, 0.0, 1.0)
		_drive_shaders(g)
		if glitch_timer <= 0.0:
			is_glitching = false
			glitch_cooldown = randf_range(2.0, 5.0)
			_drive_shaders(0.0)
	else:
		_drive_shaders(0.0)

	move_timer += delta
	if move_timer >= 1.0 / speed_steps:
		move_timer = 0.0
		_step()
		_update_position()

	_check_snake_collision()

# Drives shader uniforms / lights from a glitch intensity in 0..1.
func _drive_shaders(glitch: float) -> void:
	if face_mat:
		face_mat.set_shader_parameter("glitch_amount", glitch)
		face_mat.set_shader_parameter("emissive_power", 3.0 + glitch * 6.0)
		face_mat.set_shader_parameter("rim_power", 2.0 + glitch * 3.0)
	if aura_mat:
		aura_mat.set_shader_parameter("intensity", 1.6 + glitch * 2.0 + sin(time_passed * 5.0) * 0.3)
	if light:
		light.light_energy = 1.2 + glitch * 3.0 + sin(time_passed * 6.0) * 0.25
	if sparks:
		sparks.emitting = true

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
	if sparks:
		sparks.emitting = false
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _update_position() -> void:
	if face_mesh:
		face_mesh.position = _grid_to_world(grid_pos)

func _grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) + 0.5, 0.5, float(gp.y) + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), 0)
		1: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), LevelSettings.grid_h - 1)
		2: return Vector2i(0, randi_range(0, LevelSettings.grid_h - 1))
		_: return Vector2i(LevelSettings.grid_w - 1, randi_range(0, LevelSettings.grid_h - 1))
