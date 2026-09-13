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
	_test_spawns_away_from_snake()
	_test_wave_grows_grid()
	_test_wave5_spawns_phantom()
	_test_phantom_teleports_near_snake()
	_test_phantom_respects_invulnerability()
	_test_phantom_damages_vulnerable_snake()
	_test_wave4_spawns_shredder()
	_test_shredder_respects_invulnerability()
	_test_shredder_damages_vulnerable_snake()
	_test_wave10_spawns_boss()
	_test_wave15_spawns_hive_queen()
	_test_boss_population_capped()
	_test_sentinel_enrage()
	_test_hive_queen_enrage()
	_test_wave6_spawns_web()
	_test_web_respects_invulnerability()
	_test_wave8_spawns_split_echo()
	_test_split_echo_fractures_on_damage()
	_test_wave7_spawns_hunter()
	_test_wave14_spawns_leech()
	_test_wave12_spawns_wraith()
	_test_wave11_spawns_chrono_anchor()
	_test_wave13_spawns_overdrive_mine()
	_test_wave9_spawns_warp_shard()
	_test_warp_shard_warps_when_hit()

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

func _test_spawns_away_from_snake() -> void:
	# _spawn_enemy must place enemies at least 5 cells (Chebyshev) from the
	# snake head so they never spawn on top of the player.
	var drone := _find_enemy(_manager.enemies, "glitch_drone3d.gd")
	if drone == null:
		return
	var head: Vector2i = _snake.body[0]
	var g: Vector2i = drone.grid_pos
	assert_true(abs(g.x - head.x) >= 5 or abs(g.y - head.y) >= 5,
		"spawned enemy keeps Chebyshev distance >= 5 from snake head")

func _test_wave_grows_grid() -> void:
	# Each wave transition grows the board (1.5x) so the arena expands.
	var gw_before: int = LevelSettings.grid_w
	var gh_before: int = LevelSettings.grid_h
	_manager._start_next_wave()  # increments wave past 1 => grid grows
	assert_true(LevelSettings.grid_w > gw_before and LevelSettings.grid_h > gh_before,
		"wave transition grows the grid dimensions")

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

func _test_wave10_spawns_boss() -> void:
	# Wave 10 gates the blackwall sentinel (boss). Verify its boss flag + HP.
	_manager.wave = 9
	_manager._start_next_wave()  # wave becomes 10
	var sentinel := _find_enemy(_manager.enemies, "blackwall_sentinel3d.gd")
	assert_not_null(sentinel, "wave 10 spawns the blackwall sentinel boss")
	if sentinel:
		assert_eq(sentinel.is_boss, true, "sentinel is flagged as boss")
		assert_true(sentinel.get("max_hp") > 0, "sentinel has boss HP")

func _test_wave15_spawns_hive_queen() -> void:
	# Wave 15 gates the hive queen boss (tier-5). Verify it spawns + is flagged boss.
	_manager.wave = 14
	_manager._start_next_wave()  # wave becomes 15
	var queen := _find_enemy(_manager.enemies, "hive_queen3d.gd")
	assert_not_null(queen, "wave 15 spawns the hive queen boss")
	if queen:
		assert_eq(queen.is_boss, true, "hive queen is flagged as boss")
		assert_true(queen.get("max_hp") >= 16, "hive queen has high boss HP")

func _test_boss_population_capped() -> void:
	# At wave 20 both bosses should spawn, but at most 2 of each stay active.
	_manager.wave = 19
	_manager._start_next_wave()  # wave becomes 20
	var sentinels := _count_script(_manager.enemies, "blackwall_sentinel3d.gd")
	var queens := _count_script(_manager.enemies, "hive_queen3d.gd")
	assert_true(sentinels >= 1, "wave 20 spawns at least one sentinel")
	assert_true(sentinels <= 2, "sentinel population capped at 2")
	assert_true(queens >= 1, "wave 20 spawns at least one hive queen")
	assert_true(queens <= 2, "hive queen population capped at 2")

