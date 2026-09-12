# hud.gd — HUD overlay (reused from 2D, works on CanvasLayer in 3D)
extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var wave_label: Label = $WaveLabel
@onready var length_label: Label = $LengthLabel
@onready var death_screen: ColorRect = $DeathScreen
@onready var death_label: Label = $DeathScreen/DeathLabel
@onready var restart_label: Label = $DeathScreen/RestartLabel
@onready var wave_announce: Label = $WaveAnnounce

var announce_timer: float = 0.0

var lvl_bar: ProgressBar
var evo_bar: ProgressBar
var overcharge_bar: ProgressBar
var hp_bar: ProgressBar
var combo_label: Label
var gain_popup: Label
var countdown_label: Label
var paused_label: Label
var enemy_count_label: Label
var combo_bar: ProgressBar
var _combo_live: bool = false
var _combo_flash: float = 0.0
var boss_bar: ProgressBar
var boss_label: Label
var flash_rect: ColorRect
var evo_tween: Tween

func _ready() -> void:
	death_screen.visible = false
	wave_announce.visible = false
	
	# Add Flash Rect
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	# Add Progress Bars
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	
	var style_lvl = StyleBoxFlat.new()
	style_lvl.bg_color = Color(0.0, 1.0, 0.5, 1.0)
	
	var style_evo = StyleBoxFlat.new()
	style_evo.bg_color = Color(1.0, 0.8, 0.0, 1.0)

	lvl_bar = ProgressBar.new()
	lvl_bar.position = Vector2(20, 100)
	lvl_bar.size = Vector2(200, 15)
	lvl_bar.show_percentage = false
	lvl_bar.add_theme_stylebox_override("background", style_bg)
	lvl_bar.add_theme_stylebox_override("fill", style_lvl)
	lvl_bar.max_value = 50.0
	lvl_bar.value = 0.0
	add_child(lvl_bar)

	evo_bar = ProgressBar.new()
	evo_bar.position = Vector2(20, 120)
	evo_bar.size = Vector2(300, 20)
	evo_bar.show_percentage = false
	evo_bar.add_theme_stylebox_override("background", style_bg)
	evo_bar.add_theme_stylebox_override("fill", style_evo)
	evo_bar.max_value = 200.0
	evo_bar.value = 0.0
	add_child(evo_bar)

	# Overcharge window indicator (fills while the snake is invulnerable+lethal)
	var style_oc := StyleBoxFlat.new()
	style_oc.bg_color = Color(0.3, 1.0, 1.0, 1.0)
	overcharge_bar = ProgressBar.new()
	overcharge_bar.position = Vector2(20, 145)
	overcharge_bar.size = Vector2(200, 10)
	overcharge_bar.show_percentage = false
	overcharge_bar.add_theme_stylebox_override("background", style_bg)
	overcharge_bar.add_theme_stylebox_override("fill", style_oc)
	overcharge_bar.max_value = 8.0
	overcharge_bar.value = 0.0
	overcharge_bar.visible = false
	add_child(overcharge_bar)

	# Snake HP bar (fills with current health)
	var style_hp := StyleBoxFlat.new()
	style_hp.bg_color = Color(1.0, 0.2, 0.2, 1.0)
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(20, 160)
	hp_bar.size = Vector2(200, 10)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", style_bg)
	hp_bar.add_theme_stylebox_override("fill", style_hp)
	hp_bar.max_value = 1.0
	hp_bar.value = 1.0
	add_child(hp_bar)

	# Combo chain indicator
	combo_label = Label.new()
	combo_label.position = Vector2(240, 20)
	combo_label.size = Vector2(160, 30)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_label.add_theme_font_size_override("font_size", 18)
	combo_label.visible = false
	add_child(combo_label)

	# Last score-gain popup
	gain_popup = Label.new()
	gain_popup.position = Vector2(240, 50)
	gain_popup.size = Vector2(160, 30)
	gain_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gain_popup.add_theme_font_size_override("font_size", 18)
	gain_popup.visible = false
	add_child(gain_popup)

	# Combo chain window bar
	var style_combo := StyleBoxFlat.new()
	style_combo.bg_color = Color(0.2, 1.0, 0.4, 1.0)
	combo_bar = ProgressBar.new()
	combo_bar.position = Vector2(240, 145)
	combo_bar.size = Vector2(160, 10)
	combo_bar.show_percentage = false
	combo_bar.add_theme_stylebox_override("background", style_bg)
	combo_bar.add_theme_stylebox_override("fill", style_combo)
	combo_bar.max_value = 2.0
	combo_bar.value = 0.0
	combo_bar.visible = false
	add_child(combo_bar)

	# Boss health bar (top of screen, hidden until a boss spawns)
	boss_label = Label.new()
	boss_label.text = ">>> BLACKWALL SENTINEL <<<"
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 22)
	boss_label.position = Vector2(0, 6)
	boss_label.size = Vector2(1920, 30)
	boss_label.visible = false
	add_child(boss_label)

	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(20, 40)
	boss_bar.size = Vector2(1880, 14)
	boss_bar.min_value = 0.0
	boss_bar.max_value = 1.0
	boss_bar.value = 1.0
	boss_bar.show_percentage = false
	boss_bar.visible = false
	add_child(boss_bar)
	
	call_deferred("_connect_signals")
	update_hud(0, 1, 3)

