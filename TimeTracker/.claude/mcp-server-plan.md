# TimeTracker Local MCP Server — Implementation Spec

Status: design in progress, no implementation started yet.

## Goal
Expose an MCP server embedded inside the running TimeTracker app so an AI tool
(Claude Desktop/Code) can query local time-tracking data — time on a task, time in a
date range, report/invoice-style breakdowns, PDF report export — without any
backend. Modeled on Figma's local MCP server (app hosts the server; client connects to
a fixed localhost URL while the app is open).

## Codebase facts gathered so far
- Swift/SwiftUI + AppKit menu-bar shell, single app target (`TimeTracker`), no SPM
  dependencies yet (`TimeTracker.xcodeproj/project.pbxproj`).
- Persistence is SwiftData (not Core Data), container built in
  `TimeTracker/TimeTrackerApp.swift:17-28`. `@Model` entities in
  `TimeTracker/Services/LocalStorage/Models/`: `TaskEntity.swift`,
  `TimeEntryEntity.swift`, `TagEntity.swift`. Domain structs in
  `TimeTracker/Domain/Models/`.
- No "Invoice" entity exists — invoicing is a report/PDF export flow, not stored data.
- App already runs as a persistent background/menu-bar process
  (`AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns `false`,
  `TimeTracker/App/AppDelegate.swift`) — favorable for hosting a long-lived server.
- No existing networking/IPC/server code anywhere in the codebase (confirmed via
  exhaustive grep — no URLSession server usage, Network.framework listener, XPC,
  sockets, Vapor, Bonjour).
- Existing query/aggregation layer to build tools on top of:
  `LocalStorageService` protocol + `SwiftDataLocalStorageService` impl in
  `TimeTracker/Services/LocalStorage/`, with `totalTrackedTimeToday()`,
  `totalTrackedTimeThisWeek()`, `trackedTimeToday(for taskId:)`, `fetchTasks()`,
  `fetchTask(id:)`. Date-range aggregation for reports currently lives ad hoc in
  `TimeTracker/Presentation/Report/ReportViewModel.swift`
  (`trackedTime(for:from:to:)`, ~lines 229-241) and
  `TimeTracker/Utilities/DailyTimeAggregator.swift` — not yet a generalized reusable
  method, but straightforward to extract.
- PDF report generation already exists and is largely reusable:
  - `ReportPDFService` protocol / `CoreGraphicsReportPDFService` impl
    (`TimeTracker/Services/Report/ReportPDFService.swift`,
    `.../CoreGraphicsReportPDFService.swift`) — `generatePDF(config: ReportPDFConfig) -> Data`
    is a pure function, no UI dependency, directly callable from an MCP tool handler.
  - `ReportPeriod` enum (`TimeTracker/Presentation/Report/Models/ReportPeriod.swift`)
    already has `.thisWeek/.lastWeek/.thisMonth/.lastMonth/.thisYear/.allTime/.customRange`
    each with a pure `dateRange(calendar:now:)` calculator, plus a
    `defaultFilename(startDate:endDate:)` helper — maps directly onto a "which period"
    tool argument.
  - The day-grouping/rounding/rate-calculation logic that turns tasks + a date range
    into `ReportPDFConfig` rows currently lives inline inside
    `ReportViewModel.exportPDF()` (`ReportViewModel.swift:113-188`), tangled together
    with an `NSSavePanel` call for picking the save destination. This needs to be
    extracted into a small UI-independent service (shared by both the existing
    "Export PDF" button and the new MCP tool) before the PDF tool can be built —
    see open items below.

## Architecture decisions made so far
1. **Transport**: Embedded HTTP/SSE (Streamable HTTP) MCP server running inside the
   app process itself, not a spawned stdio subprocess. Rationale: the app is already
   always-running in the menu bar, so this matches Figma's model and reads through the
   app's own SwiftData stack — whereas a per-session subprocess opening the same store
   file directly would risk concurrent-access issues with the running app and would
   always see stale state.
2. **Binding/security**: Server must bind only to `127.0.0.1` (never `0.0.0.0`) — no
   remote access, local-machine only.
3. **Client connection model**: User registers the local server once with their MCP
   client, e.g. `claude mcp add --transport http timetracker http://127.0.0.1:PORT/mcp`.
   If the app isn't running, the connection simply fails (same as Figma).
4. **Port**: Configurable via an app Settings screen (not hardcoded), since the user
   chose configurability over a fixed port. Implies: need a small Settings UI addition
   to view/set the port, and likely a toggle to enable/disable the server entirely
   (not everyone will want it always listening). Exact UI/UX not yet designed.
5. **Tool scope for v1**: five capabilities, detailed in the "MCP tool catalog"
   section below. The server is **read-only** — the only thing it writes is the PDF
   file produced by tool #4; it never modifies tracked time data. See "Considered and
   deliberately left out of v1".
6. **App Sandbox: to be disabled.** The app currently has `ENABLE_APP_SANDBOX = YES`
   in `TimeTracker.xcodeproj/project.pbxproj` (both Debug and Release configs, no
   custom entitlements file present) with no other file-access entitlements. Today
   `ReportViewModel.exportPDF()` can only write to disk because `NSSavePanel` itself
   grants temporary write access to whatever the user picks — a sandboxed app cannot
   write to an arbitrary path with no dialog involved, which an MCP tool call would
   need. Since this app is for personal/local use only (not Mac App Store
   distribution), the user decided to **disable App Sandbox entirely** rather than
   build a "pick a reports folder once, use a security-scoped bookmark" workaround.
   This lets the PDF-export tool (and any other tool that writes files) accept an
   arbitrary destination path supplied by the calling skill/AI, matching the "save it
   somewhere" use case directly. Not yet implemented — see open items.

## MCP tool catalog

Five tools. All are **read-only** except #4, whose only write is the PDF file itself —
no tool ever modifies tracked time data. Exact tool names and JSON argument/return
schemas are still TBD; the behavior below is settled.

### 1. Time on a specific task
Search-first, because the caller only knows the task by rough name, not by `UUID`.
- **Input**: a free-text query, plus an optional date range (see the shared period
  argument in #2). With no range given, return all-time total.
- **Search behavior**: match the query case-insensitively against **both title and
  description**. Reuse the exact predicate already used by the Main Window search
  feature (`MainWindowViewModel.filteredTasks`, `MainWindowViewModel.swift:30-36`):
  `task.title.localizedCaseInsensitiveContains(query) || task.taskDescription.localizedCaseInsensitiveContains(query)`.
  Extracting that predicate into a shared helper (so UI and MCP can't drift apart)
  is preferred over copying it.
- **Response must handle all three match counts** — this is the important part:
  - **0 matches**: not an error; return an explicit "no tasks matched" result so the
    AI can tell the user plainly instead of inventing a number. Ideally include a few
    available task titles as a hint.
  - **exactly 1 match**: return that task with its total time for the range.
  - **2+ matches**: return **all** matches, each with its own total time for the
    range — do NOT silently pick the best match. The user explicitly wants "a total
    time for each task" here. Also include a combined total across matches so the AI
    can answer either way. The AI can then either report the list or ask the user
    which one they meant.
- Task identity (`id`) should be included in each match so a follow-up call can
  target one task unambiguously.

### 2. Time in a date range (all tasks)
Two response shapes, chosen by the caller, matching two different natural questions:
- **Total only** — for "what time have I tracked for some period?" Returns a single
  aggregate number for the range.
- **Per task** — for "what time have I tracked for some period per task?" Returns a
  list of tasks with time tracked in that range, each with its own total, **plus the
  overall total for the period** so the user never has to add the rows up themselves.
  Suggest sorting descending by time (matches how `ReportViewModel.recomputeRows()`
  already sorts) and excluding zero-time tasks by default.
- **Period argument (shared with #3 and #4)**: must accept both named periods and an
  explicit custom range. Reuse the existing `ReportPeriod` enum
  (`Presentation/Report/Models/ReportPeriod.swift`), which already covers
  `thisWeek/lastWeek/thisMonth/lastMonth/thisYear/allTime/customRange` with a pure
  `dateRange(calendar:now:)` calculator.
  - This must also serve **"what time have I reported today?"** and **"...this
    week?"**. `thisWeek` already exists; **`today` does not exist as a `ReportPeriod`
    case** and needs adding (or mapping to a custom single-day range). Note
    `LocalStorageService` already has `totalTrackedTimeToday()` /
    `totalTrackedTimeThisWeek()` for the total-only variants of exactly these two
    questions — cheapest path is to route those two cases to the existing methods.

### 3. Report / invoice-style breakdown
Same period argument as #2. Returns the report data grouped by task, with rounding and
hourly-rate/amount calculation applied — i.e. the numbers behind the PDF, but as
structured data rather than a file. Reuses the same extracted service as #4 (see
"Extract the day-grouping..." open item) plus `UserPreferencesService` for
`timeRounding`, `defaultHourlyRate`, `currencySymbol`, and `businessName`.

### 4. Generate PDF report and save to disk
The motivating use case: the user wants to later build a skill that generates a report
every month unattended, so **this tool must never require an interactive dialog**.
- **Input**: period (same argument as #2/#3), destination path, optional filename
  override, optional task filter.
- **Behavior**: compute the same config as #3, hand it to the existing
  `CoreGraphicsReportPDFService.generatePDF(config:)` (already a pure
  `ReportPDFConfig -> Data` function), and write the bytes to the given path — no
  `NSSavePanel`, unlike the current UI flow.
- Default filename comes from the existing
  `ReportPeriod.defaultFilename(startDate:endDate:)` helper.
- **Returns** the absolute path of the written file so the calling skill can confirm
  success / attach it elsewhere.
- Depends on App Sandbox being disabled (architecture decision #6) to write to an
  arbitrary path.

### 5. List tasks / list tags
A discovery tool, so the AI can orient itself before querying rather than guessing.
- Lists existing tasks (title, id, archived flag, and a time total) and existing tags.
- Reuses `LocalStorageService.fetchTasks()` and `fetchTags()` directly — no new logic.
- Its main practical job is **disambiguation support for #1**: when a search returns
  several matches or none, the AI can look at what actually exists and ask a sensible
  follow-up question instead of inventing task names.
- Should probably expose archived vs. active as a filter, since `TaskItem.isArchived`
  exists and stale tasks would otherwise clutter results.

## Considered and deliberately left out of v1
Recorded so future sessions don't re-litigate these:
- **Time by tag** ("how much time on tag X") — `TagItem` and Main Window tag filtering
  exist, so this is cheap to add later, but the user doesn't need it now.
- **Daily breakdown for a range** ("which days did I work", "daily average") —
  `DailyTimeAggregator` already exists and powers the Heatmap, so it stays cheap to
  add later. Not needed for v1.
- **Current running timer status** — dropped entirely at the user's direction: the
  menu-bar icon already shows it at a glance, so it earns nothing as a tool. Also
  considered and dropped was folding an `activeTimer` field into the #2/#3 responses
  (the argument for it was that a still-running timer means a range's totals are in
  flux, so an unattended monthly report could silently under-report). If it's ever
  wanted, the data is available via `TimerService.state` / `currentTaskId` and
  `LocalStorageService.fetchOpenTimeEntry()`. Revisit only if write tools are added.
- **All write tools** — manual time entry ("I forgot to track 2 hours yesterday"),
  timer start/stop, task/tag creation. **Decision: the MCP server is read-only.** The
  only thing it writes is the PDF file in #4, and it never modifies tracked data.
  Rationale: this data is billing-grade, and an AI misinterpretation silently editing
  time entries is a materially worse failure than a wrong read. If timer control is
  ever added, a timer-status tool becomes genuinely necessary again.

## Known open items (not yet decided — to fill in during future sessions)
- Exact MCP tool names, argument schemas, and return shapes for each of the 5 tools
  above.
- Extract the day-grouping/rounding/rate-calculation logic out of
  `ReportViewModel.exportPDF()` (`ReportViewModel.swift:113-188`) into a
  UI-independent service that returns a `ReportPDFConfig` (or the raw `Data`) given
  tasks + date range + prefs, so both the UI "Export PDF" button and the new MCP tool
  call the same code instead of duplicating it. Exact service name/shape TBD.
- Actually flip `ENABLE_APP_SANDBOX` to `NO` in `project.pbxproj` (both Debug/Release
  configs, currently ~lines 360-361 and 406-407) as part of implementing the PDF tool.
- Design the PDF tool's exact arguments once the above is done: period (reusing
  `ReportPeriod` cases) or explicit custom start/end, optional task filter (default:
  all tasks with time > 0 in range, matching current non-UI default), destination
  path (now that sandbox is going away, this can be any absolute path the caller
  provides), optional filename override (default via
  `ReportPeriod.defaultFilename(startDate:endDate:)`), and what the tool should
  return (e.g. the saved file path) to confirm success back to the caller.
- Add a `today` case to `ReportPeriod` (or decide to map "today" onto a custom
  single-day range) — needed for "what time have I reported today?" in tool #2.
- Extract the task-search predicate out of `MainWindowViewModel.filteredTasks`
  (`MainWindowViewModel.swift:30-36`) into a shared helper so the MCP search tool (#1)
  and the Main Window search can't drift apart.
- **Pre-existing inconsistency to resolve during extraction**: two different
  day-attribution rules exist in the codebase for entries that cross midnight.
  `DailyTimeAggregator.dailyTotals(...)` (used by the Heatmap) correctly splits such
  an entry across both days, while `ReportViewModel.exportPDF()` attributes the whole
  duration to `entry.startDate`'s day (`ReportViewModel.swift:142`). The extracted
  report service should pick one rule deliberately — otherwise the PDF and the
  Heatmap/MCP numbers can disagree for overnight work.
- Whether the server auto-starts on app launch (if enabled in settings) or only starts
  when the user explicitly turns it on each session.
- Error/edge-case behavior: ambiguous task name matches, no tasks found, invalid date
  ranges, task search returning multiple candidates.
- Which Swift MCP SDK to add via SPM (e.g. the official `modelcontextprotocol/swift-sdk`)
  and which HTTP server mechanism backs the Streamable HTTP transport inside the app.
- Thread-safety approach for querying SwiftData from the server's request-handling
  code without touching the UI's main `ModelContext` directly (e.g. a dedicated
  `@ModelActor`/background context) — SwiftData contexts are not thread-safe by
  default.
- Settings UI/UX for the port field and enable/disable toggle.

## Build order
The feature is broken into 7 sequential steps, with a ready-to-paste prompt for each,
in `.claude/mcp-server-build-steps.md` — one step per chat session, with a progress
checklist at the top of that file. This spec stays the source of truth; that file is
just the running order.

## How to use this file going forward
Each future implementation session should read this file first for context, then
append/update sections here (especially "decisions made" and "open items") as more
of the design is settled or built, rather than re-deriving this discussion from
scratch. Keep it concise and current — prune resolved "open items" into "decisions
made" as they're settled, and note here once actual implementation (code, not just
design) begins.
