# tests/unit/test_enemies.gd — unit coverage for every enemy's deterministic logic.
extends "res://tests/test_runner.gd"

const SnakeScript = preload("res://scripts/snake3d.gd")
const ManagerScript = preload("res://scripts/enemy_manager3d.gd")
const DroneScript = preload("res://scripts/enemies/glitch_drone3d.gd")
const SwarmScript = preload("res://scripts/enemies/virus_swarm3d.gd")
const ReaperScript = preload("res://scripts/enemies/net_reaper3d.gd")
const WormScript = preload("res://scripts/enemies/compiler_worm3d.gd")
const ShredderScript = preload("res://scripts/enemies/cascade_shredder3d.gd")
const PhantomScript = preload("res://scripts/enemies/phantom_protocol3d.gd")
const WebScript = preload("res://scripts/enemies/static_web3d.gd")
const SentinelScript = preload("res://scripts/enemies/blackwall_sentinel3d.gd")
const QueenScript = preload("res://scripts/enemies/hive_queen3d.gd")
const SplitEchoScript = preload("res://scripts/enemies/split_echo3d.gd")
const WarpShardScript = preload("res://scripts/enemies/warp_shard3d.gd")
const HunterScript = preload("res://scripts/enemies/hunter3d.gd")
const WraithScript = preload("res://scripts/enemies/wraith3d.gd")
const ScoreLeechScript = preload("res://scripts/enemies/score_leech3d.gd")
const OverdriveMineScript = preload("res://scripts/enemies/overdrive_mine3d.gd")
const ChronoAnchorScript = preload("res://scripts/enemies/chrono_anchor3d.gd")

var _snake: Node
var _manager: Node


func _ready() -> void:
	_run_all()
	_finish()

func _make_snake() -> void:
	# Free any leftover Snake children so enemy "../../Snake" paths always
	# resolve to the _snake member (a stray sibling would shadow it and
	# receive XP/score awards instead).
	for c in get_children():
		if c.name == "Snake":
			c.free()
	_snake = SnakeScript.new()
	_snake.name = "Snake"
	add_child(_snake)

func _make_manager() -> void:
	_manager = ManagerScript.new()
	_manager.name = "EnemyManager"
	add_child(_manager)
	_manager.wave = 1

func _make_enemy(script: GDScript, path: String) -> Node:
	var e: Node = script.new()
	_manager.add_child(e)
	return e

# ── snake attacks enemy (Section 6.3) ────────────────────────────────
func _test_snake_head_attacks_enemy() -> void:
	# When the snake's head moves into an enemy cell, the enemy takes 1
	# damage and the snake sets just_attacked (attack grace) so enemies
	# cannot instantly kill it on the same frame.
	# The snake damages the FIRST matching enemy, so clear earlier test
	# enemies to guarantee the mock is the only occupant of the head cell.
	for c in _manager.get_children():
		c.free()
	var enemy := Node.new()
	var s := GDScript.new()
	s.source_code = "extends Node\nvar hits = 0\nvar is_dead = false\nvar pos = Vector2i(0, 0)\nfunc get_grid_positions():\n\treturn [pos]\nfunc take_damage(_a):\n\thits += 1\n\tis_dead = true"
	s.reload()
	enemy.set_script(s)
	_manager.add_child(enemy)
	var head: Vector2i = _snake.body[0]
	enemy.pos = head
	_snake.just_attacked = false
	_snake._check_enemy_damage(head, false)
	assert_eq(enemy.hits, 1, "snake head damages an enemy in its cell")
	assert_true(_snake.just_attacked, "attack grants just_attacked grace")

