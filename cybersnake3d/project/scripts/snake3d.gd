# snake3d.gd — 3D Snake controller on XZ grid plane
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var body: Array[Vector2i] = []
var direction := Vector2i(1, 0)
var next_direction := Vector2i(1, 0)
var move_timer: float = 0.0
var move_interval: float = 0.125  # 8 steps/sec
var is_alive: bool = true
var score: int = 0

var xp: int = 0
var level: int = 1
const XP_PER_LEVEL: int = 50
const EVO_THRESHOLDS: Array[int] = [0, 200, 500, 1000, 2000]
var evolution_stage: int = 1

const EVO_STATS: Array[Dictionary] = [
	{},  # padding so index matches stage
	{"hp": 3, "speed": 6.0},
	{"hp": 5, "speed": 7.0},
	{"hp": 8, "speed": 8.0},
	{"hp": 12, "speed": 9.0},
	{"hp": 20, "speed": 10.0},
]

var max_hp: int = 3
var hp: int = 3

var overcharge_timer: float = 8.0
var overcharge_active: bool = false
var prev_directions: Array[Vector2i] = [Vector2i(1,0), Vector2i(1,0)]

var invuln_timer: float = 2.0
var just_attacked: bool = false

var segments: Array[MeshInstance3D] = []
var head_mesh: Mesh = null
var body_mesh: Mesh = null
var skull_custom_mesh: Mesh = null
var snout_custom_mesh: Mesh = null

# Materials
var head_mat: StandardMaterial3D
var body_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D

signal died
signal ate_shard
signal score_changed(new_score: int)
signal evolved(stage: int)
signal xp_changed(current_xp: int, current_level: int, current_evo: int)

func _ready() -> void:
	# Load custom meshes if they exist in the assets directory
	if ResourceLoader.exists("res://assets/snake_head.obj"):
		head_mesh = load("res://assets/snake_head.obj")
	if ResourceLoader.exists("res://assets/snake_body.obj"):
		body_mesh = load("res://assets/snake_body.obj")
	if ResourceLoader.exists("res://assets/snake_skull_base.obj"):
		skull_custom_mesh = load("res://assets/snake_skull_base.obj")
	if ResourceLoader.exists("res://assets/snake_snout_jaw.obj"):
		snout_custom_mesh = load("res://assets/snake_snout_jaw.obj")

	# Create materials
	head_mat = StandardMaterial3D.new()
	head_mat.emission_enabled = true
	head_mat.emission_energy_multiplier = 3.0

	body_mat = StandardMaterial3D.new()
	body_mat.emission_enabled = true
	body_mat.emission_energy_multiplier = 1.5

	_apply_evo_colors()
	
	var stats: Dictionary = EVO_STATS[evolution_stage]
	max_hp = stats["hp"]
	hp = max_hp
	move_interval = 1.0 / stats["speed"]

	var cx: int = LevelSettings.grid_w / 2
	var cy: int = LevelSettings.grid_h / 2
	body = [
		Vector2i(cx, cy),
		Vector2i(cx - 1, cy),
		Vector2i(cx - 2, cy),
	]
	_rebuild_meshes()

func _process(delta: float) -> void:
	if not is_alive:
		return

	if evolution_stage >= 5:
		overcharge_timer -= delta
		if overcharge_timer <= 0.0:
			overcharge_timer = 8.0
			invuln_timer = 2.0
			overcharge_active = true

	if invuln_timer > 0.0:
		invuln_timer -= delta
		# Flash head during invuln
		if head_mat:
			var flash := sin(invuln_timer * 20.0) * 0.5 + 0.5
			head_mat.emission_energy_multiplier = 3.0 + flash * 5.0
	else:
		overcharge_active = false

	just_attacked = false
	_handle_input()
	move_timer += delta
	if move_timer >= move_interval:
		move_timer = 0.0
		_step()

func _handle_input() -> void:
	var new_dir := direction
	if Input.is_action_pressed("ui_up"):
		new_dir = Vector2i(0, -1)
	elif Input.is_action_pressed("ui_down"):
		new_dir = Vector2i(0, 1)
	elif Input.is_action_pressed("ui_left"):
		new_dir = Vector2i(-1, 0)
	elif Input.is_action_pressed("ui_right"):
		new_dir = Vector2i(1, 0)
		
	if new_dir != direction:
		if new_dir + direction == Vector2i.ZERO:
			# Reversing
			if evolution_stage >= 3:
				next_direction = new_dir
		else:
			next_direction = new_dir

