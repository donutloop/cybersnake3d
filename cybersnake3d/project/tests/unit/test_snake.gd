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
	_test_grows_when_eating_shard()
	_test_wall_collision()
	_test_self_collision()
	_test_evolution()
	_test_overcharge_glow()
	_test_overcharge_speed_boost()
	_test_overcharge_cooldown_scales_with_evolution()
	_test_hit_breaks_combo()
	_test_combo()
	_test_overdrive_shard_bonus()
	_test_combo_tier_multiplier()
	_test_magnet_radius_scales_with_stage()
	_test_burst_damage_scales_with_stage()
	_test_combo_window_extends_with_depth()
	_test_stats_for_stage_clamps_roster()
	_test_hit_invuln_time()
	_test_pickup_and_wall_invuln_times()
	_test_overcharge_cooldown_scales_with_stage()
	_test_wave_factor_grows_with_wave()
	_test_base_shard_gain()
	_test_kill_xp_awards()
	_test_evolution_stage_for_xp()
	_test_is_milestone()
	_test_overcharge_duration_scales_with_stage()
	_test_milestone_xp_scales_with_tier()
	_test_move_interval_inverse_speed()
	_test_hit()
	_test_combo_decay()
	_test_pause()
	_test_wall_death()
	_test_burst()
	_test_burst_kill_awards_xp()
	_test_magnet()
	_test_combo_milestone()

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

func _test_grows_when_eating_shard() -> void:
	# Eating a shard in _step must keep the tail (grow by one segment)
	# instead of popping it — the classic snake growth mechanic.
	var spawner := Node.new()
	var sp := GDScript.new()
	sp.source_code = "extends Node
var ate = false
func try_eat(_c):
	ate = true
	return true"
	sp.reload()
	spawner.set_script(sp)
	var snake := _make_snake()
	spawner.name = "ICEShardSpawner"
	snake.get_parent().add_child(spawner)  # sibling at ../ICEShardSpawner
	var before: int = snake.body.size()
	snake._step()
	assert_eq(snake.body.size(), before + 1, "snake grows one segment when it eats a shard")
	spawner.free()  # don't leave a stray ICEShardSpawner for later tests

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
	var move_before: float = s.move_interval
	s.add_xp(200)
	assert_true(s.move_interval < move_before, "evolution increases speed (move_interval decreases)")
	s.disconnect("evolved", cb)
	assert_true(_evolved_fired, "evolved signal emitted at first xp threshold")
	assert_gt(s.max_hp, 3, "max_hp increases after evolution")
	assert_eq(s.hp, s.max_hp, "evolution fully heals the snake")

func _test_hit_breaks_combo() -> void:
	# Taking damage must break the active shard chain (combo resets to 0).
	var snake := _make_snake()
	snake.combo = 4
	snake.combo_timer = 1.0
	snake._hit()
	assert_true(snake.combo == 0, "hit breaks the combo chain")
	assert_true(snake.combo_timer == 0.0, "hit clears the combo window")

func _test_overcharge_speed_boost() -> void:
	# During the overcharge burst window the snake moves faster (effective
	# move interval shrinks to 0.6x), so it steps sooner than normal.
	var snake := _make_snake()
	var head_before: Vector2i = snake.body[0]
	snake.overcharge_active = true
	snake.move_timer = snake.move_interval * 0.7  # below normal, above burst threshold
	snake._process(0.01)
	assert_true(snake.body[0] != head_before, "snake dashes forward during overcharge burst")

func _test_overcharge_cooldown_scales_with_evolution() -> void:
	# Overcharge is an evolution-gated combat tool: it must NOT trigger at
	# low stages, but must unlock at stage 3 and recharge faster at higher
	# stages (stage 3: 8s cooldown, stage 5: 4s, floor 3s).
	var snake := _make_snake()
	snake.overcharge_timer = 0.5
	snake.evolution_stage = 2
	snake.overcharge_active = false
	snake._process(1.0)
	assert_false(snake.overcharge_active, "overcharge stays locked below evolution stage 3")

	# Stage 3 unlocks overcharge and sets the base 8s cooldown.
	snake.overcharge_timer = 0.5
	snake.evolution_stage = 3
	snake.overcharge_active = false
	snake._process(1.0)
	assert_true(snake.overcharge_active, "overcharge unlocks at evolution stage 3")
	assert_eq(snake.overcharge_timer, maxf(3.0, 8.0 - float(snake.evolution_stage)), "stage 3 cooldown is 5s")

	# Stage 5 recharges faster: cooldown drops to the 3s floor.
	snake.overcharge_timer = 0.5
	snake.evolution_stage = 5
	snake.overcharge_active = false
	snake._process(1.0)
	assert_true(snake.overcharge_active, "overcharge stays active at max stage")
	assert_eq(snake.overcharge_timer, maxf(3.0, 8.0 - float(snake.evolution_stage)), "stage 5 cooldown floors at 3s")

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

