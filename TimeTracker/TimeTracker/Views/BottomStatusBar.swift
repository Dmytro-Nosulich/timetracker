import SwiftUI

struct BottomStatusBar: View {
    let totalToday: TimeInterval
    let totalThisWeek: TimeInterval

    var body: some View {
        HStack {
            Spacer()
            Text("This week: \(totalThisWeek.formattedHoursMinutes)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider().frame(height: 12)
            Text("Total today: \(totalToday.formattedHoursMinutes)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
