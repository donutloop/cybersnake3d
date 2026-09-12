# tests/integration/test_waves.gd — Integration suite for the real scene topology.
#
# Runs against tests/integration.tscn which mirrors main.tscn (Snake and
# EnemyManager as siblings under a root), so enemy "../../Snake" paths resolve
# exactly like in the shipped game.
#
# The manager's auto-processing is frozen for determinism; waves are advanced
# by calling the real _start_next_wave() directly.
extends "res://tests/test_runner.gd"

var _frame: int = 0
var _done: bool = false
var _snake: Node
var _manager: Node


func _ready() -> void:
	_snake = get_node("../Snake")
	_manager = get_node("../EnemyManager")
	_manager.set_process(false)  # freeze auto wave progression (deterministic)

func _process(_delta: float) -> void:
	_frame += 1
	if _done:
		return
	if _frame < 3:
		return  # let the deferred wave-1 spawn settle
	_done = true
	_run_all()
	_finish()

func _run_all() -> void:
	_test_topology()
	_test_wave1_spawns_drone()
	_test_wave5_spawns_phantom()
	_test_phantom_teleports_near_snake()
	_test_phantom_respects_invulnerability()
	_test_phantom_damages_vulnerable_snake()
	_test_wave4_spawns_shredder()
	_test_shredder_respects_invulnerability()
	_test_shredder_damages_vulnerable_snake()

func _test_topology() -> void:
	assert_not_null(_snake, "Snake node present in test scene")
	assert_not_null(_manager, "EnemyManager node present in test scene")
	assert_eq(_snake.body.size(), 3, "snake initial body length is 3")
	assert_eq(_snake.body[0].x, LevelSettings.grid_w / 2, "snake head starts at grid center x")

func _test_wave1_spawns_drone() -> void:
	var enemies: Array = _manager.enemies
	assert_true(enemies.size() > 0, "wave 1 spawns at least one enemy")
	var drone := _find_enemy(enemies, "glitch_drone3d.gd")
	assert_not_null(drone, "wave 1 spawns a glitch_drone enemy")

func _test_wave5_spawns_phantom() -> void:
	# Advance the real wave system to wave 5: set wave to 4, then let
	# _start_next_wave() increment to 5 and spawn phantoms.
	_manager.wave = 4
	_manager._start_next_wave()
	var phantom := _find_enemy(_manager.enemies, "phantom_protocol3d.gd")
	assert_not_null(phantom, "wave 5 spawns a phantom_protocol enemy (missing-file fix)")

func _test_phantom_teleports_near_snake() -> void:
	var phantom := _find_enemy(_manager.enemies, "phantom_protocol3d.gd")
	if phantom == null:
		return  # already failed by the wave-5 test
	var head: Vector2i = _snake.body[0]
	phantom._begin_phase()
	phantom._teleport_near_snake()
	var g: Vector2i = phantom.grid_pos
	assert_true(abs(g.x - head.x) <= 6 and abs(g.y - head.y) <= 6,
		"phantom teleports within range of snake head")

func _test_phantom_respects_invulnerability() -> void:
	var phantom := _find_enemy(_manager.enemies, "phantom_protocol3d.gd")
	if phantom == null:
		return
	_snake.invuln_timer = 2.0
	phantom.is_phased = false
	phantom.grid_pos = _snake.body[0]
	var hp_before: int = _snake.hp
	phantom._check_snake_collision()
	assert_eq(_snake.hp, hp_before, "phantom never damages an invulnerable snake")

func _test_phantom_damages_vulnerable_snake() -> void:
	var phantom := _find_enemy(_manager.enemies, "phantom_protocol3d.gd")
	if phantom == null:
		return
	_snake.invuln_timer = 0.0
	_snake.just_attacked = false
	phantom.is_phased = false
	phantom.grid_pos = _snake.body[0]
	var hp_before: int = _snake.hp
	phantom._check_snake_collision()
	assert_eq(_snake.hp, hp_before - 1, "phantom damages a vulnerable snake")

func _test_wave4_spawns_shredder() -> void:
	# Wave 4 gates the cascade_shredder (tier 3 dasher).
	_manager.wave = 3
	_manager._start_next_wave()  # wave becomes 4
	var shredder := _find_enemy(_manager.enemies, "cascade_shredder3d.gd")
	assert_not_null(shredder, "wave 4 spawns a cascade_shredder enemy")

func _test_shredder_respects_invulnerability() -> void:
	var shredder := _find_enemy(_manager.enemies, "cascade_shredder3d.gd")
	if shredder == null:
		return
	_snake.invuln_timer = 2.0
	shredder.grid_pos = _snake.body[0]
	var hp_before: int = _snake.hp
	shredder._check_snake_collision()
	assert_eq(_snake.hp, hp_before, "shredder never damages an invulnerable snake")

func _test_shredder_damages_vulnerable_snake() -> void:
	var shredder := _find_enemy(_manager.enemies, "cascade_shredder3d.gd")
	if shredder == null:
		return
	_snake.invuln_timer = 0.0
	_snake.just_attacked = false
	shredder.grid_pos = _snake.body[0]
	var hp_before: int = _snake.hp
	shredder._check_snake_collision()
	assert_eq(_snake.hp, hp_before - 1, "shredder damages a vulnerable snake")

func _find_enemy(enemies: Array, script_fragment: String) -> Node:
	for e in enemies:
		if e is Node and e.get_script() != null:
			var path: String = e.get_script().resource_path
			if path.contains(script_fragment):
				return e
	return null
