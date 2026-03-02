import SwiftUI

struct BottomStatusBar: View {
    let totalToday: TimeInterval

    var body: some View {
        HStack {
            Spacer()
            Text("Total today: \(totalToday.formattedHoursMinutes)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
