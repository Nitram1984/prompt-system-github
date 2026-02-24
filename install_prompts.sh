#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"
MANIFEST="$SCRIPT_DIR/prompt_manifest.txt"
TARGET_HOME="${HOME}"
BACKUP_BASE="$SCRIPT_DIR/backups"
BACKUP_DIR=""
PRECHECK_BASE="$SCRIPT_DIR/precheck"
PRECHECK_DIR=""
PROFILE="auto"
DRY_RUN=0
NO_BACKUP=0
INCLUDE_CRITICAL=0
INCLUDE_NOT_NEEDED=0
ANALYZE_ONLY=0

usage() {
  cat <<'USAGE'
Usage: ./install_prompts.sh [options]

Copies prompt files from this package into a target home directory.
Runs a component-aware precheck that detects which prompt/skill areas are
actually relevant on the target system.

Default behavior:
- profile `auto` (recommended): install only relevant, non-critical files
- skip system-critical and not-needed files by default
- backup existing target files before overwrite

Options:
  --target-home <path>      Target home directory (default: $HOME)
  --manifest <path>         Manifest file with relative file paths
  --source-dir <path>       Package source directory (default: script directory)
  --profile <safe|auto|full>
                            Recommendation profile (default: auto)
  --analyze-only            Run analysis and reports only; do not install
  --backup-dir <path>       Backup directory (default: <script>/backups/<timestamp>)
  --no-backup               Disable backup of existing files
  --dry-run                 Show what would be changed without writing files
  --include-critical        Also install files classified as system-critical
  --include-not-needed      Also install files classified as not-needed
  -h, --help                Show this help
USAGE
}

count_nonempty() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo 0
    return
  fi
  awk 'NF && $1 !~ /^#/{c++} END{print c+0}' "$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-home)
      [[ $# -lt 2 ]] && { echo "Missing value for --target-home" >&2; exit 1; }
      TARGET_HOME="$2"
      shift 2
      ;;
    --manifest)
      [[ $# -lt 2 ]] && { echo "Missing value for --manifest" >&2; exit 1; }
      MANIFEST="$2"
      shift 2
      ;;
    --source-dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --source-dir" >&2; exit 1; }
      SOURCE_DIR="$2"
      shift 2
      ;;
    --profile)
      [[ $# -lt 2 ]] && { echo "Missing value for --profile" >&2; exit 1; }
      PROFILE="$2"
      shift 2
      ;;
    --analyze-only)
      ANALYZE_ONLY=1
      shift
      ;;
    --backup-dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --backup-dir" >&2; exit 1; }
      BACKUP_DIR="$2"
      shift 2
      ;;
    --no-backup)
      NO_BACKUP=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --include-critical)
      INCLUDE_CRITICAL=1
      shift
      ;;
    --include-not-needed)
      INCLUDE_NOT_NEEDED=1
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

if ! command -v rsync >/dev/null 2>&1; then
  echo "Error: rsync is required but not installed." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required for component-aware prompt analysis." >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_DIR/recommend_prompts.py" ]]; then
  echo "Error: recommender not found: $SCRIPT_DIR/recommend_prompts.py" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: manifest not found: $MANIFEST" >&2
  exit 1
fi

if [[ ! -d "$TARGET_HOME" ]]; then
  echo "Error: target home directory not found: $TARGET_HOME" >&2
  exit 1
fi

if [[ "$PROFILE" != "safe" && "$PROFILE" != "auto" && "$PROFILE" != "full" ]]; then
  echo "Error: invalid profile '$PROFILE'. Use one of: safe, auto, full." >&2
  exit 1
fi

PRECHECK_STAMP="$(date +%Y%m%d_%H%M%S)_$$_$RANDOM"
if [[ -z "$PRECHECK_DIR" ]]; then
  PRECHECK_DIR="$PRECHECK_BASE/$PRECHECK_STAMP"
fi
mkdir -p "$PRECHECK_DIR"

RECOMMENDER_ARGS=(
  python3
  "$SCRIPT_DIR/recommend_prompts.py"
  --manifest "$MANIFEST"
  --source-dir "$SOURCE_DIR"
  --target-home "$TARGET_HOME"
  --profile "$PROFILE"
  --output-dir "$PRECHECK_DIR"
)

if [[ "$INCLUDE_CRITICAL" -eq 1 ]]; then
  RECOMMENDER_ARGS+=(--include-critical)
