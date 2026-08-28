import Foundation
import ServiceManagement

@Observable
@MainActor
final class SettingsViewModel {
    private let userPreferences: UserPreferencesService
    private let localStorage: LocalStorageService
    private let reminderService: TrackingReminderService
    private let mcpServer: MCPServerService

    // MARK: - General

    var businessName: String = "" {
        didSet {
            guard businessName != oldValue else { return }
            userPreferences.setBusinessName(businessName)
        }
    }

    var defaultHourlyRateText: String = "" {
        didSet {
            guard defaultHourlyRateText != oldValue else { return }
            if defaultHourlyRateText.isEmpty {
                userPreferences.setDefaultHourlyRate(nil)
            } else if let value = Double(defaultHourlyRateText), value >= 0 {
                userPreferences.setDefaultHourlyRate(value)
            }
        }
    }

    var selectedCurrency: CurrencyOption = .usd {
        didSet {
            guard selectedCurrency != oldValue else { return }
            if selectedCurrency != .custom {
                userPreferences.setCurrencySymbol(selectedCurrency.symbol)
                userPreferences.setCurrencyCode(selectedCurrency.code)
            } else {
                userPreferences.setCurrencyCode("CUSTOM")
                if !customCurrencySymbol.isEmpty {
                    userPreferences.setCurrencySymbol(customCurrencySymbol)
                }
            }
        }
    }

    var customCurrencySymbol: String = "" {
        didSet {
            guard customCurrencySymbol != oldValue, selectedCurrency == .custom else { return }
            userPreferences.setCurrencySymbol(customCurrencySymbol)
        }
    }

    var selectedTimeRounding: TimeRoundingInterval = .none {
        didSet {
            guard selectedTimeRounding != oldValue else { return }
            userPreferences.setTimeRounding(selectedTimeRounding.rawValue)
        }
    }

