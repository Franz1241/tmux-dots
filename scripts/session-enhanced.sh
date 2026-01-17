#!/bin/bash

# Detect OS for date command compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MAC=true
else
    IS_MAC=false
fi

# Get detailed list of active sessions with windows count and current status
sessions=$(tmux list-sessions -F "#{session_name}|#{session_windows}|#{?session_attached,󰌹,󰌺}|#{session_created}" 2>/dev/null)

# Check if there are any sessions
if [ -z "$sessions" ]; then
    echo "No active tmux sessions found."
    exit 1
fi

# Format sessions for better display in fzf with colors
formatted_sessions=$(echo "$sessions" | while IFS='|' read -r name windows sess_icon created; do
    # Color attached sessions green, not attached gray
    if [ "$sess_icon" = "󰌹" ]; then
        color="\033[32m"  # Green for attached
    else
        color="\033[90m"  # Gray for not attached
    fi
    
    # Format creation time (cross-platform: Linux/macOS)
    if [ "$IS_MAC" = true ]; then
        created_date=$(date -r "$created" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    else
        created_date=$(date -d @"$created" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    fi
    
    printf "${color}%-20s ${sess_icon} %2s windows  %s\033[0m\n" "$name" "$windows" "$created_date"
done)

# Use fzf to select a session with enhanced preview
selected=$(echo -e "$formatted_sessions" | fzf \
    --prompt="󰆍 Select session: " \
    --height=100% \
    --reverse \
    --border \
    --ansi \
    --bind='j:down,k:up,i:unbind(j,k,q,i),esc:rebind(j,k,q,i),q:abort' \
    --header="Session Name         Status  Windows  Created  [j/k:nav i:type esc:nav q:quit]" \
    --preview='session_name=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | awk "{print \$1}");
    
    # Get session info
    win_count=$(tmux list-windows -t "$session_name" 2>/dev/null | wc -l)
    attached=$(tmux list-sessions -F "#{session_name} #{session_attached}" 2>/dev/null | grep "^$session_name " | awk "{print \$2}")
    if [ "$attached" = "1" ]; then
        sess_status="\033[32m(attached)\033[0m"
    else
        sess_status="\033[90m(not attached)\033[0m"
    fi
    
    printf "\033[1;34m%s\033[0m: %s windows %b\n\n" "$session_name" "$win_count" "$sess_status"
    
    # List windows with dot indicators
    tmux list-windows -t "$session_name" -F "#{window_index}|#{window_name}|#{window_active}|#{pane_current_command}" 2>/dev/null | while IFS="|" read -r idx wname active cmd; do
        if [ "$active" = "1" ]; then
            printf "\033[32m● %s: %s\033[0m  \"%s\"\n" "$idx" "$wname" "$cmd"
        else
            printf "\033[90m○ %s: %s  \"%s\"\033[0m\n" "$idx" "$wname" "$cmd"
        fi
    done
    
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo ""
    
    # Capture active pane content (plain text, no escape sequences)
    tmux capture-pane -t "$session_name" -p 2>/dev/null \
        | perl -pe "s/\e\[[0-9;]*[a-zA-Z]//g" \
        | perl -pe "s/\e\][^\007]*\007//g" \
        | perl -pe "s/[^[:print:]\n\t]//g" \
        | grep -v "^[[:space:]]*$" \
        | tail -25' \
    --preview-window=right:65% \
    --preview-label=" 󰋼 Details ")

# Check if user cancelled fzf or no session selected
if [ -z "$selected" ]; then
    echo "No session selected. Exiting."
    exit 0
fi

# Extract session name from the selected line
session_name=$(echo "$selected" | awk '{print $1}')

# Switch to the selected session
echo "Switching to session: $session_name"
tmux switch-client -t "$session_name"