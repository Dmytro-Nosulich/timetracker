# Time Tracker for macOS — Complete Development Specification

## Project Overview

A native macOS time tracking application for freelancers. The app allows users to create tasks, track time with a start/pause timer, view detailed time reports, and generate PDF reports for clients. The app runs as a hybrid menu bar + windowed application.

### Technical Stack
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Data Persistence:** SwiftData
- **Target:** macOS 15+ (Sequoia)
- **App Lifecycle:** SwiftUI App lifecycle
- **Architecture:** MVVM with observable services
- **Unit Tests:** as testing framework use new Testing framework

### Architecture Considerations
- Use MVVM architecture to separate Business logic from View. Also use Dependency injection into ViewModels to remove dependency on concrete service implementation. For MVVM pattern use 3 components:
    - ViewModel - incapsulates business logic, injected with services;
    - View - just SwiftUI view that has as @State property for viewModel (must be injected during View initialization);
    - ModuleBuilder - struct that has one method to build module: creates ViewModel with injected services; create View and sets for it ViewModel and returns created View.
If new MVVM module is needed to create (if some View has business logic then it must be MVVM module) place it in a separate folder inside "Presentation" folder.
- Design all data models and services with future **cloud sync** capability in mind. Use UUIDs for all identifiers, timestamps for conflict resolution, and avoid local-only assumptions.
- Design the data model to support **multiple projects** in the future. Currently the app is "single project" — all tasks belong to one implicit workspace. The data model should make it easy to add a `Project` entity later that groups tasks.
- Use `@Observable` classes for services (TimerService, IdleMonitorService) as singletons injected via SwiftUI environment.
- Store user preferences in `@AppStorage` / `UserDefaults`.
- For work with SwiftData, UserDefaults or any other service Create a protocol that will be used for Dependency Injection and default implementation - the actual implementation of a service.
- For local storage models and network models in the future use proper data layer separation. For example, SwiftData models should not be used in ViewModels or anywhere else but mapped into domain models.
- When creating a new service place it in "Services" folder. Also consider that a mock version must be created for Unit Tests.
- When create a View without business logic and it may be reused across other Views or Modules - place it in root "Views" folder. Otherwise place it in "Views" folder for a specific Module.
- When create a domain model that is reused across other components - place it in Domain/Models folder. Otherwise place it in "Models" folder for a specific Module.

### Unit tests
- Create Unit Tests for services, ViewModels and other components that are possible to test.
- For files with tests use the same structure (folder/file) as tested files.

---

## Data Models (SwiftData)

### TaskEntity - SwiftData model that is mapped into domain model `TaskItem`
```
- id: UUID (primary key)
- title: String (required, non-empty)
- taskDescription: String (default: "")
- createdAt: Date
- isArchived: Bool (default: false) — not used in V1 UI, reserved for future
- hourlyRate: Decimal? (optional, overrides default rate from Settings)
- tags: [Tag] (many-to-many relationship)
- timeEntries: [TaskEntityEntity] (one-to-many relationship, cascade delete)
```

**Computed properties on TaskEntity:**
- `totalTrackedTime: TimeInterval` — sum of all time entries' durations
- `trackedTimeToday: TimeInterval` — sum of today's entries
- `trackedTime(from: Date, to: Date) -> TimeInterval` — sum for any date range
- `activeTaskEntityEntity: TaskEntityEntity?` — entry where endDate == nil

### TaskEntityEntity - SwiftData model that is mapped into domain model `TimeEntryItem`
```
- id: UUID (primary key)
- task: TaskEntity (relationship, required)
- startDate: Date
- endDate: Date? (nil means currently tracking)
- isManual: Bool (default: false)
- note: String? (optional, for manual entries)
```

**Computed property:**
- `duration: TimeInterval` — if endDate != nil: endDate - startDate; if nil: now - startDate

### TagEntity - SwiftData model that is mapped into domain model `TagItem`
```
- id: UUID (primary key)
- name: String (required, unique, case-insensitive)
- colorHex: String (hex color string, e.g., "FF5733")
- createdAt: Date
- tasks: [TaskEntity] (many-to-many relationship)
```