func _test_snake_kill_awards_xp() -> void:
	# Killing an enemy (Section 6.3 combat) must award XP toward evolution.
	for c in _manager.get_children():
		c.free()
	var enemy := Node.new()
	var s := GDScript.new()
	s.source_code = "extends Node\nvar hits = 0\nvar is_dead = false\nvar pos = Vector2i(0, 0)\nfunc get_grid_positions():\n\treturn [pos]\nfunc take_damage(_a):\n\thits += 1\n\tis_dead = true"
	s.reload()
	enemy.set_script(s)
	_manager.add_child(enemy)
	var head: Vector2i = _snake.body[0]
	enemy.pos = head
	var xp_before: int = _snake.xp
	_snake._check_enemy_damage(head, false)
	assert_eq(enemy.hits, 1, "snake head kills the enemy")
	assert_true(_snake.xp > xp_before, "killing an enemy awards XP")

func _test_snake_tail_attack_no_grace() -> void:
	# A tail-cell attack damages the enemy but must NOT grant just_attacked
	# grace (only the head strike does), so the snake stays vulnerable.
	for c in _manager.get_children():
		c.free()
	var enemy := Node.new()
	var s := GDScript.new()
	s.source_code = "extends Node\nvar hits = 0\nvar pos = Vector2i(0, 0)\nfunc get_grid_positions():\n\treturn [pos]\nfunc take_damage(_a):\n\thits += 1"
	s.reload()
	enemy.set_script(s)
	_manager.add_child(enemy)
	var tail: Vector2i = _snake.body[_snake.body.size() - 1]
	enemy.pos = tail
	_snake.just_attacked = false
	_snake._check_enemy_damage(tail, true)  # is_tail = true
	assert_eq(enemy.hits, 1, "tail strike damages an enemy in its cell")
	assert_false(_snake.just_attacked, "tail strike grants no attack grace")

# ── glitch_drone ─────────────────────────────────────────────────────
func _test_drone_take_damage() -> void:
	var drone := _make_enemy(DroneScript, "drone")
	var before: int = drone.hp
	drone.take_damage(1)
	assert_lt(drone.hp, before, "drone hp drops on damage")
	drone.take_damage(99)
	assert_true(drone.is_dead, "drone dies when hp <= 0")

func _test_drone_glitch_stutters() -> void:
	var drone := _make_enemy(DroneScript, "drone2")
	var start: Vector3 = drone.position
	drone._process(0.0)
	# A single tick should still move the drone (random walk), and glitch
	# mode should keep it within the grid bounds.
	assert_true(abs(drone.position.x - start.x) <= 1.0 and abs(drone.position.z - start.z) <= 1.0,
		"drone random-walk stays within a single-cell step")

func _alive_count(swarm: Node) -> int:
	var n: int = 0
	for u in swarm.units:
		if u["alive"]:
			n += 1
	return n

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	return maxi(dx, dy)

# ── virus_swarm ──────────────────────────────────────────────────────
func _test_swarm_hit_kills_one_unit() -> void:
	var swarm := _make_enemy(SwarmScript, "swarm")
	var before: int = _alive_count(swarm)
	swarm.take_damage(1)
	assert_eq(_alive_count(swarm), before - 1, "swarm loses exactly one unit per hit")

func _test_swarm_scatter_trigger() -> void:
	var swarm := _make_enemy(SwarmScript, "swarm2")
	# Kill enough units to drop below half → scattering should trigger.
	while _alive_count(swarm) > _alive_count(swarm) / 2 + 1 and not swarm.scattering:
		swarm.take_damage(1)
	assert_true(swarm.scattering, "swarm scatters once half its units are lost")

func _test_swarm_all_dead_frees() -> void:
	var swarm := _make_enemy(SwarmScript, "swarm3")
	var n: int = _alive_count(swarm)
	for i in range(n):
		swarm.take_damage(1)
	assert_true(swarm.is_dead, "swarm is dead when all units are lost")

func _test_swarm_boss_cleanup_kills_all() -> void:
	# Boss cleanup calls take_damage(999) on a multi-unit swarm. A single
	# hit must clear the WHOLE swarm, not just one unit (regression guard).
	var swarm := _make_enemy(SwarmScript, "swarm_cleanup")
	var n: int = _alive_count(swarm)
	assert_gt(n, 1, "test swarm has more than one unit to exercise cleanup")
	swarm.take_damage(999)
	assert_eq(_alive_count(swarm), 0, "boss-cleanup hit kills every unit")
	assert_true(swarm.is_dead, "swarm is freed once boss cleanup clears it")

