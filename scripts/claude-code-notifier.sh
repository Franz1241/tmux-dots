#!/usr/bin/env bash

SCRIPT="$0"
OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
  TMUX="/opt/homebrew/bin/tmux"
else
  TMUX="$(command -v tmux)"
fi

kind="$1"

# Click handler mode (invoked by the notification action)
if [[ "$kind" == "--focus" ]]; then
  client="$2"
  project="$3"
  "$TMUX" switch-client -c "$client" -t "$project" 2>/dev/null

  if [[ "$OS" == "Darwin" ]]; then
    open -a Ghostty
  fi
  # On Wayland there's no portable "raise window" — tmux switch-client above
  # is enough; alt-tab to Ghostty manually if it isn't already focused.
  exit 0
fi

project="$(basename "$CLAUDE_PROJECT_DIR")"

case "$kind" in
  input)  msg="Claude needs your attention on project $project" ;;
  done)   msg="Claude finished on project $project" ;;
  failed) msg="Claude failed on project $project" ;;
  *)      msg="Claude notification for project $project" ;;
esac

client="$("$TMUX" list-clients -F '#{client_name}' 2>/dev/null | head -n 1)"

if [[ "$OS" == "Darwin" ]]; then
  terminal-notifier \
    -title "Claude Code" \
    -message "$msg" \
    -execute "$SCRIPT --focus '$client' '$project'" &

  say "$msg"
else
  # Linux (Fedora): notify-send blocks while waiting for an action click,
  # so run it backgrounded and dispatch the focus handler if clicked.
  (
    action="$(notify-send \
      --app-name="Claude Code" \
      --action="default=Focus" \
      "Claude Code" "$msg")"
    if [[ "$action" == "default" ]]; then
      "$SCRIPT" --focus "$client" "$project"
    fi
  ) &

  say "$msg"
fi
