# Prototype Omega — CyberSnake 3D

This repository contains the **CyberSnake 3D** Godot project (a neon 3D snake
game) plus its test suite. The full project documentation lives in
[`cybersnake3d/project/README.md`](cybersnake3d/project/README.md) — read that
for the complete system map, enemy roster, bosses, HUD, controls, and known
design choices.

This top-level README is intentionally a **short index** (no duplicated
detail): it points to the canonical doc, records the AI-agent build setup, and
tracks the project-level state.

---

## Layout

```
prototype_omega/            (repo root — this README)
└─ cybersnake3d/
   ├─ README.md             ← full project docs (canonical)
   ├─ project/              ← the Godot project (project.godot, main.tscn)
   │  └─ scripts/           ← snake, enemy_manager, spawner, HUD, CRT, enemies/
   ├─ setup/                ← AI agent build environment
   │  ├─ boot_deepseekv4_flash.sh
   │  └─ code_agent/pi_deepseekv4_flash.json
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

## AI Agent Setup

This project is built by an AI coding agent. The agent runs **DeepSeek V4
Flash**, served locally via vLLM. Two files in `setup/` drive that environment:

- [`setup/boot_deepseekv4_flash.sh`](cybersnake3d/setup/boot_deepseekv4_flash.sh)
  — boots the local DeepSeek V4 Flash (vLLM) server for the agent.
- [`setup/code_agent/pi_deepseekv4_flash.json`](cybersnake3d/setup/code_agent/pi_deepseekv4_flash.json)
  — the agent's model config (model id + local vLLM endpoint).

Read each file for its exact contents; this index only points to them so the
agent setup is not duplicated here.

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
