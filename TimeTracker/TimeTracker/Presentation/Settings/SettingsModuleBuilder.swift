import SwiftUI

enum SettingsModuleBuilder {
    @MainActor
    static func build(
        localStorageService: LocalStorageService,
        userPreferencesService: UserPreferencesService,
        reminderService: TrackingReminderService,
        mcpServerService: MCPServerService
    ) -> some View {
        let viewModel = SettingsViewModel(
            userPreferences: userPreferencesService,
            localStorage: localStorageService,
            reminderService: reminderService,
            mcpServer: mcpServerService
        )
        return SettingsView(viewModel: viewModel)
    }
}
