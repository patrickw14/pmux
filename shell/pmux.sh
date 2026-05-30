# pmux shell integration
# Source this file from your .zshrc or .bashrc:
#   source /path/to/pmux/shell/pmux.sh

# Auto-detect pmux directory from this file's location
if [ -n "$BASH_SOURCE" ]; then
    PMUX_DIR="$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)"
elif [ -n "$ZSH_VERSION" ]; then
    PMUX_DIR="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
fi
export PMUX_DIR

# Open or switch to a tmux session for a directory
alias to="$PMUX_DIR/scripts/open-tmux-ws.sh"
alias tmux-open="$PMUX_DIR/scripts/open-tmux-ws.sh"

# cd to the session's cwd. Falls back to ~/<session_name> for sessions created before @pmux_cwd was set.
cdsesh() {
    local dir
    dir="$(tmux show-option -qv @pmux_cwd 2>/dev/null)"
    if [ -n "$dir" ] && [ -d "$dir" ]; then
        cd "$dir"
    else
        cd "$HOME/$(tmux display-message -p '#S')"
    fi
}
