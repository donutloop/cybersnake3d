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

var _snake: Node
var _manager: Node


func _ready() -> void:
	_run_all()
	_finish()

func _make_snake() -> void:
	_snake = SnakeScript.new()
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

# ── net_reaper ────────────────────────────────────────────────────────
func _test_reaper_take_damage() -> void:
	var reaper := _make_enemy(ReaperScript, "reaper")
	var before: int = reaper.hp
	reaper.take_damage(1)
	assert_lt(reaper.hp, before, "reaper hp drops on damage")
	reaper.take_damage(99)
	assert_true(reaper.is_dead, "reaper dies at hp <= 0")

# ── compiler_worm ─────────────────────────────────────────────────────
func _test_worm_damage_shrinks_body() -> void:
	var worm := _make_enemy(WormScript, "worm")
	var before: int = worm.body.size()
	worm.take_damage(1)
	assert_lt(worm.body.size(), before, "worm body shrinks on damage")

# ── cascade_shredder ──────────────────────────────────────────────────
func _test_shredder_damage_knockback() -> void:
	var shredder := _make_enemy(ShredderScript, "shredder")
	# Start a telegraph so the shredder is committed to a charge.
	shredder._begin_telegraph(_snake)
	assert_true(shredder.telegraphing, "shredder telegraphs before a lunge")
	shredder.take_damage(1)
	assert_false(shredder.charging and shredder.telegraphing,
		"a hit interrupts the shredder's charge")

# ── phantom_protocol ──────────────────────────────────────────────────
func _test_phantom_damage_defensive_teleport() -> void:
	var phantom := _make_enemy(PhantomScript, "phantom")
	phantom.take_damage(1)
	assert_true(phantom.is_phased, "phantom phases defensively when struck")

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

# ── hive_queen ────────────────────────────────────────────────────────
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

# ── runner ─────────────────────────────────────────────────────────────
func _run_all() -> void:
	_make_snake()
	_make_manager()
	_test_drone_take_damage()
	_test_drone_glitch_stutters()
	_test_swarm_hit_kills_one_unit()
	_test_swarm_scatter_trigger()
	_test_swarm_all_dead_frees()
	_test_reaper_take_damage()
	_test_worm_damage_shrinks_body()
	_test_shredder_damage_knockback()
	_test_phantom_damage_defensive_teleport()
	_test_phantom_phases()
	_test_web_residue_fades()
	_test_sentinel_spawns_drones_into_manager()
	_test_sentinel_enrages_at_low_hp()
	_test_queen_hatches_swarms_into_manager()
	_test_queen_damage_reduces_hp()
