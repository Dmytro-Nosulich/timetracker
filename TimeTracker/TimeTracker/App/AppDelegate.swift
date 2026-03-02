import AppKit

private enum MenuAction: Int {
    case pause
    case resume
    case openMainWindow
    case openTimerWindow
    case quit
}

@preconcurrency
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var iconUpdateTimer: Timer?
    private var lastIconState: TimerState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        startIconUpdateTimer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
            return false
        } else {
            sender.activate(ignoringOtherApps: true)
            return true
        }
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let timerService = TimerServiceHolder.shared,
              timerService.state == .running else {
            return .terminateNow
        }

        let taskName: String
        if let taskId = timerService.currentTaskId, let storage = LocalStorageServiceHolder.shared, let task = storage.fetchTask(id: taskId) {
            taskName = task.title
        } else {
            taskName = "current task"
        }

        let alert = NSAlert()
        alert.messageText = "Timer is running"
        alert.informativeText = "A timer is currently running for '\(taskName)'. Quit anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save & Quit")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            timerService.saveAndStop()
            return .terminateNow
        }
        return .terminateCancel
    }

    // MARK: - Status Bar

    @MainActor
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    private func startIconUpdateTimer() {
        iconUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusIconIfNeeded()
            }
        }
    }

    @MainActor
    private func updateStatusIconIfNeeded() {
        guard let timerService = TimerServiceHolder.shared else { return }
        let state = timerService.state
        if state != lastIconState {
            lastIconState = state
            updateStatusIcon()
        }
    }

    @MainActor
    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let state = TimerServiceHolder.shared?.state ?? .idle

        switch state {
        case .running:
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Tracker")
            button.contentTintColor = .systemGreen
        case .pausedByUser:
            button.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "Time Tracker")
            button.contentTintColor = .secondaryLabelColor
        case .pausedByInactivity:
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Tracker")
            button.contentTintColor = .systemOrange
        case .idle:
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Tracker")
            button.contentTintColor = nil
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        buildMenu(menu)
    }

    @MainActor
    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let timerService = TimerServiceHolder.shared else {
            menu.addItem(NSMenuItem(title: "Quit Time Tracker", action: #selector(quitApp), keyEquivalent: "q"))
            return
        }
        let storage = LocalStorageServiceHolder.shared
        let state = timerService.state
        let taskName: String = {
            guard let taskId = timerService.currentTaskId, let storage = storage, let task = storage.fetchTask(id: taskId) else {
                return NSLocalizedString("Unknown task", comment: "")
            }
            return task.title
        }()
        let todayTotal = storage?.totalTrackedTimeToday() ?? 0
        let sessionElapsed = timerService.sessionElapsed

        switch state {
        case .running:
            menu.addItem(NSMenuItem(title: "● \(taskName)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Session: \(sessionElapsed.formattedHoursMinutes)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Today: \(todayTotal.formattedHoursMinutes)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            addMenuItem(menu, title: "⏸ Pause", action: .pause)
        case .pausedByUser:
            menu.addItem(NSMenuItem(title: "⏸ \(taskName) (paused)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Today: \(todayTotal.formattedHoursMinutes)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            addMenuItem(menu, title: "▶ Resume", action: .resume)
        case .pausedByInactivity:
            let inactiveMinutes: Int
            if let pauseDate = timerService.inactivityPauseDate {
                inactiveMinutes = max(1, Int(Date().timeIntervalSince(pauseDate) / 60))
            } else {
                inactiveMinutes = 0
            }
            menu.addItem(NSMenuItem(title: "⚠ \(taskName) (paused)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Inactive for \(inactiveMinutes)m", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Today: \(todayTotal.formattedHoursMinutes)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            addMenuItem(menu, title: "▶ Resume", action: .resume)
        case .idle:
            menu.addItem(NSMenuItem(title: "No active timer", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Today: \(todayTotal.formattedHoursMinutes)", action: nil, keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        addMenuItem(menu, title: "Open Main Window", action: .openMainWindow)
        if state != .idle {
            addMenuItem(menu, title: "Open Timer Window", action: .openTimerWindow)
        }
        menu.addItem(NSMenuItem.separator())
        addMenuItem(menu, title: "Quit Time Tracker", action: .quit)
    }

    private func addMenuItem(_ menu: NSMenu, title: String, action: MenuAction) {
        let item = NSMenuItem(title: title, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
        item.target = self
        item.tag = action.rawValue
        menu.addItem(item)
    }

    @MainActor
    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        guard let action = MenuAction(rawValue: sender.tag) else { return }
        switch action {
        case .pause:
            TimerServiceHolder.shared?.pauseTimer()
        case .resume:
            TimerServiceHolder.shared?.resumeTimer()
        case .openMainWindow:
            openMainWindow()
        case .openTimerWindow:
            openTimerWindow()
        case .quit:
            quitApp()
        }
    }

    private func openMainWindow() {
        if let url = URL(string: "timetracker://main-window") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openTimerWindow() {
        if let url = URL(string: "timetracker://timer-window") {
            NSWorkspace.shared.open(url)
        }
    }

	@MainActor
	@objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
