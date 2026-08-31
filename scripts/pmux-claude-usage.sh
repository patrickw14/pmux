#!/bin/bash

# pmux-claude-usage - Claude Code consumption percentage for the tmux status bar
#
# Usage:
#   pmux-claude-usage.sh            print the cached value, refreshing in the
#                                   background when stale (this is what tmux calls)
#   pmux-claude-usage.sh --refresh  fetch synchronously and update the cache
#   pmux-claude-usage.sh --clear    drop the cache and any stale lock
#
# Prints nothing when no usage figure is available (no credentials, no jq,
# first run) so the status bar chip stays hidden instead of showing junk.
#
# Tunables (environment):
#   PMUX_CLAUDE_USAGE_TTL   seconds before the cache is considered stale (600)
#   PMUX_CLAUDE_RESET_DAY   day of month the credit budget resets (1)
#   PMUX_CLAUDE_USAGE_UA    User-Agent sent to the usage endpoint

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/pmux"
CACHE_FILE="$CACHE_DIR/claude-usage"
LOCK_DIR="$CACHE_DIR/claude-usage.lock"
ATTEMPT_FILE="$CACHE_DIR/claude-usage.attempt"
TTL="${PMUX_CLAUDE_USAGE_TTL:-600}"
STALE_AFTER="${PMUX_CLAUDE_STALE_AFTER:-3600}"
RESET_DAY="${PMUX_CLAUDE_RESET_DAY:-1}"
LOCK_TIMEOUT=120
USER_AGENT="${PMUX_CLAUDE_USAGE_UA:-claude-code/2.1.34}"
KEYCHAIN_SERVICE='Claude Code-credentials'
USAGE_URL='https://api.anthropic.com/api/oauth/usage'

# Seconds since a file was last modified, or a huge number if it doesn't exist.
age_of() {
    local f="$1" mtime now
    [ -f "$f" ] || [ -d "$f" ] || { echo 999999; return; }
    mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)"
    [ -n "$mtime" ] || { echo 999999; return; }
    now="$(date +%s)"
    echo $((now - mtime))
}

# Whole days until the credit budget next resets. The usage endpoint doesn't
# report a cycle boundary, so this is derived from the calendar: RESET_DAY of
# the month, clamped to months that are too short to have that day.
# Rough human-readable duration, for labelling a figure we couldn't refresh.
human_age() {
    local secs="$1"
    if [ "$secs" -ge 86400 ]; then
        echo "$((secs / 86400))d"
    elif [ "$secs" -ge 3600 ]; then
        echo "$((secs / 3600))h"
    else
        echo "$((secs / 60))m"
    fi
}

# Midnight epoch of a given day in the month N months from now, with the day
# clamped to that month's length.
month_day_epoch() {
    local months="$1" day="$2" last
    last="$(date -v1d -v+$((months + 1))m -v-1d +%d 2>/dev/null)" || return 1
    last=$((10#$last))
    [ "$day" -le "$last" ] || day="$last"
    date -v1d -v+"${months}"m -v"${day}"d -v0H -v0M -v0S +%s 2>/dev/null
}

days_until_reset() {
    local today day reset_epoch today_epoch delta

    today="$(date +%d)" || return 1
    today=$((10#$today))

    day="$RESET_DAY"
    case "$day" in '' | *[!0-9]*) return 1 ;; esac
    day=$((10#$day))
    [ "$day" -ge 1 ] && [ "$day" -le 31 ] || return 1

    # Still ahead of us this month? Otherwise it's next month's reset. Landing
    # exactly on the reset day means a full fresh cycle, not zero days left.
    # Either way the day is clamped to that month's length, so a reset day of
    # 31 doesn't spill into the month after February.
    if [ "$day" -gt "$today" ]; then
        reset_epoch="$(month_day_epoch 0 "$day")" || return 1
    else
        reset_epoch="$(month_day_epoch 1 "$day")" || return 1
    fi
    today_epoch="$(date -v0H -v0M -v0S +%s 2>/dev/null)" || return 1

    # Round rather than truncate, so a span crossing a DST change (23 or 25
    # hours in a day) doesn't come out one short.
    delta=$((reset_epoch - today_epoch))
    echo $(((delta + 43200) / 86400))
}

# "claude usage: 35% (5 days left)". The day count is dropped if the date math
# misfires, and a figure we haven't managed to refresh in a long time is labelled
# so a dead OAuth token can't masquerade as a current reading.
format_chip() {
    local pct="$1" age="$2" days note=""

    if [ -n "$age" ] && [ "$age" -gt "$STALE_AFTER" ]; then
        note="$(human_age "$age") stale"
    fi

    if days="$(days_until_reset)" && [ "$days" -gt 0 ]; then
        if [ "$days" -eq 1 ]; then
            note="1 day left${note:+, $note}"
        else
            note="$days days left${note:+, $note}"
        fi
    fi

    printf 'claude usage: #[bold]%s%%#[none]%s\n' "$pct" "${note:+ ($note)}"
}

fetch_percentage() {
    command -v jq >/dev/null 2>&1 || return 1

    local token pct
    token="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null |
        jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)"
    [ -n "$token" ] || return 1

    pct="$(curl -fsS --max-time 10 \
        -H "Authorization: Bearer $token" \
        -H 'Accept: application/json' \
        -H 'anthropic-beta: oauth-2025-04-20' \
        -H "User-Agent: $USER_AGENT" \
        "$USAGE_URL" |
        jq -r '.extra_usage.utilization | floor' 2>/dev/null)"

    # Only accept a plain integer; anything else means the call went sideways.
    case "$pct" in
        '' | *[!0-9]*) return 1 ;;
    esac

    printf '%s\n' "$pct"
}

refresh() {
    mkdir -p "$CACHE_DIR"

    # A refresh left behind by a hung fetch shouldn't block us forever.
    if [ -d "$LOCK_DIR" ] && [ "$(age_of "$LOCK_DIR")" -gt "$LOCK_TIMEOUT" ]; then
        rmdir "$LOCK_DIR" 2>/dev/null
    fi

    # mkdir is the atomic bit. If someone else holds the lock, leave them to it.
    mkdir "$LOCK_DIR" 2>/dev/null || return 0
    trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

    # Mark the attempt before making it. Retry spacing is driven by this file,
    # not by the cache, so a failing fetch can't backdate a good figure or make
    # a stale one look fresh.
    touch "$ATTEMPT_FILE"

    local pct
    if pct="$(fetch_percentage)"; then
        printf '%s\n' "$pct" >"$CACHE_FILE"
    fi
}

case "$1" in
    --refresh)
        refresh
        [ -f "$CACHE_FILE" ] && format_chip "$(cat "$CACHE_FILE")" "$(age_of "$CACHE_FILE")"
        exit 0
        ;;
    --clear)
        rm -f "$CACHE_FILE" "$ATTEMPT_FILE"
        rmdir "$LOCK_DIR" 2>/dev/null
        exit 0
        ;;
esac

# Status-bar path: print what we have, then top up in the background if stale.
if [ -f "$CACHE_FILE" ]; then
    read -r cached <"$CACHE_FILE"
    [ -n "$cached" ] && format_chip "$cached" "$(age_of "$CACHE_FILE")"
fi

if [ "$(age_of "$ATTEMPT_FILE")" -gt "$TTL" ]; then
    ("$0" --refresh >/dev/null 2>&1 &) &
fi
