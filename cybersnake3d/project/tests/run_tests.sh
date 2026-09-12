#!/usr/bin/env bash
# tests/run_tests.sh — Runs the CyberSnake test suites headless for CI.
#
#   Usage: tests/run_tests.sh
#
# Uses the Godot binary from $GODOT (set it to point at a Godot 4.x binary),
# falling back to `godot` on PATH. Each suite reports its own pass/fail count
# and a process exit code; this runner aggregates them and exits non-zero if
# any suite failed.
set -u

GODOT_BIN="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR"

suites=(unit integration)
failed=0

for suite in "${suites[@]}"; do
    echo ""
    echo "== suite: $suite =="
    timeout 90 "$GODOT_BIN" --path "$PROJECT" --headless "res://tests/$suite.tscn"
    code=$?
    echo "== exit: $code =="
    if [ "$code" -ne 0 ]; then
        failed=1
    fi
done

echo ""
if [ "$failed" -ne 0 ]; then
    echo "TEST RESULT: FAILED"
    exit 1
fi
echo "TEST RESULT: PASSED"
exit 0
