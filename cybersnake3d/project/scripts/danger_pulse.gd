# danger_pulse.gd — post-process "danger telegraph" controller.
#
# Drives the CRT overlay uniforms from the Snake's current HP each frame:
#   - vignette_strength darkens the screen edge as HP drops (0 at full HP,
#     1 at 1 HP), so danger ramps up smoothly toward a near-loss state.
#   - scanline_strength spikes briefly whenever the snake takes a hit.
#
# danger_level() is a pure mapping (no node access) so the logic is fully
# unit-testable in isolation.
extends Node


var _crt_material: ShaderMaterial
var _snake: Node
var _recent_hit: float = 0.0
var _last_hp: int = -1


func _ready() -> void:
	# Self-wire in the scene tree: CRTOverlay is a sibling ColorRect carrying
	# the crt_post ShaderMaterial; Snake is the Main-level snake sibling.
	var overlay := get_node_or_null("../CRTOverlay")
	var snake := get_node_or_null("../../Snake")
	if overlay is ColorRect and snake:
		var mat := (overlay as ColorRect).material as ShaderMaterial
		setup(mat, snake)

func setup(crt_material: ShaderMaterial, snake: Node) -> void:
	_crt_material = crt_material
	_snake = snake
	_last_hp = snake.hp if snake else -1

func danger_level(hp: int, max_hp: int) -> float:
	# Full HP -> 0.0, 1 HP -> 1.0 (the denominator floors at 1 to avoid /0).
	var denom: float = maxf(max_hp - 1, 1.0)
	return clampf(float(max_hp - hp) / denom, 0.0, 1.0)

func _process(_delta: float) -> void:
	if _snake == null or _crt_material == null:
		return
	if _last_hp >= 0 and _snake.hp < _last_hp:
		_recent_hit = hit_flash_strength()
	_last_hp = _snake.hp
	if _recent_hit > 0.0:
		_recent_hit = maxf(_recent_hit - _delta, 0.0)
	_update_uniforms()




func hit_flash_strength() -> float:
	# Danger pulse recent-hit flash strength (pure mapping).
	return 0.35
func scanline_strength(hit: float) -> float:
	# CRT scanline intensity ramps with recent-hit flash (base 0.18, +0.30).
	# Pure mapping (no node access) so the logic is unit-testable.
	return 0.18 + hit * 0.30
func vignette_strength(danger: float) -> float:
	# CRT vignette ramps with danger level (base 0.25, +0.45 at full danger).
	# Pure mapping (no node access) so the logic is unit-testable.
	return 0.25 + danger * 0.45
func _update_uniforms() -> void:
	var danger: float = danger_level(_snake.hp, _snake.max_hp)
	# Base vignette + danger ramp; scanlines spike on a fresh hit.
	_crt_material.set_shader_parameter("vignette_strength", vignette_strength(danger))
	_crt_material.set_shader_parameter("scanline_strength", scanline_strength(_recent_hit))

func test_danger_level(hp: int, max_hp: int) -> float:
	return danger_level(hp, max_hp)
