#!/bin/bash
set -e

# ============================================
# pmux installer — idempotent, run as many times as you like
# ============================================

PMUX_DIR="$(cd "$(dirname "$0")" && pwd)"
TMUX_DIR="$HOME/.tmux"
TMUX_CONF="$HOME/.tmux.conf"
PLUGINS_DIR="$TMUX_DIR/plugins"
SCRIPTS_DIR="$TMUX_DIR/scripts"
OVERRIDE_DIR="$HOME/.config/pmux"

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok()    { printf "\033[1;32m  ✓\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m  !\033[0m %s\n" "$1"; }

# ------------------------------------------
# 0. Check for tmux
# ------------------------------------------
if ! command -v tmux &>/dev/null; then
    warn "tmux is not installed."
    printf "  Install tmux via Homebrew? [y/N] "
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        if ! command -v brew &>/dev/null; then
            warn "Homebrew not found. Install tmux manually, then re-run install.sh."
            exit 1
        fi
        brew install tmux
        ok "tmux installed"
    else
        echo ""
        warn "pmux requires tmux. Install it yourself, then re-run install.sh."
        exit 1
    fi
else
    ok "tmux found: $(tmux -V)"
fi

# ------------------------------------------
# 1. Create directories
# ------------------------------------------
info "Setting up directories"
mkdir -p "$PLUGINS_DIR" "$SCRIPTS_DIR"
ok "~/.tmux/plugins/ and ~/.tmux/scripts/"

# ------------------------------------------
# 2. Symlink pmux.conf
# ------------------------------------------
info "Linking tmux config"
target="$TMUX_DIR/pmux.conf"
if [ -L "$target" ] && [ "$(readlink "$target")" = "$PMUX_DIR/tmux/pmux.conf" ]; then
    ok "pmux.conf already linked"
else
    ln -sf "$PMUX_DIR/tmux/pmux.conf" "$target"
    ok "Linked ~/.tmux/pmux.conf"
fi

# ------------------------------------------
# 3. Bootstrap ~/.tmux.conf if needed
# ------------------------------------------
info "Checking ~/.tmux.conf"
SOURCE_LINE="source-file ~/.tmux/pmux.conf"

if [ ! -f "$TMUX_CONF" ]; then
    cat > "$TMUX_CONF" <<EOF
# Source pmux (add your own overrides below)
$SOURCE_LINE
EOF
    ok "Created ~/.tmux.conf"
elif grep -qF "$SOURCE_LINE" "$TMUX_CONF"; then
    ok "~/.tmux.conf already sources pmux"
else
    warn "~/.tmux.conf exists but doesn't source pmux."
    warn "Add this line to your ~/.tmux.conf:"
    warn "  $SOURCE_LINE"
fi

