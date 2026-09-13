# Prototype Omega — CyberSnake 3D

This repository contains the **CyberSnake 3D** Godot project (a neon 3D snake
game) plus its test suite. The full project documentation lives in
[`cybersnake3d/project/README.md`](cybersnake3d/project/README.md) — read that
for the complete system map, enemy roster, bosses, HUD, controls, and known
design choices.

This top-level README is intentionally a **short index** (no duplicated
detail): it points to the canonical doc and records the project-level state.

---

## Layout

```
prototype_omega/            (repo root — this README)
└─ cybersnake3d/
   ├─ README.md             ← full project docs (canonical)
   ├─ project/              ← the Godot project (project.godot, main.tscn)
   │  └─ scripts/           ← snake, enemy_manager, spawner, HUD, CRT, enemies/
   └─ tests/                ← unit + integration suite (54 tests)
```

## Run & Test

```bash
# Run the game (Godot 4.7, Forward+)
godot --path cybersnake3d/project

# Headless parse check
godot --path cybersnake3d/project --headless --quit

# Test suite (54 passing)
cybersnake3d/project/tests/run_tests.sh
```

## Recent Fixes (committed)

- **Combo meter accuracy**: the snake now tracks the live `combo_window`
  (extended up to 2.5s) so the HUD combo bar's max matches the actual window;
  the window resets to base on chain expiry.
- **Double-death guard**: every enemy death handler (`_die`, and the
  virus-swarm `_all_dead`) now returns early `if is_dead`, preventing
  overlapping damage sources (head-bump + overdrive burst) from double-awarding
  score/XP.

## Status

`HEAD` == `origin/main`, working tree clean. Headless parse clean; suite
`PASS 54 FAIL 0`.