func _test_combo() -> void:
	var s := _make_snake()
	# First pickup within a fresh window grants base score and starts the chain.
	var g1: int = s._register_pickup()
	assert_eq(g1, 100, "first pickup grants base score")
	assert_eq(s.combo, 1, "first pickup starts combo at 1")
	# A second pickup still inside the window chains and boosts the gain.
	s.combo_timer = 0.5
	var g2: int = s._register_pickup()
	assert_eq(g2, 200, "chained pickup doubles the gain")
	assert_eq(s.combo, 2, "second pickup bumps combo to 2")
	assert_eq(s.last_gain, 200, "last_gain records the chained gain")
	# Simulating an expired window (combo_timer <= 0) resets the chain.
	s.combo_timer = 0.0
	var g3: int = s._register_pickup()
	assert_eq(g3, 100, "expired window resets the chain")
	assert_eq(s.combo, 1, "combo resets to 1 after expiry")

func _test_overdrive_shard_bonus() -> void:
	# Shards eaten inside the overcharge window score a 1.5x gain bonus.
	var s := _make_snake()
	s.combo = 1
	s.combo_timer = 0.5
	s.overcharge_active = false
	var base: int = s._register_pickup()
	s.combo = 1
	s.combo_timer = 0.5
	s.overcharge_active = true
	var bonus: int = s._register_pickup()
	assert_eq(bonus, int(round(base * s.overdrive_gain_multiplier(true))), "overcharge shard scores 1.5x bonus")

func _test_combo_tier_multiplier() -> void:
	# Deep combo streaks scale shard gain via tiers (pure mapping).
	var s := _make_snake()
	assert_eq(s.combo_tier_multiplier(1), 1.0, "combo under 4 stays x1")
	assert_eq(s.combo_tier_multiplier(4), 1.5, "combo 4-7 scores x1.5")
	assert_eq(s.combo_tier_multiplier(8), 2.0, "combo 8+ scores x2")

func _test_magnet_radius_scales_with_stage() -> void:
	# Overcharge magnet radius follows evolution stage, clamped to [1,3].
	var s := _make_snake()
	assert_eq(s.magnet_radius(1), 1.0, "stage 1 magnet radius is 1")
	assert_eq(s.magnet_radius(2), 2.0, "stage 2 magnet radius is 2")
	assert_eq(s.magnet_radius(3), 3.0, "stage 3 magnet radius is 3")
	assert_eq(s.magnet_radius(9), 3.0, "magnet radius clamps above stage 3")
	assert_eq(s.magnet_radius(0), 1.0, "magnet radius clamps below stage 1")

func _test_burst_damage_scales_with_stage() -> void:
	# Overcharge burst damage follows evolution stage, clamped to [1,3].
	var s := _make_snake()
	assert_eq(s.burst_damage(1), 1, "stage 1 burst deals 1")
	assert_eq(s.burst_damage(2), 2, "stage 2 burst deals 2")
	assert_eq(s.burst_damage(3), 3, "stage 3 burst deals 3")
	assert_eq(s.burst_damage(9), 3, "burst damage clamps above stage 3")
	assert_eq(s.burst_damage(0), 1, "burst damage clamps below stage 1")

func _test_combo_window_extends_with_depth() -> void:
	# Deeper streaks extend the combo window (capped).
	var s := _make_snake()
	assert_eq(s.combo_window_seconds(0), 1.0, "base combo window is 1.0s")
	assert_gt(s.combo_window_seconds(10), 1.0, "deep streaks extend the window")
	assert_eq(s.combo_window_seconds(50), 2.5, "combo window caps at 2.5s")

func _test_overcharge_duration_scales_with_stage() -> void:
	# Higher evolution stages grant a longer overcharge window.
	var s := _make_snake()
	assert_eq(s.overcharge_duration(1), 2.5, "stage 1 overcharge lasts 2.5s")
	assert_eq(s.overcharge_duration(3), 3.5, "stage 3 overcharge lasts 3.5s")

