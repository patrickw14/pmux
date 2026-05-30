#!/bin/bash

# Use argument if provided, otherwise current directory
arg="${1:-$PWD}"

# If arg looks like a git URL (http(s)://...git), clone it into ~/git
# (or ~/git/snc for code.devsnc.com URLs) and use the clone as the target.
if [[ "$arg" == http*.git ]]; then
    if [[ "$arg" == *code.devsnc.com* ]]; then
        parent_dir="$HOME/git/snc"
    else
        parent_dir="$HOME/git"
    fi
    mkdir -p "$parent_dir"

    repo_name="${arg##*/}"
    repo_name="${repo_name%.git}"
    clone_dir="$parent_dir/$repo_name"

    if [ ! -d "$clone_dir" ]; then
        git clone "$arg" "$clone_dir" || { echo "Clone failed: $arg"; exit 1; }
    fi
    target_dir="$clone_dir"
else
    target_dir="$arg"
fi

target_dir="${target_dir/#\~/$HOME}"
target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || { echo "Invalid directory: $1"; exit 1; }

# Get directory relative to home
session_name="${target_dir#$HOME/}"

# Replace characters that tmux doesn't like in session names
session_name="${session_name//\./_}"
session_name="${session_name//:/_}"

if [ -n "$TMUX" ]; then
    # Already in tmux
    current_session=$(tmux display-message -p "#S")

    # No-op if already in the right session
    if [ "$current_session" = "$session_name" ]; then
        exit 0
    fi

    # Create session if it doesn't exist (detached)
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        tmux new-session -d -s "$session_name" -c "$target_dir"
    fi

    # Remember the original cwd so cdsesh can recover it losslessly.
    tmux set-option -t "$session_name" @pmux_cwd "$target_dir"

    # Switch to it
    tmux switch-client -t "$session_name"
else
    # Not in tmux, attach or create
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        tmux new-session -d -s "$session_name" -c "$target_dir"
    fi
    tmux set-option -t "$session_name" @pmux_cwd "$target_dir"
    tmux attach-session -t "$session_name"
fi
