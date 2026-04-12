#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/niri/focus-profiles.yaml"
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

  if [ -n "$color" ]; then
    printf 'layout {\n  focus-ring {\n    active-color "%s"\n  }\n}\n' "$color" > "$FOCUS_VARS_FILE"
  else
    > "$FOCUS_VARS_FILE"
  fi

  niri msg action load-config-file >/dev/null 2>&1 || true
}

start_focus() {
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    printf 'Focus mode is already running.\n' >&2
    exit 0
  fi

  require_cmd yq
  require_cmd fuzzel

  if [ ! -f "$CONFIG_FILE" ]; then
    printf 'Focus profile config not found: %s\n' "$CONFIG_FILE" >&2
    exit 1
  fi

  local selected_entry selected_id
  selected_entry="$(yq -r '.profiles[] | "\(.id)\t\(.label)"' "$CONFIG_FILE" | fuzzel --dmenu --prompt 'λ ' || true)"

  if [ -z "$selected_entry" ]; then
    exit 0
  fi

  selected_id="${selected_entry%%$'\t'*}"
  local profile
  profile="$(yq -r --arg id "$selected_id" '.profiles[] | select(.id == $id)' "$CONFIG_FILE")"

  if [ -z "$profile" ] || [ "$profile" = "null" ]; then
    printf 'Invalid profile selection.\n' >&2
    exit 1
  fi

  set_focus_color "$FOCUS_ACTIVE_COLOR"

  if command -v tock >/dev/null 2>&1; then
    local stop_current project description
    stop_current=$(yq -r '.tock.stop_current // "false"' <<<"$profile")
    project=$(yq -r '.tock.project // "Focus"' <<<"$profile")
    description=$(yq -r '.tock.description // ""' <<<"$profile")

    if [ "$stop_current" = "true" ]; then
      tock current --json >/dev/null 2>&1 && tock stop --tag "focus-switch" >/dev/null 2>&1 || true
    fi

    local tag_args=()
    while IFS= read -r tag; do
      [ -n "$tag" ] && [ "$tag" != "null" ] && tag_args+=(--tag "$tag")
    done < <(yq -r '.tock.tags[]' <<<"$profile" 2>/dev/null)

    tock start -p "$project" -d "$description" "${tag_args[@]}" --tag "focus-mode" >/dev/null 2>&1 || true
    notify_tock_status "Started: $project"
  fi
}

stop_focus() {
  set_focus_color ""

  if command -v tock >/dev/null 2>&1; then
    tock stop --tag "focus-ended" --note "Stopped via focus-stop" >/dev/null 2>&1 || true
    notify_tock_status "Session ended"
  fi
}

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
