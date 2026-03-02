import Foundation

enum TimeRoundingInterval: String, CaseIterable, Identifiable {
    case none = "none"
    case fiveMinutes = "5"
    case fifteenMinutes = "15"
    case thirtyMinutes = "30"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .fiveMinutes: return "5 min"
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .none: return 0
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        }
    }

    init(rawString: String) {
        self = TimeRoundingInterval(rawValue: rawString) ?? .none
    }
}

extension TimeInterval {
    func rounded(to interval: TimeRoundingInterval) -> TimeInterval {
        guard interval != .none else { return self }
        let intervalSeconds = interval.seconds
        guard intervalSeconds > 0 else { return self }
        return (self / intervalSeconds).rounded() * intervalSeconds
    }
}
