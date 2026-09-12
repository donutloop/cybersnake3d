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

---

## Contributing

See [AGENTS.md](./AGENTS.md) for coding standards, scene tree conventions, and patterns.

---

## License

- [Godot Engine — MIT](https://github.com/godotengine/godot/blob/master/LICENSE.txt)