### Important Notes on SwiftData Usage
- The main app uses a single shared `ModelContainer` and `ModelContext`.
- **Exception:** The Task Detail Window uses a **child/separate ModelContext** for draft editing. Changes are only merged to the main context when the user presses "Save." See Phase 4 for details.
- When deleting a TaskEntity, cascade delete all related TaskEntityEntity records.

---

## Phase 1 — Project Foundation

### Setup Instructions
1. Configure SwiftData ModelContainer with TaskEntity, TaskEntityEntity, and TagEntity models
2. Set up the app to use `NSStatusItem` for menu bar presence (Phase 5 will implement full menu bar UI, but the app architecture should support it from the start)
3. Override default quit behavior: closing all windows should NOT quit the app. The app quits only via menu bar "Quit" or Cmd+Q.

### App Entry Point Architecture
```
@main TimeTrackerApp
  - Creates ModelContainer (TaskEntity, TaskEntityEntity, Tag)
  - Creates TimerService (singleton, @Observable)
  - Creates IdleMonitorService (singleton)
  - Injects services into environment
  - Opens MainWindow on launch
  - Sets up NSStatusItem (menu bar icon)
```

---

## Phase 2 — Main Window (Task List)

### Window Properties
- Title: "Time Tracker"
- Resizable: YES
- Minimum size: 500×400

### Layout
```
┌─────────────────────────────────────────────────────┐
│  Time Tracker                          [+ Add] [📊] │
│─────────────────────────────────────────────────────│
│  Filter: [All Tags ▼]                               │
│─────────────────────────────────────────────────────│
│  Task Title          │ Total Time  │   Action       │
│─────────────────────────────────────────────────────│
│  ● Website Redesign  │ 12h 30m     │   [▶ Start]   │
│  ● API Integration   │  3h 45m     │   [⏸ Pause]   │
│    Bug Fixes         │  0h 00m     │   [▶ Start]   │
│─────────────────────────────────────────────────────│
│                              Total today: 4h 20m    │
└─────────────────────────────────────────────────────┘

● = colored dot representing the tag color (if task has tags)
```

### Components

**Toolbar:**
- **"+ Add" button:** Opens a sheet/popover with:
  - Task title text field (required)
  - Task description text field (optional)
  - Tag picker (optional, multi-select from existing tags)
  - [Cancel] [Create] buttons
- **"📊 Report" button:** Opens the Report window (Phase 7). Only one Report window at a time — if already open, bring to front.

**Tag Filter:**
- Dropdown above the table: "All Tags" (default), then lists all existing tags
- Selecting a tag filters the table to show only tasks with that tag
- Single-tag filter only (select one tag at a time, or "All")

**Task Table:**
- Columns: Tag color dot(s), Task Title, Total Time (all time), Action button
- Sorted by `createdAt` descending (newest first)
- Time format: `Xh Ym` (e.g., "12h 30m", "0h 00m")

**Action Button per row:**
- If no timer is running for any task: show "▶ Start"
- If timer is running for THIS task: show "⏸ Pause"
- If timer is running for a DIFFERENT task: show "▶ Start" — clicking it will silently switch (pause current task, start this one, no confirmation dialog)

**Row Interactions:**
- **Double-click:** Opens Task Detail window (Phase 4). Only one Task Detail window at a time — if already open for a different task, close the old one (with unsaved changes warning if applicable) and open the new one.
- **Right-click context menu:** "Delete Task" option

**Delete Task Flow:**
- Show confirmation dialog:
  - Title: "Delete Task"
  - Message: "Are you sure you want to delete '[task title]'? This task has X hours of tracked time. This action cannot be undone."
  - Buttons: [Delete] (destructive) and [Cancel]
- If timer is currently running for this task, stop it first (save the time entry) before deleting.
- On delete: remove the TaskEntity and all its TaskEntityEntity records (cascade).

**Bottom Bar:**
- Shows: "Total today: Xh Ym" — sum of all TaskEntityEntity durations for today (all tasks)

---

## Phase 3 — Timer System & Timer Window

### TimerService (Singleton, @Observable)

**Properties:**
```
- currentTaskId: UUID? — which task is being tracked (nil = no active timer)
- sessionStartDate: Date? — when the current session started
- sessionElapsed: TimeInterval — current session duration (ticks every second)
- state: TimerState — enum: .idle, .running, .pausedByUser, .pausedByInactivity
```