func _step() -> void:
	var is_reversing: bool = false
	if next_direction + direction == Vector2i.ZERO:
		is_reversing = true

	prev_directions.push_front(direction)
	if prev_directions.size() > 3:
		prev_directions.pop_back()

	direction = next_direction
	var new_head := body[0] + direction

	# Wall collision
	if new_head.x < 0 or new_head.x >= LevelSettings.grid_w or new_head.y < 0 or new_head.y >= LevelSettings.grid_h:
		hp = 0
		is_alive = false
		died.emit()
		return

	# Self collision
	for i in range(body.size() - 1):
		if body[i] == new_head:
			_die()
			return

	body.push_front(new_head)

	if is_reversing and evolution_stage >= 3:
		# Tail whip: attack space behind the head (which was the old direction we reversed from)
		_check_enemy_damage(body[1] - direction, true)

	# ICE shard
	var spawner := get_node_or_null("../ICEShardSpawner")
	if spawner and spawner.try_eat(new_head):
		ate_shard.emit()
		score += 100
		score_changed.emit(score)
		add_xp(10)
		invuln_timer = 0.3
	else:
		body.pop_back()

	_check_enemy_damage(new_head, false)
	_rebuild_meshes()

func add_xp(amount: int) -> void:
	xp += amount
	var new_level: int = 1 + xp / XP_PER_LEVEL
	if new_level != level:
		level = new_level
	_check_evolution()
	xp_changed.emit(xp, level, evolution_stage)

func _check_evolution() -> void:
	var new_evo: int = 0
	for threshold in EVO_THRESHOLDS:
		if xp >= threshold:
			new_evo += 1
	if new_evo > evolution_stage:
		evolution_stage = new_evo
		_on_evolve()

func _on_evolve() -> void:
	var stats: Dictionary = EVO_STATS[evolution_stage]
	max_hp = stats["hp"]
	hp = max_hp  # full heal on evolution
	move_interval = 1.0 / stats["speed"]
	_apply_evo_colors()
	evolved.emit(evolution_stage)

func _apply_evo_colors() -> void:
	var h_color: Color
	var b_color: Color
	match evolution_stage:
		1: # Cyan
			h_color = Color(0.0, 1.0, 0.85, 1.0)
			b_color = Color(0.0, 0.6, 0.4, 1.0)
		2: # Teal
			h_color = Color(0.0, 0.8, 0.8, 1.0)
			b_color = Color(0.0, 0.4, 0.5, 1.0)
		3: # Blue
			h_color = Color(0.2, 0.4, 1.0, 1.0)
			b_color = Color(0.1, 0.2, 0.6, 1.0)
		4: # Orange-Red
			h_color = Color(1.0, 0.3, 0.0, 1.0)
			b_color = Color(0.6, 0.1, 0.0, 1.0)
		_: # Amber/Gold (5+)
			h_color = Color(1.0, 0.8, 0.0, 1.0)
			b_color = Color(0.6, 0.4, 0.0, 1.0)
			
	if head_mat:
		head_mat.albedo_color = h_color
		head_mat.emission = h_color
	if body_mat:
		body_mat.albedo_color = b_color
		body_mat.emission = b_color
	
	# Update procedural head neon materials to match evolutionary color stage
	if segments.size() > 0 and is_instance_valid(segments[0]):
		_update_procedural_head_materials(segments[0])

func _check_enemy_damage(head_pos: Vector2i, is_tail_whip: bool) -> void:
	var manager := get_node_or_null("../EnemyManager")
	if not manager:
		return
	for enemy in manager.get_children():
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage") or not enemy.has_method("get_grid_positions"):
			continue
		for cell in enemy.get_grid_positions():
			if cell == head_pos:
				enemy.take_damage(1)
				if not is_tail_whip:
					just_attacked = true
					invuln_timer = 0.2
				return

func is_invulnerable() -> bool:
	return invuln_timer > 0.0 or just_attacked

