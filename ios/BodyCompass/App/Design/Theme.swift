import SwiftUI

enum Theme {
    static let accent = Color(red: 0.02, green: 0.45, blue: 0.38)
    static let warning = Color(red: 0.78, green: 0.36, blue: 0.10)
    static let surface = Color(.secondarySystemBackground)
    static let background = Color(.systemBackground)
}

struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    var systemImage: String = "circle"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
