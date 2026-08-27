# TimeTracker Local MCP Server — Implementation Spec

Status: **SHIPPED.** All 7 steps are done. The server runs inside the app on a
user-configurable port, is toggleable from Settings, and serves **all five tools**
end-to-end against live data, including writing PDF files to disk. The App Sandbox is off
(architecture decision #6). The feature is documented in `README.md`, the five tool
descriptions have been reviewed as a set (decision #38), natural-language routing is
confirmed from real Claude Code sessions, and the motivating use case — an unattended
monthly PDF report — ships as the `/monthly-report` skill with a LaunchAgent (#39-41).
Test baseline: **564 passing, 0 failing**.

Future work on this feature should read "How to work in this repo" below, then the
decisions list. The remaining unverified items are two GUI interactions, listed at the
bottom under "Known open items".

## Goal
Expose an MCP server embedded inside the running TimeTracker app so an AI tool
(Claude Desktop/Code) can query local time-tracking data — time on a task, time in a
date range, report/invoice-style breakdowns, PDF report export — without any
backend. Modeled on Figma's local MCP server (app hosts the server; client connects to
a fixed localhost URL while the app is open).

## How to work in this repo (read this before touching code)

### Build and test with the Xcode MCP server, not `xcodebuild`
An **`xcode` MCP server is connected** and is the preferred way to build and test — it
drives the Xcode instance the user already has open, so results match what they see in
the IDE, and failures come back structured instead of needing to be grepped out of
thousands of lines. Verified working as of Step 1.

Every tool needs a `tabIdentifier`, so **always start with `XcodeListWindows`** — the
identifier changes between sessions, so never hardcode one from this file or an earlier
transcript. Typical flow:

1. `XcodeListWindows` → returns e.g. `tabIdentifier: windowtabN` for the workspace at
   `.../TimeTracker/TimeTracker.xcodeproj`.
2. `BuildProject(tabIdentifier:)` → `{buildResult, errors[], fullLogPath}`. Build errors
   arrive in `errors`; no log parsing needed.
3. `RunAllTests(tabIdentifier:)` → `{counts: {passed, failed, ...}, results[], summary}`.
   **Failed tests are listed first**, and results are truncated to 100 of N with the full
   list at `fullSummaryPath`. As of Step 6 the baseline is **557 passing, 0 failing** — a
   materially lower total means tests silently stopped being compiled, not that they passed.
   (As of Step 7 the baseline is **564 passing, 0 failing**.)
4. `RunSomeTests(tabIdentifier:, tests: [{targetName, testIdentifier}])` for a focused
   re-run; get identifiers from `GetTestList` (`targetName` is `TimeTrackerTests`, and
   `testIdentifier` looks like `DefaultReportBuilderServiceTests/someTest()`; a bare suite
   name like `ReportBreakdownToolTests` also works and runs the whole suite).
5. `GetBuildLog(tabIdentifier:, severity:/pattern:/glob:)` to dig into a build failure, and
   `XcodeListNavigatorIssues(tabIdentifier:)` for what's showing in the Issue Navigator.

There are also `XcodeRead`/`XcodeWrite`/`XcodeGrep`/`XcodeGlob`/`XcodeMV`/`XcodeRM` tools;
the ordinary Read/Edit/Write/Grep tools are fine for editing, but prefer the Xcode ones for
**moving or deleting** files so the IDE stays in sync.

**Fallback** (only if `XcodeListWindows` returns nothing, i.e. Xcode isn't open):
`xcodebuild test -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS'`
run from `.../timetracker/TimeTracker/`. Schemes are `TimeTracker` and `TimeTrackerTests`.
Its output is enormous — grep for `Failing tests|\*\* |error:`.

### Other things worth knowing before you start
- **New `.swift` files need no `project.pbxproj` edit.** Both targets use
  `PBXFileSystemSynchronizedRootGroup` (objectVersion 77), so dropping a file anywhere
  under `TimeTracker/` or `TimeTrackerTests/` — new subdirectories included — is enough.
  The project file now *does* have a `PBXBuildFile` section, but it holds only the four
  SPM product links added in Step 2; source files still never appear there.
- **Test baseline is now 564 passing, 0 failing** (373 after Step 1, +25 in Step 2, +23 in
  Step 3, +66 in Step 4, +27 in Step 5, +43 in Step 6, +7 in Step 7).
- Two files are deliberately excluded via `membershipExceptions`:
  `TimeTrackerTests/Services/LocalStorage/SwiftDataLocalStorageServiceTests.swift` (not
  compiled into the test target — don't model new tests on it or expect it to run) and
  `Info.plist`.
- **Architecture pattern to follow**: protocol `<Domain>Service` + `final class
  Default<X>Service` / `<Backing><X>Service` under `TimeTracker/Services/<Domain>/`.
  There is **no DI container** — services are constructed once in `TimeTrackerApp.init()`
  and passed to a per-screen `@MainActor struct <Screen>ModuleBuilder.build(...)` that
  constructs the `@Observable @MainActor final class` view model. `LocalStorageServiceHolder`
  / `TimerServiceHolder` are the only globals, existing solely for AppKit code paths.
- **Test conventions**: Swift Testing only, never XCTest. `import Testing` / `import
  Foundation` / `@testable import TimeTracker`; plain `struct <Type>Tests` (the codebase
  never uses `@Suite`); `@Test func camelCaseName()`; `#expect` only; `@MainActor` on the
  struct when the type under test has it; private `make…` fixture factories; mocks in
  `TimeTrackerTests/Mocks/` follow `stubbed<X>` / `<method>CallCount` / `<method>Last<Param>`.
- **The dev machine's locale formats decimals with a comma** (`$1,225,50`). Don't pin
  currency literals in tests — compare against `CurrencyFormatting.amount(_:symbol:)` or
  assert on structure. `String(format:)`-based output (rates, `formattedHoursMinutes`) is
  locale-independent and safe to pin.
- **Commit after each step** — each is a working, tested increment.

## Codebase facts gathered so far
- Swift/SwiftUI + AppKit menu-bar shell, single app target (`TimeTracker`). Two SPM
  packages as of Step 2 — `modelcontextprotocol/swift-sdk` and `apple/swift-nio` — with
  `MCP`, `NIOCore`, `NIOPosix` and `NIOHTTP1` linked into **both** the app and the test
  target (the test target needs them so `@testable import TimeTracker` resolves).
- No existing networking/IPC/server code anywhere in the codebase apart from
  `TimeTracker/Services/MCP/` (added in Step 2).
- Persistence is SwiftData (not Core Data), container built in
  `TimeTracker/TimeTrackerApp.swift:17-28`. `@Model` entities in
  `TimeTracker/Services/LocalStorage/Models/`: `TaskEntity.swift`,
  `TimeEntryEntity.swift`, `TagEntity.swift`. Domain structs in
  `TimeTracker/Domain/Models/`.
- No "Invoice" entity exists — invoicing is a report/PDF export flow, not stored data.
- App already runs as a persistent background/menu-bar process
  (`AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns `false`,
  `TimeTracker/App/AppDelegate.swift`) — favorable for hosting a long-lived server.
- Existing query/aggregation layer to build tools on top of:
  `LocalStorageService` protocol + `SwiftDataLocalStorageService` impl in
  `TimeTracker/Services/LocalStorage/`, with `totalTrackedTimeToday()`,
  `totalTrackedTimeThisWeek()`, `trackedTimeToday(for taskId:)`, `fetchTasks()`,
  `fetchTask(id:)`. Date-range aggregation for reports now lives in
  `DefaultReportBuilderService` (see architecture decision #7), which is built on
  `TimeTracker/Utilities/DailyTimeAggregator.swift`.
- PDF report generation already exists and is largely reusable:
  - `ReportPDFService` protocol / `CoreGraphicsReportPDFService` impl
    (`TimeTracker/Services/Report/ReportPDFService.swift`,
    `.../CoreGraphicsReportPDFService.swift`) — `generatePDF(config: ReportPDFConfig) -> Data`
    is a pure function, no UI dependency, directly callable from an MCP tool handler.
  - `ReportPeriod` enum (`TimeTracker/Presentation/Report/Models/ReportPeriod.swift`)
    has `.today/.thisWeek/.lastWeek/.thisMonth/.lastMonth/.thisYear/.allTime/.customRange`
    (8 cases), each with a pure `dateRange(calendar:now:)` calculator, plus a
    `defaultFilename(startDate:endDate:)` helper — maps directly onto a "which period"
    tool argument.
  - The day-grouping/rounding/rate-calculation logic that turns tasks + a date range
    into `ReportPDFConfig` rows now lives in `DefaultReportBuilderService`
    (architecture decision #7). `ReportViewModel.exportPDF()` is reduced to: show the
    save panel, call the service, write the bytes.

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
4. **Port**: default **8427** (`MCPServerConfiguration.defaultPort`), user-configurable in
   Settings since Step 3. `DefaultMCPServerService` no longer takes a `port:` parameter at
   all — see decision #18.
5. **Tool scope for v1**: five capabilities, detailed in the "MCP tool catalog"
   section below — all five now implemented. The server is **read-only** — the only thing it
   writes is the PDF file produced by tool #4; it never modifies tracked time data. See
   "Considered and deliberately left out of v1".
6. **App Sandbox: DISABLED (done in Step 6).** `ENABLE_APP_SANDBOX = NO` in both Debug and
   Release of the `TimeTracker` target. `ReportViewModel.exportPDF()` could only write to
   disk because `NSSavePanel` itself grants temporary write access to whatever the user
   picks — a sandboxed app cannot write to an arbitrary path with no dialog involved, which
   is exactly what an unattended MCP tool call needs. Since this app is personal/local-only
   (not Mac App Store distribution), the sandbox came off entirely rather than building a
   "pick a reports folder once, use a security-scoped bookmark" workaround. Verified after
   the flip: `codesign -d --entitlements` no longer lists `com.apple.security.app-sandbox`.
   - **The migration this required was bigger than originally noted.** Disabling the sandbox
     relocates **two** things, not one:
     - the SwiftData store, from
       `~/Library/Containers/dmytro.TimeTracker/Data/Library/Application Support/` to
       `~/Library/Application Support/` — and a **stale 73 KB store from Sep 2025 was
       already sitting at the destination**, so the app would have silently opened that and
       looked nearly empty. The migration had to overwrite it, not copy into empty space.
     - **UserDefaults**, from the container's `Library/Preferences/` to
       `~/Library/Preferences/dmytro.TimeTracker.plist`. This is not cosmetic: with the
       prefs lost, `defaultHourlyRate` reads `nil` and **every report comes out with no
       amounts at all**, plus currency back to `$`, rounding back to `none`, blank business
       name and the MCP port back to 8427.
   - The migration ran as a one-off script (quit the app so cfprefsd flushes the plist, back
     up both sides, copy `default.store`/`-wal`/`-shm` and the plist across, `killall
     cfprefsd`, then read the values back). It needs a terminal with **Full Disk Access** —
     the app container is TCC-protected and unreadable otherwise. Verified afterwards that
     the running app holds open `~/Library/Application Support/default.store` with zero
     container references, and that `get_billable_report` on `last_month` still returns the
     Step 5 figures (22 tasks, 151h 37m, €3,942.39 at €26/h).
   - **TCC replaces the sandbox as the thing that can block a write.** An un-sandboxed app
     still needs user consent for `~/Desktop`, `~/Documents` and `~/Downloads`, and that
     consent arrives as an interactive dialog — the one thing this tool must never depend
     on. In practice the first `~/Desktop` write went through without a prompt on this
     machine, but a fresh machine or a reset TCC database may prompt once. Grant it
     deliberately rather than letting a scheduled skill discover it.
7. **Report logic extracted into `ReportBuilderService`** (Step 1, done). Protocol
   `ReportBuilderService: Sendable` + `final class DefaultReportBuilderService`, both in
   `TimeTracker/Services/Report/`. No `@MainActor`, no AppKit — callable from an MCP
   request handler as-is. Shape:
   - `buildReport(_ request: ReportRequest) -> ReportData`
   - `makePDFConfig(for: ReportData, presentation: ReportPresentation) -> ReportPDFConfig`
   - `ReportRequest` = tasks + startDate/endDate + `TimeRoundingInterval` +
     `defaultHourlyRate` + `includeZeroTime` + injectable `calendar`/`now`. A convenience
     `init(..., preferences: UserPreferencesService, ...)` reads rounding and default rate
     straight off the preferences service — that's the init MCP handlers should use.
   - `ReportData` = `taskSummaries: [ReportTaskSummary]` (descending by raw time, each
     carrying `rawTime`, `roundedTime`, resolved `hourlyRate`, `amount`, and a
     `days: [ReportDaySummary]` per-day breakdown), plus `totalRoundedTime`,
     `totalAmount`, `showAmountColumn`, `defaultHourlyRate`, and the `calendar` used.
   - `ReportPresentation` = businessName + currencySymbol + generatedDate (display-only
     values, kept out of the computation so tool #3 can skip them entirely).
   - **Tool #3 wants `ReportData`; tool #4 wants `makePDFConfig` → the existing
     `CoreGraphicsReportPDFService.generatePDF(config:)`.** No further extraction needed.
   - Both `ReportViewModel.recomputeRows()` (the on-screen table) and `exportPDF()` route
     through this service, so the screen, the PDF and the future MCP tools cannot disagree.
   - Two supporting utilities were lifted out at the same time:
     `TimeTracker/Utilities/TaskSearch.swift` (`matches(_:query:)` / `filter(_:query:)`,
     the shared search predicate for tool #1) and
     `TimeTracker/Utilities/CurrencyFormatting.swift` (`amount(_:symbol:)` /
     `rate(_:symbol:)`, so screen and PDF render money identically).
8. **Midnight rule: entries that cross midnight are split across the days they span.**
   `DailyTimeAggregator`'s rule won; `ReportViewModel.exportPDF()`'s old "attribute the
   whole entry to its start day" rule is gone, and the service delegates to
   `DailyTimeAggregator` so there is now exactly one implementation. Besides unifying the
   Heatmap and the report, this fixed a real bug: a Jan 31 23:00 → Feb 1 02:00 entry in a
   *February* report was clipped to 2h but stamped `31.01.2026`, i.e. a PDF row dated
   before the report's own start date. Task totals and the PDF grand total are unchanged
   by this; only per-day row dates/values shift, and only for overnight work.
9. **The PDF grand total is deliberately not the sum of its day rows.** Day rows are
   rounded per day, while the grand total rounds each task's whole-period time once — so
   with rounding enabled, three 10-minute days at 15-minute rounding print as 15m/15m/15m
   but total 30m. This is long-standing Report-screen behavior and was preserved verbatim
   rather than "fixed", because changing it changes billed amounts on every rounded
   report. Pinned by `DefaultReportBuilderServiceTests.dayRowsNeedNotSumToTheGrandTotal`.
   **Step 5's parity test must not assume day rows sum to the total.** If this is ever
   revisited, the Report screen's on-screen total has to change with it.
10. **`CoreGraphicsReportPDFService` output is not byte-reproducible.** CoreGraphics
    stamps a creation timestamp into every PDF, so rendering the *same* `ReportPDFConfig`
    twice yields different bytes. Any future "did the PDF change?" check must compare the
    `ReportPDFConfig` (which fully determines the output) or the PDFKit-extracted text —
    never raw bytes.

### Step 2 decisions (the server itself)

11. **SDK: `modelcontextprotocol/swift-sdk` 0.12.1** (`upToNextMajorVersion` from 0.12.1),
    product `MCP`. Official, tracks the 2025-11-25 spec, `.macOS(13.0)` against our
    deployment target of 15.6. It ships `StatelessHTTPServerTransport` and
    `StatefulHTTPServerTransport`.
12. **The SDK's HTTP transports are not HTTP servers.** They expose
    `handleRequest(HTTPRequest) async -> HTTPResponse` over their own framework-agnostic
    value types and never touch a socket — the `MCP` library target has no NIO dependency
    at all (only the SDK's conformance *executable* does). So we bring the listener:
    **SwiftNIO 2.x** (`NIOCore`, `NIOPosix`, `NIOHTTP1`), modeled on the SDK's own adapter
    at `Sources/MCPConformance/Server/HTTPApp.swift`. Two deliberate departures from that
    sample, both in `MCPHTTPChannelHandler`: responses always carry a **`Content-Length`**
    (without it NIO close-delimits the body and keep-alive clients stall), and the request's
    keep-alive preference is honored.
13. **Stateless transport, not stateful.** `StatelessHTTPServerTransport` is POST-in /
    JSON-out; GET and DELETE get `405 + Allow: POST`, which spec-compliant clients accept.
    No sessions, no SSE stream to write. Sufficient because the tools are read-only and
    hold no per-client state. Its default validation pipeline is kept as-is and pulls its
    weight: `OriginValidator.localhost()` is DNS-rebinding protection layered on top of the
    loopback bind, and the `Accept`/`Content-Type`/protocol-version validators all pass
    with Claude Code's real headers. Switching to stateful would only be needed for
    server→client notifications.
14. **One `Server` per `initialize`, via `MCPSessionCoordinator`.** This one bit us in
    testing. `Server` accepts exactly **one** `initialize` for its whole lifetime — a
    second one fails with `-32600 Server is already initialized` — so a single long-lived
    server is permanently poisoned by the first client that connects. Claude Code
    re-initializes on every restart, and a stray `curl` probe does the same, so
    `MCPSessionCoordinator` rebuilds the (transport, server) pair whenever an `initialize`
    body arrives. This is cheap and safe here: the tools hold no per-client state, and the
    server runs **non-strict** (`Configuration.default`), which means tool calls succeed
    whether or not an `initialize` preceded them — so a client whose session got replaced
    by another client keeps working. **Don't "simplify" this back to a single server.**
15. **`ENABLE_INCOMING_NETWORK_CONNECTIONS = YES`** (added in Step 2, when the sandbox was
    still on: a sandboxed app cannot `listen()` without `com.apple.security.network.server`,
    loopback included). The project has no entitlements file, so this is a build setting in
    both Debug and Release, folded into the generated entitlements by Xcode. The setting
    permits listening in general — the loopback-only guarantee comes from binding
    `127.0.0.1` explicitly, never `0.0.0.0`.
    - **Step 6 deliberately kept this**, contrary to the original plan to drop it once the
      sandbox went. It is inert without the sandbox, and it is the single setting whose
      absence would silently break the server if the sandbox were ever re-enabled — a
      failure mode that cost real debugging time in Step 2. Keeping an inert setting is
      cheaper than rediscovering why `listen()` fails. `com.apple.security.network.server`
      is still present in the built app's entitlements; `com.apple.security.app-sandbox` is
      not.
16. **SwiftData thread-safety: a dedicated actor with a fresh `ModelContext` per read.**
    `SwiftDataMCPDataStore` is a plain `actor` holding the same `ModelContainer` the UI
    uses, and every read creates its own `ModelContext`. Two properties make it safe: the
    actor serializes access so no context is ever touched concurrently, and a per-request
    context always reads through to the store. Chosen over `@ModelActor` deliberately —
    that macro synthesizes one context held for the actor's lifetime, and a long-lived
    context keeps a row cache that can serve stale values after the UI's context writes.
    At this data volume the extra context costs nothing. `@Model` entities never leave the
    actor; only the `Sendable` domain value types do. Handlers reach it through the narrow
    async `MCPDataReading` protocol — deliberately *not* `LocalStorageService`, which is
    `@MainActor` and wraps the UI's context.
    - Supporting refactor: the entity→domain mapping moved out of
      `SwiftDataLocalStorageService`'s private methods into
      `Services/LocalStorage/SwiftDataItemMapper.swift`, so the main-actor service and the
      background actor cannot drift. Pure move, no behavior change.
17. **Lifecycle lives in `AppDelegate`.** `TimeTrackerApp.init()` constructs
    `DefaultMCPServerService(container:userPreferences:)` and parks it in
    `MCPServerServiceHolder` (same pattern as `TimerServiceHolder`);
    `applicationDidFinishLaunching` starts it,
    `applicationWillTerminate` stops it best-effort. The service is
    `@Observable @MainActor` — main-actor for its *state* only, since the socket work runs
    on NIO's event loops and the SDK's actors. That's what lets `AppDelegate.buildMenu`
    read `status` synchronously, and it's what Step 3's Settings screen will bind to.
    - **Graceful, visible failure**: `start()` never throws. A bind failure sets
      `status = .failed(reason:)`, logs to `OSLog`, and adds a disabled
      `⚠ MCP server: port 8427 is already in use` item to the menu bar. Pinned by
      `DefaultMCPServerServiceTests.aBusyPortFailsVisiblyInsteadOfCrashing`, which binds a
      real socket twice. Note `OSLog` output was *not* observable via `log show` on this
      machine during testing, so **verify server state through `status`/tests, not the
      unified log.**

### Step 3 decisions (Settings UI, persistence, auto-start)

18. **Preferences are the single source of truth for enabled + port.**
    `DefaultMCPServerService` takes `userPreferences` (like `DefaultTimerService`,
    `DefaultIdleMonitorService` and `DefaultTrackingReminderService` already do) and has **no
    `port:` init parameter** — it reads `mcpServerPort` fresh at every bind and gates on
    `mcpServerEnabled`. Nothing is cached across a bind, so there is exactly one answer to
    "what should be running". The alternative — threading the values through `AppDelegate` —
    would have needed a third global holder just for `UserPreferencesService`.
    - Two new preferences in `UserPreferencesService` / `UserDefaultsUserPreferencesService`:
      `mcpServerEnabled` (Bool, **defaults to `true`**) and `mcpServerPort` (Int, defaults to
      `MCPServerConfiguration.defaultPort`). Enabled-by-default preserves Step 2's always-on
      behavior and means an unattended skill works without visiting Settings first.
    - `mcpServerPort`'s **getter is range-guarded**: a stored value outside
      `MCPServerConfiguration.validPortRange` returns the default. Without it a corrupt or
      legacy value (0, a privileged port) would leave the server permanently unable to bind
      with no way back except editing defaults. Verified by hand: a persisted `80` falls back
      to 8427 rather than failing.
19. **Auto-start on launch when enabled — yes.** `start()` opens with
    `guard userPreferences.mcpServerEnabled`, so `AppDelegate.applicationDidFinishLaunching`
    keeps calling `start()` unconditionally and **`AppDelegate` needed no change at all**.
    A disabled server simply leaves `status == .stopped` and binds nothing.
20. **`applyPreferences()` is the one live-reconfiguration entry point** (on the
    `MCPServerService` protocol). Settings writes the preference, then calls it; it stops,
    starts or rebinds to match. Idempotent when already running on the configured port, and
    it deliberately does **not** short-circuit on `.failed` — re-applying retries the bind,
    which is exactly what the Settings screen's Retry button is.
21. **Port commits via an explicit Apply button, not per-keystroke.** Every other setting in
    `SettingsViewModel` auto-saves in `didSet`, but rebinding a socket on every keystroke is
    not the same as writing a `UserDefaults` key ("8", "84", "842" are all invalid en route
    to "8427"). So `mcpServerPortText` is free text whose `didSet` only clears a stale error;
    `applyPort()` validates, and only on success persists and rebinds. `.onSubmit` (Return)
    triggers it too, and Apply is disabled while the field matches the saved port.
    - **Validation**: `MCPServerConfiguration.validPortRange = 1024...65535`. Privileged
      ports are rejected in the UI rather than surfacing as an unfixable bind error.
    - **The URL row always shows the saved port**, never the typed one, so an uncommitted
      edit can't advertise a URL nothing is listening on.
22. **The Settings section's final shape** — `Section("MCP Server")`, between Notifications
    and Tags: an enable toggle with a caption saying it's local-only; then, when enabled, a
    port field + Apply, the validation error in red, a status row (colored dot + "Running on
    port N" / "Stopped" / "Not running" / "Failed: …", with a Retry button on failure), and
    the `http://127.0.0.1:<PORT>/mcp` URL — monospaced, selectable, with a copy button that
    flips to a checkmark for 2s. The pasteboard write lives in the **view**, not the view
    model, so unit tests never touch the real clipboard. The menu-bar
    `⚠ MCP server: …` failure item from Step 2 stays as a second, always-visible signal.
    - Testing seam: `SettingsViewModel.pendingMCPServerUpdate` retains the fire-and-forget
      `Task` so tests can await a rebind deterministically. The UI never reads it.

### Step 4 decisions (the two time-query tools)

23. **One period vocabulary, wrapping `ReportPeriod`: `MCPPeriodArgument`**
    (`Services/MCP/Tools/`). Every period-taking tool merges its `schemaProperties`
    (`period` + `start_date` + `end_date`) into its own input schema and calls
    `resolve(...)`, so #3 and #4 in Steps 5-6 inherit the whole argument for free.
    - The MCP surface uses **snake_case** names (`this_month`) rather than `ReportPeriod`'s
      display raw values ("This Month"), because those are what an AI reliably produces.
      Matching is tolerant — case, spaces, underscores and hyphens are all normalised away,
      so `this month`, `thisMonth` and `This Month` all resolve. `customRange` is exposed as
      `"custom"`.
    - `dateRange(calendar:now:)` stays the single definition of where a period starts;
      nothing re-derives "this week".
    - Custom ranges are **inclusive at both ends**: `start_date` → start of day,
      `end_date` → 23:59:59. Dates parse as `yyyy-MM-dd` (POSIX locale, the calendar's time
      zone) falling back to ISO 8601, so a full timestamp isn't turned away.
    - Malformed arguments return `isError: true` with a message naming the accepted values.
      These are caller errors; "no tasks matched" deliberately is **not** one (decision #25).
    - Tools take `calendar:`/`dateProvider:` with production defaults, following
      `DefaultTimerService`, which is what makes the `today`/`this_week` paths testable.
24. **The `today` / `this week` fast path through `LocalStorageService` was dropped.** The
    catalog originally said to route those total-only cases through
    `totalTrackedTimeToday()` / `totalTrackedTimeThisWeek()`, but that service is
    `@MainActor` and decision #16 bars handlers from touching it — so "reuse" would have
    meant mirroring both methods onto `MCPDataReading`, i.e. a *second* implementation of
    "this week" with a non-injectable `Calendar.current`/`Date()` inside. Instead every
    period takes one uniform path: `ReportPeriod` → date range → `DailyTimeAggregator`.
    It costs nothing extra (`fetchTasks()` loads each task's entries either way), it is
    deterministic under test, and the numbers are provably the same:
    `TaskEntity.trackedTime(from:to:)` clips entries to the range, and the aggregator's
    per-day split sums to that same clipped total. `DailyTimeAggregator` gained a
    `total(for:rangeStart:rangeEnd:calendar:now:)` defined in terms of `dailyTotals`, so a
    range total and its per-day breakdown can never disagree.
    - **`all_time` is the one exception**: `MCPPeriodArgument.Resolved.trackedTime(for:)`
      returns `task.totalTrackedTime` rather than aggregating `distantPast…end of today`.
      That's the same number `list_tasks_and_tags` reports (verified live: both give
      2,978,569s across 86 tasks), and it also counts an entry dated in the future, which a
      range ending today never would.
    - Consequence worth knowing: a range ending 23:59:59 loses **one second** off work that
      runs through midnight. That is pre-existing `ReportPeriod` behavior in every case, so
      it was matched rather than "fixed"; pinned by
      `MCPPeriodArgumentTests.trackedTimeClipsEntriesToTheRange`.
25. **Zero matches is an answer, not an error** (tool #1). The payload for a zero-match
    search carries **no total field anywhere** — not even a zero — plus a `message` telling
    the caller not to guess and up to 10 existing task titles as a hint. One match omits the
    redundant `combined*` fields; two or more carry every match with its own total, the
    combined total, and a `message` saying not to pick one. Three counts, three visibly
    different shapes.
26. **Integer seconds are summed, never the raw intervals.** Both tools compute each task's
    seconds once and derive the total from those same integers, so printed rows always add
    up to the printed total and both of #2's breakdowns report an identical total. Dropping
    zero-time rows can't change a sum they contribute 0 to.
27. **`MCPToolResponse`** (`Services/MCP/Tools/`) now owns JSON encoding (pretty-printed,
    key-sorted) and the success/failure envelopes for every tool, including the Step 2 one —
    three copies of an encoder configuration was one drift risk too many.

### Step 5 decisions (the report tool)

28. **`UserPreferencesService` is now `Sendable`**, rather than getting its own narrow
    MCP-facing protocol the way storage did. Decision #16's reason for `MCPDataReading` was
    that `LocalStorageService` is `@MainActor` and wraps the UI's `ModelContext` — genuinely
    unsafe off-main. Neither applies here: the protocol has no isolation and
    `UserDefaultsUserPreferencesService`'s only stored property is a `UserDefaults`, which is
    documented thread-safe, so it is `@unchecked Sendable` (as is `MockUserPreferencesService`,
    following `MockMCPDataStore`). Adding `Sendable` to a protocol constrains conformers, not
    callers, so `SettingsViewModel`, `ReportViewModel` and every other consumer were untouched
    — and the tests reuse the existing mock, which is what lets the parity test feed **one**
    preferences instance to both the Report screen and the tool.
    - Preferences are read **fresh on every tool call**, never snapshotted at registration, so
      changing rounding or the default rate in Settings takes effect on the next call.
    - Plumbing: `MCPToolCatalog.register(on:dataStore:preferences:)` and
      `MCPSessionCoordinator(dataStore:preferences:)`. `DefaultMCPServerService` already held a
      `userPreferences`, so it needed no new init parameter and `TimeTrackerApp`/`AppDelegate`
      needed no change at all.
29. **Tool #3 uses `ReportPeriod`'s real range for `all_time`, unlike tools #1/#2.**
    Decision #24 has `MCPPeriodArgument.Resolved.trackedTime(for:)` special-case `.allTime` to
    `task.totalTrackedTime`; this tool bypasses that and hands `distantPast … 23:59:59 today`
    to `buildReport`, because that is exactly what the Report screen's "All Time" does and
    matching the screen is the entire point of the tool. Consequence: an entry dated in the
    **future** counts in `get_time_for_period` on `all_time` but not here. Verified live that
    no such entry currently exists — all 86 tasks report identical per-task seconds across
    both tools. (`DailyTimeAggregator` clips per entry, so a `distantPast` start costs nothing.)
30. **Integer seconds are truncated the way the screen truncates, not summed** — the opposite
    of decision #26, deliberately. `totalRoundedTimeSeconds` is `Int(report.totalRoundedTime)`:
    one truncation over the whole sum, which is what `ReportViewModel.totalSelectedTime`
    produces. Each task row truncates its own sub-second fraction separately, so **the rows can
    come out a few seconds short of the total** — 10s over 22 tasks for a real July, 44s over
    86 tasks for all-time. The two cannot both be exact, and screen parity wins, so:
    - the payload carries an **always-present `note`** telling the caller to report totals as
      given rather than re-adding rows (a caller "fixing" the total would be changing an
      invoice figure);
    - both tools still format to the **same** displayed string — live July gives `151h 37m`
      from `get_billable_report` and `get_time_for_period` alike, which is all the user sees.
    - This was found by the live run, not by the tests: whole-second fixtures hide it, so
      `ReportBreakdownParityTests` now uses fractional-second entries and
      `theFixtureCarriesSubSecondDust` fails if they ever stop mattering.
31. **`include_daily_breakdown` is opt-in, default off.** The default response mirrors the
    Report screen exactly and stays small; the PDF's day grid is a wide month × 86 tasks and
    would be thousands of JSON rows on every call. When it is asked for, the `note` gains the
    decision-#9 caveat, since per-day rounding opens a gap of *minutes* rather than seconds.

### Step 6 decisions (the PDF-export tool)

32. **`destination_path` accepts a folder *or* a full `.pdf` path, and never guesses.**
    "Save it to ~/Desktop" and "save it to ~/Desktop/July.pdf" are both things a caller
    produces naturally, so both resolve; `~` is expanded and relative paths are rejected
    (the server has no meaningful working directory). The rules, in `ReportPDFDestination`:
    - an existing directory → the report is named automatically inside it;
    - a last component ending `.pdf` → that exact file, whose folder must already exist;
    - anything else → **an error naming the ambiguity**, never a guess. A non-existent
      `~/Desktop/reports` could equally be a folder to create or a file to write, and
      picking one silently is how next month's report ends up somewhere nobody looks.
    - **Folders are never created.** A path that does not exist is far more likely a typo
      than an instruction.
    - `filename` applies only to the folder form; passing it alongside a full `.pdf` path
      is an error rather than a silent override, since ignoring one of two names the caller
      supplied is exactly the kind of surprise this tool cannot afford.
33. **Collisions rename, never overwrite.** An existing file makes the next report
    `Time Report - July 2026 (2).pdf`, counting up to `ReportPDFDestination.maximumCollisionAttempts`
    (99) before erroring. The motivating use case is a *monthly re-running skill*, and
    silently replacing a PDF the user has already invoiced from is unrecoverable, whereas an
    extra file is trivially deleted. The response carries `renamedToAvoidOverwrite` and the
    `requestedFilename`, and the `note` tells the caller to report the path it was given
    rather than the one it asked for.
34. **An empty report is an error, not an empty PDF.** Two cases return `isError`: a
    `task_query` that matches no task, and a period with no tracked time. This stretches the
    decision-#25 rule that "nothing matched is an answer, not an error" — but #25 is about
    *reporting a number*, and this tool's product is a **file**. Saving a blank document that
    looks like the user's month is a worse outcome than failing loudly, especially unattended.
    Both messages name the next tool to call to find out what went wrong.
35. **The task filter is free-text `task_query`, reusing `TaskSearch.filter`** — the same
    predicate as `get_time_for_task` and the Main Window search field, matching title and
    description case-insensitively. Chosen over a `task_ids` array because it is what an AI
    naturally has ("the Acme report") without a two-call dance, and because reusing the
    existing predicate means the filter cannot drift from the search users already know.
    - **Tool #3 deliberately did not gain one.** It ships without a filter and nothing about
      Step 6 changed that; the argument for symmetry did not outweigh adding schema surface
      to a settled, verified tool. Revisit only if a caller actually wants it.
36. **`ReportPDFService` is now `Sendable`, and the render hops to the main actor.** Two
    separate things, both required:
    - `SWIFT_STRICT_CONCURRENCY = complete` means the tool cannot hold an
      `any ReportPDFService` otherwise. `CoreGraphicsReportPDFService`'s stored properties
      are five immutable `CGFloat`s so it conforms as-is; `MockReportPDFService` needed
      `@unchecked Sendable` for its recording vars. Same precedent as decision #28 —
      constrains conformers, not callers, so `ReportViewModel` was untouched.
    - The implementation draws almost entirely with `NSFont`/`NSColor`/`NSAttributedString`,
      which are not documented safe off the main thread, and the handler runs on a NIO event
      loop. So `SaveReportPDFTool` wraps the call in `await MainActor.run { … }`. The render
      is fast and infrequent; the hop costs nothing. **Do not "optimise" this away.**
37. **The parity test compares the `ReportPDFConfig`, not the file.** Decision #10 rules out
    byte comparison (CoreGraphics stamps a creation timestamp), and the config fully
    determines the rendered page. `SaveReportPDFParityTests` builds the config
    `ReportViewModel.exportPDF()` would produce — same four lines, minus the save panel,
    which cannot run in a test — and asserts equality row by row against the one the tool
    hands to the PDF service, at three rounding settings. `generatedDate` is injected
    identically into both sides, since it is the one field legitimately "now" on each.

### Step 7 decisions (docs, description review, the skill)

38. **The five descriptions now form a closed cross-reference graph.** Read side by side for
    the first time, the set had one real gap and three one-way pointers. Every edit is
    description text only — no schema, no behavior, no annotation changed.
    - **The gap: `get_time_for_task` never said it returns *raw* time.** "How much do I bill
      for the Acme work?" names a task, so #1 wins the routing, and #1 would answer a money
      question with a duration. It now states the exclusion explicitly and routes money
      questions to `get_billable_report`, or `save_report_pdf` with `task_query` for a
      document covering just that task. (Note #3 still has **no** task filter — decision #35
      stands; the pointer is to #3 for the period figures and #4 when one task's own document
      is wanted.)
    - **`get_time_for_period` ⇄ `get_billable_report`** was one-way: #3 named #2, #2 never
      named #3. #2 now names #3, and says the raw-time exclusion holds *even when an hourly
      rate is configured* — the case where a caller is most tempted to compute money itself.
    - **`get_billable_report` → `save_report_pdf`** was likewise one-way. #3 now says it
      returns numbers "not a document" and names #4, mirroring the sentence #4 already had.
    - **`list_tasks_and_tags`** said "use a time-query tool instead" without naming one. It
      now names both, and calls itself a discovery tool rather than an answer to "how much
      time did I track" — its totals are all-time and easily mistaken for a period answer.
    - **`save_report_pdf.destination_path` is required**, so a caller with no location in the
      question had to invent a path. It now names `~/Desktop` as the default to use.
    - Pinned by tests following the existing
      `definitionPointsAtTheOtherToolSoTheTwoDontGetConfused` convention, one per tool file,
      so dropping a pointer in a future rewrite fails a test rather than silently misrouting.
      `ReportBreakdownToolTests` also gained the `definitionIsMarkedReadOnly` check every
      other tool already had.
39. **The monthly-report skill defaults to `this_month`, with the period as an argument.**
    The user's ask was explicit about the current month, and `/monthly-report last month`
    covers the invoice-shaped case; the LaunchAgent passes `last month` so a run on the 1st
    reports a complete month. The skill hands the user's own wording to
    `MCPPeriodArgument`'s tolerant parser rather than deriving date ranges itself (decision
    #23), so there is still exactly one definition of "last month".
    - Its three standing instructions are all guards against a *plausible* wrong answer:
      report `path` rather than the requested filename (decision #33 can rename it), never
      re-add or re-format the figures (decision #30 — a "corrected" total is a wrong
      invoice), and treat an empty period as the answer rather than retrying with a
      different one (decision #34 — a report labelled with the wrong month is worse than no
      report).
40. **PDFs go to `~/Desktop`.** It is the only location proven to write with no TCC dialog
    (decision #6), which is the one thing an unattended run cannot survive. `~/Documents/…`
    was the tidier option and was rejected on that basis alone.
41. **Scheduling is launchd, and cannot be a cloud agent.** A scheduled cloud agent runs on
    another machine and can never reach `127.0.0.1` on this Mac — the server is *inside* the
    app. `schedule/run-monthly-report.sh` + a `StartCalendarInterval` LaunchAgent (1st of the
    month, 09:00) are shipped next to the skill but **not installed**; `schedule/README.md`
    carries the `launchctl bootstrap` command. Two things the script has to do that are easy
    to miss: `cd` into the project directory (the skill is a **project** skill in this repo's
    `.claude/skills`, so it is only found from here), and pass `--allowed-tools` (without it
    the run blocks on a permission prompt nobody is there to answer).
    - **The server itself is registered at `-s user` scope**, so it is reachable from any
      directory on the machine (see decision #43). Only the skill is project-bound.
43. **The client registration lives at user scope, not local.** Step 7 originally registered
    with a bare `claude mcp add`, which is **local** scope — private to one project directory.
    That is the wrong shape for this server: it is a personal, machine-wide utility answering
    questions about the user's own time, not a dependency of the TimeTracker codebase, and the
    questions it answers ("how much did I bill last month?") get asked from wherever the user
    happens to be. Re-registered with `-s user` and verified answering from `~`. The README
    leads with the `-s user` form for the same reason.
42. **A build predating this feature has no server in it at all.** `/Applications/TimeTracker.app`
    was still a June 29 build with `com.apple.security.app-sandbox` — it has neither the MCP
    code nor the entitlement, so `claude mcp list` reports `ConnectionRefused` while the app is
    visibly running. Left as-is at the user's direction (they refresh it themselves); the README
    calls the symptom out by name, since it is otherwise a genuinely confusing failure. Step 7
    verified against the DerivedData Debug build.

## What exists in code (as of Step 6)

Everything lives in `TimeTracker/Services/MCP/`:

| File | Role |
|---|---|
| `MCPServerService.swift` | `MCPServerConfiguration` (host/defaultPort/path/name/`validPortRange`), `MCPServerStatus`, the `@MainActor` protocol (`start`/`stop`/`applyPreferences`) |
| `DefaultMCPServerService.swift` | `@Observable @MainActor`; NIO `ServerBootstrap` bind/close, status, graceful bind failure, preference-driven enable/port |
| `MCPSessionCoordinator.swift` | Owns the `Server` + transport pair, rebuilds on `initialize` (decision #14) |
| `MCPHTTPChannelHandler.swift` | NIO `HTTPServerRequestPart` ⇄ `MCP.HTTPRequest`/`HTTPResponse` |
| `MCPDataReading.swift` / `SwiftDataMCPDataStore.swift` | Background-actor SwiftData reads (decision #16) |
| `MCPToolCatalog.swift` | `ListTools` / `CallTool` registration for all five tools |
| `Tools/MCPPeriodArgument.swift` | The shared period argument: schema fragment, tolerant parsing, `Resolved.trackedTime(for:)` (decisions #23-24) |
| `Tools/MCPToolResponse.swift` | JSON encoding + the success/failure envelopes, shared by every tool |
| `Tools/ListTasksAndTagsTool.swift`, `Tools/ListTasksAndTagsPayload.swift` | Tool #5 |
| `Tools/TimeForTaskTool.swift`, `Tools/TimeForTaskPayload.swift` | Tool #1 |
| `Tools/TimeForPeriodTool.swift`, `Tools/TimeForPeriodPayload.swift` | Tool #2 |
| `Tools/ReportBreakdownTool.swift`, `Tools/ReportBreakdownPayload.swift` | Tool #3 (+ `ReportBreakdownPreferences`, the Sendable preference snapshot) |
| `Tools/SaveReportPDFTool.swift`, `Tools/SaveReportPDFPayload.swift` | Tool #4 |
| `Tools/ReportPDFDestination.swift` | Pure path resolution + collision renaming (decisions #32-33) |
| `Tools/MCPFileWriting.swift` | The filesystem seam (`isDirectory`/`fileExists`/`write`) + `DefaultMCPFileWriter` |

Plus `App/MCPServerServiceHolder.swift`, wiring in `TimeTrackerApp.swift` and
`App/AppDelegate.swift`, and `Services/LocalStorage/SwiftDataItemMapper.swift`.

Step 3 added the `mcpServerEnabled` / `mcpServerPort` pairs to
`Services/UserPreferences/{UserPreferencesService,UserDefaultsUserPreferencesService}.swift`
and the MCP section to `Presentation/Settings/{SettingsViewModel,SettingsView}.swift`
(+ a `mcpServerService:` parameter on `SettingsModuleBuilder`).

Step 4 added `Tools/MCPPeriodArgument.swift`, `Tools/MCPToolResponse.swift` and the two
tool/payload pairs above, plus `DailyTimeAggregator.total(...)`. It needed **no** change to
`MCPDataReading`, `SwiftDataMCPDataStore`, `MockMCPDataStore` or any preference — neither
tool touches rates, rounding or currency.

Step 5 added the two `ReportBreakdown*` files above, made `UserPreferencesService` `Sendable`
(decision #28), and threaded `preferences` through `MCPSessionCoordinator` and
`MCPToolCatalog`. It needed **no** change to `MCPDataReading`, `SwiftDataMCPDataStore`,
`DefaultReportBuilderService`, `TimeTrackerApp` or `AppDelegate`.

Step 6 added the four files above, flipped `ENABLE_APP_SANDBOX` to `NO` in both configs, and
made `ReportPDFService` `Sendable` (decision #36). Because the new tool's remaining
dependencies all have production defaults, registration was two lines in `MCPToolCatalog`
and it needed **no** change to `MCPSessionCoordinator`, `DefaultMCPServerService`,
`MCPDataReading`, `SwiftDataMCPDataStore`, `DefaultReportBuilderService`,
`CoreGraphicsReportPDFService`, `ReportViewModel`, `TimeTrackerApp` or `AppDelegate`.

Tests in `TimeTrackerTests/Services/MCP/` (payload builder, tool handlers, the period
argument, server lifecycle + preference-driven configuration),
`TimeTrackerTests/Presentation/Settings/` (the MCP section), and mocks
`MockMCPDataStore.swift` / `MockMCPServerService.swift`. The Step 4 tools reuse
`MockDateProvider` to pin `now`. Step 5 added `ReportBreakdownToolTests.swift` and
`ReportBreakdownParityTests.swift` — the latter is `@MainActor`, drives a real
`ReportViewModel` and the tool from one `MockUserPreferencesService`, and is the thing
standing between a rounding/rate change and a wrong invoice. Step 6 added
`ReportPDFDestinationTests.swift` (the path rules, driven by the new
`Mocks/MockMCPFileWriter.swift`), `SaveReportPDFToolTests.swift` (writes into a real
temporary directory — the write path and its error messages are the product, so they are
exercised against an actual filesystem) and `SaveReportPDFParityTests.swift` (decision #37).

Step 7 changed **no production logic** — only the five `Tool.description` strings and one
argument description (decision #38) — and added 7 tests across the existing tool test files.
Outside the app it added `README.md`'s "AI Access (MCP Server)" section and the skill:

| File | Role |
|---|---|
| `.claude/skills/monthly-report/SKILL.md` | The skill itself: period resolution, the `save_report_pdf` call, and the report-what-you-got / don't-work-around-failures rules (decision #39) |
| `.claude/skills/monthly-report/schedule/run-monthly-report.sh` | What launchd executes: `cd`s to the project, launches the app if needed, runs `claude -p "/monthly-report last month" --allowed-tools …`, logs to `~/Library/Logs/timetracker-monthly-report.log` |
| `.claude/skills/monthly-report/schedule/com.dmytro.timetracker.monthly-report.plist` | LaunchAgent, `StartCalendarInterval` 1st @ 09:00. **Not installed** — see its README |
| `.claude/skills/monthly-report/schedule/README.md` | Install/test/uninstall commands, and why this can't be a cloud agent (decision #41) |

**Registering the client** (the app must be running; port from Settings):
```
claude mcp add --transport http timetracker http://127.0.0.1:8427/mcp
```
Registers at **local** scope, i.e. this project directory only — which is why the scheduled
skill has to `cd` here (decision #41). `-s user` makes it available everywhere. The
user-facing version of all this lives in `README.md` → "AI Access (MCP Server)"; keep the two
in step if the port default, the tool set or the Settings wording ever changes.

**Verified in Step 2**: `lsof` shows `127.0.0.1:8427 (LISTEN)`, never `*:8427`; a request
to the machine's LAN address is refused; `GET /mcp` → 405, unknown path → 404; repeated
`initialize` succeeds; `claude mcp list` reports Connected; a real Claude Code session
lists and calls the tool and gets back the live 86 tasks / 4 tags; quitting the app makes
the connection fail cleanly.

**Verified in Step 3** (421 tests passing, 0 failing): with no preference keys written at
all the server auto-starts on 8427 and a real Claude Code session calls the tool; a
persisted `mcpServerPort = 9000` auto-binds 9000 (and only 9000) on relaunch, serves
`initialize` + `tools/list` over HTTP, and is refused on the LAN address; a persisted
`mcpServerEnabled = false` leaves the app with **no listening socket at all**; a persisted
privileged port (`80`) falls back to 8427 instead of failing; and launching with the port
already squatted leaves the app alive with no listener. The live toggle/Apply paths and the
copy button are UI interactions and were left for manual confirmation.

**Verified in Step 4** (487 tests passing, 0 failing): against the running app over HTTP,
`tools/list` returns all three tools; `get_time_for_task` gives one match, three matches
with a combined total, and a no-match result carrying no total at all; `get_time_for_period`
answers `today` / `this_week` / `this_month` / a custom July range / `all_time`, in both
breakdowns, with the per-task rows summing exactly to the reported total. Cross-check that
pins decision #24: `get_time_for_period` on `all_time` and the sum of
`list_tasks_and_tags`'s per-task totals both give **2,978,569s across 86 tasks**. Every
error path returns a message naming the fix (missing/unknown period, `custom` without
dates, `01/07/2026`, missing query), and `"This Month"` + `breakdown: "nonsense"` resolve
tolerantly instead of failing. **Still to confirm by hand**: natural-language routing from a
real Claude Code session — whether the descriptions actually send "how much on X?" to #1 and
"what did I track this month?" to #2 — which needs a session started while the app is up.

**Verified in Step 5** (514 tests passing, 0 failing): against the running app over HTTP,
`tools/list` returns all four tools with the expected schemas. `get_billable_report` on
`last_month` returns 22 tasks totalling **151h 37m / €3,942.39** at €26/h with rounding off,
and cross-checks clean against the other tools: identical task set and identical per-task
raw seconds versus `get_time_for_period` per_task, and the same formatted total from both.
On `all_time`, all three tools agree per task (86 tasks) — `get_billable_report` 2,978,613s
vs 2,978,569s from both `get_time_for_period` and the sum of `list_tasks_and_tags`, the 44s
being decision #30's truncation dust and **not** a per-task disagreement. `include_zero_time`
widens 22 → 86 tasks, `include_daily_breakdown` returns ascending dated day rows, a custom
1–15 July range gives 14 tasks / 74h 49m, and every error path names its fix (missing period,
`custom` without dates, unknown period, `01/07/2026`), while `"This Month"` resolves
tolerantly. **Still to confirm by hand**: the visual row-by-row comparison against the Report
screen and an exported PDF for the same period, and that a live `timeRounding` change in
Settings is picked up without relaunch (read fresh per call by construction, and covered by
unit tests, but not exercised against the running app).

**Verified in Step 6** (557 tests passing, 0 failing): after the sandbox flip and the data
migration, the running app holds open `~/Library/Application Support/default.store` with no
container references, binds `127.0.0.1:8427` only, and `get_billable_report` on `last_month`
still returns the Step 5 figures unchanged — 22 tasks, 151h 37m, €3,942.39 at €26/h, with
business name, currency and rate all intact. Over HTTP, `tools/list` returns **five** tools
with `save_report_pdf` advertising `readOnlyHint: false`. `save_report_pdf` on `last_month`
to `~/Desktop` wrote a 31 KB PDF with **no dialog of any kind**; its extracted text carries
the header ("Dmytro Nosulich", "TIME REPORT", "Period: 1. July 2026 – 31. July 2026"), dated
per-day rows, and a footer reading `RATE €26/h` / `TOTAL 151h 37m` — the same total the tool
and `get_billable_report` report. A second identical call landed as
`Time Report - July 2026 (2).pdf` with `renamedToAvoidOverwrite: true`, leaving the first
file untouched. `task_query: "Paywall"` narrowed it to 2 tasks / 53h 35m / €1,393.47 with a
`filename` override honored, and a custom 1–15 July range gave **14 tasks / 74h 49m**,
matching Step 5's figure for the same range. Every error path returned a message naming its
fix: non-existent folder, `/System/Library` (carrying the OS's own permission wording), a
`task_query` matching nothing, `today` (no time tracked), a relative path, and `filename`
passed alongside a full `.pdf` path.

**Verified in Step 7** (564 tests passing, 0 failing): `tools/list` over HTTP returns all five
tools carrying the edited descriptions. Following the README's own commands from a clean slate
(`claude mcp remove timetracker -s local` first) reproduced exactly what it documents:
`claude mcp add --transport http timetracker http://127.0.0.1:8427/mcp` → `claude mcp list`
reports `✔ Connected`, and `lsof` shows `127.0.0.1:8427 (LISTEN)`, never `*:8427`.

**Natural-language routing is finally confirmed** — the item carried since Step 4 — by driving
six headless `claude -p … --output-format stream-json` sessions against the running app and
reading back which tool each one actually called:

| Question | Routed to |
|---|---|
| "how much did I bill last month?" | `get_billable_report` ✓ |
| "how much time did I work last month?" | `get_time_for_period` ✓ |
| "how much time did I spend on the Reply to menu option task?" | `get_time_for_task` ✓ |
| "give me last month's report as a PDF" | `save_report_pdf` ✓ |
| "what tasks do I have?" | `list_tasks_and_tags` ✓ |
| "how much do I bill for the Reply to menu option task last month?" | `get_billable_report` (+ `get_time_for_task` for that task's share) — **not** hours reported as money, which is decision #38's gap |

The skill runs end-to-end unattended: `claude -p "/monthly-report"` produced August 2026 on the
Desktop with **no dialog or prompt of any kind**, and — because an August report was already
there — exercised the collision path, landing as `… (2).pdf` and reporting the rename rather
than the requested name. Its figures (12 tasks, 36h 42m, €954,25 at €26/h) match
`get_billable_report` on `this_month` exactly, and the PDF's own extracted text carries the same
`RATE €26/h` / `TOTAL 36h 42m` / `€954,25` footer under a `Period: 1. August 2026 – 31. August
2026` header. `/monthly-report last month` returned the unchanged Step 5/6 July figures (22
tasks, 151h 37m, €3,942.39). Finally `schedule/run-monthly-report.sh` was run directly — the
exact command line launchd will execute — and completed with exit 0, the PDF written and the
run logged.

## MCP tool catalog

Five tools, all implemented. All are **read-only** except #4, whose only write is the PDF
file itself — no tool ever modifies tracked time data. Names and schemas are settled for
all five.

### The shared period argument (all of #1-#4)
Implemented in `Services/MCP/Tools/MCPPeriodArgument.swift` — see decisions #23-24 for the
reasoning. Three properties, merged into each tool's input schema:
```json
"period":     { "type": "string",
                "enum": ["today","this_week","last_week","this_month",
                         "last_month","this_year","all_time","custom"] },
"start_date": { "type": "string", "description": "Inclusive start, YYYY-MM-DD. Required when period is \"custom\"." },
"end_date":   { "type": "string", "description": "Inclusive end, YYYY-MM-DD. Required when period is \"custom\"." }
```
Names map onto `ReportPeriod` (`custom` ⇒ `.customRange`) and match tolerantly — case,
spaces, underscores and hyphens are normalised away. Custom ranges are inclusive at both
ends. Bad arguments return `isError: true` with a message naming the accepted values.
Responses echo `period` plus `startDate`/`endDate` as `yyyy-MM-dd`, both omitted for
`all_time`.

### 1. Time on a specific task — **IMPLEMENTED (Step 4)**
Search-first, because the caller only knows the task by rough name, not by `UUID`.

**Name**: `get_time_for_task`. Annotated `readOnlyHint: true`, `openWorldHint: false`.

**Input schema** — `query` (required) plus the shared period argument, which defaults to
`all_time` when absent. `additionalProperties: false`.
```json
{ "query": { "type": "string", "description": "Free text identifying the task…" },
  "period": …, "start_date": …, "end_date": … }
```
A missing or whitespace-only `query` is an **error** pointing at `get_time_for_period` —
otherwise `TaskSearch`'s match-everything rule would quietly do #2's job under a name that
promises one task's total.

**Search behavior**: `TaskSearch.filter(tasks, query:)`
(`TimeTracker/Utilities/TaskSearch.swift`) — the shared predicate the Main Window search
field uses, case-insensitive against **both title and description**. Archived tasks are
searched too (asking about a finished project is fair) and flagged with `isArchived`.
Matches sort descending by time, ties broken by title then id.

**Output** — one `.text` block of pretty-printed, key-sorted JSON. Three match counts,
three visibly different shapes (decision #25):
```
{ query, period, startDate?, endDate?, matchCount,
  matches: [{ id, title, description, isArchived,
              trackedTimeSeconds, trackedTimeFormatted }],
  combinedTrackedTimeSeconds?, combinedTrackedTimeFormatted?,   // only when matchCount > 1
  message?,                                                     // when 0 or >1 matched
  availableTaskCount?, availableTaskTitles? }                   // only when 0 matched
```
- **0 matches**: not an error. **No total field appears anywhere** — not even a zero — so
  there is nothing for the AI to report as an answer. `message` says not to guess, and
  `availableTaskTitles` offers up to 10 active titles
  (`TimeForTaskPayloadBuilder.maximumHintTitles`) for the follow-up question.
- **1 match**: that task and its total; no redundant `combined*`, no `message`.
- **2+ matches**: every match with its own total and id, plus the combined total and a
  `message` saying to report them all or ask which was meant — never to pick one.

### 2. Time in a date range (all tasks) — **IMPLEMENTED (Step 4)**
**Name**: `get_time_for_period`. Annotated `readOnlyHint: true`, `openWorldHint: false`.

**Input schema** — `period` (required) plus the rest of the shared period argument, and:
```json
"breakdown":         { "type": "string", "enum": ["total", "per_task"] },
"include_zero_time": { "type": "boolean" }
```
`breakdown` defaults to `total`; an unrecognised value falls back to it rather than erroring
(same forgiving rule as `ListTasksFilter`), and the response echoes what was applied.
`include_zero_time` defaults to false and only affects the `per_task` rows.

**Output**:
```
{ period, startDate?, endDate?, breakdown,
  totalTrackedTimeSeconds, totalTrackedTimeFormatted,   // always present, both breakdowns
  taskCount?, tasks? }                                  // per_task only
  // tasks: [{ id, title, isArchived, trackedTimeSeconds, trackedTimeFormatted }]
```
- The period total is present in **both** shapes, so the reader never has to add rows up,
  and it is computed over all tasks independently of which rows are listed (decision #26) —
  so the two breakdowns always report the same number and the rows always sum to it.
- `per_task` sorts descending by time (matching `ReportViewModel.recomputeRows()`), ties
  broken by title then id, and drops zero-time tasks unless `include_zero_time` is set.
- Archived tasks count and are flagged.
- Returns **raw** tracked time: no rounding, no hourly-rate amounts. That's #3's job, and
  both tool descriptions say so to keep the AI from misrouting.
- `today` and `this_week` are ordinary periods here — see decision #24 for why the
  `LocalStorageService` fast path was dropped.

### 3. Report / invoice-style breakdown — **IMPLEMENTED (Step 5)**
The numbers behind the PDF as structured data: rounding applied, rates resolved, amounts
computed. Runs through `DefaultReportBuilderService.buildReport(_:)` via `ReportRequest`'s
`preferences:` convenience init and serializes the resulting `ReportData`, so it cannot
disagree with the Report screen or the PDF.

**Name**: `get_billable_report`. Annotated `readOnlyHint: true`, `openWorldHint: false`.

Named for *billing* rather than "breakdown", because `get_time_for_period` already owns the
word `breakdown` as an argument value — the two would have collided on exactly the question
they need to be told apart on. Its description draws the line explicitly: this tool for
billing / invoicing / rates / amounts / rounded hours / "the report", `get_time_for_period`
for raw tracked time. Step 7 reviewed all five descriptions as a set and closed the
reverse pointer to `save_report_pdf` — see decision #38.

**Input schema** — `period` (required) plus the rest of the shared period argument, and:
```json
"include_zero_time":       { "type": "boolean" },
"include_daily_breakdown": { "type": "boolean" }
```
`additionalProperties: false`. Both default to **false** — `include_zero_time` matching the
Report screen's own toggle, `include_daily_breakdown` per decision #31. Malformed period
arguments return `isError: true` via `MCPPeriodArgument.Failure.message`; nothing else in
this tool is a caller error.

**Output**:
```
{ period, startDate?, endDate?,
  businessName?, currencySymbol, roundingMinutes,
  defaultHourlyRate?, defaultHourlyRateFormatted?, showAmountColumn,
  taskCount,
  tasks: [{ id, title,
            rawTimeSeconds, rawTimeFormatted,
            roundedTimeSeconds, roundedTimeFormatted,
            hourlyRate?, hourlyRateFormatted?,
            amount?, amountFormatted?,
            days? }],                                  // days only when asked for
            // days: [{ date, rawTimeSeconds, roundedTimeSeconds,
            //          roundedTimeFormatted, amount?, amountFormatted? }]
  totalRoundedTimeSeconds, totalRoundedTimeFormatted,
  totalAmount?, totalAmountFormatted?,
  note }                                               // always present
```
- Money appears **twice**: the exact `Double` the screen computed, and the
  `CurrencyFormatting.amount(_:symbol:)` string the PDF prints. Nothing is re-rounded or
  re-formatted, so neither can drift from the screen.
- `roundingMinutes` is `0` when rounding is off, so the caller can state what was applied.
- `rawTimeSeconds` per task is the same figure `get_time_for_period` reports, so the two
  tools can be reconciled. There is deliberately **no raw total** — the screen has no such
  number and #2 already answers that question.
- Tasks are descending by raw time, matching `ReportViewModel.recomputeRows()`; zero-time
  tasks are dropped unless asked for; day rows are ascending, dated `yyyy-MM-dd` in the
  report's calendar.
- `note` is always present — see decision #30 for why re-adding the rows is not safe.
- `businessName` is omitted when the preference is blank; `startDate`/`endDate` are omitted
  for `all_time`, as in #1/#2.

**Code**: `Services/MCP/Tools/ReportBreakdownTool.swift` (MCP envelope) +
`ReportBreakdownPayload.swift` (the `Encodable` payload, the pure
`ReportBreakdownPayloadBuilder`, and `ReportBreakdownPreferences`). Same split as the other
tools, so the tested logic holds no MCP types.

### 4. Generate PDF report and save to disk — **IMPLEMENTED (Step 6)**
The motivating use case: a skill that generates the report every month unattended, so
**this tool never shows a dialog of any kind**. The only tool on the server that writes
anything, and the reason the app gave up its App Sandbox (decision #6).

**Name**: `save_report_pdf`. Annotated `readOnlyHint: false`, `destructiveHint: false`,
`idempotentHint: false`, `openWorldHint: false` — it writes, but never replaces (decision
#33), and calling twice leaves two files rather than one.

Its description draws the line against #3 explicitly: **this one produces a file**, #3
returns the numbers. Triggers on "export", "save", "generate the PDF", or any named
destination. Reviewed as a set in Step 7 (decision #38); only `destination_path`'s own
description changed, gaining `~/Desktop` as the stated default when the caller names no place.

**Input schema** — `period` and `destination_path` both required, plus the rest of the
shared period argument, and:
```json
"destination_path": { "type": "string" },   // folder, or a full path ending in .pdf; ~ expanded
"filename":         { "type": "string" },   // folder form only; ".pdf" appended if missing
"task_query":       { "type": "string" }    // optional; TaskSearch, same as get_time_for_task
```
`additionalProperties: false`. Resolution rules are decision #32, collisions #33.

**Behavior**: identical to #3 up to the numbers — `TaskSearch.filter` (when `task_query` is
given) → `DefaultReportBuilderService.buildReport` with `includeZeroTime: false`, which is
the Report screen's own default → `makePDFConfig(for:presentation:)` with `businessName`
and `currencySymbol` read fresh from preferences → `CoreGraphicsReportPDFService.generatePDF`
→ write. No `NSSavePanel`, unlike the UI flow. Cheap failures are checked before the render,
so a bad destination never costs a PDF.

**Output**:
```
{ path, filename, directory,
  renamedToAvoidOverwrite, requestedFilename?,     // requestedFilename only when renamed
  period, startDate?, endDate?, taskQuery?,
  taskCount, totalRoundedTimeFormatted, totalAmountFormatted?,
  fileSizeBytes, note }
```
- `path` is where the file **actually landed**, which is not always where it was asked for
  — hence `note`, which tells the caller to report the path as given.
- The totals are carried in the PDF's own formatting so a skill can summarise what it
  produced without a second `get_billable_report` call. There are deliberately no per-task
  rows: that is #3's job, and this response is meant to stay small.
- `taskQuery` is echoed only when a filter was applied, so the caller can say what the
  document covers rather than implying it covers everything.

**Errors** — malformed period arguments (via `MCPPeriodArgument.Failure`), every
destination rule in decision #32, a failed write (carrying the OS's own message and the
path), and the two empty-report cases from decision #34.

**Code**: `Services/MCP/Tools/SaveReportPDFTool.swift` (MCP envelope) +
`SaveReportPDFPayload.swift` (payload + pure builder) + `ReportPDFDestination.swift` (the
pure path resolver) + `MCPFileWriting.swift` (the filesystem seam, so resolution is
testable without a real disk). Same split as the other tools.

### 5. List tasks / list tags — **IMPLEMENTED (Step 2)**
A discovery tool, so the AI can orient itself before querying rather than guessing. Its
main practical job is **disambiguation support for #1**: when a search returns several
matches or none, the AI can look at what actually exists and ask a sensible follow-up
question instead of inventing task names.

**Name**: `list_tasks_and_tags`. Annotated `readOnlyHint: true`, `openWorldHint: false`.

**Input schema** — one optional argument:
```json
{ "type": "object", "additionalProperties": false,
  "properties": { "include": { "type": "string", "enum": ["active", "archived", "all"] } } }
```
`include` defaults to `active`. A missing *or unrecognised* value falls back to `active`
rather than erroring, and the response echoes the filter actually applied.

**Output**: one `.text` content block holding pretty-printed, key-sorted JSON:
```
{ filter, taskCount, tagCount,
  tasks: [{ id, title, description, isArchived, tags: [name],
            totalTrackedTimeSeconds, totalTrackedTimeFormatted }],
  tags:  [{ id, name, colorHex }] }
```
- `id` is the task's `UUID` string, so a follow-up call can target it unambiguously.
- `description` is included because tool #1 searches against it as well as the title.
- `tagCount`/`tags` are unaffected by the `include` filter.
- Task order is storage order (`createdAt` descending, newest first) — no re-sorting.
- `totalTrackedTimeSeconds` is **all-time**, and counts a still-running entry up to now,
  so it can move between two calls. Same number the app's UI shows.

**Code**: `Services/MCP/Tools/ListTasksAndTagsTool.swift` (MCP envelope) +
`ListTasksAndTagsPayload.swift` (`ListTasksFilter`, the `Encodable` payload, and the pure
`ListTasksAndTagsPayloadBuilder`). The split keeps the tested logic free of MCP types.
Registered in `Services/MCP/MCPToolCatalog.swift`, alongside the other four.
Reads through `MCPDataReading` (decision #16), not `LocalStorageService` — but the queries
themselves are still just `fetchTasks()` / `fetchTags()`, no new logic.

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

## Known open items
The feature is shipped. Nothing about the tool surface, the docs or the skill is
outstanding. Two items remain, both **GUI interactions that cannot be driven headlessly**
and neither of which blocks anything:
- Confirm by hand that the Report screen's own `NSSavePanel` export still works now the
  sandbox is off. Carried since Step 6. The tool path writes fine and the two share
  `CoreGraphicsReportPDFService`, so the risk is confined to the save panel itself.
- Eyeball a tool-generated PDF side by side with one exported manually from the Report
  screen for the same period. `SaveReportPDFParityTests` already pins the `ReportPDFConfig`
  the two produce (decision #37), so this is confirmation, not investigation.

If the app is ever re-sandboxed, or `/Applications/TimeTracker.app` is refreshed, re-read
decisions #6, #15 and #42 first — those are the three that make writing a PDF with no dialog
possible, and all three fail quietly rather than loudly.

## Build order
The feature is broken into 7 sequential steps, with a ready-to-paste prompt for each,
in `.claude/mcp-server-build-steps.md` — one step per chat session, with a progress
checklist at the top of that file. This spec stays the source of truth; that file is
just the running order.

## How to use this file going forward
Start with **"How to work in this repo"** at the top — it covers building and testing via
the Xcode MCP server, how new files get picked up, and the code/test conventions to match.

Each future implementation session should read this file first for context, then
append/update sections here (especially "decisions made" and "open items") as more
of the design is settled or built, rather than re-deriving this discussion from
scratch. Keep it concise and current — prune resolved "open items" into "decisions
made" as they're settled, and note here once actual implementation (code, not just
design) begins.