**TimerState enum:**
```swift
enum TimerState {
    case idle                  // no timer active
    case running               // actively tracking
    case pausedByUser          // user pressed pause
    case pausedByInactivity    // auto-paused by idle detection
}
```

**Methods:**

`startTimer(for task: TaskItem):`
1. If currently tracking a different task → save current TaskEntityEntity (set endDate = now), DO NOT reset sessionElapsed (session continues for the new task)
2. If currently tracking the same task and state is running → do nothing
3. If state is .pausedByUser or .pausedByInactivity for any task → create new TaskEntityEntity, reset sessionElapsed = 0
4. If state is .idle → create new TaskEntityEntity with startDate = now, set sessionElapsed = 0
5. Set currentTaskId = task.id, state = .running, sessionStartDate = now

`pauseTimer():`
1. Save current TaskEntityEntity (set endDate = now)
2. Set sessionElapsed = 0 (session counter resets)
3. Set state = .pausedByUser
4. currentTaskId remains set (so we know what was being tracked)

`resumeTimer():`
1. Create new TaskEntityEntity for currentTaskId with startDate = now
2. Set sessionElapsed = 0 (new session starts)
3. Set state = .running

`pauseDueToInactivity(idleDuration: TimeInterval):`
1. Check Settings: if "Subtract idle time" is enabled → set endDate = now - idleDuration; else → set endDate = now
2. Set state = .pausedByInactivity
3. Record the pause timestamp for display ("paused X minutes ago")
4. Send macOS alert notification: "Timer paused — no activity detected"

**Internal timer:**
- A Timer that fires every 1 second while state == .running
- Updates sessionElapsed = Date().timeIntervalSince(sessionStartDate)
- The UI displays this formatted as `HHh MMm` (updates visually every minute, but the underlying value updates every second for accuracy)

**Midnight rollover handling:**
- The internal timer checks if the date has changed since sessionStartDate
- If midnight is crossed: close current TaskEntityEntity with endDate = 23:59:59 of the previous day, create a new TaskEntityEntity with startDate = 00:00:00 of the new day
- This ensures daily time calculations are always accurate

**App quit handling:**
- When app is about to quit (via Cmd+Q or menu bar Quit):
  - If state == .running: save current TaskEntityEntity (endDate = now) before quitting
  - If timer is running, show confirmation: "Timer is running for '[task]'. Quit anyway?" → [Save & Quit] [Cancel]

**App crash recovery:**
- On app launch: check for any TaskEntityEntity with endDate == nil
- If found and startDate is from a previous calendar day or more than 12 hours ago:
  - Show dialog: "It looks like the app closed unexpectedly. You have an open time entry for '[task]' started at [time]. What would you like to do?"
  - Options: [Save & Close Entry (set endDate = startDate + reasonable duration)] [Discard Entry] [Resume Tracking]
- If found and startDate is recent (within reason): resume tracking normally

### Timer Window

**Window Properties:**
- Title: "Timer"
- Resizable: NO (fixed compact size)
- Size: approximately 300×280