    var launchAtLogin: Bool = false {
        didSet {
            guard launchAtLogin != oldValue else { return }
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    // MARK: - Idle Detection

    var idleTimeoutMinutes: Int = 10 {
        didSet {
            let clamped = min(60, max(1, idleTimeoutMinutes))
            if clamped != idleTimeoutMinutes {
                idleTimeoutMinutes = clamped
                return
            }
            guard idleTimeoutMinutes != oldValue else { return }
            userPreferences.setIdleTimeoutMinutes(idleTimeoutMinutes)
        }
    }

    // MARK: - Heatmap

    var targetDailyHours: Int = 8 {
        didSet {
            let clamped = min(24, max(1, targetDailyHours))
            if clamped != targetDailyHours {
                targetDailyHours = clamped
                return
            }
            guard targetDailyHours != oldValue else { return }
            userPreferences.setTargetDailyHours(TimeInterval(targetDailyHours) * 3600)
        }
    }

    var subtractIdleTime: Bool = false {
        didSet {
            guard subtractIdleTime != oldValue else { return }
            userPreferences.setSubtractIdleTimeFromTrackedTime(subtractIdleTime)
        }
    }

    // MARK: - Notifications

    var trackingReminderEnabled: Bool = false {
        didSet {
            guard trackingReminderEnabled != oldValue else { return }
            userPreferences.setTrackingReminderEnabled(trackingReminderEnabled)
            if trackingReminderEnabled {
                (reminderService as? DefaultTrackingReminderService)?.requestPermissionIfNeeded()
            }
            reminderService.rescheduleNotifications()
        }
    }

    var trackingReminderTime: Date = SettingsViewModel.defaultReminderDate() {
        didSet {
            guard trackingReminderTime != oldValue else { return }
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: trackingReminderTime)
            let seconds = TimeInterval((components.hour ?? 9) * 3600 + (components.minute ?? 0) * 60)
            userPreferences.setTrackingReminderTime(seconds)
            reminderService.rescheduleNotifications()
        }
    }

    var trackingReminderDays: Set<Int> = [2, 3, 4, 5, 6] {
        didSet {
            guard trackingReminderDays != oldValue else { return }
            userPreferences.setTrackingReminderDays(Array(trackingReminderDays).sorted())
            reminderService.rescheduleNotifications()
        }
    }

    // MARK: - MCP Server

    /// Starts at the same value production defaults to, so `loadSettings()` on a fresh
    /// install doesn't flip it and fire a pointless rebind through `didSet`.
    var mcpServerEnabled: Bool = UserDefaultsUserPreferencesService.defaultMCPServerEnabled {
        didSet {
            guard mcpServerEnabled != oldValue else { return }
            userPreferences.setMCPServerEnabled(mcpServerEnabled)
            applyMCPServerPreferences()
        }
    }

    /// Free text until the user commits it with Apply — typing must never rebind a socket,
    /// and a half-typed port ("8", "84") must never be persisted.
    var mcpServerPortText: String = "" {
        didSet {
            guard mcpServerPortText != oldValue else { return }
            portValidationError = nil
        }
    }

    private(set) var portValidationError: String?

    /// The Apply button is live only while the field differs from what's actually saved.
    var hasPendingPortChange: Bool {
        mcpServerPortText.trimmingCharacters(in: .whitespaces) != String(userPreferences.mcpServerPort)
    }

    /// Always built from the *saved* port, so an uncommitted edit can't display a URL that
    /// nothing is listening on.
    var mcpServerURL: String {
        MCPServerConfiguration.url(port: userPreferences.mcpServerPort)
    }

    /// The config block for clients that are set up by pasting JSON rather than by running a
    /// command. Built from the *saved* port for the same reason `mcpServerURL` is — an
    /// uncommitted edit must never hand out a config pointing at a port nothing is bound to.
    var mcpServerConfigJSON: String {
        MCPServerConfiguration.clientConfigurationJSON(port: userPreferences.mcpServerPort)
    }

    var mcpServerStatusText: String {
        guard mcpServerEnabled else { return "Not running" }
        switch mcpServer.status {
        case .running(let port):
            return "Running on port \(port)"
        case .stopped:
            return "Stopped"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    var mcpServerStatusIsError: Bool {
        guard mcpServerEnabled else { return false }
        if case .failed = mcpServer.status { return true }
        return false
    }

    var mcpServerIsRunning: Bool {
        if case .running = mcpServer.status { return true }
        return false
    }

    /// Validates the typed port and, only if it's usable, persists it and rebinds.
    func applyPort() {
        let trimmed = mcpServerPortText.trimmingCharacters(in: .whitespaces)

        guard let port = Int(trimmed), !trimmed.isEmpty else {
            portValidationError = "Enter a port number."
            return
        }

        guard MCPServerConfiguration.validPortRange.contains(port) else {
            portValidationError = "Port must be between \(MCPServerConfiguration.validPortRange.lowerBound) and \(MCPServerConfiguration.validPortRange.upperBound). Ports below \(MCPServerConfiguration.validPortRange.lowerBound) are reserved."
            return
        }

        portValidationError = nil
        mcpServerPortText = String(port)
        userPreferences.setMCPServerPort(port)
        applyMCPServerPreferences()
    }

    /// Re-attempts the bind after a failure, without the user having to change anything.
    func retryMCPServer() {
        applyMCPServerPreferences()
    }

    /// Retained only so tests can await the rebind deterministically — the UI never reads it.
    @ObservationIgnored private(set) var pendingMCPServerUpdate: Task<Void, Never>?

    private func applyMCPServerPreferences() {
        pendingMCPServerUpdate = Task { @MainActor [mcpServer] in
            await mcpServer.applyPreferences()
        }
    }

    // MARK: - Tags

    private(set) var tags: [TagItem] = []
    var editingTagId: UUID?
    var editingTagName: String = ""
    var editingTagColorHex: String = ""
    var isAddingTag: Bool = false
    var newTagName: String = ""
    var newTagColorHex: String = "FF3B30"
    var tagValidationError: String?
    var tagToDelete: TagItem?

    // MARK: - Init

    init(
        userPreferences: UserPreferencesService,
        localStorage: LocalStorageService,
        reminderService: TrackingReminderService,
        mcpServer: MCPServerService
    ) {
        self.userPreferences = userPreferences
        self.localStorage = localStorage
        self.reminderService = reminderService
        self.mcpServer = mcpServer
    }

    func loadSettings() {
        businessName = userPreferences.businessName

        if let rate = userPreferences.defaultHourlyRate {
            defaultHourlyRateText = rate.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", rate)
                : String(format: "%.2f", rate)
        } else {
            defaultHourlyRateText = ""
        }

        let code = userPreferences.currencyCode
        selectedCurrency = CurrencyOption.from(code: code)
        if selectedCurrency == .custom {
            customCurrencySymbol = userPreferences.currencySymbol
        }

        selectedTimeRounding = TimeRoundingInterval(rawString: userPreferences.timeRounding)
        launchAtLogin = SMAppService.mainApp.status == .enabled

        idleTimeoutMinutes = userPreferences.idleTimeoutMinutes
        subtractIdleTime = userPreferences.subtractIdleTimeFromTrackedTime

        targetDailyHours = Int(userPreferences.targetDailyHours / 3600)

        trackingReminderEnabled = userPreferences.trackingReminderEnabled
        let savedSeconds = userPreferences.trackingReminderTime
        trackingReminderTime = Self.dateFromSeconds(savedSeconds)
        trackingReminderDays = Set(userPreferences.trackingReminderDays)

        // Assigning the toggle here can fire its didSet, but applyPreferences() is
        // idempotent — a server already running on the configured port stays untouched.
        mcpServerEnabled = userPreferences.mcpServerEnabled
        mcpServerPortText = String(userPreferences.mcpServerPort)
        portValidationError = nil

        loadTags()
    }

    func loadTags() {
        tags = localStorage.fetchTags()
    }

    // MARK: - Tag CRUD

    func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            tagValidationError = "Tag name cannot be empty."
            return
        }

        if tags.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            tagValidationError = "A tag named '\(trimmed)' already exists."
            return
        }

        tagValidationError = nil
        localStorage.createTag(name: trimmed, colorHex: newTagColorHex)
        newTagName = ""
        newTagColorHex = "FF3B30"
        isAddingTag = false
        loadTags()
    }

