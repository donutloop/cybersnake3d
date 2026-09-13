# CyberSnake 3D

A neon **3D snake game** built in **Godot 4.7** (Forward+ renderer). Drive a
cybernetic snake across a 40x40 grid, eat ICE shards, overcharge, and survive
an escalating wave of hostile drones, bosses, and environmental hazards.

> Repository facts are drawn directly from `main.tscn`, `scripts/`, and
> `tests/` — see each section for the exact source it is derived from.

---

## Table of Contents

- [Run & Test](#run--test)
- [Scene Layout](#scene-layout)
- [Core Systems](#core-systems)
- [Snake Mechanics](#snake-mechanics)
- [Enemy Roster & Wave Gates](#enemy-roster--wave-gates)
- [Bosses](#bosses)
- [HUD & CRT Danger Overlay](#hud--crt-danger-overlay)
- [Controls](#controls)
- [Project Structure](#project-structure)
- [Known Design Choices](#known-design-choices)

---

## Run & Test

```bash
# Run the game
godot --path . 

# Headless parse check (no script errors)
godot --path . --headless --quit

# Run the unit + integration suite
tests/run_tests.sh
```

The suite currently reports **54 passing** tests (`PASS 54 FAIL 0`) across
`tests/unit/` and `tests/integration/`. `tests/integration/test_waves.gd`
spawns waves up to the boss gates and asserts enemy HP invariants
(e.g. `hp <= max_hp` for `blackwall_sentinel` and `hive_queen`).

---

## Scene Layout

Source: `main.tscn`.

```
Main [Node3D]                     # root
├─ WorldEnvironment               # fog / tonemap / glow (Forward+)
├─ Camera3D                       # fixed view over the 40x40 grid
├─ GridFloor                      # neon grid floor mesh
├─ Snake      [scripts/snake3d.gd]
├─ ICEShardSpawner                # [scripts/spawner3d.gd] shard field
├─ EnemyManager                  # [scripts/enemy_manager3d.gd] wave director
└─ HUD         [scripts/hud.gd]
└─ CRT         [CanvasLayer]
   ├─ CRTOverlay (ColorRect + shader)
   └─ DangerPulse                 # [scripts/danger_pulse.gd] vignette telegraph
```

Node paths are contract: `EnemyManager` and `ICEShardSpawner` are siblings of
`Snake` under `Main`; every enemy resolves the snake via `../../Snake`.

---

## Core Systems

- **Snake** (`snake3d.gd`) — grid-stepped movement, HP/XP, evolution,
  overcharge burst, combo scoring, shard eating, and enemy head-on attacks.
- **EnemyManager** (`enemy_manager3d.gd`) — wave timers, spawn caps, boss
  caps, and per-wave HP scaling (non-boss enemies gain `wave - 1` HP).
- **ICEShardSpawner** (`spawner3d.gd`) — keeps a shard field; `try_eat(cell)`
  removes a shard when the snake's head lands on it.
- **HUD** (`hud.gd`) — score/HP/XP, overcharge meter, combo meter, boss bar,
  wave announce, and milestone popups.
- **CRT overlay** (`danger_pulse.gd`) — post-process vignette that pulses with
  the snake's remaining HP as a danger telegraph.

---

## Snake Mechanics

Source: `snake3d.gd`.

- **Grid step**: the snake advances on `move_timer >= move_interval`; during
  overcharge it steps at **0.6×** the normal interval (faster).
- **HP / XP**: `base_hp()` and `xp_for(level)` gate evolution stages. XP comes
  from shards and enemy kills (`add_xp`).
- **Evolution stages** lower the overcharge cooldown:
  `overcharge_cooldown(stage) = maxf(3.0, 8.0 - stage)`.
- **Overcharge**: when the recharge meter empties, the snake enters an
  `overcharge_duration()` burst window — full invulnerability, a speed boost,
  and `_release_burst()` that damages every enemy within `burst_reach()`
  (damage per frame = `burst_damage()`).
- **Head-on attack**: moving onto an enemy cell damages it, grants a short
  `wall_invuln_time()` invulnerability, and sets `just_attacked` so the enemy's
  retaliatory `_die()` call is blocked (no mutual kill).
- **Combo**: each shard eaten increments `combo`; the window extends via
  `combo_window_seconds(combo) = clampf(1.0 + combo * 0.05, 1.0, 2.5)`.
  The HUD combo bar's `max_value` tracks the live window (kept in sync in
  `_register_pickup`, reset to `base_combo_window()` on chain expiry).
- **Shard score** uses `base_score() * shard_gain() * combo_multiplier()`.

---

## Enemy Roster & Wave Gates

Source: `enemy_manager3d.gd` `_spawn_wave`, `scripts/enemies/*.gd`.

All enemies are children of `EnemyManager` and share a contract: `hp`,
`max_hp`, `is_dead`, `take_damage(amount)`, `get_grid_positions()`, and a
death handler (`_die` or the virus-swarm `_all_dead`) that awards score + XP
once and `queue_free()`s the node.

| Enemy (script) | Wave gate | Behaviour |
|---|---|---|
| `glitch_drone3d` | early | basic chaser drone |
| `virus_swarm3d` | early | swarm group; death handled by `_all_dead` |
| `net_reaper3d` | early-mid | mid-speed reaper |
| `hunter3d` | mid | targets the snake's head cell |
| `compiler_worm3d` | mid | worm body segments |
| `cascade_shredder3d` | mid | telegraph-then-lunge shredder |
| `chrono_anchor3d` | mid | anchored / time-telegraphed hazard |
| `phantom_protocol3d` | mid | phasing enemy |
| `static_web3d` | mid | slows the snake (web field) |
| `wraith3d` | late | phasing wraith |
| `split_echo3d` | late | echo splitter |
| `warp_shard3d` | late | warping shard hazard |
| `score_leech3d` | late | steals score on contact |
| `overdrive_mine3d` | late | stationary mine, burst damage |
| `blackwall_sentinel3d` | **boss, w≥10** | `boss_cap()`-limited; boss HP scales with wave |
| `hive_queen3d` | **boss, w≥15** | `hive_queen_cap()`-limited; queen HP scales with wave |

Bosses set `is_boss = true` and compute `max_hp` from the wave in `_ready`;
`_spawn_enemy` skips the generic HP bump for bosses so their wave-scaled HP is
not double-applied.

---

## Bosses

- **Blackwall Sentinel** (wave 10+): boss bar HP; wave-scaled `max_hp`.
- **Hive Queen** (wave 15+): spawns/hatches minions; queen-scaled HP.

The HUD boss bar targets the first `is_boss` enemy and reads its live
`hp / max_hp`.

---

## HUD & CRT Danger Overlay

Source: `hud.gd`, `danger_pulse.gd`.

- **Score / HP / XP** readouts bound to the snake's state.
- **Overcharge meter** (`_update_overcharge_bar`): `max = maxf(3.0, 8.0 - stage)`,
  value = the snake's live recharge `overcharge_timer` (full during the burst
  window = "charged").
- **Combo meter** (`_update_combo_bar`): `max = snake.combo_window`, value =
  the remaining `combo_timer`.
- **Boss bar** (`_update_boss_bar`): `hp / max_hp` of the first boss.
- **Wave announce + milestone** popups.
- **CRT overlay**: a full-screen vignette shader; `danger_pulse.gd` scales
  vignette intensity with low HP so danger is readable at a glance.

---

## Controls

Source: snake input handling in `snake3d.gd` (arrow keys / `ui_*` actions).

- **Arrow keys** (or `ui_up` / `ui_down` / `ui_left` / `ui_right`) steer the
  snake on the grid. Turns are queued and applied on the next grid step.
- The snake auto-advances each `move_interval`; no "pause" input is wired in
  the current scene.

---

## Project Structure

```
cybersnake3d/
├─ project.godot          # Godot 4.7, Forward+ renderer
├─ main.tscn              # scene graph (see Scene Layout)
├─ scripts/
│  ├─ level_settings.gd   # 40x40 grid constants (grid_w/grid_h)
│  ├─ snake3d.gd
│  ├─ enemy_manager3d.gd
│  ├─ spawner3d.gd
│  ├─ hud.gd
│  ├─ danger_pulse.gd
│  └─ camera_follow.gd
│  └─ enemies/            # 16 enemy scripts (see Enemy Roster)
└─ tests/
   ├─ unit/               # pure-logic unit tests (mappings, stats)
   └─ integration/        # scene/wave integration (test_waves.gd)
```

---

## Known Design Choices

- The snake is effectively the aggressor head-on: ramming an enemy damages it
  and grants a short invulnerability window, so enemies mostly kill the snake
  by moving onto an idle snake rather than by being rammed.
- Enemy death handlers are guarded with `if is_dead: return` so overlapping
  damage sources (head-bump + overdrive burst) never double-award score/XP.
- Shards may spawn onto an occupied cell (snake/enemy) — the spawner only
  avoids other shards; the snake eats a shard the moment its head lands there.