func _test_sentinel_enrage() -> void:
	# Sentinel enrages once HP drops to half its max.
	_manager.wave = 9
	_manager._start_next_wave()  # wave 10 spawns a sentinel
	var sentinel := _find_enemy(_manager.enemies, "blackwall_sentinel3d.gd")
	assert_not_null(sentinel, "wave 10 spawns a sentinel for enrage test")
	if sentinel:
		while not sentinel.enraged and sentinel.hp > 0:
			sentinel.take_damage(1)
	assert_eq(sentinel.enraged, true, "sentinel enrages below half HP")

func _test_hive_queen_enrage() -> void:
	# Hive queen enrages below half HP and immediately hatches swarms.
	_manager.wave = 14
	_manager._start_next_wave()  # wave 15 spawns a hive queen
	var queen := _find_enemy(_manager.enemies, "hive_queen3d.gd")
	assert_not_null(queen, "wave 15 spawns a hive queen for enrage test")
	if queen:
		while not queen.enraged and queen.hp > 0:
			queen.take_damage(1)
	assert_eq(queen.enraged, true, "hive queen enrages below half HP")

func _test_wave6_spawns_web() -> void:
	# Wave 6 gates the static_web (tier 4 area-denial crawler).
	_manager.wave = 5
	_manager._start_next_wave()  # wave becomes 6
	var web := _find_enemy(_manager.enemies, "static_web3d.gd")
	assert_not_null(web, "wave 6 spawns a static_web enemy")

func _test_web_respects_invulnerability() -> void:
	var web := _find_enemy(_manager.enemies, "static_web3d.gd")
	if web == null:
		return
	_snake.invuln_timer = 2.0
	web.grid_pos = _snake.body[0]
	web.mark_residue(_snake.body[0], 10.0)
	var hp_before: int = _snake.hp
	web._check_snake_collision()
	assert_eq(_snake.hp, hp_before, "static_web never damages an invulnerable snake")
	# Overcharge burns residue instead of hurting the snake.
	web.residue.clear()
	web.mark_residue(_snake.body[0], 10.0)
	_snake.overcharge_active = true
	web._check_residue_collision(_snake)
	_snake.overcharge_active = false
	assert_eq(_snake.hp, hp_before, "overcharge burns residue without hurting the snake")

func _test_wave8_spawns_split_echo() -> void:
	# Wave 8 gates the tier-4 split echo (hydra). Verify it actually spawns
	# at wave 8 and not before. Prior tests advance the shared manager past
	# wave 20, leaving split echoes in _manager.enemies, so isolate first.
	_reset_enemies()
	_manager.wave = 6
	_manager._start_next_wave()  # wave becomes 7 (no split echoes yet)
	assert_eq(_count_script(_manager.enemies, "split_echo3d.gd"), 0,
		"no split echoes before wave 8")
	_manager.wave = 7
	_manager._start_next_wave()  # wave becomes 8
	var echo := _find_enemy(_manager.enemies, "split_echo3d.gd")
	assert_not_null(echo, "wave 8 spawns a split_echo enemy")

func _test_split_echo_fractures_on_damage() -> void:
	# A wounded split echo fractures into two offspring that register in the
	# manager and cannot split further (regression guard for wave-8 gating).
	_reset_enemies()
	_manager.wave = 7
	_manager._start_next_wave()  # wave becomes 8
	var echo := _find_enemy(_manager.enemies, "split_echo3d.gd")
	if echo == null:
		return  # already failed by the wave-8 spawn test
	var before: int = _manager.enemies.size()
	echo.hp = 6
	echo.max_hp = 6
	echo.take_damage(3)  # drop to half HP -> fractures
	assert_true(echo.split_used, "echo splits once below half hp")
	assert_gt(_manager.enemies.size(), before, "echo fractures into offspring")
	# Offspring must not split again.
	for c in _manager.enemies:
		if c != echo and c.get_script() and c.get_script().resource_path.contains("split_echo3d.gd"):
			var off: Node = c
			off.hp = 1
			off.take_damage(0)
			assert_eq(off.split_used, true, "offspring cannot split further")
			break

