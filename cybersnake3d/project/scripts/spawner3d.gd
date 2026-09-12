# spawner3d.gd — ICE shard spawner in 3D
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")

const MAX_SHARDS := 3

var shards: Array[Vector2i] = []
var shard_meshes: Array[MeshInstance3D] = []
var shard_lights: Array[OmniLight3D] = []
var shard_timer: float = 0.0
var anim_time: float = 0.0

var shard_mat: StandardMaterial3D

func _ready() -> void:
	shard_mat = StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.9)
	shard_mat.emission_enabled = true
	shard_mat.emission = Color(0.4, 0.85, 1.0, 1.0)
	shard_mat.emission_energy_multiplier = 4.0
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	call_deferred("_spawn_shard")

func _process(delta: float) -> void:
	anim_time += delta

	if shards.size() < 1:
		_spawn_shard()
	shard_timer += delta
	if shard_timer > 5.0 and shards.size() < MAX_SHARDS:
		shard_timer = 0.0
		_spawn_shard()

	# Animate shards — float and rotate
	for i in range(shard_meshes.size()):
		if i < shard_meshes.size():
			var mesh := shard_meshes[i]
			var base_y := 0.7
			mesh.position.y = base_y + sin(anim_time * 2.0 + float(i)) * 0.3
			mesh.rotation.y += delta * 2.0

func _spawn_shard() -> void:
	var snake := get_node_or_null("../Snake")
	var occupied: Array[Vector2i] = []
	if snake and snake.has_method("get_occupied_cells"):
		occupied = snake.get_occupied_cells()
	occupied.append_array(shards)

	for _attempt in range(200):
		var pos := Vector2i(randi_range(1, LevelSettings.grid_w - 2), randi_range(1, LevelSettings.grid_h - 2))
		if pos not in occupied:
			shards.append(pos)
			_create_shard_mesh(pos)
			return

func _create_shard_mesh(gp: Vector2i) -> void:
	var mesh_inst := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 0.8, 0.5)
	mesh_inst.mesh = prism
	mesh_inst.material_override = shard_mat
	mesh_inst.position = _grid_to_world(gp)
	add_child(mesh_inst)
	shard_meshes.append(mesh_inst)

	# Point light for glow
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	mesh_inst.add_child(light)
	shard_lights.append(light)

func try_eat(head_pos: Vector2i) -> bool:
	var idx := shards.find(head_pos)
	if idx >= 0:
		shards.remove_at(idx)
		if idx < shard_meshes.size():
			shard_meshes[idx].queue_free()
			shard_meshes.remove_at(idx)
		if idx < shard_lights.size():
			shard_lights.remove_at(idx)
		return true
	return false

func get_shard_positions() -> Array[Vector2i]:
	return shards

func _grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(float(gp.x) - LevelSettings.grid_w * 0.5 + 0.5, 0.7, float(gp.y) - LevelSettings.grid_h * 0.5 + 0.5)
