import Foundation

@MainActor
final class TimerServiceHolder {
    static var shared: TimerService?
}
