#!/bin/bash
# MEMPALACE SESSION-START HOOK — inject recall context at session start
#
# Claude Code "SessionStart" hook. Runs `mempalace wake-up` and feeds the
# L0 (identity) + L1 (essential story) summary into the new session's
# context via the hookSpecificOutput.additionalContext contract.
#
# === INSTALL ===
# Add to ~/.claude/settings.json:
#
#   "hooks": {
#     "SessionStart": [{
#       "matcher": "*",
#       "hooks": [{
#         "type": "command",
#         "command": "/absolute/path/to/mempal_sessionstart_hook.sh",
#         "timeout": 30
#       }]
#     }]
#   }
#
# === CONFIGURATION ===

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

STATE_DIR="$HOME/.mempalace/hook_state"

# Kill-switch: if ~/.mempalace was removed, do nothing (no recreation).
if [ ! -d "$HOME/.mempalace" ]; then
    echo "{}"
    exit 0
fi

mkdir -p "$STATE_DIR"

# Silent mode / opt-out
if [ -n "$MEMPALACE_HOOKS_AUTO_SAVE" ]; then
    case "$MEMPALACE_HOOKS_AUTO_SAVE" in
        false|0|no) echo "{}"; exit 0 ;;
    esac
fi

WAKEUP="$(mempalace wake-up 2>>"$STATE_DIR/hook.log")"

if [ -z "$WAKEUP" ]; then
    echo "{}"
    exit 0
fi

# Drop the "Wake-up text (~N tokens):" header and the "====" separator line
CONTEXT="$(printf '%s\n' "$WAKEUP" | tail -n +3)"

echo "[$(date '+%H:%M:%S')] SESSION START — injected wake-up context" >> "$STATE_DIR/hook.log"

# Emit as additionalContext via Python so JSON escaping is correct
printf '%s' "$CONTEXT" | python3 -c '
import json, sys
context = sys.stdin.read()
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context
    }
}))
'
