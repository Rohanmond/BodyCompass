import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(red: 0.00, green: 0.55, blue: 0.45)
    static let blue = Color(red: 0.12, green: 0.48, blue: 0.92)
    static let orange = Color(red: 0.95, green: 0.48, blue: 0.12)
    static let indigo = Color(red: 0.36, green: 0.38, blue: 0.86)
    static let coral = Color(red: 0.90, green: 0.28, blue: 0.32)
    static let cyan = Color(red: 0.00, green: 0.62, blue: 0.72)
    static let violet = Color(red: 0.52, green: 0.32, blue: 0.78)
    static let warning = Color(red: 0.78, green: 0.36, blue: 0.10)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let elevatedSurface = Color(.tertiarySystemGroupedBackground)
    static let background = Color(.systemGroupedBackground)
    static let border = Color.primary.opacity(0.08)
}

struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    var systemImage: String = "circle"
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14))
                .clipShape(Circle())
            Text(value)
                .font(.title2.bold())
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(minHeight: 142, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(caption)
    }
}

extension View {
    func keyboardDismissible() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

private struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded { dismissKeyboard() },
                including: .gesture
            )
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .fontWeight(.semibold)
                }
            }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