# ── net_reaper ────────────────────────────────────────────────────────
func _test_reaper_take_damage() -> void:
	var reaper := _make_enemy(ReaperScript, "reaper")
	var before: int = reaper.hp
	reaper.take_damage(1)
	assert_lt(reaper.hp, before, "reaper hp drops on damage")

func _test_reaper_frenzy_at_low_hp() -> void:
	# The reaper enters frenzy once it is wounded to its last HP point.
	var reaper := _make_enemy(ReaperScript, "reaper2")
	reaper.take_damage(reaper.hp - 1)
	assert_true(reaper.frenzy, "reaper frenzies when hp reaches 1")
	assert_gt(reaper.speed_steps, 0, "frenzy still exposes a chase speed")
	reaper.take_damage(99)
	assert_true(reaper.is_dead, "reaper dies at hp <= 0")

# ── compiler_worm ─────────────────────────────────────────────────────
func _test_worm_damage_shrinks_body() -> void:
	var worm := _make_enemy(WormScript, "worm")
	var before: int = worm.body.size()
	worm.take_damage(1)
	assert_lt(worm.body.size(), before, "worm body shrinks on damage")

func _test_worm_chases_snake_head() -> void:
	# The worm's head advances toward the snake's head each step.
	_make_snake()
	var worm := _make_enemy(WormScript, "worm_chase")
	worm.body[0] = Vector2i(0, 0)
	_snake.body[0] = Vector2i(3, 0)
	var dist_before: int = _chebyshev(worm.body[0], _snake.body[0])
	worm._step()
	var dist_after: int = _chebyshev(worm.body[0], _snake.body[0])
	assert_lt(dist_after, dist_before, "worm head closes distance to snake head")
	assert_eq(worm.body[0].y, _snake.body[0].y, "worm heads straight along the chase axis")

# ── cascade_shredder ──────────────────────────────────────────────────
func _test_shredder_damage_knockback() -> void:
	var shredder := _make_enemy(ShredderScript, "shredder")
	# Start a telegraph so the shredder is committed to a charge.
	shredder._begin_telegraph(_snake)
	assert_true(shredder.telegraphing, "shredder telegraphs before a lunge")
	shredder.take_damage(1)
	assert_false(shredder.charging and shredder.telegraphing,
		"a hit interrupts the shredder's charge")

func _test_shredder_lunge_advances() -> void:
	# A lunging shredder advances exactly one cell per lunge step.
	var shredder := _make_enemy(ShredderScript, "shredder_lunge")
	shredder.grid_pos = Vector2i(0, 0)
	shredder.lunge_dir = Vector2i(1, 0)
	shredder.lunge_cells = 3
	shredder.move_timer = 0.0
	shredder._advance_lunge(1.0 / shredder.lunge_speed)
	assert_eq(shredder.grid_pos.x, 1, "shredder advances one cell along lunge_dir")
	assert_eq(shredder.lunge_cells, 2, "shredder consumes one lunge cell per step")

# ── phantom_protocol ──────────────────────────────────────────────────
func _test_phantom_damage_defensive_teleport() -> void:
	var phantom := _make_enemy(PhantomScript, "phantom")
	phantom.grid_pos = Vector2i(20, 20)
	seed(1234)  # deterministic RNG for the teleport offset
	var before: Vector2i = phantom.grid_pos
	phantom.take_damage(1)
	assert_true(phantom.is_phased, "phantom phases defensively when struck")
	assert_true(phantom.grid_pos != before, "phantom teleports to a new grid cell when struck")

func _test_phantom_phases() -> void:
	var phantom := _make_enemy(PhantomScript, "phantom2")
	phantom._begin_phase()
	assert_true(phantom.is_phased, "phantom phases out of the grid")

