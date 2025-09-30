# base_dir="/Proyectos"
base_dir=$HOME/Proyectos
proyecto=`echo $(ls $base_dir)|tr ' ' '\n' | fzf`

# Check if user cancelled fzf or proyecto is empty
if [ -z "$proyecto" ]; then
    echo "No project selected. Exiting."
    exit 0
fi

full_proyecto="$base_dir/$proyecto"


if [ -f "$full_proyecto/tmux.sh" ]; then
    # Extract the session name from the tmux.sh script
    cd "$full_proyecto"
    bash "$full_proyecto/tmux.sh" "$proyecto" "$full_proyecto"
else
    # Run default tmux commands
    tmux neww -n $proyecto
    tmux send-keys -t $proyecto "cd $full_proyecto" C-m
    tmux send-keys -t $proyecto "ave 2>/dev/null" C-m

    tmux send-keys -t $proyecto "clear" C-m

    tmux send-keys -t $proyecto "nv" C-m
fi
