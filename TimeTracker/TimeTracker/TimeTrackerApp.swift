import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let sharedModelContainer: ModelContainer
    let localStorageService: SwiftDataLocalStorageService
    let timerService: DefaultTimerService

    init() {
        let schema = Schema([
            TaskEntity.self,
            TimeEntryEntity.self,
            TagEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        let localStorage = SwiftDataLocalStorageService(modelContext: sharedModelContainer.mainContext)
        self.localStorageService = localStorage

        let timer = DefaultTimerService(localStorage: localStorage)
        self.timerService = timer

        TimerServiceHolder.shared = timer
        timer.recoverFromCrashIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowModuleBuilder.build(
                localStorageService: localStorageService,
                timerService: timerService
            )
            .frame(minWidth: 500, minHeight: 400)
        }
        .defaultSize(width: 700, height: 500)
        .windowResizability(.contentMinSize)

        Window("Timer", id: "timer-window") {
            TimerWindowModuleBuilder.build(
                localStorageService: localStorageService,
                timerService: timerService
            )
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 280)
    }
}
