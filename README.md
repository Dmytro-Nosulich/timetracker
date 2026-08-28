# TimeTracker

> A native macOS time tracking app for freelancers — track time, manage tasks, and generate professional PDF reports.

![macOS](https://img.shields.io/badge/macOS-15%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)
![SwiftData](https://img.shields.io/badge/Storage-SwiftData-green)

---

## Why This Exists

Freelancers need a simple, distraction-free way to track time across multiple tasks — without the overhead of a full project management tool or a subscription-based SaaS. TimeTracker lives quietly in your menu bar, stays out of your way, and gives you accurate time data when you need it.

No accounts. No syncing to third-party servers. No monthly fees. Just a fast, native macOS app that does one thing well.

---

## What It Does

TimeTracker lets you create tasks, start/pause a timer with a single click, and review tracked time through a calendar heatmap and detailed time entries. At the end of a billing period, generate a clean PDF report — complete with hourly rates, totals, and your business name — ready to send to a client.

The app runs as a **hybrid menu bar + windowed application**: it stays alive in your menu bar even when all windows are closed, so you never lose a running timer.

---

## Features

### Task Management
- Create tasks with a title, description, and optional tags
- Assign an optional per-task hourly rate (overrides the global default)
- Filter tasks by tag in the main window
- Live search: a native macOS toolbar search field filters the task list by title or description (case-insensitive), combining with the tag filter via AND logic
- Delete tasks with cascade removal of all time entries

### Timer
- Start, pause, and resume tracking with one click
- Silently switch between tasks — the previous session is saved automatically
- Session counter displayed in a dedicated Timer Window (compact, always-on-top optional)
- Midnight rollover: entries are split at 00:00 so daily totals are always accurate
- App crash recovery: detects unfinished entries on next launch and prompts you to save or discard

### Menu Bar Integration
- Always-visible menu bar icon with visual state indicators:
  - **Green dot** — timer running
  - **Orange/yellow** — paused due to inactivity
  - **Paused icon** — paused by user
  - **Default** — no active timer
- Pause/resume directly from the menu bar dropdown without opening any window
- Shows current task name, session elapsed time, and today's total

### Idle Detection
- Automatically pauses the timer after a configurable inactivity timeout (default: 10 minutes)
- Uses `CGEventSource` — no Input Monitoring permission required
- Optional: subtract idle time from the tracked entry (time ends at last detected activity)
- "Welcome back" dialog when activity resumes — choose to resume or stay paused
- Detects computer sleep/wake events and handles them the same way

### Task Detail & Time Entry Editing
- Per-task calendar heatmap showing intensity by hours tracked per day
- View, add, edit, and delete individual time entries for any day
- Overlap detection warns when a new entry conflicts with an existing one
- All edits use a draft context — nothing is saved until you press Save

### Heatmap (All Tasks)
- A dedicated window, opened from the Main Window toolbar or `⌘T`, showing total tracked time across **all tasks** per day — complements the per-task heatmap in Task Detail above
- Monthly calendar grid with Month/Year pickers, ◀/▶ navigation (also arrow-key navigable), and a running monthly total
- Navigation is bounded to the range between your earliest and latest recorded time entry
- Color shading is anchored to a configurable "target daily hours" setting, with 8 discrete intensity tiers
- Click a day to reveal a read-only "Tracked tasks" list below the calendar — a per-task time breakdown for that day, sorted by duration
- Disabled until at least one time entry exists; only one Heatmap window at a time

### Reports & PDF Export
- Choose a period: Today, This Week, Last Week, This Month, Last Month, This Year, All Time, or a custom date range
- Select which tasks to include via checkboxes
- Time rounding options: None, 5 min, 15 min, or 30 min (display/export only — raw data is never modified)
- Amount column calculated automatically from hours × hourly rate
- Export a professional PDF with your business name, period, task breakdown, rates, and totals
- Currency support: USD, EUR, GBP, CAD, AUD, JPY, CHF, or a custom symbol

### Settings
- Business name (pre-fills the Report window and PDF header)
- Default hourly rate and currency
- Idle timeout and "subtract idle time" toggle
- Target daily hours (1–24h, default 8h) — scales the Heatmap's color intensity
- Launch at Login (using `SMAppService`)
- Daily tracking reminder: sends a local notification at a configured time on selected weekdays if no timer has been started
- Full tag management: create, rename, recolor, and delete tags
- MCP server: enable/disable, choose the port, see live status, and copy the URL to register with an AI client (see [AI Access](#ai-access-mcp-server))

---

## AI Access (MCP Server)

TimeTracker has a [Model Context Protocol](https://modelcontextprotocol.io) server built into the app itself, so an AI client — Claude Code, Claude Desktop — can answer questions about your tracked time and generate report PDFs for you:

> "How much did I bill last month?"
> "What have I tracked this week, per task?"
> "Generate last month's report and save it to my Desktop."

Because the server runs **inside** the running app rather than as a separate process, it reads through the app's own live data. There is no export step, no second copy of your database, and nothing to keep in sync.

### Local-only and read-only

- **Local-only.** The server binds `127.0.0.1` and never `0.0.0.0`. It is not reachable from your network, your router, or anywhere else — only from this Mac.
- **Read-only, with one exception.** Four of the five tools cannot write anything at all. The fifth, `save_report_pdf`, writes exactly one thing: the PDF file you asked it to produce, at the path you named. **No tool can create, edit, or delete tasks, tags, or time entries.** Your tracked time is billing data, so the server can only ever read it.
- **No accounts, no cloud.** Nothing leaves your machine except what you choose to share with your AI client.

### Setup

**1. Enable it in the app** — **Settings** (`⌘,`) → **MCP Server**:

| Control | What it does |
|---|---|
| **Enable MCP server** | **Off by default — turn this on first.** The server is opt-in, so nothing is listening until you enable it. Toggling takes effect immediately, no relaunch. |
| **Port** | Defaults to `8427`. Type a new one and press **Apply** (or Return); any port from 1024 to 65535. |
| **Status** | Green *Running on port N*, grey *Stopped*, or red *Failed* with a **Retry** button — most often because something else already holds the port. |
| **URL** | The exact address to register, with a copy button. |
| **Configuration for other AI clients** | A collapsible, read-only block holding the whole config as JSON, with its own copy button — for clients you set up by editing a file rather than running a command. Tracks the saved port. |

**2. Register it with Claude Code** — once, from a terminal:

```bash
claude mcp add -s user --transport http timetracker http://127.0.0.1:8427/mcp
```

Change the port if you changed it in Settings. Then check it:

```bash
claude mcp list      # timetracker: http://127.0.0.1:8427/mcp (HTTP) - ✔ Connected
```

`-s user` makes it available in **every directory on your Mac**, which is usually what you want — the questions it answers ("how much did I bill last month?") aren't tied to any one project. Drop the `-s user` to register it for the current project directory only:

```bash
claude mcp add --transport http timetracker http://127.0.0.1:8427/mcp    # this project only
```

Check which scope a registration is in with `claude mcp get timetracker`, and remove it with `claude mcp remove timetracker -s user`.

**3. Other MCP clients** — expand **Configuration for other AI clients** in Settings and copy the block, or paste this into your client's config file. Clients that speak HTTP natively — Cursor, and Claude Code's own `.mcp.json` — take it as-is; VS Code wants the same object under `servers` rather than `mcpServers`:

```json
{
  "mcpServers": {
    "timetracker": {
      "type": "http",
      "url": "http://127.0.0.1:8427/mcp"
    }
  }
}
```

### Claude Desktop needs a bridge

Claude Desktop is the exception, and it fails in two confusing ways if you don't know that:

- **Settings → Connectors → Add custom connector rejects the address**, insisting it start with `https://`. That dialog is built for remote connectors and will never accept a `127.0.0.1` URL.
- **The JSON above won't work there either.** Claude Desktop's `claude_desktop_config.json` launches MCP servers over **stdio** — `command` and `args` — and does not take a `url`.

The fix is [`mcp-remote`](https://www.npmjs.com/package/mcp-remote), a small stdio↔HTTP bridge that needs [Node.js](https://nodejs.org/). Open **Settings → Developer → Edit Config** and add:

```json
{
  "mcpServers": {
    "timetracker": {
      "command": "npx",
      "args": [
        "-y", "mcp-remote@latest",
        "http://127.0.0.1:8427/mcp",
        "--allow-http", "--transport", "http-only"
      ]
    }
  }
}
```

`--allow-http` is required — without it the bridge refuses a non-HTTPS address, the same wall the connector dialog puts up. Then **quit Claude Desktop completely and reopen it**; closing the window is not enough.

If the server doesn't appear, the usual cause is that Claude Desktop launches with a minimal `PATH` and cannot find `npx`. Replace `"npx"` with its absolute path — `which npx` will tell you, e.g. `/opt/homebrew/opt/node@24/bin/npx`. Connection failures are logged to `~/Library/Logs/Claude/mcp.log`.

### Available Tools

| Tool | What it answers | Ask it |
|---|---|---|
| `get_time_for_task` | Raw time on one task you name — every match with its own total, never a guess | *"How much time have I spent on the Acme redesign?"* |
| `get_time_for_period` | Raw time across all tasks in a period, as a single total or per task | *"What have I tracked this month, per task?"* |
| `get_billable_report` | The invoice numbers: your rounding applied, rates resolved, amounts computed — exactly what the Report screen shows | *"How much did I bill last month?"* |
| `save_report_pdf` | The same report rendered to a **PDF file** on disk, with no save dialog | *"Generate last month's report and save it to my Desktop."* |
| `list_tasks_and_tags` | What tasks and tags exist — discovery, and for resolving an ambiguous name | *"What tasks do I have?"* |

The billable tools read your live **Settings**: time rounding, default hourly rate, currency, and business name. Change a setting and the next answer reflects it — no relaunch.

### Good to know

- **The app must be running.** The server lives inside it. Quit the app and the connection simply fails; start it again and the next question works. Turn on **Launch at Login** in Settings if you want it always available.
- **Run a current build.** A build from before this feature has no server in it at all — if `claude mcp list` says `ConnectionRefused` while the app is clearly running, check you are not launching an older copy.
- **First write to a protected folder may prompt once.** The app runs un-sandboxed so it can save a PDF without a dialog. macOS still guards `~/Desktop`, `~/Documents` and `~/Downloads`, so the very first save into one of those may ask for permission. Grant it once and unattended saves work from then on.
- **Reports are never overwritten.** Saving a report whose name is taken produces `Time Report - July 2026 (2).pdf` instead of replacing the original.

### Monthly reports, unattended

The project ships a `/monthly-report` skill that generates the current month's PDF to your Desktop in one command, and a ready-made LaunchAgent to run it on the 1st of every month. See [`.claude/skills/monthly-report/`](TimeTracker/.claude/skills/monthly-report/).

```bash
claude                      # then, in the session:
/monthly-report             # this month
/monthly-report last month  # the month that just ended
/monthly-report July 2026   # a named month
```

It also triggers without the slash — "generate my monthly report" reaches it just as well.

**Install it once so it works from any directory.** Skill discovery only searches upward from where you started `claude`, so a skill inside this repo is invisible from anywhere above it — including the repo's own git root. Symlink it into your personal skills directory:

```bash
mkdir -p ~/.claude/skills
ln -sfn "$PWD/TimeTracker/.claude/skills/monthly-report" ~/.claude/skills/monthly-report
```

A symlink rather than a copy, so the skill stays version-controlled here while being reachable everywhere. Without it, `/monthly-report` only works from `TimeTracker/` or below.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Observable State | `@Observable` (Observation framework) |
| PDF Generation | Core Graphics |
| AI Access | MCP (`modelcontextprotocol/swift-sdk`) over local HTTP, served by SwiftNIO |
| Idle Detection | `CGEventSource` |
| Login Items | `SMAppService` |
| Notifications | `UNUserNotificationCenter` |
| Testing | Swift Testing framework |
| Target | macOS 15+ (Sequoia) |

---

## Architecture

TimeTracker follows **MVVM** with clean layer separation and protocol-based dependency injection throughout.

### Layer Overview

```
TimeTracker/
├── Domain/Models/         # Pure Swift domain models (TaskItem, TimeEntryItem, TagItem, TimerState)
├── Services/              # Business logic, each behind a protocol + default implementation
│   ├── Timer/             # TimerService — session tracking, state machine, midnight rollover
│   ├── LocalStorage/      # SwiftData persistence + entity→domain mapping
│   ├── IdleMonitor/       # Idle detection via CGEventSource
│   ├── Notifications/     # UNUserNotificationCenter tracking reminders
│   ├── Report/            # PDF generation via Core Graphics
│   ├── MCP/               # Embedded MCP server + its five tools
│   └── UserPreferences/   # AppStorage / UserDefaults wrapper
├── Presentation/          # MVVM modules (ViewModel + View + ModuleBuilder)
│   ├── MainWindow/
│   ├── TimerWindow/
│   ├── TaskDetail/
│   ├── AddTask/
│   ├── Report/
│   └── Settings/
├── Views/                 # Reusable SwiftUI components (CalendarHeatmapView, TagChip, etc.)
├── Utilities/             # Pure helpers (time formatting, rounding, overlap detection, hex colors)
└── App/                   # AppDelegate, window coordinators, service holders
```

### Key Design Decisions

**MVVM Modules** — Each screen is a self-contained module with three components:
- `ViewModel` — `@Observable` class holding state and business logic, injected with service protocols
- `View` — SwiftUI view that takes a ViewModel as a `@State` property
- `ModuleBuilder` — Factory struct that wires real services into the ViewModel and returns the configured View

**Protocol-Driven Services** — Every service is defined as a protocol (`TimerService`, `LocalStorageService`, `IdleMonitorService`, etc.) with a default implementation and a mock for testing. ViewModels depend only on the protocol.

**Data Layer Separation** — SwiftData `@Model` entities (`TaskEntity`, `TimeEntryEntity`, `TagEntity`) never leave the Services layer. The rest of the app works exclusively with domain models (`TaskItem`, `TimeEntryItem`, `TagItem`).

**Draft Editing Context** — The Task Detail window creates a child `ModelContext` on open. All edits stay local until the user presses Save, then the child context merges into the main context. Closing without saving prompts a discard confirmation.

**Timer State Machine**

```
          startTimer()
  .idle ──────────────────► .running
    ▲                           │
    │  pauseTimer()             │ pauseTimer()
    │  (via quit/save)          ▼
    └──────────────── .pausedByUser
                               │
          pauseDueToInactivity()│ (idle / sleep)
                               ▼
                    .pausedByInactivity
                               │
                    resumeTimer()│
                               ▼
                           .running
```

### Testing

The project includes a full suite of **unit tests** using Apple's Swift Testing framework, mirroring the production folder structure:

```
TimeTrackerTests/
├── Mocks/              # Mock implementations of all service protocols
├── Services/           # Tests for TimerService, LocalStorageService, IdleMonitor, etc.
├── Presentation/       # ViewModel tests for every MVVM module
├── Utilities/          # Tests for time formatting, rounding, overlap detection
├── Domain/             # Domain model computed property tests
└── App/                # Coordinator tests
```

All ViewModels and services are tested in isolation using mock services injected via DI.

---

## Requirements

- **macOS 15.0+** (Sequoia)
- **Xcode 16+**

---

## Getting Started

```bash
# Clone the repository
git clone <repo-url>
cd timetracker/TimeTracker

# Open in Xcode
open TimeTracker.xcodeproj
```

Select the **TimeTracker** scheme, choose your Mac as the run destination, and press **Run** (⌘R).

Two Swift Package Manager dependencies, both resolved by Xcode on first open — no CocoaPods, nothing to install by hand:

| Package | Why |
|---|---|
| [`modelcontextprotocol/swift-sdk`](https://github.com/modelcontextprotocol/swift-sdk) | The MCP protocol implementation behind [AI Access](#ai-access-mcp-server) |
| [`apple/swift-nio`](https://github.com/apple/swift-nio) | The HTTP listener the MCP server binds to `127.0.0.1` |

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | Add new task (Main Window focused) |
| `⌘R` | Open Report window |
| `⌘T` | Open Heatmap window |
| `⌘,` | Open Settings |
| `⌘Q` | Quit (with timer save confirmation if running) |

---

## Future Plans

- **Multiple Projects** — Group tasks under named projects
- **Cloud Sync** — iCloud or custom backend (UUIDs and timestamps are already in place)
- **Archive** — Archive tasks without deleting them (flag already in the data model)
- **Multi-tag Filtering** — Filter by multiple tags with AND/OR logic
- **CSV Export** — Export report data for spreadsheets
- **Pomodoro Mode** — Optional Pomodoro timer alongside the regular timer
