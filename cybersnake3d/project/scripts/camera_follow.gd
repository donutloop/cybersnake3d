# camera_follow.gd — Smooth third-person camera following the snake
extends Camera3D

@export var offset := Vector3(0.0, 30.0, 20.0)
@export var look_ahead: float = 3.0
@export var smooth_speed: float = 5.0
@export var shake_decay: float = 6.0

var target: Node3D
var initialized: bool = false
var smooth_look_target := Vector3.ZERO
var shake_time: float = 0.0
var shake_strength: float = 0.0

func _ready() -> void:
	target = get_node_or_null("../Snake")
	if target and target.has_method("get_head_world_pos"):
		var head_pos: Vector3 = target.get_head_world_pos()
		position = head_pos + offset
		smooth_look_target = head_pos
		look_at(head_pos, Vector3.UP)
		initialized = true
	# Small bump when the snake eats an ICE shard.
	if target and target.has_signal("ate_shard"):
		target.ate_shard.connect(_on_snake_ate_shard)

func _process(delta: float) -> void:
	if not target or not target.has_method("get_head_world_pos"):
		target = get_node_or_null("../Snake")
		return

	var head_pos: Vector3 = target.get_head_world_pos()

	# Smooth look-ahead
	var dir3d := Vector3.ZERO
	if "direction" in target:
		dir3d = Vector3(float(target.direction.x), 0.0, float(target.direction.y))
	var desired_look := head_pos + dir3d * look_ahead
	var desired_pos := head_pos + offset

	if not initialized:
		position = desired_pos
		smooth_look_target = desired_look
		initialized = true
	else:
		position = position.lerp(desired_pos, smooth_speed * delta)
		smooth_look_target = smooth_look_target.lerp(desired_look, smooth_speed * delta)

	# Camera shake juice: bump when the snake takes damage (just_attacked flag).
	if "just_attacked" in target and target.just_attacked:
		shake_strength = maxf(shake_strength, 1.4)

	look_at(smooth_look_target, Vector3.UP)
	if shake_strength > 0.001:
		apply_shake(delta)

func apply_shake(delta: float) -> void:
	shake_time += delta
	shake_strength = maxf(0.0, shake_strength - shake_decay * delta)
	var amp := shake_strength
	var ox := sin(shake_time * 60.0) * amp
	var oz := sin(shake_time * 47.0 + 1.7) * amp
	position += Vector3(ox, 0.0, oz) * 0.35

func _on_snake_ate_shard() -> void:
	shake_strength = maxf(shake_strength, 0.6)