func _connect_signals() -> void:
	var snake := get_node_or_null("../Snake")
	if snake:
		if snake.has_signal("score_changed"):
			snake.score_changed.connect(_on_score_changed)
		if snake.has_signal("died"):
			snake.died.connect(_on_snake_died)
		if snake.has_signal("ate_shard"):
			snake.ate_shard.connect(_on_ate_shard)
		if snake.has_signal("evolved"):
			snake.evolved.connect(_on_evolved)
		if snake.has_signal("xp_changed"):
			snake.xp_changed.connect(_on_xp_changed)
		if snake.has_signal("boss_slain"):
			snake.boss_slain.connect(_on_boss_slain)
		var manager := get_node_or_null("../EnemyManager")
		if manager and manager.has_signal("wave_cleared"):
			manager.wave_cleared.connect(_on_wave_cleared)

func _process(delta: float) -> void:
	if wave_announce.visible:
		announce_timer -= delta
		if announce_timer <= 0.0:
			wave_announce.visible = false
		else:
			wave_announce.modulate.a = clampf(announce_timer / 0.5, 0.0, 1.0)

	_update_overcharge_bar()
	_update_hp_bar()
	_update_combo_label()
	_update_gain_popup()
	_update_combo_bar()
	_update_wave_countdown()
	_update_enemy_count()
	_update_pause()
	_update_boss_bar()

	if death_screen.visible and Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()

func _update_overcharge_bar() -> void:
	var snake := get_node_or_null("../Snake")
	var stage: int = snake.evolution_stage if snake else 0
	var oc_active: bool = snake.overcharge_active if snake else false
	if stage >= 5 or oc_active:
		overcharge_bar.visible = true
		overcharge_bar.value = snake.overcharge_timer
		overcharge_bar.modulate = Color(1.0, 0.25, 0.25) if snake.overcharge_timer <= 1.0 else Color.WHITE if snake else 0.0
	else:
		overcharge_bar.visible = false
		overcharge_bar.value = 0.0

func _update_hp_bar() -> void:
	var snake := get_node_or_null("../Snake")
	var hp: float = snake.hp if snake else 0.0
	var max_hp: float = snake.max_hp if snake else 1.0
	if max_hp > 0.0:
		hp_bar.value = clampf(hp / max_hp, 0.0, 1.0)
	else:
		hp_bar.value = 0.0

