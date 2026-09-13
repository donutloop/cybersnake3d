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
