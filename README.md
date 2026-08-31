# pmux

Opinionated tmux configuration with theming. Clone it, run the installer, get a nice tmux setup.

<img width="3090" height="1956" alt="image" src="https://github.com/user-attachments/assets/dd4e0ca0-2643-4b97-89e8-56c5a049d310" />

## Quick Start

```bash
# Install
git clone https://github.com/patrickw14/pmux.git ~/pmux
cd ~/pmux && ./install.sh

# Add to your .zshrc / .bashrc
source ~/pmux/shell/pmux.sh
```

Then start using it:

```bash
# Start a tmux session in the current directory
to

# Start a session for a specific project
to ~/git/my-project

# Already in tmux? `to` switches sessions instantly
to ~/git/another-project
```

### Cheatsheet

All keybindings use **Ctrl+Space** as the prefix.

| Keys | Action |
|------|--------|
| `Ctrl+Space \|` | Split pane horizontally |
| `Ctrl+Space -` | Split pane vertically |
| `Ctrl+Space arrow` | Switch between panes |
| `Ctrl+Space x` | Kill the selected pane |
| `Ctrl+Space Space` | Open the command panel |
| `Ctrl+Space t` | Open the theme picker |
| `Ctrl+Space c` | New window |
| `Ctrl+Space r` | Reload config |

### Themes

Three built-in themes, switchable live with `Ctrl+Space t`:

- **ServiceNow Dark** — wasabi green + infinite blue
- **Tokyo Night** — cool blue accents on dark
- **Daylight** — clean light theme

Your choice persists across sessions in `~/.config/pmux/theme`.

### Claude usage chip

The status bar shows your Claude Code consumption as a percentage, plus the days
left in the current credit cycle, left of the date:

```
  claude usage: 35% (5 days left) │  2026-08-27   3:31pm
```

It reads the OAuth token from your login keychain and polls
`api.anthropic.com/api/oauth/usage`. The figure is cached in
`~/.cache/pmux/claude-usage` and refreshed at most once every 10 minutes; the
status bar only ever reads the cache, so it never blocks on the network.

The chip hides itself entirely when there's no figure to show: no Claude Code
credentials, no `jq`, or a first run that hasn't fetched yet.

If a fetch fails (an expired OAuth token, no network, a 401) the last good
figure keeps showing and a retry happens on the next poll. Once that figure is
more than an hour old it gets labelled, so a dead token can't quietly pass off a
day-old number as current:

```
claude usage: 36% (5 days left, 3h stale)
```

Adjust that threshold with `PMUX_CLAUDE_STALE_AFTER` (seconds).

The usage endpoint reports no cycle boundary, so the day count is derived from
the calendar and assumes the budget resets on the 1st. If your cycle starts on
another day, set `PMUX_CLAUDE_RESET_DAY`. A day past the end of a short month is
clamped to that month's last day, so `31` behaves in February.

```bash
# Force a refresh now
~/.tmux/scripts/pmux-claude-usage.sh --refresh

# Drop the cache
~/.tmux/scripts/pmux-claude-usage.sh --clear

# Poll every 30 minutes instead (set before tmux starts)
export PMUX_CLAUDE_USAGE_TTL=1800

# Credit cycle resets on the 15th, not the 1st
export PMUX_CLAUDE_RESET_DAY=15

# Label the figure stale after 30 minutes instead of an hour
export PMUX_CLAUDE_STALE_AFTER=1800
```

---

## What you get

- **Ctrl+Space** prefix (instead of Ctrl+b)
- Mouse support, vi copy mode, true color
- Intuitive splits: `|` horizontal, `-` vertical
- 1-based window/pane indexing with auto-renumber
- Themed status bar with powerline separators and nerd font icons
- **Claude usage chip** - your Claude Code consumption percentage in the status bar
- Inactive pane dimming
- 50k line scrollback
- **tmux-which-key** — discoverable command menu via `prefix + Space`
- **Session management** — `to ~/project` opens/switches to a tmux session for that directory
- **cdsesh** — cd to the directory matching your current session name

## Install

```bash
git clone https://github.com/patrickwilson/pmux.git ~/git/pmux
cd ~/git/pmux
./install.sh
```

Then add this to your `.zshrc` or `.bashrc`:

```bash
source ~/git/pmux/shell/pmux.sh
```

## Update

```bash
cd ~/git/pmux
git pull
./install.sh
```

The installer is idempotent — run it as many times as you want.

## What the installer does

1. Symlinks the pmux tmux config into `~/.tmux/`
2. Creates a starter `~/.tmux.conf` if you don't have one (or tells you what to add)
3. Symlinks helper scripts into `~/.tmux/scripts/`
4. Symlinks theme files into `~/.tmux/themes/`
5. Sets a default theme if none chosen
6. Installs TPM (tmux plugin manager) if missing
7. Installs plugins via TPM
8. Sets up the tmux-which-key menu config

## Customization

### Adding your own tmux config

Your `~/.tmux.conf` sources pmux. Add your own settings below the source line:

```tmux
source-file ~/.tmux/pmux.conf

# Your overrides here
set -g status-position top
```

### Custom which-key menus

To override the which-key config without modifying pmux:

```bash
mkdir -p ~/.config/pmux
cp ~/git/pmux/tmux/which-key.yaml ~/.config/pmux/which-key.yaml
# Edit to taste, then re-run install.sh
```

### Adding plugins

Add `set -g @plugin 'owner/repo'` to your `~/.tmux.conf` (after the source line), then press `prefix + I` in tmux.

### Adding themes

Drop a `.conf` file in `~/.config/pmux/themes/` and it will automatically appear in the theme picker (`Ctrl+Space t`). No need to modify any pmux files.

```bash
mkdir -p ~/.config/pmux/themes
cp ~/pmux/tmux/themes/tokyo-night.conf ~/.config/pmux/themes/my-theme.conf
# Edit the colors, then pick it from the menu
```

User themes in `~/.config/pmux/themes/` take priority over built-in themes with the same name.

## Shell commands

| Command | Description |
|---------|-------------|
| `to <dir>` | Open or switch to a tmux session for a directory |
| `tmux-open <dir>` | Same as `to` |
| `cdsesh` | cd to the directory matching current session name |

## All key bindings

| Binding | Action |
|---------|--------|
| `Ctrl+Space` | Prefix |
| `prefix + Space` | Which-key menu (shows all commands) |
| `prefix + \|` | Split horizontally |
| `prefix + -` | Split vertically |
| `prefix + c` | New window (preserves cwd) |
| `prefix + x` | Kill pane |
| `prefix + t` | Theme picker |
| `prefix + h` | Clock |
| `prefix + r` | Reload config |
| `Alt + arrows` | Navigate panes |
| `prefix + I` | Install new plugins |
| `prefix + U` | Update plugins |

## Requirements

- tmux 3.3+ (3.6 recommended)
- A [Nerd Font](https://www.nerdfonts.com/) for icons and powerline separators
- `jq` and `curl` for the Claude usage chip (optional; the chip just hides without them)
