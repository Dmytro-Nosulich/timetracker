import Testing
import Foundation
@testable import TimeTracker

@MainActor
struct SettingsViewModelTests {

    private func makeViewModel() -> (SettingsViewModel, MockUserPreferencesService, MockLocalStorageService, MockTrackingReminderService) {
        let prefs = MockUserPreferencesService()
        let storage = MockLocalStorageService()
        let reminder = MockTrackingReminderService()
        let vm = SettingsViewModel(userPreferences: prefs, localStorage: storage, reminderService: reminder)
        return (vm, prefs, storage, reminder)
    }

    // MARK: - Load Settings

    @Test func loadSettingsPopulatesBusinessName() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedBusinessName = "Acme Corp"
        vm.loadSettings()
        #expect(vm.businessName == "Acme Corp")
    }

    @Test func loadSettingsPopulatesDefaultHourlyRate() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedDefaultHourlyRate = 75.0
        vm.loadSettings()
        #expect(vm.defaultHourlyRateText == "75")
    }

    @Test func loadSettingsPopulatesDefaultHourlyRateNil() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedDefaultHourlyRate = nil
        vm.loadSettings()
        #expect(vm.defaultHourlyRateText == "")
    }

    @Test func loadSettingsPopulatesDecimalRate() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedDefaultHourlyRate = 49.99
        vm.loadSettings()
        #expect(vm.defaultHourlyRateText == "49.99")
    }

    @Test func loadSettingsPopulatesCurrencyUSD() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedCurrencyCode = "USD"
        prefs.stubbedCurrencySymbol = "$"
        vm.loadSettings()
        #expect(vm.selectedCurrency == .usd)
    }

    @Test func loadSettingsPopulatesCurrencyCustom() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedCurrencyCode = "CUSTOM"
        prefs.stubbedCurrencySymbol = "₴"
        vm.loadSettings()
        #expect(vm.selectedCurrency == .custom)
        #expect(vm.customCurrencySymbol == "₴")
    }

    @Test func loadSettingsPopulatesTimeRounding() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedTimeRounding = "15"
        vm.loadSettings()
        #expect(vm.selectedTimeRounding == .fifteenMinutes)
    }

    @Test func loadSettingsPopulatesIdleTimeout() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedIdleTimeoutMinutes = 20
        vm.loadSettings()
        #expect(vm.idleTimeoutMinutes == 20)
    }

    @Test func loadSettingsPopulatesSubtractIdleTime() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedSubtractIdleTimeFromTrackedTime = true
        vm.loadSettings()
        #expect(vm.subtractIdleTime == true)
    }

    @Test func loadSettingsPopulatesTrackingReminder() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedTrackingReminderEnabled = true
        prefs.stubbedTrackingReminderDays = [2, 4, 6]
        vm.loadSettings()
        #expect(vm.trackingReminderEnabled == true)
        #expect(vm.trackingReminderDays == Set([2, 4, 6]))
    }

    @Test func loadSettingsLoadsTags() {
        let (vm, _, storage, _) = makeViewModel()
        storage.stubbedTags = [
            TagItem(id: UUID(), name: "Work", colorHex: "FF0000", createdAt: Date())
        ]
        vm.loadSettings()
        #expect(vm.tags.count == 1)
        #expect(vm.tags.first?.name == "Work")
    }

    // MARK: - Auto-Save Business Name

    @Test func changingBusinessNameSavesToPreferences() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.businessName = "New Name"
        #expect(prefs.setBusinessNameCallCount == 1)
        #expect(prefs.setBusinessNameLastValue == "New Name")
    }

    // MARK: - Auto-Save Hourly Rate

    @Test func changingRateTextSavesValidDouble() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.defaultHourlyRateText = "100"
        #expect(prefs.setDefaultHourlyRateCallCount >= 1)
        #expect(prefs.stubbedDefaultHourlyRate == 100.0)
    }

    @Test func clearingRateTextSavesNil() {
        let (vm, prefs, _, _) = makeViewModel()
        prefs.stubbedDefaultHourlyRate = 50.0
        vm.loadSettings()
        prefs.setDefaultHourlyRateCallCount = 0

        vm.defaultHourlyRateText = ""
        #expect(prefs.setDefaultHourlyRateCallCount == 1)
    }

    // MARK: - Currency

    @Test func selectingCurrencySavesSymbolAndCode() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.selectedCurrency = .eur
        #expect(prefs.setCurrencySymbolLastValue == "€")
        #expect(prefs.setCurrencyCodeLastValue == "EUR")
    }

    @Test func selectingCustomCurrencySavesCode() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.selectedCurrency = .custom
        #expect(prefs.setCurrencyCodeLastValue == "CUSTOM")
    }

    @Test func changingCustomSymbolSavesWhenCustomSelected() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.selectedCurrency = .custom
        vm.customCurrencySymbol = "₴"
        #expect(prefs.setCurrencySymbolLastValue == "₴")
    }

    // MARK: - Time Rounding

    @Test func changingTimeRoundingSaves() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.selectedTimeRounding = .thirtyMinutes
        #expect(prefs.setTimeRoundingLastValue == "30")
    }

    // MARK: - Idle Timeout

    @Test func changingIdleTimeoutSaves() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.idleTimeoutMinutes = 15
        #expect(prefs.setIdleTimeoutMinutesLastValue == 15)
    }

    @Test func idleTimeoutClampedToMinimum() {
        let (vm, _, _, _) = makeViewModel()
        vm.loadSettings()
        vm.idleTimeoutMinutes = 0
        #expect(vm.idleTimeoutMinutes == 1)
    }

    @Test func idleTimeoutClampedToMaximum() {
        let (vm, _, _, _) = makeViewModel()
        vm.loadSettings()
        vm.idleTimeoutMinutes = 100
        #expect(vm.idleTimeoutMinutes == 60)
    }

    // MARK: - Subtract Idle Time

    @Test func changingSubtractIdleTimeSaves() {
        let (vm, prefs, _, _) = makeViewModel()
        vm.loadSettings()
        vm.subtractIdleTime = true
        #expect(prefs.setSubtractIdleTimeFromTrackedTimeLastValue == true)
    }

    // MARK: - Tracking Reminder

    @Test func enablingReminderSavesAndReschedules() {
        let (vm, prefs, _, reminder) = makeViewModel()
        vm.loadSettings()
        let countBefore = reminder.rescheduleNotificationsCallCount
        vm.trackingReminderEnabled = true
        #expect(prefs.setTrackingReminderEnabledLastValue == true)
        #expect(reminder.rescheduleNotificationsCallCount == countBefore + 1)
    }

    @Test func disablingReminderSavesAndReschedules() {
        let (vm, prefs, _, reminder) = makeViewModel()
        prefs.stubbedTrackingReminderEnabled = true
        vm.loadSettings()
        let countBefore = reminder.rescheduleNotificationsCallCount
        vm.trackingReminderEnabled = false
        #expect(prefs.setTrackingReminderEnabledLastValue == false)
        #expect(reminder.rescheduleNotificationsCallCount == countBefore + 1)
    }

    @Test func changingReminderDaysReschedules() {
        let (vm, _, _, reminder) = makeViewModel()
        vm.loadSettings()
        let countBefore = reminder.rescheduleNotificationsCallCount
        vm.trackingReminderDays = [2, 3]
        #expect(reminder.rescheduleNotificationsCallCount == countBefore + 1)
    }

    // MARK: - Tag CRUD

    @Test func addTagCreatesAndReloads() {
        let (vm, _, storage, _) = makeViewModel()
        vm.loadSettings()
        vm.isAddingTag = true
        vm.newTagName = "Design"
        vm.newTagColorHex = "007AFF"
        vm.addTag()

        #expect(storage.createTagCallCount == 1)
        #expect(storage.createTagLastName == "Design")
        #expect(storage.createTagLastColorHex == "007AFF")
        #expect(vm.isAddingTag == false)
        #expect(vm.newTagName == "")
    }

    @Test func addTagEmptyNameShowsError() {
        let (vm, _, storage, _) = makeViewModel()
        vm.loadSettings()
        vm.isAddingTag = true
        vm.newTagName = "   "
        vm.addTag()

        #expect(storage.createTagCallCount == 0)
        #expect(vm.tagValidationError != nil)
    }

    @Test func addTagDuplicateNameShowsError() {
        let (vm, _, storage, _) = makeViewModel()
        storage.stubbedTags = [
            TagItem(id: UUID(), name: "Work", colorHex: "FF0000", createdAt: Date())
        ]
        vm.loadSettings()
        vm.isAddingTag = true
        vm.newTagName = "work"
        vm.addTag()

        #expect(storage.createTagCallCount == 0)
        #expect(vm.tagValidationError != nil)
    }

    @Test func editTagSavesChanges() {
        let tagId = UUID()
        let (vm, _, storage, _) = makeViewModel()
        storage.stubbedTags = [
            TagItem(id: tagId, name: "Old", colorHex: "FF0000", createdAt: Date())
        ]
        vm.loadSettings()
        vm.startEditing(tag: vm.tags.first!)
        vm.editingTagName = "New"
        vm.editingTagColorHex = "00FF00"
        vm.saveEditingTag()

        #expect(storage.updateTagCallCount == 1)
        #expect(storage.updateTagLastName == "New")
        #expect(storage.updateTagLastColorHex == "00FF00")
        #expect(vm.editingTagId == nil)
    }

    @Test func editTagDuplicateNameShowsError() {
        let id1 = UUID()
        let id2 = UUID()
        let (vm, _, storage, _) = makeViewModel()
        storage.stubbedTags = [
            TagItem(id: id1, name: "Work", colorHex: "FF0000", createdAt: Date()),
            TagItem(id: id2, name: "Play", colorHex: "00FF00", createdAt: Date()),
        ]
        vm.loadSettings()
        vm.startEditing(tag: vm.tags.last!)
        vm.editingTagName = "Work"
        vm.saveEditingTag()

        #expect(storage.updateTagCallCount == 0)
        #expect(vm.tagValidationError != nil)
    }

    @Test func editTagSameNameAllowed() {
        let tagId = UUID()
        let (vm, _, storage, _) = makeViewModel()
        storage.stubbedTags = [
            TagItem(id: tagId, name: "Work", colorHex: "FF0000", createdAt: Date())
        ]
        vm.loadSettings()
        vm.startEditing(tag: vm.tags.first!)
        vm.editingTagName = "Work"
        vm.editingTagColorHex = "00FF00"
        vm.saveEditingTag()

        #expect(storage.updateTagCallCount == 1)
        #expect(vm.tagValidationError == nil)
    }

    @Test func deleteTagCallsStorageAndReloads() {
        let tagId = UUID()
        let (vm, _, storage, _) = makeViewModel()
        storage.stubbedTags = [
            TagItem(id: tagId, name: "ToDelete", colorHex: "FF0000", createdAt: Date())
        ]
        vm.loadSettings()
        #expect(vm.tags.count == 1)

        vm.deleteTag(id: tagId)

        #expect(storage.deleteTagCallCount == 1)
        #expect(storage.deleteTagLastId == tagId)
        #expect(vm.tags.isEmpty)
    }

    @Test func cancelEditingClearsState() {
        let tagId = UUID()
        let (vm, _, storage, _) = makeViewModel()
        storage.stubbedTags = [
            TagItem(id: tagId, name: "Tag", colorHex: "FF0000", createdAt: Date())
        ]
        vm.loadSettings()
        vm.startEditing(tag: vm.tags.first!)
        #expect(vm.editingTagId == tagId)

        vm.cancelEditing()
        #expect(vm.editingTagId == nil)
        #expect(vm.editingTagName == "")
        #expect(vm.tagValidationError == nil)
    }
}
