# Prototype Omega — CyberSnake 3D

This repository contains the **CyberSnake 3D** Godot project (a neon 3D snake
game) plus its test suite and the AI-agent environment that builds it.

This top-level README is a short **index** — it points to the canonical docs
and setup files without duplicating their contents.

- Full project docs: [`cybersnake3d/project/README.md`](cybersnake3d/project/README.md)
- Agent setup: [`cybersnake3d/setup/`](cybersnake3d/setup/)

---

## Layout

```
prototype_omega/
└─ cybersnake3d/
   ├─ README.md             ← this index
   ├─ project/              ← Godot project (project.godot, main.tscn, scripts/, tests/)
   ├─ setup/                ← AI agent build environment
   │  ├─ boot_deepseekv4_flash.sh
   │  └─ code_agent/pi_deepseekv4_flash.json
   └─ project/README.md     ← canonical, full project documentation
```

## Run & Test

```bash
# Run the game (Godot 4.7, Forward+)
godot --path cybersnake3d/project

# Headless parse check
godot --path cybersnake3d/project --headless --quit

# Test suite
cybersnake3d/project/tests/run_tests.sh
```

## AI Agent Setup

This project is developed by an AI coding agent running **DeepSeek V4 Flash**,
served **locally via vLLM**. The environment is in `setup/`:

- [`setup/boot_deepseekv4_flash.sh`](cybersnake3d/setup/boot_deepseekv4_flash.sh)
  boots the local vLLM server that serves the agent's model.
- [`setup/code_agent/pi_deepseekv4_flash.json`](cybersnake3d/setup/code_agent/pi_deepseekv4_flash.json)
  is the agent's model config. It selects the model id **`deepseek-v4-flash`**
  and points the agent at the **local vLLM endpoint** — the model is never
  hosted remotely.

Read each file for its exact contents; this index only points to them.