func _test_milestone_xp_scales_with_tier() -> void:
	# Combo milestone XP scales with the streak tier.
	var s := _make_snake()
	assert_eq(s.milestone_xp(3), 25, "low-tier milestone awards base XP")
	assert_eq(s.milestone_xp(5), 38, "tier 1.5 milestone awards 38 XP")
	assert_eq(s.milestone_xp(10), 50, "tier 2 milestone awards 50 XP")

func _test_move_interval_inverse_speed() -> void:
	# Move interval is the inverse of speed (floored at 1).
	var s := _make_snake()
	assert_eq(s.move_interval_from_speed(2), 0.5, "speed 2 moves every 0.5s")
	assert_eq(s.move_interval_from_speed(4), 0.25, "speed 4 moves every 0.25s")
	assert_eq(s.move_interval_from_speed(0), 1.0, "speed 0 floors to 1.0s")

func _test_combo_milestone() -> void:
	var s := _make_snake()
	var xp_before: int = s.xp
	for i in range(5):
		s.combo_timer = 10.0
		s._register_pickup()
	assert_true(s.xp >= xp_before + 25, "combo x5 milestone grants bonus XP")
	assert_eq(s.combo, 5, "combo reaches 5 after five chained pickups")

func _test_hit() -> void:
	var s := _make_snake()
	# A surviving hit reduces hp by 1 and grants i-frames.
	s.hp = 2
	s.max_hp = 2
	# The hp_changed signal must fire with the new hp after each hit.
	var recorded_hp: Array = [-1]
	s.hp_changed.connect(func(v: int): recorded_hp[0] = v)
	var survived1: bool = s._hit()
	assert_true(survived1, "first hit is survived")
	assert_eq(s.hp, 1, "hp reduces by 1 on hit")
	assert_gt(s.invuln_timer, 0.0, "surviving hit grants i-frames")
	assert_eq(recorded_hp[0], 1, "hp_changed signal fires with new hp")
	# The second hit at hp=1 brings hp to 0 and is fatal, clamped at 0.
	var survived2: bool = s._hit()
	assert_false(survived2, "hit at hp=1 is fatal")
	assert_eq(s.hp, 0, "hp never goes negative (clamped at 0)")
	assert_true(not s.is_alive, "snake is dead at hp 0")

func _test_combo_decay() -> void:
	var s := _make_snake()
	# The combo window decays each frame while active.
	s.combo = 3
	s.combo_timer = 1.0
	s._decay_combo(0.5)
	assert_lt(s.combo_timer, 1.0, "combo timer decays over time")
	# When the window expires, the chain resets and the timer clamps at 0.
	s.combo_timer = 0.2
	s._decay_combo(0.5)
	assert_eq(s.combo_timer, 0.0, "combo timer clamps at 0")
	assert_eq(s.combo, 0, "combo resets when the window expires")

func _test_pause() -> void:
	var s := _make_snake()
	# While paused, per-frame decay still runs but movement is frozen.
	s.paused = true
	s.combo_timer = 1.0
	s._process(0.5)
	assert_lt(s.combo_timer, 1.0, "combo timer still decays while paused")
	# Un-pausing resumes normal per-frame updates without crashing.
	s.paused = false
	s._process(0.1)
	assert_true(s.paused == false, "un-paused snake keeps updating")

func _test_wall_death() -> void:
	var s := _make_snake()
	assert_false(s._is_wall_death(Vector2i(1, 1)), "inside bounds is safe")
	assert_true(s._is_wall_death(Vector2i(-1, 0)), "negative x is fatal")
	assert_true(s._is_wall_death(Vector2i(0, -1)), "negative y is fatal")

func _test_burst() -> void:
	var snake := _make_snake()
	var mgr_script := GDScript.new()
	mgr_script.source_code = "extends Node\nvar enemies = []"
	mgr_script.reload()
	var mgr := Node.new()
	mgr.name = "EnemyManager"
	mgr.set_script(mgr_script)
	snake.get_parent().add_child(mgr)
	var enemy := Node.new()
	var s := GDScript.new()
	s.source_code = "extends Node\nvar hits = 0\nvar pos = Vector2i(0, 0)\nfunc get_grid_positions():\n\treturn [pos]\nfunc take_damage(_a):\n\thits += 1"
	s.reload()
	enemy.set_script(s)
	mgr.enemies = [enemy]
	var head: Vector2i = snake.body[0]
	enemy.pos = head
	snake._release_burst()
	assert_eq(enemy.hits, 1, "overcharge burst damages a nearby enemy")
	mgr.queue_free()
	enemy.queue_free()

