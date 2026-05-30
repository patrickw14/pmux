#!/bin/bash

# pmux-theme — switch tmux themes on the fly
# Usage: pmux-theme.sh [theme-name]
#   With no args, shows a tmux menu picker.
#
# Themes are loaded from ~/.tmux/themes/ which contains:
#   - Built-in themes (symlinked from pmux/tmux/oob-themes/)
#   - User themes (any .conf file dropped in directly)

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
CONFIG_DIR="$HOME/.config/pmux"
THEME_FILE="$CONFIG_DIR/theme"
THEMES_DIR="$HOME/.tmux/themes"

available_themes() {
    [ -d "$THEMES_DIR" ] || return
    for f in "$THEMES_DIR"/*.conf; do
        [ -f "$f" ] || continue
        basename "$f" .conf
    done | sort
}

apply_theme() {
    local theme="$1"
    local theme_file="$THEMES_DIR/$theme.conf"

    if [ ! -f "$theme_file" ]; then
        echo "Unknown theme: $theme"
        echo "Available: $(available_themes | tr '\n' ' ')"
        exit 1
    fi

    mkdir -p "$CONFIG_DIR"
    echo "$theme" > "$THEME_FILE"
    tmux source-file "$theme_file"
    tmux display-message "Theme: $theme"
}

if [ -n "$1" ]; then
    apply_theme "$1"
else
    # Build a tmux display-menu from all available themes
    menu_args=()
    for theme in $(available_themes); do
        # Pretty-print: replace hyphens with spaces and title-case
        label="$(echo "$theme" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')"
        key="${theme:0:1}"
        menu_args+=("$label" "$key" "run-shell '$SCRIPT_PATH $theme'")
    done
    tmux display-menu -T "Choose Theme" "${menu_args[@]}"
fi
