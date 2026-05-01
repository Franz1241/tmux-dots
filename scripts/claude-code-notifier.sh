#!/bin/zsh

TMUX="/opt/homebrew/bin/tmux"
SCRIPT="$0"

kind="$1"

# Click handler mode
if [[ "$kind" == "--focus" ]]; then
  client="$2"
  project="$3"
  "$TMUX" switch-client -c "$client" -t "$project" 2>/dev/null
  open -a Ghostty
  exit 0
fi

project="$(basename "$CLAUDE_PROJECT_DIR")"

case "$kind" in
  input) msg="Claude needs your attention on project $project" ;;
  done) msg="Claude finished on project $project" ;;
  failed) msg="Claude failed on project $project" ;;
  *) msg="Claude notification for project $project" ;;
esac

client="$("$TMUX" list-clients -F '#{client_name}' 2>/dev/null | head -n 1)"

terminal-notifier \
  -title "Claude Code" \
  -message "$msg" \
  -execute "$SCRIPT --focus '$client' '$project'" &

say "$msg"