fi
if [[ "$INCLUDE_NOT_NEEDED" -eq 1 ]]; then
  RECOMMENDER_ARGS+=(--include-not-needed)
fi

"${RECOMMENDER_ARGS[@]}"

RECOMMENDED_LIST="$PRECHECK_DIR/recommended.txt"
CRITICAL_LIST="$PRECHECK_DIR/system_critical.txt"
NOT_NEEDED_LIST="$PRECHECK_DIR/not_needed.txt"
OPTIONAL_LIST="$PRECHECK_DIR/optional_unmatched.txt"
INSTALL_LIST="$PRECHECK_DIR/install_list.txt"
INVALID_LIST="$PRECHECK_DIR/invalid_entries.txt"
MISSING_LIST="$PRECHECK_DIR/missing_files.txt"
SUMMARY_FILE="$PRECHECK_DIR/summary.txt"

TOTAL_COUNT="$(count_nonempty "$MANIFEST")"
RECOMMENDED_COUNT="$(count_nonempty "$RECOMMENDED_LIST")"
CRITICAL_COUNT="$(count_nonempty "$CRITICAL_LIST")"
NOT_NEEDED_COUNT="$(count_nonempty "$NOT_NEEDED_LIST")"
OPTIONAL_COUNT="$(count_nonempty "$OPTIONAL_LIST")"
INSTALL_COUNT="$(count_nonempty "$INSTALL_LIST")"
INVALID_COUNT="$(count_nonempty "$INVALID_LIST")"
MISSING_COUNT="$(count_nonempty "$MISSING_LIST")"

echo "Source:               $SOURCE_DIR"
echo "Manifest:             $MANIFEST"
echo "Target home:          $TARGET_HOME"
echo "Profile:              $PROFILE"
echo "Total in manifest:    $TOTAL_COUNT"
echo "Recommended:          $RECOMMENDED_COUNT"
echo "System-critical:      $CRITICAL_COUNT"
echo "Not-needed:           $NOT_NEEDED_COUNT"
echo "Optional-unmatched:   $OPTIONAL_COUNT"
echo "Planned for install:  $INSTALL_COUNT"
echo "Invalid entries:      $INVALID_COUNT"
echo "Missing files:        $MISSING_COUNT"
echo "Precheck report:      $PRECHECK_DIR"
if [[ -f "$SUMMARY_FILE" ]]; then
  echo
  cat "$SUMMARY_FILE"
fi

if [[ "$INVALID_COUNT" -gt 0 || "$MISSING_COUNT" -gt 0 ]]; then
  echo
  echo "Precheck failed due to validation issues."
  if [[ "$INVALID_COUNT" -gt 0 ]]; then
    echo "See: $INVALID_LIST"
  fi
  if [[ "$MISSING_COUNT" -gt 0 ]]; then
    echo "See: $MISSING_LIST"
  fi
  exit 1
fi

if [[ "$ANALYZE_ONLY" -eq 1 ]]; then
  echo
  echo "Analysis complete. No files were installed (--analyze-only)."
  exit 0
fi

if [[ "$INSTALL_COUNT" -eq 0 ]]; then
  echo
  echo "Nothing to install with current options."
  echo "Try --profile full or --include-critical / --include-not-needed."
  exit 0
fi

if [[ -z "$BACKUP_DIR" ]]; then
  BACKUP_DIR="$BACKUP_BASE/$PRECHECK_STAMP"
fi

RSYNC_ARGS=(
  -rltD
  --itemize-changes
  --human-readable
  --no-owner
  --no-group
  --no-perms
  --omit-dir-times
  --files-from="$INSTALL_LIST"
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_ARGS+=(--dry-run)
fi

if [[ "$NO_BACKUP" -eq 0 ]]; then
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$BACKUP_DIR"
  fi
  RSYNC_ARGS+=(--backup "--backup-dir=$BACKUP_DIR")
fi

if [[ "$NO_BACKUP" -eq 1 ]]; then
  echo "Backup:               disabled"
else
  echo "Backup dir:           $BACKUP_DIR"
fi
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Mode:                 dry-run"
fi

echo
echo "Applying prompts..."
rsync "${RSYNC_ARGS[@]}" "$SOURCE_DIR/" "$TARGET_HOME/"
echo

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry-run complete. No files were changed."
else
  echo "Install complete."
  if [[ "$NO_BACKUP" -eq 0 ]]; then
    echo "Previous files (if any) were backed up to: $BACKUP_DIR"
  fi
fi