func _die() -> void:
	if invuln_timer > 0.0 and not overcharge_active:
		return
	if overcharge_active:
		return # handled in enemy scripts now, snake doesn't die during overcharge

	hp -= 1
	if hp <= 0:
		is_alive = false
		died.emit()
	else:
		invuln_timer = 2.0

func get_occupied_cells() -> Array[Vector2i]:
	return body

func grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) - LevelSettings.grid_w * 0.5 + 0.5, 0.5, float(gp.y) - LevelSettings.grid_h * 0.5 + 0.5)

func get_head_world_pos() -> Vector3:
	if body.size() > 0:
		return grid_to_world(body[0])
	return Vector3.ZERO

# ── mesh management ──────────────────────────────────────────────────
func _rebuild_meshes() -> void:
	# Remove excess segments
	while segments.size() > body.size():
		var seg: MeshInstance3D = segments.pop_back()
		seg.queue_free()

	# Add missing segments
	while segments.size() < body.size():
		var mesh_inst := MeshInstance3D.new()
		add_child(mesh_inst)
		segments.append(mesh_inst)

	# Position and style segments — snap to grid (no lerp)
	for i in range(body.size()):
		var seg := segments[i]
		seg.position = grid_to_world(body[i])

		if i == 0:
			_ensure_procedural_head(seg)
			
			# Rotate head to face movement direction
			var dir3d := Vector3(float(direction.x), 0.0, float(direction.y))
			if dir3d.length_squared() > 0.001:
				seg.look_at(seg.position + dir3d, Vector3.UP)
		else:
			var t := float(i) / float(body.size())
			var s := lerpf(1.3, 0.7, t)
			if body_mesh:
				seg.mesh = body_mesh
				seg.scale = Vector3(s, s * 0.5, s)
				seg.material_override = body_mat
			else:
				var box := BoxMesh.new()
				box.size = Vector3(s, s * 0.5, s)
				seg.mesh = box
				seg.scale = Vector3.ONE
				seg.material_override = body_mat

			# Rotate segment to face the segment ahead
			var segment_ahead := grid_to_world(body[i - 1])
			var segment_dir := segment_ahead - seg.position
			if segment_dir.length_squared() > 0.001:
				seg.look_at(seg.position + segment_dir.normalized(), Vector3.UP)

