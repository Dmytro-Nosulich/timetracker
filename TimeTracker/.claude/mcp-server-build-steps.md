# TimeTracker MCP Server — Step-by-Step Build Prompts

Companion to `mcp-server-plan.md` (the spec). This file holds ready-to-paste prompts,
one per chat session, so no single conversation has to carry the whole feature's
context.

## How to use this file
- **One step = one fresh chat.** Paste the step's prompt — everything between the
  ``` fences — verbatim. The blockquote above each prompt is a note for you, not part
  of the prompt.
- **Start the chat from the repo root** (`.../timetracker/TimeTracker/`), since the
  prompts use paths relative to it.
- Steps are ordered by dependency — don't skip ahead. Each assumes the previous ones
  are merged.
- Every prompt starts by telling the model to read `mcp-server-plan.md`, and ends by
  telling it to update that spec **and tick this file's checkbox** for that step. So
  the Progress section below maintains itself — but glance at it after each step and
  fix it by hand if the model forgot. It's a plain instruction in a prompt, not an
  enforced mechanism.
- The spec (`mcp-server-plan.md`) is the source of truth for what's being built; this
  file is just the running order.
- **Commit after each step.** Each one is a working, tested increment, so a bad step
  is cheap to roll back without losing the earlier ones.

## Progress
- [x] Step 1 — Foundation refactor (no MCP code yet)
- [x] Step 2 — MCP server skeleton + first tool end-to-end
- [x] Step 3 — Settings UI (port + enable toggle)
- [x] Step 4 — Tools: task search & date-range time
- [x] Step 5 — Tool: report / invoice breakdown
- [x] Step 6 — Tool: PDF export to disk (+ disable App Sandbox)
- [x] Step 7 — Docs, client registration, monthly-report skill

---

## Step 1 — Foundation refactor (no MCP code yet)

> Rationale for this step existing at all: every MCP tool needs report/search logic
> that currently only exists inside `@MainActor` view models. Doing this first means
> the MCP steps are pure additions rather than risky surgery, and this step is
> independently valuable even if the MCP server never ships.

```
Read .claude/mcp-server-plan.md for full context on the MCP server feature we're
building. This step writes NO MCP code — it's a pure refactor to prepare for it.

Do these four things:

1. Extract the day-grouping / rounding / hourly-rate logic out of
   ReportViewModel.exportPDF() (TimeTracker/Presentation/Report/ReportViewModel.swift,
   ~lines 113-188) into a new UI-independent service. It should take tasks + a date
   range + the relevant user preferences and return a ReportPDFConfig (and/or the
   report rows as structured data). It must NOT reference NSSavePanel, AppKit, or
   @MainActor. ReportViewModel.exportPDF() should then be reduced to: show the save
   panel, call the new service, write the returned data.

2. Extract the task-search predicate out of MainWindowViewModel.filteredTasks
   (MainWindowViewModel.swift:30-36) into a shared, testable helper so the UI search
   and the future MCP search tool can't drift apart. Keep behavior identical:
   case-insensitive match against BOTH title and taskDescription.

3. Add a `today` case to ReportPeriod
   (TimeTracker/Presentation/Report/Models/ReportPeriod.swift) with a correct
   dateRange() implementation, following the existing cases' conventions. Make sure
   it appears sensibly in the existing Report UI picker.

4. Resolve a pre-existing inconsistency: DailyTimeAggregator (used by the Heatmap)
   splits an entry that crosses midnight across both days, but exportPDF() attributes
   the whole duration to the entry's start day (ReportViewModel.swift:142). Pick ONE
   rule for the new service and apply it deliberately. Tell me which you chose and
   why before/while doing it, since it changes reported numbers for overnight work.

Constraints:
- No behavior change to the app's UI other than the new `today` period and whatever
  the midnight-rule decision implies.
- Follow the existing architecture: protocol + implementation, dependency-injected,
  matching the style of ReportPDFService / LocalStorageService.

Verification:
- Add unit tests for the new service and the search helper, following the existing
  Swift Testing style in TimeTrackerTests/ (reuse the mocks in TimeTrackerTests/Mocks/
  — MockLocalStorageService, MockUserPreferencesService, MockDateProvider).
- Add ReportPeriod tests for `today` alongside the existing ReportPeriodTests.
- Run the full test suite and make sure everything passes, including the existing
  ReportViewModelTests and DailyTimeAggregatorTests.
