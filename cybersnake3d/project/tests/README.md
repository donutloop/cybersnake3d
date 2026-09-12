# CyberSnake Test & Integration Framework

Testing is a first-class requirement for this project. Every feature ships with
unit and/or integration coverage, and the full suite must pass before a commit.

## Architecture

```
tests/
├── test_runner.gd            # Base framework: assertions, summary, exit code
├── run_tests.sh              # CLI runner (headless, CI-friendly)
├── unit.tscn                 # Unit entry scene
├── unit/test_snake.gd        # Unit suite: snake3d.gd pure logic
├── integration.tscn          # Integration scene (mirrors main.tscn topology)
├── integration/test_waves.gd # Integration suite: wave spawning, enemies, contracts
└── README.md                 # this document
```

Design principles:

- **Isolation** — unit suites instantiate scripts in isolation, disable
  auto-processing, and drive methods directly so every assertion is
  deterministic.
- **Real topology** — the integration scene mirrors `main.tscn` (Snake and
  EnemyManager as siblings under a root), so enemy `../../Snake` paths resolve
  exactly like the shipped game.
- **Deterministic waves** — the enemy manager's auto-processing is frozen;
  suites call the real `_start_next_wave()` to advance waves.
- **No observer leaks** — signal assertions wire and then disconnect method
  callables, so suites never pollute the scene tree.
- **Method callables, not lambdas** — Godot 4 does not reliably invoke
  captured-local lambdas from emitted signals, so suites use `Callable(self,
  "_on_*")` instead.

## Running

Requires a Godot 4.x binary. Set `GODOT` (recommended) or have `godot` on PATH:

```bash
GODOT=/path/to/godot tests/run_tests.sh
```

Run a single suite directly:

```bash
godot --path project --headless res://tests/unit.tscn
godot --path project --headless res://tests/integration.tscn
```

The process exits `0` on pass and `1` on fail — suitable for CI gates.

## Coverage

- **Unit (`test_snake.gd`)** — snake initial state, movement, wall collision
  (`died` signal), self-collision (hp decrement), evolution (`evolved` signal,
  max_hp growth).
- **Integration (`test_waves.gd`)** — scene topology, wave-1 drone spawn, wave-5
  phantom spawn (the missing-file regression), phantom teleport behavior, and
  the snake invulnerability contract (phantom must not damage an invulnerable
  snake, and must damage a vulnerable one).

## Regression guard

The wave-5 integration assertion is a regression test for the
`phantom_protocol3d.gd` gap and for the Variant-inference parse bugs that once
prevented `compiler_worm3d.gd` and `net_reaper3d.gd` from loading. If an enemy
script ever stops spawning, this suite fails loudly instead of silently.
