#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PKG_DIR="$TMP_DIR/package"
TARGET_DIR="$TMP_DIR/target"
mkdir -p "$PKG_DIR" "$TARGET_DIR"

cp "$REPO_ROOT/install_prompts.sh" "$PKG_DIR/install_prompts.sh"
cp "$REPO_ROOT/recommend_prompts.py" "$PKG_DIR/recommend_prompts.py"
chmod +x "$PKG_DIR/install_prompts.sh" "$PKG_DIR/recommend_prompts.py"

mkdir -p \
  "$PKG_DIR/projects/demo/prompts" \
  "$PKG_DIR/projects/demo/templates" \
  "$PKG_DIR/projects/demo/src"

cat >"$PKG_DIR/projects/demo/prompts/system_prompt.txt" <<'EOF'
System prompt content
EOF

cat >"$PKG_DIR/projects/demo/templates/code_review_prompt.md" <<'EOF'
# Code Review Prompt
EOF

cat >"$PKG_DIR/projects/demo/src/runtime_prompt.ts" <<'EOF'
export const runtimePrompt = "runtime";
EOF

cat >"$PKG_DIR/projects/demo/prompts/check.spec.ts" <<'EOF'
describe("prompt", () => {});
EOF

cat >"$PKG_DIR/prompt_manifest.txt" <<'EOF'
# sample manifest
projects/demo/prompts/system_prompt.txt
projects/demo/templates/code_review_prompt.md
projects/demo/src/runtime_prompt.ts
projects/demo/prompts/check.spec.ts
EOF

"$PKG_DIR/install_prompts.sh" \
  --analyze-only \
  --source-dir "$PKG_DIR" \
  --manifest "$PKG_DIR/prompt_manifest.txt" \
  --target-home "$TARGET_DIR" \
  --profile auto \
  >"$TMP_DIR/analyze.log"

PRECHECK_DIR="$(awk -F': ' '/Precheck report:/{print $2; exit}' "$TMP_DIR/analyze.log")"
PRECHECK_DIR="$(printf '%s' "$PRECHECK_DIR" | sed 's/^[[:space:]]*//')"
if [[ -z "$PRECHECK_DIR" || ! -d "$PRECHECK_DIR" ]]; then
  echo "Precheck directory not found after analyze run" >&2
  exit 1
fi

python3 - "$PRECHECK_DIR/analysis.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

assert data["total_in_manifest"] == 4, data
assert data["recommended_count"] == 2, data
assert data["system_critical_count"] == 1, data
assert data["not_needed_count"] == 1, data
assert data["install_count"] == 2, data
assert data["invalid_entry_count"] == 0, data
assert data["missing_file_count"] == 0, data
PY

"$PKG_DIR/install_prompts.sh" \
  --dry-run \
  --source-dir "$PKG_DIR" \
  --manifest "$PKG_DIR/prompt_manifest.txt" \
  --target-home "$TARGET_DIR" \
  --profile auto \
  >"$TMP_DIR/dry_run.log"

grep -q "Dry-run complete. No files were changed." "$TMP_DIR/dry_run.log"