# ── static_web ────────────────────────────────────────────────────────
func _test_web_residue_fades() -> void:
	var web := _make_enemy(WebScript, "web")
	web._process(0.0)
	assert_gt(web.residue.size(), 0, "web marks residue cells")
	# Drive the fade timer; residue should be cleared once it expires.
	var n: int = web.residue.size()
	web._process(web.residue_life + 1.0)
	assert_lt(web.residue.size(), n, "residue fades over time")

# ── blackwall_sentinel ────────────────────────────────────────────────
func _test_sentinel_spawns_drones_into_manager() -> void:
	var sentinel := _make_enemy(SentinelScript, "sentinel")
	var before: int = _manager.enemies.size()
	sentinel._spawn_drones(2)
	assert_gt(_manager.enemies.size(), before, "sentinel drones register in manager.enemies")

func _test_sentinel_enrages_at_low_hp() -> void:
	var sentinel := _make_enemy(SentinelScript, "sentinel2")
	sentinel.hp = 1
	sentinel.take_damage(0)
	assert_true(sentinel.enraged, "sentinel enrages when wounded below half hp")

func _test_enrage_threshold_is_half_hp() -> void:
	var sentinel := _make_enemy(SentinelScript, "sentinel3")
	assert_eq(sentinel.enrage_threshold(20), 10, "sentinel enrage threshold is half max HP")
	assert_eq(sentinel.enrage_threshold(1), 1, "enrage threshold floors at 1")

# ── hive_queen ────────────────────────────────────────────────────────
func _test_drone_swarm_size_scales_with_phase() -> void:
	var sentinel := _make_enemy(SentinelScript, "sentinel4")
	assert_eq(sentinel.drone_swarm_size(1), 2, "phase 1 spawns 2 drones")
	assert_eq(sentinel.drone_swarm_size(3), 1, "later phases spawn 1 drone")

func _test_queen_hatches_swarms_into_manager() -> void:
	var queen := _make_enemy(QueenScript, "queen")
	var before: int = _manager.enemies.size()
	queen._hatch_swarms(10.0)
	var mgr: Node = queen.get_node_or_null("../EnemyManager")
	print("DBG queen before=", before, " after=", _manager.enemies.size(), " swarm_timer=", queen.swarm_timer, " mgr=", mgr, " mgr_name=", mgr.name if mgr else "null", " children=", queen.get_parent().get_child_count())
	assert_gt(_manager.enemies.size(), before, "queen swarms register in manager.enemies")

func _test_queen_damage_reduces_hp() -> void:
	var queen := _make_enemy(QueenScript, "queen2")
	queen.take_damage(1)
	assert_lt(queen.hp, queen.max_hp, "queen hp drops on damage")

func _test_queen_respects_invulnerability() -> void:
	# Section 4 invariant: an enemy must never call snake._die() while the
	# snake is invulnerable — it only damages itself during overcharge.
	var queen := _make_enemy(QueenScript, "queen_invuln")
	var head: Vector2i = _snake.body[0]
	queen.grid_pos = head
	_snake.invuln_timer = 2.0   # spawn/hit grace: queen must not kill
	var hp_before: int = queen.hp
	_snake.is_alive = true
	queen._check_snake_collision()
	assert_true(_snake.is_alive, "queen cannot kill an invulnerable snake")
	assert_eq(queen.hp, hp_before, "queen does not self-damage while snake is invulnerable (not overcharging)")

func _test_split_fractures_on_damage() -> void:
	var echo := _make_enemy(SplitEchoScript, "split")
	echo.hp = 6
	echo.max_hp = 6
	var before: int = _manager.enemies.size()
	echo.take_damage(3)   # drop to half HP -> fractures into offspring
	assert_true(echo.split_used, "echo splits once below half hp")
	assert_gt(_manager.enemies.size(), before, "echo fractures into offspring")

func _test_split_offspring_cannot_split() -> void:
	var echo := _make_enemy(SplitEchoScript, "split")
	echo.hp = 6
	echo.max_hp = 6
	echo.take_damage(3)
	var before: int = _manager.enemies.size()
	# Damaging an offspring must NOT trigger another split.
	for c in _manager.get_children():
		if c != echo and c.has_method("take_damage") and not c.is_dead:
			c.take_damage(1)
			break
	assert_eq(_manager.enemies.size(), before, "offspring cannot split further")

