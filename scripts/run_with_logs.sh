#!/bin/bash
./scripts/run.sh
echo "🔍 Watching logs for Pace..."
# Try to find the process and attach or just look at system logs if possible
# Alternatively, run the binary directly
./build/Build/Products/Debug/pace.app/Contents/MacOS/pace
