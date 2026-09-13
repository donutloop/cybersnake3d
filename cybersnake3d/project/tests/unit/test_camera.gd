# tests/unit/test_camera.gd — deterministic unit tests for camera_follow.gd shake juice.
extends "res://tests/test_runner.gd"

const CameraScript = preload("res://scripts/camera_follow.gd")

var _cam: Camera3D


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.set_script(CameraScript)
	add_child(_cam)
	_run_all()
	_finish()


func _run_all() -> void:
	_test_ate_shard_bumps_shake()
	_test_shake_decays_over_time()
	_test_shake_decays_to_zero()
	_test_shake_never_negative()
	_test_shake_amplitude_scales_with_strength()
	_test_shake_decay_rate()
	_test_base_mappings()


func _test_ate_shard_bumps_shake() -> void:
	_cam.shake_strength = 0.0
	_cam._on_snake_ate_shard()
	assert_true(_cam.shake_strength >= 0.6, "eating a shard bumps shake strength")


func _test_shake_decays_over_time() -> void:
	_cam.shake_strength = 0.0
	_cam._on_snake_ate_shard()
	var before: float = _cam.shake_strength
	_cam.apply_shake(0.1)
	assert_lt(_cam.shake_strength, before, "shake decays over time")


func _test_shake_decays_to_zero() -> void:
	_cam.shake_strength = 0.0
	_cam._on_snake_ate_shard()
	_cam.apply_shake(100.0)
	assert_true(_cam.shake_strength <= 0.0, "shake decays to zero after a long decay")


func _test_shake_never_negative() -> void:
	_cam.shake_strength = 0.0
	_cam._on_snake_ate_shard()
	_cam.apply_shake(100.0)
	assert_true(_cam.shake_strength >= 0.0, "shake strength never goes negative")

func _test_shake_amplitude_scales_with_strength() -> void:
	assert_eq(_cam.shake_amplitude(1.0), 0.35, "full shake maps to 0.35 amplitude")
	assert_eq(_cam.shake_amplitude(0.0), 0.0, "no shake maps to zero amplitude")

func _test_base_mappings() -> void:
	var c := _cam
	assert_eq(c.base_offset(), Vector3(0.0, 30.0, 20.0), "camera base offset")
	assert_eq(c.base_look_ahead(), 3.0, "camera base look ahead")
	assert_eq(c.base_smooth_speed(), 5.0, "camera base smooth speed")

func _test_shake_decay_rate() -> void:
	assert_eq(_cam.shake_decay_rate(), 6.0, "shake decays at 6 per second")