func _test_split_echo_dies_awards_xp() -> void:
	var echo := _make_enemy(SplitEchoScript, "split")
	echo.hp = 3
	var xp_before: int = _snake.xp
	echo.take_damage(99)
	assert_true(echo.is_dead, "echo dies at hp <= 0")
	assert_gt(_snake.xp, xp_before, "killing a split echo awards XP")

# ── runner ─────────────────────────────────────────────────────────────
# ── warp_shard ──────────────────────────────────────────────────────────
func _test_warp_shard_teleports_away_on_damage() -> void:
	var shard := _make_enemy(WarpShardScript, "shard")
	var start: Vector2i = shard.grid_pos
	# Place the snake far from the shard so the warp anchor is well away.
	_snake.body[0] = Vector2i(start.x + 8, start.y + 8)
	var before: int = shard.warps_used
	shard.take_damage(1)
	assert_eq(shard.hp, 3, "warp shard survives a single hit")
	assert_gt(shard.warps_used, before, "warp shard warps when struck")
	assert_true(shard.grid_pos != start, "warp shard flees to a new cell after being hit")
	assert_gt(shard.grid_pos.distance_to(_snake.body[0]), 1.0,
		"warp shard lands far from the snake head")

func _test_warp_shard_dies_awards_xp() -> void:
	var shard := _make_enemy(WarpShardScript, "shard2")
	var xp_before: int = _snake.xp
	shard.hp = 2
	shard.take_damage(99)
	assert_true(shard.is_dead, "warp shard dies at hp <= 0")
	assert_gt(_snake.xp, xp_before, "killing a warp shard awards XP")


# ── hunter ──────────────────────────────────────────────────────────────
func _test_hunter_accelerates_while_pursuing() -> void:
	var hunter := _make_enemy(HunterScript, "hunter")
	var start_speed: float = hunter.speed_steps
	# Step repeatedly toward a snake head; speed must ramp up.
	_snake.body[0] = Vector2i(hunter.grid_pos.x + 2, hunter.grid_pos.y)
	for _i in range(40):
		hunter._step_toward_snake()
	assert_gt(hunter.speed_steps, start_speed,
		"hunter accelerates the longer it chases")
	assert_true(hunter.speed_steps <= hunter.max_speed,
		"hunter never exceeds its max speed")

func _test_hunter_dies_awards_xp() -> void:
	var hunter := _make_enemy(HunterScript, "hunter2")
	var xp_before: int = _snake.xp
	hunter.hp = 2
	hunter.take_damage(99)
	assert_true(hunter.is_dead, "hunter dies at hp <= 0")
	assert_gt(_snake.xp, xp_before, "killing a hunter awards XP")


# ── wraith ──────────────────────────────────────────────────────────────
func _test_wraith_ignores_body_segments() -> void:
	var wraith := _make_enemy(WraithScript, "wraith")
	# Place the wraith on a body segment that is NOT the head; stepping must
	# still move it toward the head (body segments never block the wraith).
	_snake.body[0] = Vector2i(5, 5)
	_snake.body.resize(3)
	_snake.body[1] = Vector2i(4, 5)
	wraith.grid_pos = Vector2i(4, 5)
	var moved: bool = false
	for _i in range(10):
		var before: Vector2i = wraith.grid_pos
		wraith._step_toward_snake()
		if wraith.grid_pos != before:
			moved = true
			break
	assert_true(moved, "wraith steps through a body segment toward the head")

func _test_wraith_dies_awards_xp() -> void:
	var wraith := _make_enemy(WraithScript, "wraith2")
	var xp_before: int = _snake.xp
	wraith.hp = 3
	wraith.take_damage(99)
	assert_true(wraith.is_dead, "wraith dies at hp <= 0")
	assert_gt(_snake.xp, xp_before, "killing a wraith awards XP")