func _test_burst_kill_awards_xp() -> void:
	# Overcharge burst kills must also feed evolution (consistent with head kills).
	# Remove leftover EnemyManager siblings so ../EnemyManager resolves to ours.
	for child in get_children():
		if child.name == "EnemyManager":
			child.free()
	var enemy := Node.new()
	var es := GDScript.new()
	es.source_code = "extends Node\nvar pos = Vector2i(1, 1)\nvar is_dead = false\nfunc get_grid_positions():\n\treturn [pos]\nfunc take_damage(_a):\n\tis_dead = true"
	es.reload()
	enemy.set_script(es)
	var mgr := Node.new()
	var ms := GDScript.new()
	ms.source_code = "extends Node\nvar enemies = []"
	ms.reload()
	mgr.set_script(ms)
	mgr.name = "EnemyManager"
	var snake := _make_snake()
	snake.get_parent().add_child(mgr)
	var head: Vector2i = snake.body[0]
	enemy.pos = head
	mgr.add_child(enemy)
	mgr.enemies = [enemy]  # _release_burst iterates mgr.enemies, not children
	snake.overcharge_active = true
	var xp_before: int = snake.xp
	snake._release_burst()
	assert_true(snake.xp > xp_before, "overcharge burst kill awards XP")


func _test_magnet() -> void:
	var snake := _make_snake()
	var sp_script := GDScript.new()
	sp_script.source_code = "extends Node\nvar shards = []\nvar eaten = 0\nfunc try_eat(_c):\n\teaten += 1\n\treturn true"
	sp_script.reload()
	var sp := Node.new()
	sp.name = "ICEShardSpawner"
	sp.set_script(sp_script)
	snake.get_parent().add_child(sp)
	var head: Vector2i = snake.body[0]
	sp.shards = [head]
	snake._magnet_shards()
	assert_eq(sp.eaten, 1, "overcharge magnet eats a nearby shard")
	sp.queue_free()


func _is_contiguous(body: Array) -> bool:
	for i in range(1, body.size()):
		var d: Vector2i = body[i] - body[i - 1]
		if abs(d.x) + abs(d.y) != 1:
			return false
	return true

func _test_stats_for_stage_clamps_roster() -> void:
	var s := _make_snake()
	assert_eq(s.stats_for_stage(2)["hp"], 5, "stage 2 hp is 5")
	assert_eq(s.stats_for_stage(5)["speed"], 10.0, "stage 5 speed is 10")
	assert_eq(s.stats_for_stage(99)["hp"], 20, "out-of-range stage clamps to last")

func _test_hit_invuln_time() -> void:
	var s := _make_snake()
	assert_eq(s.hit_invuln_time(), 2.0, "snake is invulnerable 2s after a hit")

func _test_pickup_and_wall_invuln_times() -> void:
	var s := _make_snake()
	assert_eq(s.pickup_invuln_time(), 0.3, "pickup grace lasts 0.3s")
	assert_eq(s.wall_invuln_time(), 0.2, "wall grace lasts 0.2s")

func _test_overcharge_cooldown_scales_with_stage() -> void:
	var s := _make_snake()
	assert_eq(s.overcharge_cooldown(1), 7.0, "stage 1 overcharge cools 7s")
	assert_eq(s.overcharge_cooldown(5), 3.0, "stage 5 overcharge floors at 3s")

func _test_wave_factor_grows_with_wave() -> void:
	var s := _make_snake()
	assert_eq(s.wave_factor(5), 1, "wave 5 has base factor 1")
	assert_eq(s.wave_factor(20), 3, "wave 20 has factor 3")

func _test_base_shard_gain() -> void:
	var s := _make_snake()
	assert_eq(s.base_shard_gain(), 100, "base shard gain is 100")

func _test_kill_xp_awards() -> void:
	var s := _make_snake()
	assert_eq(s.kill_xp(), 15, "enemy kill awards 15 xp")

func _test_evolution_stage_for_xp() -> void:
	var s := _make_snake()
	assert_eq(s.evolution_stage_for_xp(100), 1, "100 xp is stage 1")
	assert_eq(s.evolution_stage_for_xp(200), 2, "200 xp is stage 2")
	assert_eq(s.evolution_stage_for_xp(2000), 5, "2000 xp is stage 5")

func _test_is_milestone() -> void:
	var s := _make_snake()
	assert_eq(s.is_milestone(4), false, "combo 4 is not a milestone")
	assert_eq(s.is_milestone(5), true, "combo 5 is a milestone")
