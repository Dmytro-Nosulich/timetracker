# TimeTracker

> A native macOS time tracking app for freelancers — track time, manage tasks, and generate professional PDF reports.

![macOS](https://img.shields.io/badge/macOS-15%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)
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

### Reports & PDF Export
- Choose a period: This Week, Last Week, This Month, Last Month, This Year, All Time, or a custom date range
- Select which tasks to include via checkboxes
- Time rounding options: None, 5 min, 15 min, or 30 min (display/export only — raw data is never modified)
- Amount column calculated automatically from hours × hourly rate
- Export a professional PDF with your business name, period, task breakdown, rates, and totals
- Currency support: USD, EUR, GBP, CAD, AUD, JPY, CHF, or a custom symbol

### Settings
- Business name (pre-fills the Report window and PDF header)
- Default hourly rate and currency
- Idle timeout and "subtract idle time" toggle
- Launch at Login (using `SMAppService`)
- Daily tracking reminder: sends a local notification at a configured time on selected weekdays if no timer has been started
- Full tag management: create, rename, recolor, and delete tags

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Observable State | `@Observable` (Observation framework) |
| PDF Generation | Core Graphics |
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

No external dependencies — no Swift Package Manager packages, no CocoaPods.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | Add new task (Main Window focused) |
| `⌘R` | Open Report window |
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
