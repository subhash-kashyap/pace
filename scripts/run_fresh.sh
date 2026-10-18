#!/bin/bash

# run_fresh.sh - Clears app state and runs Pace to test onboarding.

echo "🧹 Clearing app state..."
defaults delete com.synw.pace 2>/dev/null

echo "🚀 Running Pace..."
./scripts/run.sh
