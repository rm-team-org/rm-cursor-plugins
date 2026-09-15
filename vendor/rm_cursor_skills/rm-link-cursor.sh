#!/usr/bin/env bash
# Link or unlink Cursor agent skills and user rules from this repo into ~/.cursor.
# Default mode creates per-item symlinks; -u removes symlinks that point here.
# Compatible with both Bash and Zsh (run via shebang, or: bash|zsh this-script).
set -euo pipefail

# Zsh defaults differ from Bash: enable ksh-style 0-based arrays and null globs
# so shared array/glob logic behaves the same under both shells.
if [ -n "${ZSH_VERSION:-}" ]; then
  setopt KSH_ARRAYS
  setopt NULL_GLOB
fi

CURSOR_SKILLS="${HOME}/.cursor/skills"
CURSOR_RULES="${HOME}/.cursor/rules"
MODE="link"

# Resolve ./skills and ./rules relative to this script, not the caller's cwd.
# Capture $0 at top level: inside Zsh functions $0 is the function name, not the script.
SCRIPT_PATH="$0"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/skills"
RULES_DIR="${SCRIPT_DIR}/rules"

usage() {
  echo "Usage: $SCRIPT_NAME [-u]"
  echo "  (default) Link each skill subfolder from ./skills and each .mdc rule from ./rules"
  echo "            into ~/.cursor/skills and ~/.cursor/rules."
  echo "  -u        Unlink symlinks in those directories that point to this repo."
}

# --- Argument parsing ---

if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

while getopts ":hu" opt; do
  case "$opt" in
    h)
      usage
      exit 0
      ;;
    u)
      MODE="unlink"
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

if [ "$#" -gt 0 ]; then
  usage >&2
  exit 1
fi

# Parallel arrays describing each item to link or unlink in the main loop.
ITEM_NAMES=()
ITEM_PATHS=()
ITEM_DETAILS=()

# Globals set by process_batch for the current resource type.
BATCH_KIND=""
BATCH_CURSOR_DIR=""
BATCH_SOURCE_RESOLVED=""