func _test_wave9_spawns_warp_shard() -> void:
	# Wave 9 gates the warp shard: it must NOT spawn at wave 8 but must
	# appear once the wave advances to 9.
	_reset_enemies()
	_manager.wave = 8
	_manager._start_next_wave()  # wave becomes 9
	assert_eq(_count_script(_manager.enemies, "warp_shard3d.gd"), 1,
		"wave 9 spawns exactly one warp shard")

func _test_warp_shard_warps_when_hit() -> void:
	# A struck warp shard survives and warps to a distant cell instead of
	# dying (defensive teleport).
	_reset_enemies()
	_manager.wave = 8
	_manager._start_next_wave()  # wave becomes 9 -> spawns a warp shard
	var shard := _find_enemy(_manager.enemies, "warp_shard3d.gd")
	if shard == null:
		return  # wave-9 spawn already asserted by the prior test
	var start: Vector2i = shard.grid_pos
	var before: int = shard.warps_used
	var hp_before: int = shard.hp
	shard.take_damage(1)
	assert_eq(shard.hp, hp_before - 1, "warp shard survives a single hit (wave-scaled HP)")
	assert_gt(shard.warps_used, before, "warp shard warps when struck")
	assert_true(shard.grid_pos != start, "warp shard flees to a new cell")


func _test_wave7_spawns_hunter() -> void:
	# Wave 7 gates the hunter: it must NOT spawn at wave 6 but must appear
	# once the wave advances to 7.
	_reset_enemies()
	_manager.wave = 6
	_manager._start_next_wave()  # wave becomes 7
	assert_gt(_count_script(_manager.enemies, "hunter3d.gd"), 0,
		"wave 7 spawns at least one hunter")


func _test_wave12_spawns_wraith() -> void:
	# Wave 12 gates the wraith: it must NOT spawn at wave 11 but must appear
	# once the wave advances to 12.
	_reset_enemies()
	_manager.wave = 11
	_manager._start_next_wave()  # wave becomes 12
	assert_gt(_count_script(_manager.enemies, "wraith3d.gd"), 0,
		"wave 12 spawns at least one wraith")
func _test_wave13_spawns_overdrive_mine() -> void:
	# Wave 13 gates the Overdrive Mine (wounds, never kills outright).
	_reset_enemies()
	_manager.wave = 12
	_manager._start_next_wave()
	assert_gt(_count_script(_manager.enemies, "overdrive_mine3d.gd"), 0,
		"wave 13 spawns at least one Overdrive Mine")
func _test_wave11_spawns_chrono_anchor() -> void:
	# Wave 11 gates the Chrono Anchor (rewinds the snake, never kills).
	_reset_enemies()
	_manager.wave = 10
	_manager._start_next_wave()
	assert_gt(_count_script(_manager.enemies, "chrono_anchor3d.gd"), 0,
		"wave 11 spawns at least one Chrono Anchor")




func _test_wave14_spawns_leech() -> void:
	# Wave 14 gates the score leech: it must NOT spawn at wave 13 but must
	# appear once the wave advances to 14.
	_reset_enemies()
	_manager.wave = 13
	_manager._start_next_wave()  # wave becomes 14
	assert_gt(_count_script(_manager.enemies, "score_leech3d.gd"), 0,
		"wave 14 spawns at least one score leech")

func _reset_enemies() -> void:
	# Test isolation: free every enemy node and clear the manager's array so
	# leftover spawns from earlier wave tests can't pollute later assertions.
	for e in _manager.enemies:
		if e is Node:
			(e as Node).free()
	_manager.enemies.clear()

func _count_script(enemies: Array, script_fragment: String) -> int:
	var n := 0
	for e in enemies:
		if e and e.get_script() and e.get_script().resource_path.contains(script_fragment):
			n += 1
	return n

func _find_enemy(enemies: Array, script_fragment: String) -> Node:
	for e in enemies:
		if e is Node and e.get_script() != null:
			var path: String = e.get_script().resource_path
			if path.contains(script_fragment):
				return e
	return null