func _update_combo_label() -> void:
	var snake := get_node_or_null("../Snake")
	var combo: int = snake.combo if snake else 0
	var timer: float = snake.combo_timer if snake else 0.0
	if combo >= 2 and timer > 0.0:
		combo_label.visible = true
		combo_label.text = "COMBO x%d" % combo
		# Color tiers: x2-3 cyan, x4-5 gold, x6+ red-hot.
		var color := Color(0.3, 1.0, 0.9) if combo < 4 else (Color(1, 0.85, 0.2) if combo < 6 else Color(1, 0.25, 0.25))
		combo_label.add_theme_color_override("font_color", color)
	else:
		combo_label.visible = false
		combo_label.text = ""

func _update_gain_popup() -> void:
	var snake := get_node_or_null("../Snake")
	var gain: int = snake.last_gain if snake else 0
	if gain > 0:
		gain_popup.visible = true
		gain_popup.text = "+%d" % gain
	else:
		gain_popup.visible = false
	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 22)
	countdown_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.9))
	countdown_label.position = Vector2(560, 260)
	countdown_label.size = Vector2(800, 30)
	countdown_label.visible = false
	add_child(countdown_label)
	enemy_count_label = Label.new()
	enemy_count_label.add_theme_font_size_override("font_size", 18)
	enemy_count_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	enemy_count_label.position = Vector2(20, 205)
	enemy_count_label.visible = true
	add_child(enemy_count_label)
	paused_label = Label.new()
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_label.add_theme_font_size_override("font_size", 40)
	paused_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	paused_label.position = Vector2(560, 360)
	paused_label.size = Vector2(800, 50)
	paused_label.visible = false
	add_child(paused_label)

func _update_combo_bar() -> void:
	var snake := get_node_or_null("../Snake")
	var timer: float = snake.combo_timer if snake else 0.0
	var window: float = snake.combo_window if snake else 2.0
	if timer > 0.0:
		_combo_live = true
		combo_bar.visible = true
		combo_bar.max_value = window
		combo_bar.value = timer
	else:
		if _combo_live:
			_combo_live = false
			_combo_flash = 0.35
		combo_bar.visible = false
		combo_bar.value = 0.0
	if _combo_flash > 0.0:
		_combo_flash = maxf(_combo_flash - 0.05, 0.0)
		combo_bar.modulate = Color(1.0, 0.2, 0.2)
	else:
		combo_bar.modulate = Color.WHITE

func _update_boss_bar() -> void:
	var manager := get_node_or_null("../EnemyManager")
	var boss: Node = null
	if manager:
		var enemies: Array = manager.get("enemies")
		for e in enemies:
			if e and e.get("is_boss"):
				boss = e
				break
	if boss and boss.get("hp") != null and boss.get("max_hp") != null:
		var hp: float = boss.get("hp")
		var max_hp: float = boss.get("max_hp")
		boss_bar.max_value = max_hp
		boss_bar.value = hp
		boss_bar.visible = true
		boss_label.visible = true
	else:
		boss_bar.visible = false
		boss_label.visible = false

func update_hud(p_score: int, wave: int, length: int) -> void:
	if score_label:
		score_label.text = "SCORE: %d" % p_score
	if wave_label:
		wave_label.text = "WAVE: %d" % wave
	if length_label:
		length_label.text = "LEN: %d" % length

func show_wave_announce(wave: int) -> void:
	if not wave_announce:
		return
	wave_announce.modulate.a = 1.0
	if wave >= 10:
		wave_announce.text = ">>> BOSS WAVE %d <<<" % wave
		wave_announce.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	else:
		wave_announce.text = ">>> WAVE %d <<<" % wave
		wave_announce.add_theme_color_override("font_color", Color(1, 0.15, 0.4))
	wave_announce.visible = true
	announce_timer = 2.0

func _on_score_changed(new_score: int) -> void:
	var snake := get_node_or_null("../Snake")
	var length: int = snake.body.size() if snake else 0
	update_hud(new_score, 1, length)

