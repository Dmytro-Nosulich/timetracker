import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let timerService = TimerServiceHolder.shared,
              timerService.state == .running else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Timer is running"
        alert.informativeText = "A timer is currently running. Quit anyway?"
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

    @MainActor
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Tracker")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Time Tracker", action: #selector(quitApp), keyEquivalent: ""))
        statusItem?.menu = menu
    }

    @MainActor
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