- Build the app and manually export a PDF from the Report screen to confirm it's
  byte-for-byte sane compared to before.

When done, update .claude/mcp-server-plan.md: move the completed items out of "Known
open items", record the new service's name/shape and the midnight-rule decision under
architecture decisions. Then tick Step 1's checkbox in the Progress section of
.claude/mcp-server-build-steps.md.
```

---

## Step 2 — MCP server skeleton + first tool end-to-end

> Goal is a thin vertical slice: dependency, transport, thread-safe data access, and
> tool registration all proven at once by the simplest possible tool. Resist adding
> more tools here.

```
Read .claude/mcp-server-plan.md for full context. Step 1 (foundation refactor) is
already done. This step stands up the MCP server itself and proves it end-to-end with
ONE tool.

Do this:

1. Add a Swift MCP SDK via SPM (the app currently has zero SPM dependencies — check
   the official modelcontextprotocol/swift-sdk first and tell me what you picked and
   why, including whether it supports the Streamable HTTP server transport we need).

2. Create an MCP server service inside the app that:
   - Serves the MCP Streamable HTTP transport, bound ONLY to 127.0.0.1 (never
     0.0.0.0). This is a hard security requirement.
   - Uses a hardcoded default port constant for now (Settings UI comes in Step 3).
   - Has explicit start()/stop() lifecycle, started from the app's existing AppDelegate
     (TimeTracker/App/AppDelegate.swift), which already keeps the app alive in the
     menu bar after windows close.
   - Fails gracefully and visibly if the port is already in use — don't crash the app.

3. Solve SwiftData thread-safety properly: request handlers must NOT touch the UI's
   main ModelContext. Use a dedicated background context / @ModelActor reading from
   the same ModelContainer built in TimeTrackerApp.swift:17-28. Explain the approach
   you chose.

