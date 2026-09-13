# split_echo3d.gd — Tier 4: hydra-like enemy that splits into echoes when damaged.
# When an echo drops to half HP it fractures into two smaller echoes (which cannot
# split again). Each echo awards XP when killed, so a fractured swarm pays more.
extends Node3D
const LevelSettings = preload("res://scripts/level_settings.gd")


var grid_pos := Vector2i.ZERO
var hp: int = echo_base_hp()
var max_hp: int = echo_base_hp()
var speed_steps: float = 4.0
var move_timer: float = 0.0
var is_dead: bool = false
var split_used: bool = false


func _ready() -> void:
	grid_pos = _random_edge()
	move_timer = randf() * 1.0
	_update_position()

func _process(delta: float) -> void:
	if is_dead:
		return
	move_timer += delta
	if move_timer >= 1.0 / speed_steps:
		move_timer = 0.0
		_step()
		_update_position()
	_check_snake_collision()

func take_damage(amount: int = 1) -> void:
	# HP never goes negative.
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()
		return
	# Fracture once when the echo is damaged below half its original HP.
	if not split_used and hp <= max_hp / 2:
		_split()

func get_grid_positions() -> Array[Vector2i]:
	return [grid_pos]

func _check_snake_collision() -> void:
	var snake := get_node_or_null("../../Snake")
	if not snake or not snake.is_alive:
		return
	if snake.body.size() > 0 and snake.body[0] == grid_pos:
		if snake.is_invulnerable():
			# Overcharge/grace: the snake fractures this echo instead of dying.
			take_damage(2)
		else:
			snake._die()

func _die() -> void:
	is_dead = true
	var snake := get_node_or_null("../../Snake")
	if snake:
		snake.score += 80
		snake.score_changed.emit(snake.score)
		if snake.has_method("add_xp"):
			snake.add_xp(30)
	queue_free()



func echo_base_hp() -> int:
	# Split Echo base HP (pure mapping).
	return 6
func split_count() -> int:
	# Split Echo fractures into this many echoes (pure mapping).
	return 2

func echo_hp_divisor() -> int:
	# Echoes carry a third of the parent's HP (pure mapping).
	return 3
func _split() -> void:
	split_used = true
	var parent := get_parent()
	if not parent:
		return
	var spawned := 0
	for cell in _neighbor_cells():
		if spawned >= split_count():
			break
		# Avoid overlapping another echo at the same cell.
		var occupied := false
		for c in parent.get_children():
			if c.has_method("get_grid_positions"):
				for gp in c.get_grid_positions():
					if gp == cell:
						occupied = true
						break
			if occupied:
				break
		if occupied:
			continue
		var echo := Node3D.new()
		echo.name = "SplitEcho%d" % (randi() % 10000)
		echo.set_script(load("res://scripts/enemies/split_echo3d.gd"))
		parent.add_child(echo)
		echo.grid_pos = cell
		echo.hp = maxi(1, max_hp / echo_hp_divisor())
		echo.max_hp = echo.hp
		echo.split_used = true  # echoes cannot split further
		echo._update_position()
		# Register the offspring with the manager so burst attacks reach it.
		if "enemies" in parent:
			parent.enemies.append(echo)
		spawned += 1

func _step() -> void:
	# Random-walk to a neighboring cell within the play field.
	var candidates := _neighbor_cells()
	if candidates.size() > 0:
		grid_pos = candidates[randi_range(0, candidates.size() - 1)]

func _neighbor_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off in offsets:
		var next: Vector2i = grid_pos + off
		if next.x >= 0 and next.x < LevelSettings.grid_w and next.y >= 0 and next.y < LevelSettings.grid_h:
			out.append(next)
	return out

func _update_position() -> void:
	# Mesh instances are optional (unit tests run without visuals).
	if has_node("MeshInstance3D"):
		var mi := get_node("MeshInstance3D") as MeshInstance3D
		mi.position = Vector3(float(grid_pos.x) + 0.5, 0.5, float(grid_pos.y) + 0.5)

func _random_edge() -> Vector2i:
	var side := randi_range(0, 3)
	match side:
		0: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), 0)
		1: return Vector2i(randi_range(0, LevelSettings.grid_w - 1), LevelSettings.grid_h - 1)
		2: return Vector2i(0, randi_range(0, LevelSettings.grid_h - 1))
		_: return Vector2i(LevelSettings.grid_w - 1, randi_range(0, LevelSettings.grid_h - 1))
