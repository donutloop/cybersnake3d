# glitch_drone3d.gd — Tier 1: random walk with glitch stutter (3D)
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = 1
var speed_steps: float = 3.0
var move_timer: float = 0.0
var ticks_until_turn: int = 4
var tick_count: int = 0
var is_glitching: bool = false
var glitch_timer: float = 0.0
var glitch_cooldown: float = 0.0
var is_dead: bool = false

var mesh_inst: MeshInstance3D
var light: OmniLight3D
var mat: StandardMaterial3D
var mat_face: StandardMaterial3D
var mat_flame: StandardMaterial3D
var face_mesh: MeshInstance3D
var flame_mesh: MeshInstance3D
var time_passed: float = 0.0

const DIRECTIONS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

func _ready() -> void:
	grid_pos = _random_edge()
	ticks_until_turn = randi_range(3, 6)
	glitch_cooldown = randf_range(2.0, 5.0)
	time_passed = randf() * 100.0

	# 1. Load the demon face mesh if it exists
	var demon_mesh: Mesh = null
	if ResourceLoader.exists("res://assets/demon_face.obj"):
		demon_mesh = load("res://assets/demon_face.obj")

	# 2. Create inner demon face material
	mat_face = StandardMaterial3D.new()
	mat_face.albedo_color = Color(1.0, 0.05, 0.15, 1.0)
	mat_face.emission_enabled = true
	mat_face.emission = Color(1.0, 0.0, 0.1, 1.0)
	mat_face.emission_energy_multiplier = 7.0

	# 3. Create outer transparent flickering flame material
	mat_flame = StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 0.5, 0.1, 0.22)
	mat_flame.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat_flame.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	mat_flame.cull_mode = StandardMaterial3D.CULL_DISABLED
	mat_flame.roughness = 0.1
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.4, 0.05, 1.0)
	mat_flame.emission_energy_multiplier = 3.5
	mat = mat_flame # Backwards compatibility

	# 4. Create base pivot mesh instance
	mesh_inst = MeshInstance3D.new()
	add_child(mesh_inst)

	# 5. Create inner demon face mesh instance
	face_mesh = MeshInstance3D.new()
	if demon_mesh:
		face_mesh.mesh = demon_mesh
		face_mesh.scale = Vector3(0.85, 0.85, 0.85)
		face_mesh.position = Vector3(0, -0.22, 0)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.65, 0.65, 0.65)
		face_mesh.mesh = box
	face_mesh.material_override = mat_face
	mesh_inst.add_child(face_mesh)

	# 6. Create outer flickering flame mesh instance
	flame_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	flame_mesh.mesh = sphere
	flame_mesh.material_override = mat_flame
	mesh_inst.add_child(flame_mesh)

	# 7. Create flicker light
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.1)
	light.light_energy = 1.5
	light.omni_range = 3.5
	mesh_inst.add_child(light)

	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return

	time_passed += delta

	glitch_cooldown -= delta
	if glitch_cooldown <= 0.0 and not is_glitching:
		is_glitching = true
		glitch_timer = randf_range(0.15, 0.35)

	# Calculate high-frequency flicker values
	var flicker_val := sin(time_passed * 45.0) * 0.12 + cos(time_passed * 60.0) * 0.08 + randf_range(-0.08, 0.08)

	if is_glitching:
		glitch_timer -= delta
		# Glitch visual — random offset + flash
		mesh_inst.position = _grid_to_world(grid_pos) + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		
		var glitch_scale := 1.3 + randf_range(-0.25, 0.25)
		flame_mesh.scale = Vector3(glitch_scale, glitch_scale, glitch_scale)
		mat_flame.emission_energy_multiplier = 9.0 + randf_range(-2.0, 2.0)
		light.light_energy = 4.0 + randf_range(-1.0, 1.0)
		
		if glitch_timer <= 0.0:
			is_glitching = false
			glitch_cooldown = randf_range(2.0, 5.0)
			mat_flame.emission_energy_multiplier = 4.0
		return

	# Natural hovering wobble + slow rotation of the face core
	if face_mesh:
		face_mesh.rotate_y(delta * 1.8)
		face_mesh.position.y = -0.1 + sin(time_passed * 4.5) * 0.06

	# Natural flame flickering (scaling distort and emission fluctuation)
	var flame_scale_x := 1.0 + flicker_val
	var flame_scale_y := 1.0 + flicker_val + sin(time_passed * 25.0) * 0.12 # stretch vertically
	var flame_scale_z := 1.0 + flicker_val
	flame_mesh.scale = Vector3(flame_scale_x, flame_scale_y, flame_scale_z)

	mat_flame.emission_energy_multiplier = 4.5 + flicker_val * 7.5 + randf_range(-0.3, 0.3)
	light.light_energy = 1.8 + flicker_val * 2.5

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

	# Try random direction
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
	if not snake or not snake.is_alive:
		return
	if snake.is_invulnerable():
		if snake.overcharge_active and snake.body.size() > 0 and snake.body[0] == grid_pos:
			take_damage(1)
		return
	if snake.body.size() > 0 and snake.body[0] == grid_pos:
		snake._die()

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 50
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(25)
	queue_free()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _update_position() -> void:
	if mesh_inst:
		mesh_inst.position = _grid_to_world(grid_pos)

func _grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) - LevelSettings.grid_w * 0.5 + 0.5, 0.5, float(gp.y) - LevelSettings.grid_h * 0.5 + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), 0)
		1: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), LevelSettings.grid_h - 1)
		2: return Vector2i(0, randi_range(0, LevelSettings.grid_h - 1))
		_: return Vector2i(LevelSettings.grid_w - 1, randi_range(0, LevelSettings.grid_h - 1))
