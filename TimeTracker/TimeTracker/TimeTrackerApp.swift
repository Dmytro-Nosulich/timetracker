import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskEntity.self,
            TimeEntryEntity.self,
            TagEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainWindowModuleBuilder.build(
                localStorageService: SwiftDataLocalStorageService(
                    modelContext: sharedModelContainer.mainContext
                )
            )
            .frame(minWidth: 500, minHeight: 400)
        }
        .defaultSize(width: 700, height: 500)
        .windowResizability(.contentMinSize)
    }
}
