# camera_follow.gd — Smooth third-person camera following the snake
extends Camera3D

@export var offset := Vector3(0.0, 30.0, 20.0)
@export var look_ahead: float = 3.0
@export var smooth_speed: float = 5.0

var target: Node3D
var initialized: bool = false
var smooth_look_target := Vector3.ZERO

func _ready() -> void:
	target = get_node_or_null("../Snake")
	if target and target.has_method("get_head_world_pos"):
		var head_pos: Vector3 = target.get_head_world_pos()
		position = head_pos + offset
		smooth_look_target = head_pos
		look_at(head_pos, Vector3.UP)
		initialized = true

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

	look_at(smooth_look_target, Vector3.UP)
