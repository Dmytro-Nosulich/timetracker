#!/bin/bash
#
# Runs the /monthly-report skill unattended. Invoked by the LaunchAgent alongside this
# script (com.dmytro.timetracker.monthly-report.plist) on the 1st of each month.
#
# Run it by hand any time to test the scheduled path exactly as launchd will execute it:
#   ~/Projects/TimeTracker/timetracker/TimeTracker/.claude/skills/monthly-report/schedule/run-monthly-report.sh

set -uo pipefail

# The MCP server is registered at local scope, i.e. against this project directory, and the
# skill itself lives in this project's .claude/skills. Both are found only from here.
PROJECT_DIR="$HOME/Projects/TimeTracker/timetracker/TimeTracker"
LOG_FILE="$HOME/Library/Logs/timetracker-monthly-report.log"

# launchd gives a job almost no PATH, so `claude` has to be found deliberately.
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"
}

log "--- monthly report run starting ---"

if [[ ! -x "$CLAUDE_BIN" ]]; then
    log "ERROR: claude CLI not found (looked for '$CLAUDE_BIN'). Nothing generated."
    exit 1
fi

# The app hosts the MCP server, so nothing can be generated without it. Launch it and give
# it a moment to bind rather than failing on a Mac that has just booted.
if ! pgrep -qf "TimeTracker.app/Contents/MacOS/TimeTracker"; then
    log "TimeTracker is not running — launching it."
    open -ga TimeTracker || log "WARNING: could not launch TimeTracker."
    sleep 15
fi

cd "$PROJECT_DIR" || { log "ERROR: project directory '$PROJECT_DIR' is missing."; exit 1; }

# --allowed-tools is what keeps this prompt-free: without it the run would block on a
# permission prompt nobody is there to answer.
OUTPUT=$(
    "$CLAUDE_BIN" -p "/monthly-report last month" \
        --allowed-tools "mcp__timetracker__save_report_pdf" \
        2>&1
)
STATUS=$?

log "$OUTPUT"

if [[ $STATUS -ne 0 ]]; then
    log "--- run FAILED (exit $STATUS) ---"
    exit $STATUS
fi

log "--- run finished ---"
