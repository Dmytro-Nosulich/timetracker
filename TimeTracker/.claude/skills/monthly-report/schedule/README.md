# Scheduling the monthly report

Runs `/monthly-report last month` at 09:00 on the 1st of every month, saving the PDF to
`~/Desktop`. Nothing here is installed by default — the two commands below do that.

## Why launchd and not a cloud agent

The report comes from the MCP server **inside the running TimeTracker app**, on
`127.0.0.1`. A scheduled cloud agent runs on someone else's machine and can never reach it.
The job has to run locally, which means launchd (or `cron`).

## Install

```bash
cp ~/Projects/TimeTracker/timetracker/TimeTracker/.claude/skills/monthly-report/schedule/com.dmytro.timetracker.monthly-report.plist \
   ~/Library/LaunchAgents/

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dmytro.timetracker.monthly-report.plist
```

Confirm it is loaded:

```bash
launchctl print gui/$(id -u)/com.dmytro.timetracker.monthly-report | head -20
```

## Test without waiting for the 1st

Run the script directly — this is exactly what launchd executes:

```bash
./run-monthly-report.sh
tail -30 ~/Library/Logs/timetracker-monthly-report.log
```

Or trigger the installed job itself:

```bash
launchctl kickstart -p gui/$(id -u)/com.dmytro.timetracker.monthly-report
```

## Uninstall

```bash
launchctl bootout gui/$(id -u)/com.dmytro.timetracker.monthly-report
rm ~/Library/LaunchAgents/com.dmytro.timetracker.monthly-report.plist
```

## Requirements

- **The MCP server must be enabled.** It is **off by default** — Settings → MCP Server →
  *Enable MCP server*. Without it the app runs but binds nothing, and every run fails with
  the skill reporting that TimeTracker isn't reachable.
- **TimeTracker must be running.** The script launches it if it isn't and waits 15s for the
  server to bind, but enabling **Launch at Login** in Settings is more reliable.
- **The `claude` CLI must be on `PATH`** at the location the script resolves. launchd gives
  a job almost no environment, so if `command -v claude` fails inside the job, set
  `CLAUDE_BIN` in the script to an absolute path.
- **The PDF folder must be writable without a prompt.** `~/Desktop` is guarded by macOS
  privacy; if TimeTracker has never written there, save one report by hand first and grant
  the permission, so the unattended run never meets a dialog.
- **The skill must be installed globally.** It lives in this repo, but is reached through a
  symlink in the personal skills directory:

  ```bash
  mkdir -p ~/.claude/skills
  ln -sfn "$PWD/.." ~/.claude/skills/monthly-report   # run from this schedule/ directory
  ```

  Without that, `/monthly-report` is only found from this project directory or below, and
  the job would have to `cd` here first. With it, the skill works from anywhere and stays
  version-controlled in one place. Confirm with `ls -l ~/.claude/skills/`.
- **The plist path is absolute and personal.** It hardcodes
  `/Users/dmytronosulich/...`; change it if the project moves — and re-point the symlink
  above too.

## Changing the schedule

Edit `StartCalendarInterval` in the plist, then `bootout` and `bootstrap` again — launchd
reads the file only at load. `Day` is the day of the month; drop it to run daily.
