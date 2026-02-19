import Foundation
import ServiceManagement

@Observable
@MainActor
final class SettingsViewModel {
    private let userPreferences: UserPreferencesService
    private let localStorage: LocalStorageService
    private let reminderService: TrackingReminderService

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
        reminderService: TrackingReminderService
    ) {
        self.userPreferences = userPreferences
        self.localStorage = localStorage
        self.reminderService = reminderService
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

        trackingReminderEnabled = userPreferences.trackingReminderEnabled
        let savedSeconds = userPreferences.trackingReminderTime
        trackingReminderTime = Self.dateFromSeconds(savedSeconds)
        trackingReminderDays = Set(userPreferences.trackingReminderDays)

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
