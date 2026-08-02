#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== LuaCPU2 Verilator Test Suite ==="
echo "Running simulation..."

cd "$SCRIPT_DIR"
make all

echo ""
echo "=== Done ==="