# ── score_leech ─────────────────────────────────────────────────────────
func _test_leech_drains_score_on_head_collision() -> void:
	var leech := _make_enemy(ScoreLeechScript, "leech")
	_snake.body[0] = leech.grid_pos
	_snake.score = 1000
	_snake.invuln_timer = 0.0   # snake must be vulnerable for the leech to latch
	_snake.just_attacked = false
	leech._check_snake_collision()
	assert_true(_snake.is_alive, "leech does not kill the snake")
	assert_lt(_snake.score, 1000, "leech drains a fraction of the score")

func _test_leech_dies_awards_xp() -> void:
	var leech := _make_enemy(ScoreLeechScript, "leech2")
	var xp_before: int = _snake.xp
	leech.hp = 3
	leech.take_damage(99)
	assert_true(leech.is_dead, "leech dies at hp <= 0")
	assert_gt(_snake.xp, xp_before, "killing a leech awards XP")

func _test_mine_detonates_wounds_snake() -> void:
	# A vulnerable snake stepping onto an armed Overdrive Mine is wounded for
	# exactly 1 HP (not killed) and the mine is consumed by the detonation.
	var mine := _make_enemy(OverdriveMineScript, "mine")
	_snake.invuln_timer = 0.0
	_snake.just_attacked = false
	_snake.overcharge_active = false
	_snake.body[0] = mine.grid_pos
	var hp_before: int = _snake.hp
	mine._check_snake_collision()
	assert_eq(_snake.hp, hp_before - 1, "mine wounds the snake by exactly 1 HP")
	assert_true(_snake.is_alive, "mine never kills outright")
	assert_true(mine.is_dead, "mine is consumed by the detonation")

func _test_mine_burns_on_overcharge() -> void:
	# An overcharged (invulnerable) snake burns the mine away instead of
	# detonating it — no snake HP is lost.
	var mine := _make_enemy(OverdriveMineScript, "mine2")
	# Overcharge grants a real invulnerability window (invuln_timer > 0).
	_snake.invuln_timer = 2.0
	_snake.just_attacked = false
	_snake.overcharge_active = true
	_snake.body[0] = mine.grid_pos
	var hp_before: int = _snake.hp
	mine._check_snake_collision()
	assert_eq(_snake.hp, hp_before, "overcharge burns the mine with no snake damage")
	assert_true(mine.is_dead, "mine is burned away")

func _test_mine_strike_destroys_awards_xp() -> void:
	# A direct head strike destroys the mine normally and awards XP.
	var mine := _make_enemy(OverdriveMineScript, "mine3")
	var xp_before: int = _snake.xp
	mine.take_damage(2)
	assert_true(mine.is_dead, "mine dies at hp <= 0")
	assert_gt(_snake.xp, xp_before, "destroying a mine awards XP")

func _test_anchor_rewinds_snake() -> void:
	# A vulnerable snake head entering a Chrono Anchor cell is shunted back
	# onto the neck (body[1]) — no HP lost, the anchor persists as a wall.
	var anchor := _make_enemy(ChronoAnchorScript, "anchor")
	_snake.invuln_timer = 0.0
	_snake.just_attacked = false
	_snake.overcharge_active = false
	_snake.body[0] = anchor.grid_pos
	_snake.body[1] = Vector2i(anchor.grid_pos.x - 1, anchor.grid_pos.y)
	var hp_before: int = _snake.hp
	anchor._check_snake_collision()
	assert_eq(_snake.body[0], _snake.body[1], "head is rewound back onto the neck")
	assert_eq(_snake.hp, hp_before, "rewind deals no HP damage")
	assert_false(anchor.is_dead, "anchor persists after rewinding")

func _test_anchor_burns_on_overcharge() -> void:
	# Overcharge erases the anchor away; the snake keeps its position and HP.
	var anchor := _make_enemy(ChronoAnchorScript, "anchor2")
	_snake.invuln_timer = 2.0
	_snake.just_attacked = false
	_snake.overcharge_active = true
	_snake.body[0] = anchor.grid_pos
	var head_before: Vector2i = _snake.body[0]
	var hp_before: int = _snake.hp
	anchor._check_snake_collision()
	assert_eq(_snake.body[0], head_before, "overcharge does not rewind the snake")
	assert_eq(_snake.hp, hp_before, "overcharge deals no HP damage")
	assert_true(anchor.is_dead, "anchor is burned away")

