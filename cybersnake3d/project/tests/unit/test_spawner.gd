# tests/unit/test_spawner.gd — deterministic unit tests for spawner3d.gd shard spawning.
extends "res://tests/test_runner.gd"

const SnakeScript = preload("res://scripts/snake3d.gd")
const SpawnerScript = preload("res://scripts/spawner3d.gd")

var _snake: Node3D
var _spawner: Node3D


func _ready() -> void:
	_snake = Node3D.new()
	_snake.name = "Snake"
	_snake.set_script(SnakeScript)
	add_child(_snake)

	_spawner = Node3D.new()
	_spawner.set_script(SpawnerScript)
	add_child(_spawner)


	_run_all()
	_finish()


func _run_all() -> void:
	_test_spawn_adds_one_shard()
	_test_spawn_avoids_snake_cells()
	_test_spawn_no_duplicates()
	_test_eat_removes_shard()
	_test_get_shard_positions()


func _set_snake_occupied(cells: Array) -> void:
	_snake.body.clear()
	for cell in cells:
		_snake.body.append(cell)


func _spawn_many(count: int) -> void:
	for _i in range(count):
		_spawner._spawn_shard()


func _test_spawn_adds_one_shard() -> void:
	_spawner.shards.clear()
	_set_snake_occupied([Vector2i(0, 0), Vector2i(1, 0)])
	var before: int = _spawner.shards.size()
	_spawner._spawn_shard()
	assert_eq(_spawner.shards.size(), before + 1, "spawning adds exactly one shard")


func _test_spawn_avoids_snake_cells() -> void:
	_spawner.shards.clear()
	_set_snake_occupied([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	_spawn_many(3)
	var occupied: Array = _snake.get_occupied_cells()
	for shard in _spawner.shards:
		assert_false(occupied.has(shard), "spawned shard never sits on a snake cell")


func _test_spawn_no_duplicates() -> void:
	_spawner.shards.clear()
	_set_snake_occupied([Vector2i(0, 0)])
	_spawn_many(3)
	var seen := {}
	for shard in _spawner.shards:
		assert_false(seen.has(shard), "spawner never drops two shards on one cell")
		seen[shard] = true


func _test_eat_removes_shard() -> void:
	_spawner.shards.clear()
	_set_snake_occupied([Vector2i(0, 0)])
	_spawn_many(1)
	var before: int = _spawner.shards.size()
	if before == 0:
		return
	var cell: Vector2i = _spawner.shards[0]
	assert_true(_spawner.try_eat(cell), "eating at a shard cell removes it")
	assert_lt(_spawner.shards.size(), before, "eaten shard leaves the board")
	assert_false(_spawner.try_eat(Vector2i(-99, -99)), "eating off-board returns false")


func _test_get_shard_positions() -> void:
	_spawner.shards.clear()
	_set_snake_occupied([Vector2i(0, 0)])
	_spawn_many(2)
	var positions: Array = _spawner.get_shard_positions()
	assert_eq(positions.size(), _spawner.shards.size(), "shard positions mirror the board")
