# tests/unit/test_snake.gd — Unit suite for snake3d.gd (pure logic).
#
# Instantiates the snake script in isolation (no ICEShardSpawner / EnemyManager
# siblings), disables auto-processing, and drives _step()/_die()/add_xp()
# directly so every assertion is deterministic.
#
# Each test builds a fresh snake instance to guarantee isolation. Signal
# assertions use method callables (not lambdas) because Godot 4 does not
# reliably invoke captured-local lambdas from emitted signals.
extends "res://tests/test_runner.gd"

const SnakeScript = preload("res://scripts/snake3d.gd")

var _died_fired: bool = false
var _evolved_fired: bool = false


func _ready() -> void:
	_run_all()
	_finish()

func _make_snake() -> Node:
	var s: Node = SnakeScript.new()
	add_child(s)           # triggers _ready (builds meshes, seeds body)
	s.set_process(false)   # deterministic: no auto-stepping
	return s

func _on_died() -> void:
	_died_fired = true

func _on_evolved(_stage: int) -> void:
	_evolved_fired = true

func _run_all() -> void:
	_test_initial_state()
	_test_movement()
	_test_wall_collision()
	_test_self_collision()
	_test_evolution()
	_test_overcharge_glow()

func _test_initial_state() -> void:
	var s := _make_snake()
	assert_eq(s.body.size(), 3, "initial body length is 3")
	assert_true(s.is_alive, "snake starts alive")
	assert_eq(s.body[0].x, LevelSettings.grid_w / 2, "head starts at grid center x")
	assert_true(_is_contiguous(s.body), "initial body cells are contiguous")
	assert_true(s.is_invulnerable(), "snake is invulnerable at full hp")

func _test_movement() -> void:
	var s := _make_snake()
	var start: Vector2i = s.body[0]
	var old_len: int = s.body.size()
	s.next_direction = Vector2i(1, 0)
	s._step()
	assert_eq(s.body[0], start + Vector2i(1, 0), "step moves head +x")
	assert_eq(s.body.size(), old_len, "step preserves body length")
	assert_true(_is_contiguous(s.body), "body stays contiguous after a step")

func _test_wall_collision() -> void:
	var s := _make_snake()
	_died_fired = false
	var cb := Callable(self, "_on_died")
	s.connect("died", cb)
	# Drive straight in the snake's current facing so _step() never hits a
	# 180-degree reversal guard; it will run into the wall ahead.
	var facing: Vector2i = s.direction
	s.next_direction = facing
	var guard := 0
	while s.is_alive and guard < 300:
		s._step()
		guard += 1
	s.disconnect("died", cb)
	assert_false(s.is_alive, "moving into the wall kills the snake")
	assert_true(_died_fired, "died signal is emitted on wall collision")

func _test_self_collision() -> void:
	var s := _make_snake()
	# L-shape body: head (0,0), neck (0,1), tail (1,1). Stepping the head into
	# its own neck (a non-tail cell) must trigger a self collision.
	var body: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	s.set("body", body)
	s.direction = Vector2i(0, 1)   # facing +y so the step is not a reversal
	s.next_direction = Vector2i(0, 1)
	s.invuln_timer = 0.0           # clear spawn-grace so _die() applies
	var hp_before: int = s.hp
	s._step()
	assert_eq(s.hp, hp_before - 1, "self collision reduces hp by 1")
	assert_true(s.is_alive, "snake survives a single self collision")

func _test_evolution() -> void:
	var s := _make_snake()
	_evolved_fired = false
	var cb := Callable(self, "_on_evolved")
	s.connect("evolved", cb)
	s.add_xp(200)
	s.disconnect("evolved", cb)
	assert_true(_evolved_fired, "evolved signal emitted at first xp threshold")
	assert_gt(s.max_hp, 3, "max_hp increases after evolution")

func _test_overcharge_glow() -> void:
	var s := _make_snake()
	# When the snake overcharges, the body material's emissive energy must spike
	# (visual feedback for the invulnerable + lethal window).
	var base_energy: float = s.body_mat.emission_energy_multiplier
	s.overcharge_active = true
	s._update_overcharge_visual(0.1)
	assert_gt(s.body_mat.emission_energy_multiplier, base_energy, "body emissive spikes during overcharge")
	# When the window ends, the glow must settle back toward the base energy.
	s.overcharge_active = false
	s._update_overcharge_visual(0.2)
	assert_lt(s.body_mat.emission_energy_multiplier, base_energy + 4.0, "body glow settles when overcharge ends")

func _is_contiguous(body: Array) -> bool:
	for i in range(1, body.size()):
		var d: Vector2i = body[i] - body[i - 1]
		if abs(d.x) + abs(d.y) != 1:
			return false
	return true