func _on_ate_shard() -> void:
	var snake := get_node_or_null("../Snake")
	var length: int = snake.body.size() if snake else 0
	var sc: int = snake.score if snake else 0
	update_hud(sc, 1, length)

func _on_snake_died() -> void:
	var snake := get_node_or_null("../Snake")
	var final_score: int = snake.score if snake else 0
	var best := _load_best_score()
	if final_score > best:
		best = final_score
		_save_best_score(best)
	death_label.text = "GAME OVER — SCORE: %d — BEST: %d" % [final_score, best]
	death_screen.visible = true
	restart_label.visible = true

func _load_best_score() -> int:
	var f := FileAccess.open("user://best_score.txt", FileAccess.READ)
	if f == null:
		return 0
	var text := f.get_as_text().strip_edges()
	f.close()
	return text.to_int()

func _save_best_score(value: int) -> void:
	var f := FileAccess.open("user://best_score.txt", FileAccess.WRITE)
	if f:
		f.store_string(str(value))
		f.close()

func _on_wave_cleared(wave: int) -> void:
	var bonus: int = 100 + wave * 20
	wave_announce.text = "WAVE CLEAR +%d" % bonus
	wave_announce.modulate = Color(0.4, 1.0, 0.4)
	wave_announce.visible = true

func _update_wave_countdown() -> void:
	var mgr := get_node_or_null("../EnemyManager")
	if not mgr or not mgr.between_waves:
		if countdown_label:
			countdown_label.visible = false
		return
	var remain: float = mgr.wave_delay - mgr.wave_timer
	var secs: int = maxi(1, int(remain))
	if countdown_label:
		countdown_label.text = "NEXT WAVE IN %d" % secs
		countdown_label.visible = true

func _update_enemy_count() -> void:
	var mgr := get_node_or_null("../EnemyManager")
	var alive: int = 0
	if mgr and "enemies" in mgr:
		for e in mgr.enemies:
			if e and e.is_inside_tree():
				alive += 1
	if enemy_count_label:
		enemy_count_label.text = "ENEMIES LEFT: %d" % alive

func _update_pause() -> void:
	var paused: bool = get_tree().paused if get_tree() else false
	if paused_label:
		paused_label.visible = paused
		if paused:
			paused_label.text = "PAUSED"

func _on_evolved(_stage: int) -> void:
	if evo_tween:
		evo_tween.kill()
	evo_tween = create_tween()
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.8)
	evo_tween.tween_property(flash_rect, "color", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	var banner := Label.new()
	banner.text = "EVOLUTION UP!"
	banner.add_theme_font_size_override("font_size", 32)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9))
	banner.position = Vector2(560, 120)
	banner.size = Vector2(800, 44)
	add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "position:y", 60.0, 1.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
	tw.finished.connect(func(): banner.queue_free())

func _on_xp_changed(xp: int, _level: int, evo: int) -> void:
	lvl_bar.value = xp % 50

	var thresholds := [0, 200, 500, 1000, 2000]
	var current_thresh: int = thresholds[evo - 1] if (evo - 1) >= 0 and (evo - 1) < thresholds.size() else 2000
	var next_thresh: int = thresholds[evo] if evo < thresholds.size() else 2000
	
	evo_bar.min_value = current_thresh
	evo_bar.max_value = next_thresh
	evo_bar.value = clampf(xp, current_thresh, next_thresh)

func _on_boss_slain(value: int) -> void:
	# Red banner announcing a boss kill reward.
	var banner := Label.new()
	banner.text = "BOSS SLAIN +%d" % value
	banner.add_theme_font_size_override("font_size", 28)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	banner.position = Vector2(560, 120)
	banner.size = Vector2(800, 40)
	add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "position:y", 60.0, 1.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	tw.finished.connect(func(): banner.queue_free())