# ------------------------------------------
# 4. Symlink scripts
# ------------------------------------------
info "Linking scripts"
for script in "$PMUX_DIR"/scripts/*.sh; do
    name="$(basename "$script")"
    target="$SCRIPTS_DIR/$name"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$script" ]; then
        ok "$name already linked"
    else
        ln -sf "$script" "$target"
        ok "Linked $name"
    fi
done
chmod +x "$PMUX_DIR"/scripts/*.sh

# ------------------------------------------
# 5. Symlink themes
# ------------------------------------------
info "Linking themes"
THEMES_DIR="$TMUX_DIR/themes"
# Remove old directory symlink from previous installs
[ -L "$THEMES_DIR" ] && rm "$THEMES_DIR"
mkdir -p "$THEMES_DIR"
for theme in "$PMUX_DIR"/tmux/oob-themes/*.conf; do
    name="$(basename "$theme")"
    target="$THEMES_DIR/$name"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$theme" ]; then
        ok "$name already linked"
    else
        ln -sf "$theme" "$target"
        ok "Linked $name"
    fi
done

# Ensure theme config dir exists
mkdir -p "$OVERRIDE_DIR"

# Set default theme if none chosen
if [ ! -f "$OVERRIDE_DIR/theme" ]; then
    echo "tokyo-night" > "$OVERRIDE_DIR/theme"
    ok "Default theme set to tokyo-night"
else
    ok "Theme already configured: $(cat "$OVERRIDE_DIR/theme")"
fi

# ------------------------------------------
# 6. Install TPM
# ------------------------------------------

info "Checking TPM"
TPM_DIR="$PLUGINS_DIR/tpm"
if [ -d "$TPM_DIR" ]; then
    ok "TPM already installed"
else
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    ok "Installed TPM"
fi

# ------------------------------------------
# 7. Handle which-key config
# ------------------------------------------
info "Setting up tmux-which-key config"
WHICHKEY_PLUGIN_DIR="$PLUGINS_DIR/tmux-which-key"
WHICHKEY_TARGET="$WHICHKEY_PLUGIN_DIR/config.yaml"
WHICHKEY_OVERRIDE="$OVERRIDE_DIR/which-key.yaml"

if [ -f "$WHICHKEY_OVERRIDE" ]; then
    # User has a local override — use it
    if [ -L "$WHICHKEY_TARGET" ] && [ "$(readlink "$WHICHKEY_TARGET")" = "$WHICHKEY_OVERRIDE" ]; then
        ok "which-key using local override (already linked)"
    else
        ln -sf "$WHICHKEY_OVERRIDE" "$WHICHKEY_TARGET"
        ok "which-key linked to local override (~/.config/pmux/which-key.yaml)"
    fi
else
    # Use pmux default
    if [ -L "$WHICHKEY_TARGET" ] && [ "$(readlink "$WHICHKEY_TARGET")" = "$PMUX_DIR/tmux/which-key.yaml" ]; then
        ok "which-key config already linked"
    elif [ -d "$WHICHKEY_PLUGIN_DIR" ]; then
        ln -sf "$PMUX_DIR/tmux/which-key.yaml" "$WHICHKEY_TARGET"
        ok "Linked which-key config"
    else
        ok "which-key plugin not yet installed (will configure after plugin install)"
    fi
fi

# ------------------------------------------
# 8. Install plugins via TPM
# ------------------------------------------
info "Installing tmux plugins"
if [ -x "$TPM_DIR/bin/install_plugins" ]; then
    "$TPM_DIR/bin/install_plugins" || true
    ok "Plugins installed"

    # Link which-key config if plugin was just installed
    if [ -d "$WHICHKEY_PLUGIN_DIR" ] && [ ! -L "$WHICHKEY_TARGET" ]; then
        if [ -f "$WHICHKEY_OVERRIDE" ]; then
            ln -sf "$WHICHKEY_OVERRIDE" "$WHICHKEY_TARGET"
        else
            ln -sf "$PMUX_DIR/tmux/which-key.yaml" "$WHICHKEY_TARGET"
        fi
        ok "Linked which-key config (post plugin install)"
    fi
else
    warn "TPM install script not found — plugins will install on first tmux launch (prefix + I)"
fi

# ------------------------------------------
# 9. Shell integration
# ------------------------------------------
info "Shell integration"
SHELL_FILE="$PMUX_DIR/shell/pmux.sh"

shell_sourced=false
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rc" ] && grep -qF "source $SHELL_FILE" "$rc"; then
        shell_sourced=true
    fi
    if [ -f "$rc" ] && grep -qF "source \"$SHELL_FILE\"" "$rc"; then
        shell_sourced=true
    fi
done

if $shell_sourced; then
    ok "Shell integration already configured"
else
    echo ""
    warn "Add this line to your .zshrc and/or .bashrc:"
    warn "  source \"$SHELL_FILE\""
    echo ""
fi

# ------------------------------------------
# Done
# ------------------------------------------
echo ""
info "pmux installed! 🎉"
echo "  Reload tmux config:  tmux source ~/.tmux.conf"
echo "  Or start a new tmux session to pick up changes."
echo ""
