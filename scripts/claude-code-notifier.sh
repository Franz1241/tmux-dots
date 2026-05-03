#!/usr/bin/env bash

SCRIPT="$0"
OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
  TMUX_BIN="/opt/homebrew/bin/tmux"
else
  TMUX_BIN="$(command -v tmux)"
fi

# Find the tmux session that "owns" a project directory by matching
# session_path, since session names often diverge from directory basenames
# (e.g. session "medlife-sms-agent" lives in /…/Proyectos/sms-agent).
# Priority: exact path > deepest ancestor (session above project) > shallowest
# descendant (session below project).
find_project_session() {
  local project_dir="$1"
  [[ -z "$project_dir" ]] && return 1

  local best_name="" best_score=-1
  local name path score

  while IFS=$'\t' read -r name path; do
    [[ -z "$path" ]] && continue
    # Skip sessions rooted at $HOME or /: they're ancestors of every project
    # path and would always win on shallow matches (e.g. the "main" session).
    [[ "$path" == "$HOME" || "$path" == "/" ]] && continue

    score=-1
    if [[ "$path" == "$project_dir" ]]; then
      score=$(( ${#path} * 2 ))                # exact match: always wins
    elif [[ "$project_dir" == "$path"/* ]]; then
      score=${#path}                           # ancestor: deeper path wins
    elif [[ "$path" == "$project_dir"/* ]]; then
      score=${#project_dir}                    # descendant: cap by project depth
    fi

    if (( score > best_score )); then
      best_name="$name"; best_score=$score
    fi
  done < <("$TMUX_BIN" list-sessions -F '#{session_name}'$'\t''#{session_path}' 2>/dev/null)

  [[ -n "$best_name" ]] || return 1
  printf '%s' "$best_name"
}

kind="$1"

# Click handler mode (invoked by the notification action).
# On Linux this expects XDG_ACTIVATION_TOKEN in the environment — the token
# the compositor minted in response to the user clicking the notification.
if [[ "$kind" == "--focus" ]]; then
  project_dir="$2"
  session_name="$(find_project_session "$project_dir")"

  if [[ "$OS" == "Darwin" ]]; then
    open -a Ghostty
  else
    # Wayland: cross-process focus only works via an xdg-activation token tied
    # to the user's click. The token came in via XDG_ACTIVATION_TOKEN and is
    # inherited by ghostty here.
    #
    # Strip TMUX/TMUX_PANE before spawning: the hook fires from inside a tmux
    # pane, so those vars leak into the child. With them set, tmux refuses
    # `attach` ("sessions should be nested with care") and the user's .bashrc
    # skips its auto-attach guard, leaving a bare shell.
    #
    # `-e tmux attach` makes the new window land directly on the project's
    # session, bypassing .bashrc's `tmux new-session -A -s main` auto-attach.
    if [[ -n "$session_name" ]]; then
      env -u TMUX -u TMUX_PANE ghostty -e tmux attach -t "=$session_name" >/dev/null 2>&1 &
    else
      env -u TMUX -u TMUX_PANE ghostty >/dev/null 2>&1 &
    fi
  fi
  exit 0
fi

project="$(basename "$CLAUDE_PROJECT_DIR")"

# The Notification hook fires for both "tool needs approval" and Claude's
# built-in idle reminder ("Claude is waiting for your input"), which lands
# ~60s after a Stop if the user hasn't replied. We only want the former —
# read the hook's JSON payload from stdin and bail on the idle reminder.
if [[ "$kind" == "input" ]]; then
  payload="$(cat)"
  hook_msg="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
  if [[ "$hook_msg" == *"waiting for your input"* ]]; then
    exit 0
  fi
fi

case "$kind" in
  input)  msg="Claude needs your attention on project $project" ;;
  done)   msg="Claude finished on project $project" ;;
  failed) msg="Claude failed on project $project" ;;
  *)      msg="Claude notification for project $project" ;;
esac

# Detach backgrounded jobs from the hook's stdio. Claude Code reads the hook's
# stdout via a pipe and only sees EOF when *all* writers close it, so any
# child that inherits stdout (notify-send --action waiting for click,
# terminal-notifier -execute, the TTS pipeline in `say`) keeps the hook
# "running" from claude's perspective even after this script exits.
if [[ "$OS" == "Darwin" ]]; then
  terminal-notifier \
    -title "Claude Code" \
    -message "$msg" \
    -execute "$SCRIPT --focus '$CLAUDE_PROJECT_DIR'" </dev/null >/dev/null 2>&1 &

  say "$msg" </dev/null >/dev/null 2>&1 &
else
  # Linux/GNOME (Wayland): use a named action — GNOME Shell hides actions
  # named "default" as a button. --action implies --wait, so background the
  # whole thing. --activation-token-fd=3 makes libnotify write the
  # compositor-issued xdg-activation token to FD 3 when the user clicks; we
  # capture it and forward it to the focus handler so it can raise Ghostty.
  (
    tokfile="$(mktemp -t claude-act-tok.XXXXXX)"
    trap 'rm -f "$tokfile"' EXIT
    action="$(notify-send \
      --app-name="Claude Code" \
      --action="focus=Focus" \
      --activation-token-fd=3 \
      "Claude Code" "$msg" 3>"$tokfile")"
    if [[ "$action" == "focus" ]]; then
      token="$(cat "$tokfile" 2>/dev/null)"
      XDG_ACTIVATION_TOKEN="$token" "$SCRIPT" --focus "$CLAUDE_PROJECT_DIR"
    fi
  ) </dev/null >/dev/null 2>&1 &

  say "$msg" </dev/null >/dev/null 2>&1 &
fi
