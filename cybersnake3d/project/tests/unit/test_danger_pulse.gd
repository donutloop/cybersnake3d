# tests/unit/test_danger_pulse.gd — Unit suite for the danger_pulse CRT
# "danger telegraph" controller.
#
# danger_level() is a pure HP->danger mapping (0.0 at full HP, 1.0 at 1 HP)
# with no node access, so every assertion is deterministic.
extends "res://tests/test_runner.gd"

const DangerPulseScript = preload("res://scripts/danger_pulse.gd")


func _ready() -> void:
	_run_all()
	_finish()

func _run_all() -> void:
	_test_full_hp_zero_danger()
	_test_one_hp_max_danger()
	_test_mid_hp_linear()
	_test_clamps_out_of_range()
	_test_vignette_strength_ramps_with_danger()
	_test_scanline_strength_ramps_with_hit()

func _danger(hp: int, max_hp: int) -> float:
	var pulse := Node.new()
	pulse.set_script(DangerPulseScript)
	return pulse.test_danger_level(hp, max_hp)

func _test_full_hp_zero_danger() -> void:
	# Full HP -> no vignette ramp.
	assert_eq(_danger(3, 3), 0.0, "danger is 0.0 at full HP")

func _test_one_hp_max_danger() -> void:
	# 1 HP left -> strongest danger telegraph.
	assert_eq(_danger(1, 3), 1.0, "danger is 1.0 at 1 HP")

func _test_mid_hp_linear() -> void:
	# Midpoint maps linearly: (max-hp)/(max-1).
	assert_eq(_danger(3, 5), 0.5, "danger maps linearly at mid HP")

func _test_clamps_out_of_range() -> void:
	# hp=0 (overwound) and hp>max clamp to the [0,1] band.
	assert_eq(_danger(0, 3), 1.0, "danger clamps at 0 HP")
	assert_eq(_danger(4, 3), 0.0, "danger clamps below 0 above full HP")

func _test_vignette_strength_ramps_with_danger() -> void:
	var pulse := Node.new()
	pulse.set_script(DangerPulseScript)
	assert_eq(pulse.vignette_strength(0.0), 0.25, "no danger gives base vignette")
	assert_eq(pulse.vignette_strength(1.0), 0.7, "full danger gives max vignette")
	pulse.free()

func _test_scanline_strength_ramps_with_hit() -> void:
	var pulse := Node.new()
	pulse.set_script(DangerPulseScript)
	assert_eq(pulse.scanline_strength(0.0), 0.18, "no hit gives base scanline")
	assert_eq(pulse.scanline_strength(1.0), 0.48, "full hit flash gives max scanline")
	pulse.free()