func _ensure_procedural_head(head_node: MeshInstance3D) -> void:
	# Ensure the parent head node does not render a primitive mesh itself
	head_node.mesh = null
	head_node.material_override = null
	
	# Scale the master head parent to make it proportional and large
	head_node.scale = Vector3(2.3, 2.3, 2.3)

	# Check if procedural head has already been constructed
	if head_node.get_child_count() > 0:
		_update_procedural_head_materials(head_node)
		return

	# Sleek cyber materials
	var metal_dark := StandardMaterial3D.new()
	metal_dark.albedo_color = Color(0.12, 0.12, 0.15, 1.0) # Titanium armor plate
	metal_dark.metallic = 0.9
	metal_dark.roughness = 0.2
	
	var metal_accent := StandardMaterial3D.new()
	metal_accent.albedo_color = Color(0.25, 0.25, 0.3, 1.0) # Accent panels
	metal_accent.metallic = 0.95
	metal_accent.roughness = 0.1

	var neon_glow := StandardMaterial3D.new()
	neon_glow.albedo_color = head_mat.albedo_color if head_mat else Color(0.2, 1.0, 1.0)
	neon_glow.emission_enabled = true
	neon_glow.emission = head_mat.emission if head_mat else Color(0.2, 1.0, 1.0)
	neon_glow.emission_energy_multiplier = 4.0

	var glass_black := StandardMaterial3D.new()
	glass_black.albedo_color = Color(0.01, 0.01, 0.01, 1.0) # Piano-black lenses
	glass_black.metallic = 0.95
	glass_black.roughness = 0.02

	# 1. Main Brain Case (Rear Skull)
	var skull := MeshInstance3D.new()
	skull.name = "Skull"
	if skull_custom_mesh:
		skull.mesh = skull_custom_mesh
		skull.scale = Vector3(0.55, 0.20, 0.30)
	else:
		var skull_mesh := BoxMesh.new()
		skull_mesh.size = Vector3(0.85, 0.38, 0.6)
		skull.mesh = skull_mesh
		skull.scale = Vector3.ONE
	skull.material_override = metal_dark
	skull.position = Vector3(0.0, 0.1, 0.1)
	head_node.add_child(skull)

	# 2. Sleek Tapered Snout
	var snout := MeshInstance3D.new()
	snout.name = "Snout"
	if snout_custom_mesh:
		snout.mesh = snout_custom_mesh
		snout.scale = Vector3(0.30, 0.20, 0.38)
	else:
		var snout_mesh := BoxMesh.new()
		snout_mesh.size = Vector3(0.55, 0.28, 0.55)
		snout.mesh = snout_mesh
		snout.scale = Vector3.ONE
	snout.material_override = metal_accent
	snout.position = Vector3(0.0, 0.05, -0.42)
	head_node.add_child(snout)

	# 3. Triangular Temporal Cheek Plates (Broad back, tapering front)
	for side in [-1.0, 1.0]:
		var cheek := MeshInstance3D.new()
		cheek.name = "Cheek_" + ("L" if side < 0 else "R")
		var cheek_mesh := BoxMesh.new()
		cheek_mesh.size = Vector3(0.12, 0.32, 0.6)
		cheek.mesh = cheek_mesh
		cheek.material_override = metal_dark
		cheek.position = Vector3(0.48 * side, 0.08, 0.05)
		cheek.rotation_degrees = Vector3(0, 15.0 * side, 0)
		head_node.add_child(cheek)

	# 4. Glossy Black Cyber Eye Lenses (Positioned perfectly on lateral sockets)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "Eye_" + ("L" if side < 0 else "R")
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.13
		eye_mesh.height = 0.26
		eye.mesh = eye_mesh
		eye.material_override = glass_black
		eye.position = Vector3(0.42 * side, 0.15, -0.22)
		head_node.add_child(eye)

	# 5. Cybernetic Brow Plates (Natural stern brow ridges!)
	for side in [-1.0, 1.0]:
		var brow := MeshInstance3D.new()
		brow.name = "Brow_" + ("L" if side < 0 else "R")
		var brow_mesh := BoxMesh.new()
		brow_mesh.size = Vector3(0.18, 0.06, 0.35)
		brow.mesh = brow_mesh
		brow.material_override = metal_accent
		brow.position = Vector3(0.38 * side, 0.24, -0.22)
		brow.rotation_degrees = Vector3(5.0, 0, 12.0 * side)
		head_node.add_child(brow)

	# 6. Lower Jaw Plate
	var jaw := MeshInstance3D.new()
	jaw.name = "Jaw"
	var jaw_mesh := BoxMesh.new()
	jaw_mesh.size = Vector3(0.75, 0.1, 0.85)
	jaw.mesh = jaw_mesh
	jaw.material_override = metal_dark
	jaw.position = Vector3(0.0, -0.16, -0.18)
	head_node.add_child(jaw)

	# 7. Neon Cyber Fangs (Glowing fangs!)
	for side in [-1.0, 1.0]:
		var fang := MeshInstance3D.new()
		fang.name = "Fang_" + ("L" if side < 0 else "R")
		var fang_mesh := CylinderMesh.new()
		fang_mesh.top_radius = 0.01
		fang_mesh.bottom_radius = 0.04
		fang_mesh.height = 0.28
		fang.mesh = fang_mesh
		fang.material_override = neon_glow
		fang.position = Vector3(0.2 * side, -0.15, -0.58)
		fang.rotation_degrees = Vector3(-10.0, 0, 5.0 * side)
		head_node.add_child(fang)

	# 8. Sleek Neon Forehead Visor Stripe
	var stripe := MeshInstance3D.new()
	stripe.name = "VisorStripe"
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.08, 0.03, 0.6)
	stripe.mesh = stripe_mesh
	stripe.material_override = neon_glow
	stripe.position = Vector3(0.0, 0.25, -0.32)
	stripe.rotation_degrees = Vector3(15.0, 0, 0)
	head_node.add_child(stripe)

func _update_procedural_head_materials(head_node: MeshInstance3D) -> void:
	var current_color = head_mat.emission if head_mat else Color(0.2, 1.0, 1.0)
	for child in head_node.get_children():
		if child.name.begins_with("Fang_") or child.name == "VisorStripe":
			var mat = child.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = current_color
				mat.emission = current_color