    func startEditing(tag: TagItem) {
        editingTagId = tag.id
        editingTagName = tag.name
        editingTagColorHex = tag.colorHex
        tagValidationError = nil
    }

    func saveEditingTag() {
        guard let editId = editingTagId else { return }
        let trimmed = editingTagName.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            tagValidationError = "Tag name cannot be empty."
            return
        }

        if tags.contains(where: { $0.id != editId && $0.name.lowercased() == trimmed.lowercased() }) {
            tagValidationError = "A tag named '\(trimmed)' already exists."
            return
        }

        tagValidationError = nil
        localStorage.updateTag(id: editId, name: trimmed, colorHex: editingTagColorHex)
        editingTagId = nil
        editingTagName = ""
        editingTagColorHex = ""
        loadTags()
    }

    func cancelEditing() {
        editingTagId = nil
        editingTagName = ""
        editingTagColorHex = ""
        tagValidationError = nil
    }

    func deleteTag(id: UUID) {
        localStorage.deleteTag(id: id)
        tagToDelete = nil
        loadTags()
    }

    // MARK: - Private Helpers

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    static func defaultReminderDate() -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    static func dateFromSeconds(_ seconds: TimeInterval) -> Date {
        let hour = Int(seconds) / 3600
        let minute = (Int(seconds) % 3600) / 60
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
