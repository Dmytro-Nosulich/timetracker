import SwiftUI

enum SettingsModuleBuilder {
    @MainActor
    static func build(
        localStorageService: LocalStorageService,
        userPreferencesService: UserPreferencesService,
        reminderService: TrackingReminderService
    ) -> some View {
        let viewModel = SettingsViewModel(
            userPreferences: userPreferencesService,
            localStorage: localStorageService,
            reminderService: reminderService
        )
        return SettingsView(viewModel: viewModel)
    }
}
