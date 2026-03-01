#!/usr/bin/env bash
set -euo pipefail

# run_analyze_check.sh - Analysiert die Prompt-Empfehlungen
# Führt die Analyse durch, ohne Dateien zu installieren

SCRIPT_DIR="$(cd ""$(dirname ""${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$SCRIPT_DIR"
MANIFEST="$SCRIPT_DIR/prompt_manifest.txt"
TARGET_HOME="${HOME}"
PROFILE="">${1:-auto}"

if [[ ! -f "$SCRIPT_DIR/recommend_prompts.py" ]]; then
  echo "Error: recommend_prompts.py not found" >&2
  exit 1
fi

echo "Running analysis check..."
python3 "$SCRIPT_DIR/recommend_prompts.py" \
  --manifest "$MANIFEST" \
  --source-dir "$SOURCE_DIR" \
  --target-home "$TARGET_HOME" \
  --profile "$PROFILE" \
  --output-dir "$SCRIPT_DIR/out_auto"

echo "Analysis check completed successfully"