import Foundation

extension TimeInterval {
    /// Formats a time interval as "Xh Ym" (e.g., "12h 30m", "0h 00m")
    var formattedHoursMinutes: String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let minutes = abs(totalMinutes % 60)
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }
}
