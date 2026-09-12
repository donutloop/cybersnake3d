# test_wave_eat.gd — Deterministic reproduction of "snake cannot eat new shards
# after a wave transition (board growth)".
#
# Simulates: snake eats a shard on the original 40x40 board, then the board
# grows to 60x60 (as the enemy_manager does on _start_next_wave), a new shard
# spawns, and the snake tries to eat it.
extends "res://tests/test_runner.gd"

const SnakeScript = preload("res://scripts/snake3d.gd")
const SpawnerScript = preload("res://scripts/spawner3d.gd")
const LevelSettings = preload("res://scripts/level_settings.gd")

var _snake: Node
var _spawner: Node


func _ready() -> void:
	LevelSettings.grid_w = 40
	LevelSettings.grid_h = 40
	_snake = SnakeScript.new()
	_snake.name = "Snake"
	add_child(_snake)
	_spawner = SpawnerScript.new()
	_spawner.name = "ICEShardSpawner"
	add_child(_spawner)
	_run_all()
	_finish()


func _run_all() -> void:
	_test_eat_before_wave()
	_test_eat_after_wave()
	_test_long_snake_can_eat_after_wave()


func _reset_snake() -> void:
	_snake.body.clear()
	_snake.body.append(Vector2i(20, 20))
	_snake.body.append(Vector2i(19, 20))
	_snake.body.append(Vector2i(18, 20))
	_snake.prev_directions.clear()
	_snake.direction = Vector2i(1, 0)
	_snake.next_direction = Vector2i(1, 0)


func _make_long_snake(length: int) -> void:
	# A straight horizontal snake of `length` cells ending at the board's left edge.
	_snake.body.clear()
	var y := 20
	for i in range(length):
		_snake.body.append(Vector2i(39 - i, y))
	_snake.prev_directions.clear()
	_snake.direction = Vector2i(-1, 0)
	_snake.next_direction = Vector2i(-1, 0)


func _clear_shards() -> void:
	_spawner.shards.clear()
	for m in _spawner.shard_meshes:
		m.queue_free()
	_spawner.shard_meshes.clear()
	for l in _spawner.shard_lights:
		l.queue_free()
	_spawner.shard_lights.clear()


func _in_body(cell: Vector2i) -> bool:
	# Mirrors snake3d._is_self_collision: the tail cell (last index) is vacated.
	for i in range(_snake.body.size() - 1):
		if _snake.body[i] == cell:
			return true
	return false


func _dir_to(head: Vector2i, target: Vector2i) -> Vector2i:
	var delta := target - head
	var cands: Array[Vector2i] = []
	if absi(delta.x) >= absi(delta.y):
		cands.append(Vector2i(signi(delta.x), 0))
		cands.append(Vector2i(0, signi(delta.y)))
	else:
		cands.append(Vector2i(0, signi(delta.y)))
		cands.append(Vector2i(signi(delta.x), 0))
	for c in cands:
		if not _in_body(head + c):
			return c
	return cands[0]


func _drive_to(target: Vector2i, max_steps: int) -> int:
	# Returns number of steps taken; the shard is eaten when the head lands on it.
	var guard := 0
	while _spawner.shards.size() > 0 and guard < max_steps:
		var head: Vector2i = _snake.body[0]
		_snake.next_direction = _dir_to(head, target)
		_snake._step()
		guard += 1
	return guard


func _test_eat_before_wave() -> void:
	_reset_snake()
	_clear_shards()
	var ahead := Vector2i(21, 20)
	_spawner.shards.append(ahead)
	_spawner._create_shard_mesh(ahead)
	var before: int = _snake.body.size()
	_snake.next_direction = Vector2i(1, 0)
	_snake._step()
	assert_eq(_snake.body[0], ahead, "pre-wave: head advances onto shard cell")
	assert_eq(_spawner.shards.size(), 0, "pre-wave: shard is eaten")
	assert_eq(_snake.body.size(), before + 1, "pre-wave: snake grows when it eats")


func _test_eat_after_wave() -> void:
	# Wave transition: board grows from 40x40 to 60x60.
	LevelSettings.grid_w = 60
	LevelSettings.grid_h = 60
	# Origin-fixed mapping: the snake must NOT teleport when the board grows.
	var head_before: Vector3 = _snake.grid_to_world(_snake.body[0])
	_clear_shards()
	_spawner._spawn_shard()
	assert_gt(_spawner.shards.size(), 0, "post-wave: a new shard spawns")
	var head_after: Vector3 = _snake.grid_to_world(_snake.body[0])
	assert_eq(head_after, head_before, "post-wave: snake head stays in place on growth")
	var target: Vector2i = _spawner.shards[0]
	var steps := _drive_to(target, 600)
	assert_eq(_spawner.shards.size(), 0, "post-wave: new shard is eaten")
	assert_lt(steps, 600, "post-wave: snake reaches the new shard")


func _test_long_snake_can_eat_after_wave() -> void:
	# A long snake (e.g. after eating many shards) then a wave transition.
	LevelSettings.grid_w = 40
	LevelSettings.grid_h = 40
	_make_long_snake(150)
	_clear_shards()
	# Pre-wave the board is 40x40 = 1600 cells; the snake covers 150. A shard
	# must still spawn on a free cell.
	_spawner._spawn_shard()
	assert_gt(_spawner.shards.size(), 0, "long snake pre-wave: shard spawns")
	# Wave transition: board grows to 60x60, snake body stays the same size.
	LevelSettings.grid_w = 60
	LevelSettings.grid_h = 60
	_clear_shards()
	_spawner._spawn_shard()
	assert_gt(_spawner.shards.size(), 0, "long snake post-wave: a new shard spawns")
	var target: Vector2i = _spawner.shards[0]
	var steps := _drive_to(target, 800)
	assert_eq(_spawner.shards.size(), 0, "long snake post-wave: new shard is eaten")
	assert_lt(steps, 800, "long snake post-wave: snake reaches the new shard")
