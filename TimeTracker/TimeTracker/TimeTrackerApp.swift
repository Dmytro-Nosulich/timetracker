import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var taskDetailCoordinator = TaskDetailCoordinator()

    let sharedModelContainer: ModelContainer
    let localStorageService: SwiftDataLocalStorageService
    let timerService: DefaultTimerService
    let userPreferencesService: UserPreferencesService
    let idleMonitorService: DefaultIdleMonitorService
    let trackingReminderService: DefaultTrackingReminderService

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
        LocalStorageServiceHolder.shared = localStorage

        let preferences = UserDefaultsUserPreferencesService()
        self.userPreferencesService = preferences

        let timer = DefaultTimerService(localStorage: localStorage, userPreferences: preferences)
        self.timerService = timer

        TimerServiceHolder.shared = timer
        timer.recoverFromCrashIfNeeded()

        let idleMonitor = DefaultIdleMonitorService(timerService: timer, userPreferences: preferences, localStorage: localStorage)
        self.idleMonitorService = idleMonitor
        idleMonitor.start()

        let reminder = DefaultTrackingReminderService(userPreferences: preferences, timerService: timer)
        self.trackingReminderService = reminder
        reminder.rescheduleNotifications()
    }

    var body: some Scene {
        Window("Main", id: "main-window") {
            MainWindowModuleBuilder.build(
                localStorageService: localStorageService,
                timerService: timerService,
                coordinator: taskDetailCoordinator
            )
            .frame(minWidth: 500, minHeight: 400)
        }
        .defaultSize(width: 700, height: 500)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: Set(["main-window"]))

        Window("Timer", id: "timer-window") {
            TimerWindowModuleBuilder.build(
                localStorageService: localStorageService,
                timerService: timerService
            )
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 280)
        .handlesExternalEvents(matching: Set(["timer-window"]))

        Window("Task Details", id: "task-detail") {
            TaskDetailWindowContent(
                container: sharedModelContainer,
                coordinator: taskDetailCoordinator,
                userPreferencesService: userPreferencesService
            )
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 700)

        Window("Report", id: "report-window") {
            ReportModuleBuilder.build(
                localStorageService: localStorageService,
                userPreferencesService: userPreferencesService
            )
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 700, height: 600)

        Settings {
            SettingsModuleBuilder.build(
                localStorageService: localStorageService,
                userPreferencesService: userPreferencesService,
                reminderService: trackingReminderService
            )
        }
    }
}
