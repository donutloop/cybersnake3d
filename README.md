# Prototype Omega — Godot Game Projects

Experimental game projects built with **Godot Engine 4.5+**.

> **Status**: Experimental — expect rough edges and rapid iteration.

---

## Prerequisites

| Dependency       | Version | Notes                                                             |
| ---------------- | ------- | ----------------------------------------------------------------- |
| **Godot Engine** | 4.5+    | Download from [godotengine.org](https://godotengine.org/download) |

```bash
export GODOT=/path/to/godot
```

---

## Repository Layout

```
prototype_omega/
├── AGENTS.md                      # AI-agent rules & conventions
├── README.md                      # ← you are here
├── .gitignore
│
└── cybersnake3d/                  # 3D Cyberpunk Snake game (GDScript)
    └── project/                   # Godot project root
        ├── project.godot          # Forward+, 1920×1080, SDFGI, SSR, TAA
        ├── main.tscn              # 3D scene (environment, camera, grid, snake, enemies, HUD)
        ├── scripts/
        │   ├── snake3d.gd         # Core snake controller (grid on XZ plane)
        │   ├── camera_follow.gd   # Smooth third-person camera
        │   ├── spawner3d.gd       # ICE shard spawner (PrismMesh + OmniLight)
        │   ├── hud.gd             # HUD overlay (CanvasLayer)
        │   ├── enemy_manager3d.gd # Wave system
        │   └── enemies/           # 5 enemy types + boss (all 3D)
        └── shaders/
            └── grid_floor.gdshader # Neon grid floor (spatial shader)
```

---

## CyberSnake 3D

A neon-noir **3D snake game** with tiered enemies, a multi-phase boss, boid-flocking swarms, volumetric fog, and bloom.

```bash
# Run the game (using GODOT env var)
$GODOT --path cybersnake3d/project/

# Or directly with the binary path
/home/donutloop/Workspace/godot_binary --path cybersnake3d/project/

# Open in editor
$GODOT --editor --path cybersnake3d/project/
```

**Controls**: Arrow keys to steer, Enter to restart after death.

#### Enemy Roster (wave-gated)

| Enemy | Wave | Behavior |
|-------|------|----------|
| Glitch Drone | 1 | Random walk stutter |
| Virus Swarm | 2+ | Boid flock |
| Net Reaper | 3+ | A* hunter with frenzy |
| Compiler Worm | 4+ | Snake-like trail |
| **Cascade Shredder** | 4+ | Telegraphs a glowing line, then lunges straight down a row/column at high speed; a hit knocks it out of the charge |
| Phantom Protocol | 5+ | Phase-shifting teleport |
| **Static Web** | 6+ | Area-denial crawler that leaves damaging residue cells; overcharge burns residue away |
| **Hunter** | 7+ | Homing seeker that accelerates the longer it chases |
| Split Echo | 8+ | Splits into non-splitting echoes when wounded |
| **Warp Shard** | 9+ | Teleports to a distant edge cell when struck, forcing pursuit |
| Blackwall Sentinel | 10+ | Boss, spawns drones |
| **Wraith** | 12+ | Phases through body segments — only the head blocks it |
| **Overdrive Mine** | 13+ | Stationary hazard: wounds for exactly 1 HP (never kills), burns away under overcharge |
| **Chrono Anchor** | 11+ | Stationary temporal wall: rewinds the snake head one cell (no HP loss), burns away under overcharge |
| **Score Leech** | 14+ | Drains a fraction of the score instead of killing outright |
| Hive Queen | 15+ | Boss, spawns swarm minions |

A boss health bar (top of screen) appears while the Blackwall Sentinel is alive, fed from its `is_boss`/`hp`/`max_hp` each frame.

The death screen now shows the final score (e.g. `GAME OVER — SCORE: 1234`) before the restart prompt.

Press `Space`/`P` to pause/resume (`get_tree().paused` + a `PAUSED` HUD overlay).

Clearing a wave awards a bonus (`100 + wave*20` score + 30 XP) and flashes a green `WAVE CLEAR +N` announcement.

Taking damage now flashes an enemy's neon material white briefly (hit feedback) on the Shredder, Static Web, and Sentinel boss.

Wave announcements distinguish boss waves: wave 10+ shows a red `>>> BOSS WAVE N <<<` instead of the normal cyan wave banner.

Wave 15+ spawns a second boss, the **Hive Queen** — a mobile amber boss that hatches Virus Swarm minions around itself (capped at 3 active) and dashes toward the snake's head. It shares the overcharge-burn contract and rewards 2500 score + 250 XP on death.

Combo labels now color by tier: cyan at x2-3, gold at x4-5, red-hot at x6+.

Boss populations are capped at 2 concurrent per boss type (Sentinel, Hive Queen) to keep the field manageable at high waves.

Boss kills now announce a red `BOSS SLAIN +N` banner via a new `snake.boss_slain` signal emitted by the Sentinel (2000) and Hive Queen (2500).

Evolution up shows a rising cyan `EVOLUTION UP!` banner alongside the existing white flash.

Overcharge now releases a radial burst: when the timer completes, `_release_burst()` damages every enemy within a 2-cell radius of the snake's head.

The death screen now shows `GAME OVER — SCORE: N — BEST: M`, persisting the high score to `user://best_score.txt`.

Overcharge now magnetizes nearby shards: `_magnet_shards()` eats every shard within a 2-cell radius at burst time, awarding their score/combo.

Wave clears now pulse the neon grid floor: a new `grid_energy` shader uniform flashes the glow and tweens back to 0 via `_pulse_floor()`.

Combo milestones now grant bonus XP: every 5th chained pickup awards 25 XP (`combo % 5 == 0`).

The Sentinel boss now enrages below half HP: `enraged` triggers an immediate drone spawn and doubles its base neon glow.

Between waves the HUD now shows a `NEXT WAVE IN N` countdown, and `update_hud` guards its labels against missing scene nodes.

Enemy spawns are now placed far from the snake head (distance >= 5, retried up to 60 cells) so enemies don't appear on top of the player.

Pausing now shows a gold `PAUSED` overlay via `_update_pause()` reading `get_tree().paused`.

Overcharge burst and shard-magnet radii now scale with evolution stage: radius = 1 + clamp(stage, 1, 3), so higher evolutions sweep a wider area.

The Hive Queen now enrages below half HP like the Sentinel: `enraged` triggers an immediate swarm hatch and doubles its base neon glow.

The overcharge meter now tints red during the final second before the burst (a ready-flash).

Boss death now cleans up its minions: the Sentinel kills its tagged drones and the Hive Queen kills its tagged swarms on `_die`.

The HUD now shows a live `ENEMIES LEFT` counter, counting in-tree enemies each frame.

The combo meter flashes red when a chain is dropped (timer expires).

Shard gain now scales with the wave: each +10 wave tier multiplies gain by 10% (e.g. wave 10+ shards pay 200 per combo base).

### Post-Processing (neon CRT)

A fullscreen `CanvasLayer` (layer 10, above the HUD) applies `shaders/crt_post.gdshader` to the viewport backbuffer: scanlines, chromatic aberration, and a vignette for the neon-noir look.

A `danger_pulse.gd` controller drives those uniforms from the Snake's HP each frame: the `vignette_strength` darkens toward the screen edge as HP drops (0 at full HP, 1 at 1 HP — a pure, unit-tested mapping), and `scanline_strength` spikes briefly whenever the snake takes a hit.
Danger pulse hit flash strength comes from hit_flash_strength, a pure mapping (0.35).
Danger pulse hit flash fade comes from decay_flash, a pure mapping (linear fade, clamped).
ICE shard respawn interval comes from shard_spawn_interval, a pure mapping (5 seconds).
Enemy manager boss cap comes from boss_cap, a pure mapping (2 concurrent).
Enemy manager hive queen cap comes from hive_queen_cap, a pure mapping (2 concurrent).
Snake combo milestones come from is_milestone, a pure mapping (every 5th combo).
Snake combo window fade comes from decay_combo_timer, a pure mapping (linear, clamped).
Snake overcharge cooldown fade comes from decay_overcharge_timer, a pure mapping (linear, clamped).
Snake overcharge unlock stage comes from overcharge_unlock_stage, a pure mapping (stage 3).
Snake overcharge burst reach comes from burst_reach, a pure mapping (magnet radius + 1).
HUD boss-kill banner comes from boss_slain_text, a pure formatter.
HUD wave-clear bonus grows via wave_clear_bonus, a pure mapping (base 100 + 20/wave).
HUD evolution banner comes from evolution_banner_text, a pure mapping.
Chrono Anchor base HP comes from anchor_base_hp, a pure mapping (3 HP).
Net Reaper base HP comes from reaper_base_hp, a pure mapping (2 HP).
Warp Shard base HP comes from shard_base_hp, a pure mapping (4 HP).
Split Echo base HP comes from echo_base_hp, a pure mapping (6 HP).
Score Leech base HP comes from leech_base_hp, a pure mapping (4 HP).
Hunter base HP comes from hunter_base_hp, a pure mapping (3 HP).
Cascade Shredder base HP comes from shredder_base_hp, a pure mapping (3 HP).
Static Web base HP comes from web_base_hp, a pure mapping (4 HP).
Wave intervals shrink as waves progress via enemy_manager.wave_delay, a pure mapping (floors at 1.0).
Net Reaper frenzy doubles speed via frenzy_speed_multiplier, a pure mapping.
Virus swarm size bounds come from swarm_size_min/max, pure mappings.
Split Echo fracture count and HP divisor come from split_count/echo_hp_divisor, pure mappings.
Static Web residue persistence comes from residue_life, a pure mapping (6 seconds).
Warp Shard flash duration comes from warp_flash_time, a pure mapping (0.35s).
Hunter chase speed ramps via hunt_speed, a pure mapping (base + 0.35/s, capped).
Score Leech siphon rate comes from drain_ratio, a pure mapping (25% per drain).
Overdrive Mine flash durations come from prime_flash_time/hit_flash_time, pure mappings.
Wraith glide speed comes from wraith_speed, a pure mapping (speed 3).
ICE shard float height comes from shard_float_height, a pure mapping (0.3 units).
Chrono Anchor flash durations come from anchor_flash_time/anchor_hit_flash_time, pure mappings.
Snake hit invulnerability comes from hit_invuln_time, a pure mapping (2 seconds).
Snake pickup/wall grace periods come from pickup_invuln_time/wall_invuln_time, pure mappings.
Snake overcharge cooldown scales via overcharge_cooldown, a pure mapping (floors at 3s).
Snake shard gain wave multiplier comes from wave_factor, a pure mapping (+1 per 10 waves).
Snake base shard gain comes from base_shard_gain, a pure mapping (100 per shard).
Snake enemy-kill XP comes from kill_xp, a pure mapping (15 XP).
Snake evolution stage derives from XP via evolution_stage_for_xp, a pure mapping.
HUD boss-wave detection comes from is_boss_wave, a pure mapping (waves >= 10).
HUD snake HP bar fill comes from hp_ratio, a pure mapping (clamped 0..1).
HUD evolution XP bar fill comes from evolution_bar_fill, a pure mapping (clamped to stage range).
HUD wave announce duration comes from wave_announce_time, a pure mapping (2 seconds).
HUD death screen headline comes from game_over_text, a pure formatter.
Camera shake decay rate comes from shake_decay_rate, a pure mapping (6/s).
CRT scanline intensity ramps via scanline_strength, a pure mapping.

## Gameplay Features

- **Overcharge window** (evolution stage ≥ 3): when the snake eats an ICE
  shard it enters a brief invulnerable + lethal state. The whole body now
  glows cyan (`snake3d.gd::_update_overcharge_visual`) so the player can see
  when they are safe to plow through enemies. Evolution gates the tool: it
  stays locked below stage 3, and higher stages recharge the cooldown faster
  (8s at stage 3 down to a 4s floor at stage 5) so late-game combat cadence
  improves rather than just raw HP/speed.

- **Shard combo**: eating shards within a short window chains a combo; each
  extra pickup in the chain adds +100 to the score (`snake3d.gd::_register_pickup`).
  The camera also shakes on damage and shard pickups (`camera_follow.gd::apply_shake`).

---

## Contributing

See [AGENTS.md](./AGENTS.md) for coding standards, scene tree conventions, and patterns.

---

## Testing & Integration (Required)

Tests are a first-class requirement — see `AGENTS.md §9` and `tests/README.md`.

```bash
GODOT=/path/to/godot tests/run_tests.sh
```

Runs the unit suite (`tests/unit/test_snake.gd`) and the integration suite
(`tests/integration/test_waves.gd`) headless and exits non-zero on any failure.
The integration suite is a regression guard for enemy spawning (phantom, worm,
reaper) and the snake invulnerability contract.

## License

- [Godot Engine — MIT](https://github.com/godotengine/godot/blob/master/LICENSE.txt)
Shards eaten inside the overcharge window score a 1.5x gain bonus (overdrive_gain_multiplier), so risky overcharge play pays off.
Deep combo streaks also tier up the shard gain: x1 under 4, x1.5 at 4-7, x2 at 8+ (combo_tier_multiplier).
The overcharge shard-magnet radius scales with evolution stage (1..3) via magnet_radius, a pure clamped mapping.
The Sentinel boss (wave 10) scales its HP with the wave via boss_hp (base 10, +1 per 5 waves past the first), a pure mapping.
The overcharge burst damage scales with evolution stage (1..3) via burst_damage, a pure clamped mapping.
Enemy spawn counts scale with waves past unlock via spawn_count (capped at 6 per type), a pure clamped mapping.
The HUD score label comma-groups thousands via format_score, a pure formatter.
Deep combo streaks extend the combo window via combo_window_seconds (base 1.0s, capped 2.5s), a pure mapping.
Higher evolution stages grant a longer overcharge invulnerability window via overcharge_duration, a pure mapping.
Combo milestone XP scales with the streak tier via milestone_xp, a pure mapping.
The wave-clear score bonus scales with the wave via clear_bonus, a pure mapping.
The HUD wave label zero-pads the wave number via wave_label_text, a pure formatter.
The HUD combo label shows the multiplier only while the combo window is live via combo_display_text, a pure formatter.
The snake move interval is the inverse of speed via move_interval_from_speed, a pure clamped mapping.
The Blackwall Sentinel enrages below half max HP via enrage_threshold, a pure mapping.
The HUD combo label color comes from combo_tier_color, a pure mapping (cyan/gold/red-hot tiers).
The HUD wave countdown label hides when elapsed via countdown_text, a pure formatter.
The HUD score gain popup formats "+N" via gain_text, a pure formatter.
ICE shard counts scale with board area via spawner.max_shards, a pure mapping (clamped 3-8).
Snake evolution stats (hp/speed) come from snake.stats_for_stage, a pure clamped roster lookup.
Sentinel drone swarms scale with phase via drone_swarm_size, a pure mapping.
Hive Queen swarm hatch counts scale with wave via hatch_size, a pure mapping (capped 2-6).
Phantom teleport jitter radius comes from teleport_radius, a pure mapping.
Camera shake amplitude scales via camera.shake_amplitude, a pure mapping.
CRT vignette ramps with danger via danger_pulse.vignette_strength, a pure mapping.