# Build ITEM_* arrays for the current mode and resource type.
collect_items() {
  local collect_type="$1"

  ITEM_NAMES=()
  ITEM_PATHS=()
  ITEM_DETAILS=()

  if [ "$MODE" = "link" ]; then
    if ! mkdir -p "$BATCH_CURSOR_DIR"; then
      echo "Error: could not create $BATCH_CURSOR_DIR" >&2
      return 1
    fi

    local item_path item_name list_file
    list_file="$(mktemp)"
    if [ "$collect_type" = "dir" ]; then
      find "$BATCH_SOURCE_RESOLVED" -mindepth 1 -maxdepth 1 -type d | sort >"$list_file"
    else
      find "$BATCH_SOURCE_RESOLVED" -mindepth 1 -maxdepth 1 -type f -name '*.mdc' | sort >"$list_file"
    fi
    while IFS= read -r item_path; do
      [ -n "$item_path" ] || continue
      item_name="$(basename "$item_path")"
      ITEM_NAMES+=("$item_name")
      ITEM_PATHS+=("$item_path")
      ITEM_DETAILS+=("")
    done <"$list_file"
    rm -f "$list_file"

    if [ "${#ITEM_NAMES[@]}" -eq 0 ]; then
      echo "No ${BATCH_KIND} items found under $BATCH_SOURCE_RESOLVED."
      return 1
    fi
    return 0
  fi

  # Unlink mode: scan the Cursor directory for symlinks pointing into the repo source.
  if [ ! -d "$BATCH_CURSOR_DIR" ]; then
    echo "No $BATCH_CURSOR_DIR directory found (nothing to unlink)."
    return 1
  fi

  local entry target item_name
  for entry in "$BATCH_CURSOR_DIR"/*; do
    [ -e "$entry" ] || continue
    [ -L "$entry" ] || continue
    target=$(realpath "$entry" 2>/dev/null) || continue
    if [ "$(dirname "$target")" = "$BATCH_SOURCE_RESOLVED" ]; then
      item_name="$(basename "$entry")"
      ITEM_NAMES+=("$item_name")
      ITEM_PATHS+=("$entry")
      ITEM_DETAILS+=("$entry -> $target")
    fi
  done

  if [ "${#ITEM_NAMES[@]}" -eq 0 ]; then
    echo "No linked ${BATCH_KIND}s from $BATCH_SOURCE_RESOLVED found under $BATCH_CURSOR_DIR."
    return 1
  fi
  return 0
}

link_item() {
  local item_name="$1"
  local source_path="$2"
  local target_path="${BATCH_CURSOR_DIR}/${item_name}"
  local existing

  if [ -L "$target_path" ]; then
    if existing=$(realpath "$target_path" 2>/dev/null) && [ "$existing" = "$source_path" ]; then
      echo "  Already linked: $target_path -> $source_path"
      return 0
    fi
    echo "  Skipping $item_name: $target_path exists and points elsewhere." >&2
    return 1
  fi

  if [ -e "$target_path" ]; then
    echo "  Skipping $item_name: $target_path already exists and is not a symlink." >&2
    return 1
  fi

  ln -s "$source_path" "$target_path"
  echo "  Linked $target_path -> $source_path"
}

unlink_item() {
  local entry="$1"
  local item_name
  item_name="$(basename "$entry")"

  if [ ! -L "$entry" ]; then
    echo "  Skipping $item_name: no longer a symlink." >&2
    return 1
  fi

  rm "$entry"
  echo "  Unlinked $entry"
}

apply_action() {
  local item_name="$1"
  local item_path="$2"

  if [ "$MODE" = "link" ]; then
    link_item "$item_name" "$item_path"
  else
    unlink_item "$item_path"
  fi
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

prompt_user() {
  local verb="$1"
  local item_name="$2"
  local detail="$3"
  local prompt choice

  if [ -n "$detail" ]; then
    prompt="${verb} ${BATCH_KIND} '$item_name' ($detail)?"
  else
    prompt="${verb} ${BATCH_KIND} '$item_name'?"
  fi

  printf '%s' "$prompt [y]es / [n]o / [a]ll remaining / [s]kip all remaining: " >&2
  read -r choice
  case "$(to_lower "$choice")" in
    y|yes) echo "yes" ;;
    n|no) echo "no" ;;
    a|all) echo "all" ;;
    s|skip) echo "skip" ;;
    *) echo "invalid" ;;
  esac
}

run_prompt_loop() {
  local verb="$1"
  local action_label="$2"
  local prompt_mode="ask"
  local applied=0
  local skipped=0
  local i=0
  local choice item_name item_path item_detail

  while [ "$i" -lt "${#ITEM_NAMES[@]}" ]; do
    item_name="${ITEM_NAMES[$i]}"
    item_path="${ITEM_PATHS[$i]}"
    item_detail="${ITEM_DETAILS[$i]}"

    case "$prompt_mode" in
      ask)
        while true; do
          choice=$(prompt_user "$verb" "$item_name" "$item_detail")
          case "$choice" in
            yes)
              break
              ;;
            no)
              echo "  Skipped $item_name"
              skipped=$((skipped + 1))
              i=$((i + 1))
              continue 2
              ;;
            all)
              prompt_mode="all"
              break
              ;;
            skip)
              prompt_mode="skip"
              echo "  Skipped $item_name"
              skipped=$((skipped + 1))
              i=$((i + 1))
              continue 2
              ;;
            invalid)
              echo "  Please enter y, n, a, or s."
              ;;
          esac
        done
        ;;
      skip)
        echo "  Skipped $item_name"
        skipped=$((skipped + 1))
        i=$((i + 1))
        continue
        ;;
    esac

    if apply_action "$item_name" "$item_path"; then
      applied=$((applied + 1))
    else
      skipped=$((skipped + 1))
    fi
    i=$((i + 1))
  done

  echo "${BATCH_KIND}s: ${action_label}: $applied, skipped: $skipped."
}

process_batch() {
  local kind="$1"
  local source_dir="$2"
  local cursor_dir="$3"
  local collect_type="$4"
  local resolved
  local verb action_label

  BATCH_KIND="$kind"
  BATCH_CURSOR_DIR="$cursor_dir"

  echo ""
  echo "=== ${kind}s ==="

  if [ ! -d "$source_dir" ]; then
    echo "Skipping ${kind}s: directory not found: $source_dir"
    return 0
  fi

  if ! resolved=$(realpath "$source_dir" 2>/dev/null); then
    echo "Error: could not resolve path: $source_dir" >&2
    return 1
  fi
  BATCH_SOURCE_RESOLVED="$resolved"

  if [ -L "$cursor_dir" ]; then
    echo "Error: $cursor_dir is a symlink. Remove it first, then run this script again." >&2
    echo "  (An older version linked the whole ${kind}s directory; use per-item symlinks instead.)" >&2
    return 1
  fi

  if [ -e "$cursor_dir" ] && [ ! -d "$cursor_dir" ]; then
    echo "Error: $cursor_dir exists but is not a directory. Remove it first, then run this script again." >&2
    return 1
  fi

  if ! collect_items "$collect_type"; then
    return 0
  fi

  verb="Link"
  [ "$MODE" = "unlink" ] && verb="Unlink"
  action_label="Linked"
  [ "$MODE" = "unlink" ] && action_label="Unlinked"

  run_prompt_loop "$verb" "$action_label"
}

# --- Main ---

process_batch "skill" "$SKILLS_DIR" "$CURSOR_SKILLS" "dir"
process_batch "rule" "$RULES_DIR" "$CURSOR_RULES" "mdc"

echo ""
echo "Done."
