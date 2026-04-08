#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/niri/focus-profiles.json"
FOCUS_VARS_FILE="${HOME}/.config/niri/focus-vars.kdl"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/focus-mode.lock"
FOCUS_ACTIVE_COLOR="#D699B6"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

notify_tock_status() {
  local message="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name "Focus Launcher" "Focus Mode" "$message" >/dev/null 2>&1 || true
  fi
}

set_focus_color() {
  local color="$1"
  
  # If a color is passed, write the override. Otherwise, clear the file.
  if [ -n "$color" ]; then
    printf 'layout {\n  focus-ring {\n    active-color "%s"\n  }\n}\n' "$color" > "$FOCUS_VARS_FILE"
  else
    > "$FOCUS_VARS_FILE"
  fi
  
  niri msg action load-config-file >/dev/null 2>&1 || true
}

launch_workspace_windows() {
  local workspace_json="$1"
  local workspace="$2"

  niri msg action focus-workspace "$workspace"

  sleep 0.1

  jq -c '.windows[]? // empty' <<<"$workspace_json" | while read -r window; do
    app=$(jq -r '.app' <<<"$window")
    mapfile -t args < <(jq -r '.args[]? // empty' <<<"$window")
    
    "$app" "${args[@]}" >/dev/null 2>&1 &
  done

  sleep 1
}

start_focus() {
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    printf 'Focus mode is already running.\n' >&2
    exit 0
  fi

  require_cmd niri
  require_cmd jq
  require_cmd fuzzel
  require_cmd flock

  if [ ! -f "$CONFIG_FILE" ]; then
    printf 'Focus profile config not found: %s\n' "$CONFIG_FILE" >&2
    exit 1
  fi

  local selected_entry selected_id profile
  selected_entry="$(jq -r '.profiles[] | "\(.id)\t\(.label)"' "$CONFIG_FILE" | fuzzel --dmenu --prompt 'λ ' || true)"
  
  if [ -z "$selected_entry" ]; then
    exit 0
  fi

  selected_id="${selected_entry%%$'\t'*}"
  profile="$(jq -c --arg id "$selected_id" '.profiles[] | select(.id == $id)' "$CONFIG_FILE")"

  if [ -z "$profile" ]; then
    printf 'Invalid profile selection.\n' >&2
    exit 1
  fi

  set_focus_color "$FOCUS_ACTIVE_COLOR"

  if command -v tock >/dev/null 2>&1; then
    local stop_current project description
    stop_current=$(jq -r '.tock.stop_current // false' <<<"$profile")
    project=$(jq -r '.tock.project // "Focus"' <<<"$profile")
    description=$(jq -r '.tock.description // "Focused session"' <<<"$profile")

    if [ "$stop_current" = "true" ]; then
      tock current --json >/dev/null 2>&1 && tock stop --tag "focus-switch" >/dev/null 2>&1 || true
    fi

    mapfile -t tags < <(jq -r '.tock.tags[]? // empty' <<<"$profile")
    local tag_args=()
    for tag in "${tags[@]}"; do
      tag_args+=(--tag "$tag")
    done

    if tock start -p "$project" -d "$description" "${tag_args[@]}" >/dev/null 2>&1; then
      notify_tock_status "Started: $project"
    else
      notify_tock_status "Failed to start Tock session"
    fi
  fi

  # Launch Workspaces
  mapfile -t workspaces < <(jq -r '.workspaces | keys[]' <<<"$profile" | sort -n)
  for workspace in "${workspaces[@]}"; do
    workspace_json=$(jq -c --arg ws "$workspace" '.workspaces[$ws]' <<<"$profile")
    launch_workspace_windows "$workspace_json" "$workspace"
  done
}

stop_focus() {
  # Emptying the file removes the override, falling back to config.kdl defaults
  set_focus_color ""

  if command -v tock >/dev/null 2>&1 && tock current --json >/dev/null 2>&1; then
    if tock stop --tag "focus-ended" --note "Stopped via focus-stop" >/dev/null 2>&1; then
      notify_tock_status "Tock session ended"
    else
      notify_tock_status "Failed to end Tock session"
    fi
  fi
}

# --- Main Command Router ---
case "${1:-}" in
  start)
    start_focus
    ;;
  stop)
    stop_focus
    ;;
  *)
    printf "Usage: %s {start|stop}\n" "${0##*/}" >&2
    exit 1
    ;;
esac
