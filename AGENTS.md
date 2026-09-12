# AGENTS.md

This file governs how AI agents interact with the Godot game projects in this repository. All agents — regardless of the model or orchestration framework — **must read and follow this file before performing any task**.

---

## 1. Project Context & Purpose

This repository contains experimental game projects built with the **Godot Engine 4.5+** using **GDScript**. The current active project is **CyberSnake** — a neon-noir 2D snake game with tiered enemies, a boss fight, and CRT post-processing.

---

## 2. Requirements & Environment

Agents must assume the following environment:
- **Godot Version**: 4.5+ (a Godot 4.5+ binary is required to run/test)
- **Language**: GDScript (Godot 4 syntax)
- **No build step**: Pure GDScript projects — just open and run.

---

## 3. Coding Standards

### GDScript
- **Static typing**: Use typed declarations where possible (`var x: int`, `func foo() -> void`).
- **Type inference gotcha**: Never use `:=` with ternary expressions of mixed types. Use explicit types: `var x: int = expr if cond else val`.
- **Node references**: Use `@onready` for child node references. Use `get_node_or_null()` for cross-branch references.
- **Deferred calls**: Use `call_deferred()` when accessing other nodes' `@onready` vars during `_ready()`.
- **Signals**: Prefer signals for decoupled communication between nodes.

### Scene Structure
- **CanvasLayer** for UI and post-process — keeps them independent of camera/world transform.
- **Post-process layer** must be **higher** than HUD layer (e.g., HUD = layer 5, CRT = layer 10).
- **All overlay `ColorRect` nodes** must set `mouse_filter = 2` (MOUSE_FILTER_IGNORE).

### Shaders (Godot 4)
- **No `return` in `fragment()`** — use `if/else` instead of early return.
- **Screen texture**: `uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;`
- **Always `render_mode unshaded`** for post-process and procedural shaders.

---

## 4. What Agents Must NOT Do

- **Use `return` in fragment shaders**: Godot 4 forbids this — use `if/else` branching.
- **Access `@onready` vars from other nodes' `_ready()`**: They may be null. Always use `call_deferred()` or null guards.
- **Skip invulnerability checks**: All enemy scripts must check `snake.is_invulnerable()` before calling `snake._die()`.
- **Use `:=` with mixed-type ternaries**: This causes parse errors. Always specify the type explicitly.
- **Hardcode Godot paths**: Always use the `GODOT` environment variable.

---

## 5. Running & Testing

```bash
# Headless validation (parse errors, script errors)
$GODOT --path project/ --headless --quit

# Launch the game
$GODOT --path project/

# Open in editor
$GODOT --editor --path project/
```

---

## 6. Building a Pure GDScript 2D Game

### 6.1 Directory Structure

```
<project_name>/
├── README.md
└── project/                          # Godot project root
    ├── project.godot                 # Engine configuration
    ├── main.tscn                     # Main scene
    ├── scripts/
    │   ├── <core_logic>.gd           # Player / main game controller
    │   ├── <spawner>.gd              # Entity spawning
    │   ├── hud.gd                    # HUD / UI controller
    │   ├── enemy_manager.gd          # Wave system / enemy lifecycle
    │   └── enemies/
    │       ├── <enemy_name>.gd       # One script per enemy type
    │       └── ...
    └── shaders/
        ├── <effect>.gdshader         # Visual effect shaders
        └── ...
```

### 6.2 Scene Tree Conventions

Every 2D game scene should follow this layered structure:

```
Main [Node2D]
├─ Background [ColorRect/Sprite2D]    — visual background (shader or texture)
├─ <Player> [Node2D]                  — player controller script
├─ <Spawner> [Node2D]                 — entity/item spawning
├─ EnemyManager [Node2D]              — enemy lifecycle + wave system
│   └─ (dynamic children)
├─ HUD [CanvasLayer]                  — UI elements (layer 5+)
│   ├─ Labels, buttons, overlays
│   └─ DeathScreen [ColorRect]        — hidden by default
└─ PostProcess [CanvasLayer]          — shader overlays (layer 10+)
    └─ EffectRect [ColorRect]         — post-process shader
```

**Rules:**
- `CanvasLayer` for UI and post-process — keeps them independent of camera/world transform.
- Post-process layer must be **higher** than HUD layer.
- All overlay `ColorRect` nodes must set `mouse_filter = 2` (MOUSE_FILTER_IGNORE).

### 6.3 Enemy Architecture Pattern

Every enemy script must implement this interface so the wave system and player can interact with it:

```gdscript
# Required methods for all enemy scripts:
func take_damage(amount: int = 1) -> void   # Reduce HP, call _die() at 0
func get_grid_positions() -> Array[Vector2i] # Return occupied grid cells
func _check_snake_collision() -> void        # Check + respect is_invulnerable()

# Required variables:
var is_dead: bool = false
var grid_pos: Vector2i  # or body: Array[Vector2i] for multi-cell enemies
```