func _test_anchor_strike_destroys_awards_xp() -> void:
	# A direct head strike destroys the anchor normally and awards XP.
	var anchor := _make_enemy(ChronoAnchorScript, "anchor3")
	var xp_before: int = _snake.xp
	anchor.take_damage(3)
	assert_true(anchor.is_dead, "anchor dies at hp <= 0")
	assert_gt(_snake.xp, xp_before, "destroying an anchor awards XP")

func _test_boss_hp_scales_with_wave() -> void:
	# Boss HP scales with wave via the pure boss_hp mapping.
	var boss := _make_enemy(SentinelScript, "boss")
	assert_eq(boss.boss_hp(10), 10, "wave 10 boss has base HP 10")
	assert_eq(boss.boss_hp(15), 11, "wave 15 boss gains +1 HP")
	assert_eq(boss.boss_hp(25), 13, "wave 25 boss gains +3 HP")
	assert_eq(boss.boss_hp(5), 10, "pre-boss wave floors at base HP")

func _run_all() -> void:
	_make_snake()
	_make_manager()
	_test_drone_take_damage()
	_test_drone_glitch_stutters()
	_test_swarm_hit_kills_one_unit()
	_test_swarm_scatter_trigger()
	_test_swarm_all_dead_frees()
	_test_swarm_boss_cleanup_kills_all()
	_test_reaper_take_damage()
	_test_reaper_frenzy_at_low_hp()
	_test_worm_damage_shrinks_body()
	_test_worm_chases_snake_head()
	_test_shredder_damage_knockback()
	_test_shredder_lunge_advances()
	_test_phantom_damage_defensive_teleport()
	_test_phantom_phases()
	_test_web_residue_fades()
	_test_sentinel_spawns_drones_into_manager()
	_test_sentinel_enrages_at_low_hp()
	_test_enrage_threshold_is_half_hp()
	_test_drone_swarm_size_scales_with_phase()
	_test_hatch_size_scales_with_wave()
	_test_phantom_teleport_radius_is_six()
	_test_boss_hp_scales_with_wave()
	_test_queen_hatches_swarms_into_manager()
	_test_queen_damage_reduces_hp()
	_test_queen_respects_invulnerability()
	_test_snake_head_attacks_enemy()
	_test_snake_tail_attack_no_grace()
	_test_snake_kill_awards_xp()
	_test_split_fractures_on_damage()
	_test_split_offspring_cannot_split()
	_test_split_echo_dies_awards_xp()
	_test_warp_shard_teleports_away_on_damage()
	_test_hunter_accelerates_while_pursuing()
	_test_wraith_ignores_body_segments()
	_test_leech_drains_score_on_head_collision()
	_test_leech_dies_awards_xp()
	_test_mine_detonates_wounds_snake()
	_test_mine_burns_on_overcharge()
	_test_mine_strike_destroys_awards_xp()
	_test_anchor_rewinds_snake()
	_test_anchor_burns_on_overcharge()
	_test_anchor_strike_destroys_awards_xp()
	_test_wraith_dies_awards_xp()
	_test_hunter_dies_awards_xp()
	_test_warp_shard_dies_awards_xp()

func _test_hatch_size_scales_with_wave() -> void:
	var queen := _make_enemy(QueenScript, "queen2")
	assert_eq(queen.hatch_size(1), 2, "wave 1 hatches 2 swarms")
	assert_eq(queen.hatch_size(5), 3, "wave 5 hatches 3 swarms")
	assert_eq(queen.hatch_size(30), 6, "high wave caps at 6 swarms")

func _test_phantom_teleport_radius_is_six() -> void:
	var phantom := _make_enemy(PhantomScript, "phantom2")
	assert_eq(phantom.teleport_radius(), 6, "phantom teleport jitter radius is 6")
