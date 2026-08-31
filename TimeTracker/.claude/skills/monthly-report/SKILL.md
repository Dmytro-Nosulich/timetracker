---
name: monthly-report
description: Generate the TimeTracker PDF report for a month and save it to the Desktop. Use when asked for "my monthly report", "generate my report", "this month's PDF", "last month's invoice report", or when running the scheduled monthly report job. Defaults to the current month; accepts a period argument.
allowed-tools: mcp__timetracker__save_report_pdf, mcp__timetracker__get_billable_report
---

# Monthly report

Produces the TimeTracker PDF report and saves it to `~/Desktop`, with no dialogs and no
questions asked — this runs unattended on a schedule, so it must complete or fail cleanly
without waiting on anyone.

## 1. Work out the period

Read the argument the skill was invoked with:

| Invoked as | `period` | Notes |
|---|---|---|
| `/monthly-report` | `this_month` | **The default.** No argument means the current month. |
| `/monthly-report last month` | `last_month` | What the scheduled job passes. |
| `/monthly-report july` / `/monthly-report July 2026` | `custom` | Also pass `start_date` and `end_date` as `YYYY-MM-DD`, first and last day inclusive. Assume the current year when none is given. |
| `/monthly-report 2026-07-01 to 2026-07-15` | `custom` | Pass the two dates through as given. |

Anything else the user says that names a period the tool already understands — `this_week`,
`last_week`, `this_year`, `all_time` — pass straight through. The tool matches tolerantly
(case, spaces, underscores and hyphens are all ignored), so hand it the user's own wording
rather than re-deriving date ranges yourself.

## 2. Check the server is there

The tools live inside the running TimeTracker app. If `mcp__timetracker__save_report_pdf`
is not available, the app is not running.

**Say so and stop.** Do not estimate the figures from anywhere else, do not read the
database directly, and do not report a number you did not get from the tool. The correct
output in that case is:

> TimeTracker is not running, so no report was generated. Start the app and run this again.

## 3. Generate the PDF

Call `mcp__timetracker__save_report_pdf` **once**:

```json
{ "period": "this_month", "destination_path": "~/Desktop" }
```

Leave `filename` out — the app names the file itself (`Time Report - August 2026.pdf`).
Leave `task_query` out unless the user explicitly asked to limit the report to particular
tasks.

## 4. Report what it produced

Read these fields straight off the tool's response and repeat them **exactly as given**:

- `path` — where the file actually landed. This is not always where it was asked to go: if
  the name was taken, the report saved alongside the old one as `… (2).pdf` and
  `renamedToAvoidOverwrite` is `true`. Always report `path`, never the name you requested.
- `taskCount`, `totalRoundedTimeFormatted`, `totalAmountFormatted`.

Do **not** re-add rows, re-round anything, or re-format the money. Those are invoice
figures; the app has already computed them the way the user's Report screen and their
client's invoice will show them. A "corrected" total here is a wrong invoice.

A good summary looks like:

> Saved **Time Report - August 2026.pdf** to the Desktop — <taskCount> tasks,
> <totalRoundedTimeFormatted>, <totalAmountFormatted>.

Mention the rename only when `renamedToAvoidOverwrite` is `true`:

> The August name was already taken, so this saved as **Time Report - August 2026 (2).pdf**.

## 5. If it fails, say why — don't work around it

The tool returns a message naming the fix. Pass that on and stop. In particular:

- **"No tracked time in this period"** — that is the answer. The month is genuinely empty.
  **Never** retry with a different period to produce a file; a report labelled with the
  wrong month is worse than no report.
- **No task matched `task_query`** — report it. Don't broaden the filter and hand over a
  document covering more than was asked for.
- **A destination problem** — the message names it. Don't try other paths.

Never call the tool a second time to "get a better answer". Two calls mean two PDFs.
