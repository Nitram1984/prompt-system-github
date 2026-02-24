#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${PROMPT_SYSTEM_BASE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
INSTALLER="$BASE_DIR/install_prompts.sh"
PRECHECK_DIR="$BASE_DIR/precheck"
STATE_DIR="$BASE_DIR/monitor"
LOG_DIR="$STATE_DIR/logs"
ALERT_LOG="$STATE_DIR/alerts.log"
HISTORY_LOG="$STATE_DIR/history.log"

PROFILE="auto"
TARGET_HOME="/"
ACCEPT_CURRENT=0

usage() {
  cat <<'USAGE'
Usage: run_analyze_check.sh [options]

Runs install_prompts.sh in --analyze-only mode and checks for drift against
the saved baseline state.

Options:
  --profile <safe|auto|full>   Analysis profile (default: auto)
  --target-home <path>         Target home/root path (default: /)
  --accept-current             Accept current analysis as new baseline
  -h, --help                   Show this help
USAGE
}

log_info() {
  local msg="$1"
  printf '[%s] INFO  %s\n' "$(date -Is)" "$msg" | tee -a "$HISTORY_LOG"
}

log_alert() {
  local msg="$1"
  printf '[%s] ALERT %s\n' "$(date -Is)" "$msg" | tee -a "$ALERT_LOG" >&2
  if command -v logger >/dev/null 2>&1; then
    logger -t prompt-system-monitor -- "$msg"
  fi
}

target_slug() {
  local raw="$1"
  local slug="${raw//\//_}"
  slug="${slug##_}"
  if [[ -z "$slug" ]]; then
    slug="root"
  fi
  printf '%s\n' "$slug"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -lt 2 ]] && { echo "Missing value for --profile" >&2; exit 1; }
      PROFILE="$2"
      shift 2
      ;;
    --target-home)
      [[ $# -lt 2 ]] && { echo "Missing value for --target-home" >&2; exit 1; }
      TARGET_HOME="$2"
      shift 2
      ;;
    --accept-current)
      ACCEPT_CURRENT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$PROFILE" != "safe" && "$PROFILE" != "auto" && "$PROFILE" != "full" ]]; then
  echo "Invalid profile: $PROFILE" >&2
  exit 1
fi

if [[ ! -x "$INSTALLER" ]]; then
  echo "Installer not executable: $INSTALLER" >&2
  exit 1
fi

mkdir -p "$STATE_DIR" "$LOG_DIR"

slug="$(target_slug "$TARGET_HOME")"
BASELINE_FILE="$STATE_DIR/baseline_${PROFILE}_${slug}.json"
CURRENT_FILE="$STATE_DIR/current_${PROFILE}_${slug}.json"
PENDING_FILE="$STATE_DIR/pending_${PROFILE}_${slug}.json"
DIFF_FILE="$STATE_DIR/last_diff_${PROFILE}_${slug}.txt"
LAST_PRECHECK_FILE="$STATE_DIR/last_precheck_${PROFILE}_${slug}.txt"

run_id="$(date +%Y%m%d_%H%M%S)"
run_log="$LOG_DIR/run_${PROFILE}_${slug}_${run_id}.log"

if ! "$INSTALLER" --analyze-only --target-home "$TARGET_HOME" --profile "$PROFILE" >"$run_log" 2>&1; then
  log_alert "Analyze failed (profile=$PROFILE target=$TARGET_HOME). See $run_log"
  tail -n 60 "$run_log" >&2 || true
  exit 1
fi

latest_precheck="$(ls -1t "$PRECHECK_DIR" 2>/dev/null | head -n1 || true)"
if [[ -z "$latest_precheck" ]]; then
  log_alert "No precheck folder found after analyze run."
  exit 1
fi

analysis_file="$PRECHECK_DIR/$latest_precheck/analysis.json"
summary_file="$PRECHECK_DIR/$latest_precheck/summary.txt"
if [[ ! -f "$analysis_file" ]]; then
  log_alert "analysis.json missing: $analysis_file"
  exit 1
fi

cp "$analysis_file" "$CURRENT_FILE"
printf '%s\n' "$latest_precheck" > "$LAST_PRECHECK_FILE"

if [[ "$ACCEPT_CURRENT" -eq 1 ]]; then
  cp "$analysis_file" "$BASELINE_FILE"
  rm -f "$PENDING_FILE" "$DIFF_FILE"
  log_info "Accepted current analysis as baseline: $BASELINE_FILE"
  exit 0
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  cp "$analysis_file" "$BASELINE_FILE"
  log_info "Baseline initialized: $BASELINE_FILE"
  exit 0
fi

set +e
python3 - "$BASELINE_FILE" "$analysis_file" <<'PY' >"$DIFF_FILE"
import json
import sys

baseline_path = sys.argv[1]
current_path = sys.argv[2]

with open(baseline_path, "r", encoding="utf-8") as f:
    base = json.load(f)
with open(current_path, "r", encoding="utf-8") as f:
    cur = json.load(f)

keys = [
    "total_in_manifest",
    "recommended_count",
    "system_critical_count",
    "not_needed_count",
    "optional_unmatched_count",
    "install_count",
    "invalid_entry_count",
    "missing_file_count",
]

diffs = []
for k in keys:
    if base.get(k) != cur.get(k):
        diffs.append(f"{k}: baseline={base.get(k)} current={cur.get(k)}")

for list_key in ("detected_components", "missing_components"):
    a = sorted(base.get(list_key, []))
    b = sorted(cur.get(list_key, []))
    if a != b:
        diffs.append(f"{list_key}: baseline={a} current={b}")

if diffs:
    print("DRIFT_DETECTED")
    for line in diffs:
        print(line)
    sys.exit(2)

print("NO_DRIFT")
sys.exit(0)
PY
cmp_rc=$?
set -e

if [[ "$cmp_rc" -eq 0 ]]; then
  rm -f "$PENDING_FILE"
  log_info "No drift detected (profile=$PROFILE target=$TARGET_HOME)"
  exit 0
fi

if [[ "$cmp_rc" -eq 2 ]]; then
  cp "$analysis_file" "$PENDING_FILE"
  if [[ -f "$summary_file" ]]; then
    cat "$summary_file" >> "$DIFF_FILE"
  fi
  log_alert "Drift detected (profile=$PROFILE target=$TARGET_HOME). See $DIFF_FILE"
  cat "$DIFF_FILE" >&2 || true
  log_alert "If expected, accept new baseline with: $0 --profile $PROFILE --target-home \"$TARGET_HOME\" --accept-current"
  exit 2
fi

log_alert "Compare failed (unexpected rc=$cmp_rc). See $DIFF_FILE"
exit 1