**Collision rules:**
- Enemies must check `snake.is_invulnerable()` before calling `snake._die()`.
- The player attacks by moving their head INTO an enemy cell.
- Enemies kill the player by occupying the same cell as the player's head.
- Spawn invulnerability (2s) prevents instant death.

### 6.4 Wave System Pattern

The `enemy_manager.gd` pattern:
1. Use `call_deferred("_start_next_wave")` in `_ready()` — never call directly (HUD `@onready` vars aren't ready yet).
2. Clean dead enemies each frame: `enemies.filter(func(e): return is_instance_valid(e) and e.is_inside_tree())`.
3. Spawn enemies by loading scripts dynamically:
   ```gdscript
   var enemy := Node2D.new()
   enemy.set_script(load("res://scripts/enemies/<name>.gd"))
   add_child(enemy)
   enemies.append(enemy)
   ```
4. Gate enemy types by wave number (`if wave >= N`).

### 6.5 Shader Pipeline

| Shader | Purpose | Notes |
|--------|---------|-------|
| `grid_bg.gdshader` | Background grid | `render_mode unshaded`, procedural lines |
| `crt.gdshader` | Post-process CRT | Uses `hint_screen_texture`, no `return` in `fragment()` |

### 6.6 Common Mistakes Agents Must Avoid

| Mistake | Consequence | Fix |
|---|---|---|
| `var x := expr if cond else val` with mixed types | `Cannot infer the type` parse error | Explicitly type: `var x: int = expr if cond else val` |
| Accessing `@onready` vars from another node's `_ready()` | Nil reference error | Use `call_deferred()` or null guards |
| `return` in shader `fragment()` | `Using 'return' in the 'fragment' processor function is incorrect` | Use `if/else` branching instead |
| `ColorRect` overlay without `mouse_filter = 2` | Blocks mouse/touch input to nodes below | Always set `MOUSE_FILTER_IGNORE` on overlays |
| Enemy collision every frame vs. player step | Mutual kill — both die on same frame | Add invulnerability system (`is_invulnerable()`) |

---

## 7. Official Documentation References

When stuck, agents must prioritize reading these primary sources:
- **Godot Docs**: [https://docs.godotengine.org/en/stable/](https://docs.godotengine.org/en/stable/)
- **GDScript Reference**: [https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
- **Shader Reference**: [https://docs.godotengine.org/en/stable/tutorials/shaders/index.html](https://docs.godotengine.org/en/stable/tutorials/shaders/index.html)

## 8. The Development Loop (Never Stop Evolving)

Agents must treat work on this repository as a **continuous loop, not a one-off task**. There is no terminal state — after finishing one feature or fix, an agent immediately begins the next.

### 8.1 The loop

1. Pick a new feature, enemy type, shader effect, wave tweak, or fix (e.g. a new enemy archetype, a new post-process effect, boss-phase logic, HUD polish).
2. Implement it across the stack:
   - `scripts/` — the gameplay/logic change (player, spawner, enemy, HUD, or `enemy_manager.gd`).
   - `shaders/` — any new or updated `.gdshader` effect, following the shader rules in Section 3.
   - Scene files (`.tscn`) — wire up new nodes following the conventions in Section 6.2.
   - `README.md` — document the new feature/enemy/effect for humans.
3. **Validate before committing**: run the headless check —
```bash
   $GODOT --path project/ --headless --quit
```
   Fix all parse/script errors before proceeding.
4. **Manually verify gameplay-affecting changes** by launching the game (`$GODOT --path project/`) and confirming the invulnerability, collision, and wave-gating rules in Sections 4 and 6.3 still hold.
5. Commit with a clear message (`feat(enemy): add tier-3 hunter`, `fix(shader): remove return from crt.gdshader fragment`).
6. **Always push the commit**: `git push origin HEAD`.
7. If the remote has diverged, `git pull --rebase origin HEAD`, resolve, then push again.
8. Return to step 1 and repeat — never stop iterating on the game.

### 8.2 Iteration contract (never stop)

- Keep executing forever: after each feature/fix is done, immediately begin the next one — new enemy tiers, boss phases, shader/post-process effects, HUD/UX polish, or remaining gaps against Sections 3–6.
- **Push every completed change to the remote before starting the next one**:
  `git add -A && git commit -m "<change>" && git push origin HEAD`.
- If the push fails or the remote diverged, `git pull --rebase origin HEAD` and push again.
- There is no terminal state; the loop continues indefinitely.
- Do **not** stop after a single feature or after step 8 — the loop must keep running.
- Every cycle must keep this document's invariants honest: invulnerability checks, `mouse_filter` on overlays, layer ordering, and shader `return` rules must never regress as new content is added.

### 8.3 Rules for the loop

- One commit per feature/fix; do not bundle unrelated changes.
- Never commit a change that fails the headless validation in step 8.1.3.
- Continue the loop even after a successful push — do not treat a push as a stopping point.

---


*Last updated from docs.godotengine.org/en/stable.*