**When to open:**
- When user clicks "Start" on any task in the Main Window
- If Timer Window is already open, just update it (don't open a second one)
- Timer Window can be closed without stopping the timer (timer continues in background, menu bar still shows status)

**Layout:**
```
┌──────────────────────────────────────┐
│                                      │
│           01h 23m                    │  ← large font, prominent
│                                      │
│          [ ⏸ Pause ]                │
│                                      │
│  Task: [Website Redesign       ▼]   │  ← dropdown to switch tasks
│                                      │
│     Today this task: 3h 45m          │
│     Today all tasks: 6h 10m          │
│                                      │
│  ⚠ Paused: inactivity (12m ago)     │  ← only when state == .pausedByInactivity
└──────────────────────────────────────┘
```

**Components:**

**Session Counter (top, large font):**
- Shows current session elapsed time as `HHh MMm`
- Updates every minute visually
- When state == .pausedByUser: shows "00h 00m"
- When state == .pausedByInactivity: shows the session time at the moment of auto-pause (frozen)

**Pause/Start Button:**
- When running: shows "⏸ Pause"
- When paused (by user or inactivity): shows "▶ Resume"

**Task Dropdown:**
- Shows all tasks, current one selected
- Changing task: silently switches tracking (saves TaskEntityEntity for previous task, starts new one for selected task)
- When switching task via dropdown: DO NOT reset session counter. Only save time for old task, start tracking new task, session continues.

**Today Statistics:**
- "Today this task: Xh Ym" — total TaskEntityEntity durations today for the currently selected task
- "Today all tasks: Xh Ym" — total TaskEntityEntity durations today for all tasks

**Inactivity Banner:**
- Only visible when state == .pausedByInactivity
- Shows yellow/orange warning banner: "⚠ Paused: inactivity (Xm ago)"
- Disappears when user resumes

---

## Phase 4 — Task Detail Window

### Window Properties
- Title: "Task Details — [task title]"
- Resizable: YES
- Minimum size: 500×600
- Only one Task Detail window at a time

### Draft Editing Pattern
This window uses a **separate/child ModelContext** for editing. This is critical:
1. On open: create a child ModelContext from the main container
2. Fetch the task in the child context
3. All edits happen in the child context (not reflected in the main UI)
4. On "Save": merge child context changes to the main context, close window
5. On "Cancel" or window close with unsaved changes: show confirmation dialog "You have unsaved changes. Discard?" → [Discard] [Keep Editing]

### Layout
```
┌──────────────────────────────────────────────────┐
│  Task Details                       [Cancel][Save]│
│──────────────────────────────────────────────────│
│                                                   │
│  Title: [Website Redesign          ] (editable)   │
│                                                   │
│  Description:                                     │
│  ┌──────────────────────────────────────────┐     │
│  │ Redesign the client's website using      │     │
│  │ the new brand guidelines...              │     │
│  └──────────────────────────────────────────┘     │
│                                                   │
│  Tags: [tag1] [tag2] [+ Add Tag]                  │
│                                                   │
│  Hourly Rate: [$] [50.00] (optional)              │
│                                                   │
│  Total tracked: 45h 30m                           │
│                                                   │
│  ── Time Calendar ──────────────────────────      │
│                                                   │
│       ◀  February 2026  ▶                         │
│  Mo Tu We Th Fr Sa Su                             │
│                     1                              │
│   2  3  4  5  6  7  8                              │
│   9 10 11 12 13 14 15                              │
│  16 17 18 19 20 21 22                              │
│  23 24 25 26 27 28                                 │
│                                                   │
│  ── Selected Day: Feb 17, 2026 ─────────────      │
│                                                   │
│  Time entries:                                    │
│  09:00 - 11:30  (2h 30m)              [✏️] [🗑]  │
│  13:00 - 15:45  (2h 45m)              [✏️] [🗑]  │
│  Manual entry    1h 00m               [✏️] [🗑]  │
│                          Day total: 6h 15m        │
│                                                   │
│                      [+ Add Time Entry]           │
│                                                   │
└──────────────────────────────────────────────────┘
```

### Components

**Title Field:**
- Editable text field, required (cannot be empty)

**Description Field:**
- Multi-line text editor, optional

**Tags:**
- Shows current tags as colored chips
- "+" button to add existing tags (dropdown of all tags) or type a new one
- Click "x" on a chip to remove tag from this task

**Hourly Rate:**
- Optional decimal field
- Currency symbol from Settings displayed as prefix
- If empty, the default rate from Settings is used in reports (if set)

**Calendar Heatmap:**
- Monthly view with ◀ ▶ navigation arrows
- **Default month on open:** the month of the most recent TaskEntityEntity for this task. If no entries exist, show current month.
- Each day cell shows color intensity based on hours tracked:
  - 0h: no color / default background
  - 0.1h–2h: light color
  - 2h–5h: medium color
  - 5h+: dark color
- Clicking a day selects it and shows that day's time entries below

**Time Entries List (for selected day):**
- Shows all TaskEntityEntity records for the selected day for this task
- Each entry shows:
  - For tracked entries (isManual == false): "HH:MM - HH:MM (Xh Ym)" — start and end times with duration
  - For manual entries (isManual == true): "Manual entry  Xh Ym" with optional note
- Edit button (✏️): Opens a sheet to modify:
  - For tracked entries: start time picker and end time picker for the selected day
  - For manual entries: hours and minutes fields, note field
- Delete button (🗑): Confirmation → deletes the entry
- **"+ Add Time Entry" button:** Opens a sheet for the currently selected calendar day with:
  - Option 1: "Add tracked time" — start time picker and end time picker
  - Option 2: "Add duration" — hours and minutes fields, optional note
  - Creates a TaskEntityEntity with isManual flag set appropriately
  - **Validation:** When adding/editing, check for overlapping time ranges with existing entries for the same task on the same day. Show warning if overlap detected (but allow user to proceed).

**Save / Cancel buttons (top right):**
- Save: commit all changes to the main context, close window
- Cancel: discard changes, close window

---

## Phase 5 — Menu Bar Integration

### Architecture
- The app is a hybrid: it has a Dock icon AND a menu bar icon
- Use `NSStatusItem` with `NSStatusBar.system`
- The menu bar icon is always present while the app is running
- Closing all windows does NOT quit the app (app stays in menu bar)
- The app quits only via "Quit" in the menu bar dropdown or Cmd+Q

### Menu Bar Icon
- Use a small clock/timer SF Symbol
- **Visual states:**
  - Timer running: icon has a green accent/dot indicator
  - Timer paused by inactivity: icon has a yellow/orange indicator
  - Timer paused by user: icon has a paused indicator (different from running)
  - No timer: default icon, no indicator

### Menu Bar Dropdown

**State: Timer Running**
```
┌─────────────────────────────────┐
│  ● Website Redesign             │  ← green dot + task name
│  Session: 01h 23m               │
│  Today: 6h 10m                  │
│                                 │
│  [ ⏸ Pause ]                   │
│─────────────────────────────────│
│  Open Main Window               │
│  Open Timer Window              │
│─────────────────────────────────│
│  Quit Time Tracker              │
└─────────────────────────────────┘
```

**State: Timer Paused by User**
```
┌─────────────────────────────────┐
│  ⏸ Website Redesign (paused)   │
│  Today: 6h 10m                  │
│                                 │
│  [ ▶ Resume ]                   │
│─────────────────────────────────│
│  Open Main Window               │
│  Open Timer Window              │
│─────────────────────────────────│
│  Quit Time Tracker              │
└─────────────────────────────────┘
```

**State: Timer Paused by Inactivity**
```
┌─────────────────────────────────┐
│  ⚠ Website Redesign (paused)   │
│  Inactive for 12m               │
│  Today: 6h 10m                  │
│                                 │
│  [ ▶ Resume ]                   │
│─────────────────────────────────│
│  Open Main Window               │
│  Open Timer Window              │
│─────────────────────────────────│
│  Quit Time Tracker              │
└─────────────────────────────────┘
```

**State: No Active Timer**
```
┌─────────────────────────────────┐
│  No active timer                │
│  Today: 6h 10m                  │
│─────────────────────────────────│
│  Open Main Window               │
│─────────────────────────────────│
│  Quit Time Tracker              │
└─────────────────────────────────┘
```

### Behavior
- Clicking Pause/Resume directly controls the timer — no window needs to open
- "Open Main Window": brings Main Window to front, or creates it if it was closed
- "Open Timer Window": only shown when a timer is active or paused; brings Timer Window to front or creates it
- "Quit Time Tracker": if timer is running, show confirmation dialog: "Timer is running for '[task]'. Quit anyway?" → [Save & Quit] [Cancel]. Save & Quit saves the current TaskEntityEntity before quitting.
- Session time and Today time are static snapshots (do NOT update live while the dropdown is open — the dropdown is only open for a few seconds)

### App Lifecycle
- On launch: open Main Window + set up menu bar icon
- On window close: windows close, app stays alive in menu bar
- On Cmd+Q or "Quit": proper quit with timer save confirmation
- On re-activate (e.g., clicking Dock icon): bring Main Window to front

---

## Phase 6 — Idle Detection

### IdleMonitorService (Singleton)

**Technology:** `CGEventSource.secondsSinceLastEventType(.combinedSessionState, .mouseMoved)` and similar for keyboard. This approach requires NO special permissions (no Input Monitoring access needed).

**Properties:**
```
- isMonitoring: Bool
- idleThreshold: TimeInterval — from Settings (default: 600 seconds / 10 minutes)
- pollInterval: TimeInterval = 30 seconds
```

**Behavior:**
- Only active when TimerService.state == .running
- Polls every 30 seconds using a Timer
- Each poll: check `CGEventSource.secondsSinceLastEventType` for the combined session state
- If idle time >= idleThreshold:
  1. Call TimerService.pauseDueToInactivity(idleDuration: secondsSinceLastEvent)
  2. Send macOS **alert** notification (stays until dismissed): "Timer paused — no activity detected"
  3. Stop polling (will restart when timer resumes)

**When user returns (state == .pausedByInactivity):**
- Continue polling; when secondsSinceLastEvent becomes small (< pollInterval), user is back
- Show a dialog window (brought to front):
  ```
  ┌──────────────────────────────────────────┐
  │  Welcome back!                           │
  │                                          │
  │  Your timer was paused X minutes ago     │
  │  due to inactivity.                      │
  │                                          │
  │  Task: Website Redesign                  │
  │                                          │
  │  [ Resume Timer ]  [ Keep Paused ]       │
  └──────────────────────────────────────────┘
  ```
- **Resume Timer:** calls TimerService.resumeTimer()
- **Keep Paused:** sets TimerService.state = .pausedByUser (user resumes manually later)

### Computer Sleep/Wake
- Register for `NSWorkspace.willSleepNotification`:
  - If timer is running → same as idle pause: save TaskEntityEntity with endDate handling based on Settings, set state = .pausedByInactivity
- Register for `NSWorkspace.didWakeNotification`:
  - If state == .pausedByInactivity → show the "Welcome back" dialog (same as idle return)

---

## Phase 7 — Reports & PDF Export

### Report Window

**Window Properties:**
- Title: "Report"
- Resizable: YES
- Minimum size: 600×500
- Only one Report window at a time

**Layout:**
```
┌──────────────────────────────────────────────────────────┐
│  Report                                                   │
│──────────────────────────────────────────────────────────│
│                                                           │
│  Report Name/Business: [John Doe Freelancing       ]      │
│                                                           │
│  Period: [ This Month          ▼ ]                        │
│  Custom: [Feb 1, 2026] — [Feb 28, 2026]                  │
│                                                           │
│  ☐ Include tasks with zero time                           │
│                                                           │
│  ☑ Select All                                             │
│──────────────────────────────────────────────────────────│
│  ☑  │ Task Title              │ Time       │ Amount       │
│──────────────────────────────────────────────────────────│
│  ☑  │ Website Redesign        │ 24h 30m    │ $1,225.00    │
│  ☑  │ API Integration         │ 12h 15m    │ $612.50      │
│  ☐  │ Bug Fixes               │  3h 00m    │ —            │
│  ☑  │ Client Meetings         │  5h 45m    │ —            │
│──────────────────────────────────────────────────────────│
│                                                           │
│         Total selected: 42h 30m        Total: $1,837.50   │
│                                                           │
│                              [ Export PDF ]                │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

### Components

**Report Name/Business field:**
- Text field, pre-filled with the value from Settings ("Business Name")
- User can edit this for the current report — changes here do NOT save back to Settings
- This value is used in the PDF header

**Period Picker:**
- Dropdown with predefined options:
  - This Week (Monday–Sunday of current week)
  - Last Week
  - This Month
  - Last Month
  - This Year
  - All Time
  - Custom Range
- Default: "This Month"
- Two date pickers below for start and end date
- Selecting a predefined period auto-fills the date pickers
- User can always manually adjust dates regardless of dropdown selection

**"Include tasks with zero time" checkbox:**
- Default: unchecked (OFF)
- When OFF: tasks with 0h for the selected period are hidden from the table and excluded from PDF
- When ON: all tasks are shown in the table and included in PDF

**Task Table:**
- Columns: Checkbox, Task Title, Time for Period, Amount (only if at least one task has an hourly rate)
- Checkbox per task for selection
- "Select All" toggle at top
- Time column: calculated as sum of TaskEntityEntity durations within the selected period for each task
- Amount column: time (in hours) × hourly rate. If task has no rate and no default rate in Settings, show "—"
- Tasks sorted by time for period descending (most worked on first)
- **Time rounding:** Apply the rounding setting from Settings to displayed times and amount calculations. Raw data is never modified — rounding is display/export only.

**Total selected (bottom):**
- "Total selected: Xh Ym" — sum of time for checked tasks only
- "Total: $X,XXX.XX" — sum of amounts for checked tasks that have rates

**Export PDF button:**
- Opens NSSavePanel (system save dialog) to choose location
- Default filename: "Time Report - [period description].pdf" (e.g., "Time Report - February 2026.pdf")
- Generates PDF and saves to chosen location

### PDF Layout

```
┌───────────────────────────────────────────────┐
│                                               │
│  [Report Name / Business Name]                │
│                                               │
│  TIME REPORT                                  │
│  Period: February 1, 2026 –                   │
│          February 28, 2026                    │
│                                               │
│  Generated: February 17, 2026                 │
│                                               │
│─────────────────────────────────────────────  │
│                                               │
│  Task              │ Time    │ Rate  │ Amount │
│─────────────────────────────────────────────  │
│  Website Redesign  │ 24h 30m │ $50/h │$1,225  │
│  API Integration   │ 12h 15m │ $50/h │  $613  │
│  Client Meetings   │  5h 45m │  —    │   —    │
│─────────────────────────────────────────────  │
│  TOTAL             │ 42h 30m │       │$1,838  │
│                                               │
└───────────────────────────────────────────────┘
```

**PDF Generation Notes:**
- Clean, professional, minimal design
- Only include checked tasks. Respect the "Include tasks with zero time" checkbox setting.
- Rate/Amount columns only appear if at least one selected task has an hourly rate
- Currency symbol from Settings
- Time rounding from Settings applied
- Use native macOS PDF rendering (e.g., render a SwiftUI view to PDF using ImageRenderer, or use Core Graphics PDF context)

---

## Phase 8 — Settings, Tags Management & Polish

### Settings Window

Accessible via: macOS menu bar → App menu → "Settings..." (Cmd+,)

**Layout:**
```
┌──────────────────────────────────────────────────┐
│  Settings                                         │
│──────────────────────────────────────────────────│
│                                                   │
│  ── General ────────────────────────────────      │
│                                                   │
│  Business Name: [John Doe Freelancing      ]      │
│                                                   │
│  Default Hourly Rate: [50.00]                     │
│                                                   │
│  Currency: [USD ($)              ▼]               │
│                                                   │
│  Time Rounding (Reports): [None        ▼]        │
│    Options: None, 5 min, 15 min, 30 min           │
│                                                   │
│  ☑ Launch at Login                                │
│                                                   │
│  ── Idle Detection ─────────────────────────      │
│                                                   │
│  Idle timeout: [ 10 ] minutes                     │
│                                                   │
│  ☑ Subtract idle time from tracked time           │
│    When enabled, tracked time ends at the         │
│    moment of last detected activity instead       │
│    of when the pause occurs.                      │
│                                                   │
│  ── Notifications ──────────────────────────      │
│                                                   │
│  ☑ Tracking reminder                              │
│    Time: [09:00 AM]  Days: [Mon-Fri]              │
│    Sends a reminder if no timer has been           │
│    started by this time.                           │
│                                                   │
│  ── Tags ───────────────────────────────────      │
│                                                   │
│  [● Red]    Client Work            [✏️] [🗑]     │
│  [● Blue]   Internal               [✏️] [🗑]     │
│  [● Green]  Admin                  [✏️] [🗑]     │
│                                                   │
│  [+ Add Tag]                                      │
│                                                   │
└──────────────────────────────────────────────────┘
```

### Settings Details

**All settings auto-save** (no Save button). Use `@AppStorage` / `UserDefaults`.

**Currency Picker:**
- Common currencies: USD ($), EUR (€), GBP (£), CAD (C$), AUD (A$), JPY (¥), CHF (CHF)
- "Custom" option where user types a symbol (e.g., "₴" for Ukrainian hryvnia)
- Store both the currency code and symbol

**Time Rounding:**
- Options: None (exact time), 5 minutes, 15 minutes, 30 minutes
- Applied only in Report window display and PDF export
- Raw TaskEntityEntity data is never modified
- Rounding method: round to nearest (2m → 0m for 5min rounding; 3m → 5m for 5min rounding)

**Launch at Login:**
- Use `SMAppService.mainApp` (modern macOS API for login items)
- Toggle adds/removes the app from login items

**Tracking Reminder:**
- When enabled: schedule a local notification (UNUserNotificationCenter) for the configured time on configured days
- Each day at the set time, check if any TaskEntityEntity exists for today. If not, send notification: "Don't forget to start tracking your time!"
- If a timer is already running, don't send the notification

**Tags Management:**
- Shows all existing tags with their color dot and name
- Edit (✏️): inline edit the tag name and color picker
- Delete (🗑): confirmation dialog "Delete tag '[name]'? This will remove the tag from all tasks." → [Delete] [Cancel]. Deleting a tag removes it from all tasks but does NOT delete tasks.
- "+ Add Tag": inline row to type name and pick color
- Color picker: a small palette of 8-10 predefined colors to choose from (red, blue, green, yellow, orange, purple, pink, gray, teal)
- Tag names are case-insensitive unique (cannot have "Work" and "work")

### Keyboard Shortcuts
- `Cmd + N` — Add new task (from Main Window, if Main Window is focused)
- `Cmd + ,` — Open Settings
- `Cmd + R` — Open Report window
- `Cmd + Q` — Quit (with save confirmation if timer running)

### Edge Cases & Polish

**Midnight Rollover:**
- Handled in TimerService (see Phase 3)

**Computer Sleep/Wake:**
- Handled in IdleMonitorService (see Phase 6)

**App Crash Recovery:**
- Handled in TimerService on app launch (see Phase 3)

**Duplicate Windows:**
- Only one Task Detail window at a time
- Only one Report window at a time
- Only one Timer window at a time
- If user tries to open a second, bring existing one to front

**Dark Mode:**
- Use system SwiftUI colors throughout — dark mode support is automatic
- Calendar heatmap colors should work in both light and dark mode (use semantic colors or adjust based on colorScheme)

**App Icon:**
- Use a placeholder SF Symbol-based icon for V1 (e.g., clock with play button)
- Can be replaced with a custom icon later

**Time Display Format:**
- Throughout the app, use consistent format: `Xh Ym` (e.g., "12h 30m", "0h 00m", "145h 15m")
- For the Timer Window session counter: same format but larger font

---

## Development Order

Build in this order. Each phase builds on the previous one:

| Phase | Feature | Dependencies | Priority |
|-------|---------|-------------|----------|
| 1 | Foundation & Data Models | None | Must have |
| 2 | Main Window (Task List) | Phase 1 | Must have |
| 3 | Timer System & Timer Window | Phase 1, 2 | Must have |
| 4 | Task Detail Window | Phase 1, 2 | Must have |
| 5 | Menu Bar Integration | Phase 3 | Must have |
| 6 | Idle Detection | Phase 3, 5 | Must have |
| 7 | Reports & PDF Export | Phase 1, 2 | Must have |
| 8 | Settings, Tags & Polish | All phases | Must have |

### Recommended approach for Claude Code:
- Build phase by phase, testing each phase before moving to the next
- Phase 1 & 2 should be built together (foundation + first visible UI)
- Phase 3 is critical and should be thoroughly tested (timer accuracy, midnight rollover, state transitions)
- Phase 5 & 6 are tightly coupled — build together
- Phase 8 integrates with all other phases — build last

---

## Future Considerations (NOT for V1, but keep in mind)

- **Multiple Projects:** A `Project` entity that groups tasks. Each task belongs to one project.
- **Cloud Sync:** Sync data across devices. UUIDs and timestamps are already in place for this.
- **Archive functionality:** UI to archive/unarchive tasks (data model already has `isArchived` flag).
- **Multi-tag filtering:** Filter by multiple tags with AND/OR logic.
- **Full-text search:** Search across task titles, descriptions, and tags.
- **Tag-based grouping in reports:** Group tasks by tag in the PDF report.
- **CSV export:** Export report data as CSV for spreadsheets.
- **Pomodoro mode:** Optional Pomodoro timer alongside the regular timer.
