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
