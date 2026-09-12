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
| Blackwall Sentinel | 10+ | Boss, spawns drones |

### Post-Processing (neon CRT)

A fullscreen `CanvasLayer` (layer 10, above the HUD) applies `shaders/crt_post.gdshader` to the viewport backbuffer: scanlines, chromatic aberration, and a vignette for the neon-noir look.

## Gameplay Features

- **Overcharge window** (evolution stage ≥ 5): when the snake eats an ICE
  shard it enters a brief invulnerable + lethal state. The whole body now
  glows cyan (`snake3d.gd::_update_overcharge_visual`) so the player can see
  when they are safe to plow through enemies.

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
