import SwiftUI

enum TokeniLayout {
    static let compactSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 12
    static let cornerRadius: CGFloat = 10
    static let minimumIconButtonSize: CGFloat = 28
}

enum TokeniStatusKind {
    case information
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .information: .accentColor
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }

    var systemImage: String {
        switch self {
        case .information: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

struct TokeniStatusBanner: View {
    let text: String
    let kind: TokeniStatusKind

    var body: some View {
        Label(self.text, systemImage: self.kind.systemImage)
            .font(.caption)
            .foregroundStyle(self.kind.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                self.kind.color.opacity(0.1),
                in: RoundedRectangle(
                    cornerRadius: TokeniLayout.cornerRadius - 2))
            .accessibilityElement(children: .combine)
    }
}

struct TokeniMetricTile: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let systemImage {
                Label(self.title, systemImage: systemImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(self.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(self.value)
                .font(.headline)
                .foregroundStyle(self.tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            .quaternary.opacity(0.45),
            in: RoundedRectangle(
                cornerRadius: TokeniLayout.cornerRadius - 2))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func tokeniIconButtonTarget() -> some View {
        self.frame(
            minWidth: TokeniLayout.minimumIconButtonSize,
            minHeight: TokeniLayout.minimumIconButtonSize)
            .contentShape(Rectangle())
    }
}
