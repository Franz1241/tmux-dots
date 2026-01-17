#!/bin/bash
base_dir=$HOME/Proyectos

# Detect OS for stat command compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MAC=true
else
    IS_MAC=false
fi

# Get project directories with metadata (fast version, sorted by last modified descending)
projects=$(ls -1 "$base_dir" | while read -r project_name; do
    dir="$base_dir/$project_name"
    [ -d "$dir" ] || continue
    
    # Fast tech detection (fixed width labels for alignment)
    if [ -f "$dir/package.json" ]; then tech="\033[38;5;34m󰎙 Node.js\033[0m"
    elif [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ] || [ -d "$dir/.venv" ] || [ -d "$dir/venv" ] || [ -d "$dir/env" ] || [ -d "$dir/pyenv" ]; then tech="\033[33m󰌠 Python \033[0m"
    elif [ -f "$dir/go.mod" ]; then tech="\033[32m󰟓 Go     \033[0m"
    elif [ -f "$dir/Cargo.toml" ]; then tech="\033[38;5;208m󱘗 Rust   \033[0m"
    elif [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ]; then tech="\033[31m󰬷 Java   \033[0m"
    elif [ -f "$dir/composer.json" ]; then tech="\033[35m󰌟 PHP    \033[0m"
    elif [ -f "$dir/Gemfile" ]; then tech="\033[91m󰴭 Ruby   \033[0m"
    elif [ -f "$dir/Dockerfile" ]; then tech="\033[34m󰡨 Docker \033[0m"
    else tech="\033[90m󰉋 Other  \033[0m"; fi
    
    # Get last modified (cross-platform: Linux/macOS)
    newest=$(ls -t "$dir" 2>/dev/null | head -1)
    if [ -n "$newest" ]; then
        file_path="$dir/$newest"
        if [ "$IS_MAC" = true ]; then
            # macOS (BSD stat)
            mod_epoch=$(stat -f "%m" "$file_path" 2>/dev/null || echo "0")
            mod_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$file_path" 2>/dev/null || echo "unknown")
        else
            # Linux (GNU stat)
            stat_out=$(stat -c "%Y %y" "$file_path" 2>/dev/null)
            mod_epoch=${stat_out%% *}
            mod_date=$(echo "$stat_out" | cut -d' ' -f2)
        fi
    else
        mod_epoch="0"
        mod_date="empty"
    fi
    
    # Output: epoch|name|tech|date (tab-separated for clean columns)
    printf "%s\t%-24s\t%b\t%s\n" "$mod_epoch" "$project_name" "$tech" "$mod_date"
done | sort -t$'\t' -k1 -rn | cut -f2-)

# Use fzf to select a project with preview
proyecto=$(echo "$projects" | fzf \
    --prompt="󰍉 Select project: " \
    --height=100% \
    --reverse \
    --border \
    --bind='j:down,k:up,i:unbind(j,k,q,i),esc:rebind(j,k,q,i),q:abort' \
    --header=$'[j/k:nav i:type esc:nav q:quit]\nProject                 \tTech     \tLast Updated' \
    --preview='project_name=$(echo {} | awk "{print \$1}"); project_dir="'"$base_dir"'/$project_name"; 
    if [ -f "$project_dir/README.md" ]; then 
        echo "󰈙 README.md"; 
        echo "─────────────────────────────────"; 
        head -8 "$project_dir/README.md" | sed "s/^/  /"; 
        echo ""; 
    fi; 
    echo "󰙅 Contents"; 
    echo "─────────────────────────────────"; 
    if [[ "$OSTYPE" == "darwin"* ]]; then CLICOLOR_FORCE=1 ls -G "$project_dir" 2>/dev/null; else ls --color=always "$project_dir" 2>/dev/null; fi | head -15 | sed "s/^/  /" || echo "  Cannot access"' \
    --preview-window=right:50% \
    --ansi \
    --preview-label=" 󰋼 Details " | awk '{print $1}')

# Check if user cancelled fzf or proyecto is empty
if [ -z "$proyecto" ]; then
    echo "No project selected. Exiting."
    exit 0
fi

full_proyecto="$base_dir/$proyecto"

# Check if tmux session already exists
if tmux has-session -t "$proyecto" 2>/dev/null; then
    echo "Session '$proyecto' already exists. Switching to it."
    tmux switch-client -t "$proyecto"
    exit 0
fi

if [ -f "$full_proyecto/tmux.sh" ]; then
    # Extract the session name from the tmux.sh script
    cd "$full_proyecto"
    bash "$full_proyecto/tmux.sh" "$proyecto" "$full_proyecto"
else
    # Run default tmux commands
    tmux new-session -d -s "$proyecto" -c "$full_proyecto"
    tmux send-keys -t "$proyecto" "ave 2>/dev/null" C-m
    tmux send-keys -t "$proyecto" "clear" C-m
    tmux send-keys -t "$proyecto" "nv" C-m
    tmux switch-client -t "$proyecto"
fi
