#!/bin/bash
# Rebuild and (re)launch Pomodoro.
set -euo pipefail

cd "$(dirname "$0")"

./build.sh
pkill -f "Pomodoro.app/Contents/MacOS/Pomodoro" 2>/dev/null || true
open build/Pomodoro.app

echo "Running — look for the 🍅 in your menu bar."