4. Implement exactly ONE tool as the proof of life: "list tasks / list tags" (tool #5
   in the spec's catalog). It reuses LocalStorageService.fetchTasks() / fetchTags()
   and needs no new query logic — which is why it's first. Support filtering archived
   vs active tasks (TaskItem.isArchived exists).

Do NOT implement the other tools in this step.

Verification:
- Build and run the app.
- Register the server with Claude Code:
  `claude mcp add --transport http timetracker http://127.0.0.1:<PORT>/mcp`
- From a Claude Code session, confirm the server connects, the tool is listed, and
  calling it returns real tasks/tags from the running app.
- Confirm the server is NOT reachable from another machine on the network.
- Confirm quitting the app makes the connection fail cleanly (expected behavior).
- Add unit tests for the tool's handler logic using the existing mocks.

When done, update .claude/mcp-server-plan.md with: the SDK chosen, the thread-safety
approach, the default port, where the server lifecycle lives, and mark tool #5 as
implemented. Then tick Step 2's checkbox in the Progress section of
.claude/mcp-server-build-steps.md.
```

---

## Step 3 — Settings UI (port + enable toggle)

```
Read .claude/mcp-server-plan.md for full context. Steps 1-2 are done: the MCP server
runs on hardcoded port 8427 and serves one tool. DefaultMCPServerService already takes a
`port:` init parameter and exposes an observable MCPServerStatus
(.stopped/.running(port:)/.failed(reason:)) plus async start()/stop(), so this step is
mostly about feeding it from preferences and rendering that status.

Make the server user-configurable:

1. Add to the Settings screen (TimeTracker/Presentation/Settings/):
   - An enable/disable toggle for the MCP server.
   - A port field, defaulting to the constant from Step 2, with validation (valid port
     range, reject privileged ports below 1024).
   - A read-only display of the exact URL to register
     (http://127.0.0.1:<PORT>/mcp) with a copy button — so I can paste it into
     `claude mcp add` without retyping.
   - Clear status feedback: running / stopped / failed to bind (port in use).

2. Persist both settings via the existing UserPreferencesService
   (TimeTracker/Services/UserPreferences/), following how existing preferences are
   stored.

3. Wire it up: toggling restarts or stops the server live without an app relaunch;
   changing the port rebinds. Decide and implement whether the server auto-starts on
   app launch when enabled — I'd expect yes, so an unattended monthly-report skill
   works without me opening Settings first. Tell me what you chose.

Verification:
- Add SettingsViewModel tests following the existing
  TimeTrackerTests/Presentation/Settings/SettingsViewModelTests.swift style.
- Run the app: toggle off, confirm the MCP client can no longer connect; toggle on,
  confirm it reconnects.
- Change the port, re-register the new URL, confirm it works.
- Enter an invalid/in-use port and confirm the UI shows a clear error rather than
  failing silently.
- Relaunch the app and confirm the settings persisted and the server auto-started.

When done, update .claude/mcp-server-plan.md: mark the Settings UI and auto-start
questions resolved, and record the final UX. Then tick Step 3's checkbox in the
Progress section of .claude/mcp-server-build-steps.md.
```

---

## Step 4 — Tools: task search & date-range time

```
Read .claude/mcp-server-plan.md for full context, especially the "MCP tool catalog"
section. Steps 1-3 are done: the server runs, is configurable, and serves the
list-tasks/tags tool.

Implement tools #1 and #2 from the catalog. Follow the spec's behavior exactly — the
details there were deliberate:

Tool #1 — Time on a specific task:
- Free-text query, matched via the shared search helper extracted in Step 1
  (case-insensitive, BOTH title and description).
- Optional date range; with none given, return the all-time total.
- Handle all three match counts distinctly:
  - 0 matches: an explicit "no tasks matched" result, NOT an error, ideally with a few
    available task titles as a hint. The AI must never invent a number here.
  - 1 match: that task with its total for the range.
  - 2+ matches: ALL matches, each with its own total, plus a combined total. Never
    silently pick a "best" match.
- Include each task's id so a follow-up call can target it unambiguously.

Tool #2 — Time in a date range:
- Two response shapes chosen by the caller:
  - Total only — "what time have I tracked for some period?"
  - Per task — "...per task?" → list of tasks each with their own total, PLUS the
    overall period total so the user never has to add rows up. Sort descending by
    time; exclude zero-time tasks by default.
- Shared period argument reusing ReportPeriod (including the `today` case added in
  Step 1), accepting both named periods and an explicit custom start/end range.
- Route the simple "today" / "this week" total-only cases through the existing
  LocalStorageService.totalTrackedTimeToday() / totalTrackedTimeThisWeek().

Both tools are strictly read-only.

Design the tool names, descriptions, and argument schemas carefully — the tool
description is what the AI reads to decide when to call it, so make the distinction
between #1 and #2 unambiguous, and make it clear that #2 handles "today"/"this week".

Verification:
- Unit tests for both handlers using the existing mocks, covering: 0/1/many matches,
  both response shapes of #2, custom ranges, and the today/this-week paths.
- Run the app and from Claude Code ask these in natural language, confirming correct
  routing and numbers:
  - "How much time have I spent on <task>?"
  - "What time have I tracked this month?"
  - "What time have I tracked this month per task?"
  - "What time have I reported today?" / "...this week?"
  - A query matching several tasks, and one matching none.

When done, update .claude/mcp-server-plan.md: mark tools #1 and #2 implemented and
record their final names and argument schemas. Then tick Step 4's checkbox in the
Progress section of .claude/mcp-server-build-steps.md.
```

---

## Step 5 — Tool: report / invoice breakdown

```
Read .claude/mcp-server-plan.md for full context. Steps 1-4 are done.

Implement tool #3 from the catalog — the report / invoice-style breakdown:
- Takes the same period argument as tool #2 (reusing ReportPeriod).
- Returns the report data grouped by task as STRUCTURED DATA, not a file — i.e. the
  numbers behind the PDF: rounding applied, hourly rates and amounts computed.
- Reuses the UI-independent report service extracted in Step 1 — do not duplicate that
  math — plus UserPreferencesService for timeRounding, defaultHourlyRate,
  currencySymbol and businessName.
- Read-only.

Make sure the returned figures match exactly what the Report screen shows for the same
period — same rounding, same rate resolution (task rate falling back to default rate),
same currency handling. A mismatch between what the AI reports and what the PDF says
would be a billing problem, so include a test asserting they agree.

Verification:
- Unit tests using existing mocks, including one that asserts parity between this
  tool's output and the Report screen's computed rows for the same inputs.
- Run the app and from Claude Code ask "give me a breakdown of last month by task" and
  compare against the Report screen for the same period, including amounts.

When done, update .claude/mcp-server-plan.md: mark tool #3 implemented, record its
name and schema. Then tick Step 5's checkbox in the Progress section of
.claude/mcp-server-build-steps.md.
```

---

## Step 6 — Tool: PDF export to disk (+ disable App Sandbox)

```
Read .claude/mcp-server-plan.md for full context, especially architecture decision #6
about App Sandbox. Steps 1-5 are done.

Two parts:

1. Disable App Sandbox: set ENABLE_APP_SANDBOX to NO in
   TimeTracker.xcodeproj/project.pbxproj for BOTH Debug and Release configs (currently
   ~lines 360-361 and 406-407). This was a deliberate decision — the app is
   personal/local-only, not Mac App Store distributed — because a sandboxed app cannot
   write to an arbitrary path without an interactive save dialog, which an unattended
   MCP tool call can't use. Confirm the app still builds, launches, and that the
   existing Report screen PDF export still works afterwards.

2. Implement tool #4 — generate a PDF report and save it to disk:
   - Input: period (same argument as tools #2/#3), destination path, optional filename
     override, optional task filter.
   - Computes the same config as tool #3, hands it to the existing
     CoreGraphicsReportPDFService.generatePDF(config:) (already a pure
     ReportPDFConfig -> Data function), and writes the bytes to the given path.
   - MUST NOT show NSSavePanel or any other interactive dialog — the whole point is
     unattended use from a scheduled skill.
   - Default filename from the existing
     ReportPeriod.defaultFilename(startDate:endDate:) helper.
   - Returns the absolute path of the written file so the caller can confirm success.
   - Handle failure clearly: non-existent parent directory, no write permission,
     path pointing at a directory, etc. Return a useful error, don't crash the app.
   - Expand `~` in supplied paths.

Verification:
- Unit tests for path resolution, filename defaulting, and error cases.
- Run the app and from Claude Code: "generate a PDF report for last month and save it
  to ~/Desktop". Open the resulting file and confirm it's identical in content to one
  exported manually from the Report screen for the same period.
- Test the error paths (bad directory, unwritable location) and confirm the failure
  message is understandable.

When done, update .claude/mcp-server-plan.md: mark tool #4 implemented and the sandbox
item resolved. Then tick Step 6's checkbox in the Progress section of
.claude/mcp-server-build-steps.md.
```

---

## Step 7 — Docs, client registration, monthly-report skill

```
Read .claude/mcp-server-plan.md for full context. All five tools are implemented and
working.

Wrap the feature up:

1. Update README.md to document the MCP server: what it is, that it's local-only and
   read-only (except writing PDF files), how to enable it in Settings, the exact
   `claude mcp add --transport http timetracker http://127.0.0.1:<PORT>/mcp` command,
   the list of available tools with example questions for each, and the caveat that
   the app must be running for it to work.

2. Review all five tool names and descriptions together now that they exist as a set.
   Tool descriptions are the only thing the AI reads when deciding which to call —
   check they're mutually unambiguous, especially #2 vs #3 (raw time vs
   rounded/billable amounts) and #3 vs #4 (data vs file). Fix any that could
   misroute.

3. Write a Claude Code skill that generates my monthly report unattended — this was
   the motivating use case for the whole feature. It should generate current month's PDF
   report and save it to a sensible location. Put it wherever project skills belong,
   and tell me how to invoke it and how to schedule it monthly.

Verification:
- Follow the README instructions from scratch as if I'd never set this up, and confirm
  they're complete and correct.
- Run the new skill end-to-end and confirm it produces the right PDF with no prompts
  or dialogs.
- Ask a few ambiguous questions ("how much did I bill last month?", "how much time did
  I work last month?") and confirm the AI picks the right tool each time.

When done, do a final update of .claude/mcp-server-plan.md: change Status at the top
to reflect that the feature is shipped, and prune any stale open items. Then tick
Step 7's checkbox in the Progress section of .claude/mcp-server-build-steps.md.
```

---

## Notes for future sessions
- If a step turns out bigger than one session, split it and add the split here rather
  than letting a chat run long — keeping context small per session is the whole point.
- If a decision in `mcp-server-plan.md` turns out wrong once real code exists, change
  the spec and note why. The spec should describe what was actually built, not what
  was originally imagined.
