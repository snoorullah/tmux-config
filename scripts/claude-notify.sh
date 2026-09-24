#!/usr/bin/env bash
# claude-notify.sh — Claude Code `Notification` hook → desktop notification
#
# Outside tmux, kitty turns Claude Code's terminal notifications into desktop
# ones itself. Inside tmux those escape sequences never reach kitty, so this
# hook calls notify-send directly, tagged with the tmux session:window.
# Clicking the notification jumps the tmux client to the pane that raised it.
#
# Wire up in ~/.claude/settings.json:
#   "hooks": { "Notification": [ { "hooks": [ { "type": "command",
#     "command": "~/.config/tmux/scripts/claude-notify.sh" } ] } ] }

# Not in tmux → kitty already handles it; avoid duplicate notifications.
[[ -n "$TMUX" && -n "$TMUX_PANE" ]] || exit 0
command -v notify-send &>/dev/null || exit 0

icon="$(dirname "$(readlink -f "$0")")/../assets/claude.png"
[[ -f "$icon" ]] || icon=utilities-terminal

input=$(cat)
field() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

message=$(field .message)
title=$(field .title)
cwd=$(field .cwd)
[[ -n "$message" ]] || message="Claude needs your attention"
[[ -n "$title" ]] || title="Claude Code"

location=$(tmux display-message -p -t "$TMUX_PANE" '#S:#I #W' 2>/dev/null)
project=${cwd:+$(basename "$cwd")}

summary="$title${project:+ · $project}"
body="$message${location:+\n<i>tmux $location</i>}"

# Visual cue in tmux too (shows on whichever client is viewing that session)
tmux display-message -t "$TMUX_PANE" -d 4000 "󰚩 $message" 2>/dev/null

# Detach from the hook so Claude isn't blocked waiting on the click.
(
    action=$(notify-send --app-name="Claude Code" --icon="$icon" \
        --urgency=normal --expire-time=10000 \
        --action=default=Focus --wait \
        "$summary" "$(printf '%b' "$body")" 2>/dev/null)
    if [[ "$action" == "default" ]]; then
        tmux switch-client -t "$TMUX_PANE" 2>/dev/null
        tmux select-window -t "$TMUX_PANE" 2>/dev/null
        tmux select-pane -t "$TMUX_PANE" 2>/dev/null
    fi
) </dev/null &>/dev/null &
disown

exit 0
