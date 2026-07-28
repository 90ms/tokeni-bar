import Foundation
import SwiftUI
import TokeniCore

extension CompanionCosmeticID {
    var systemImage: String {
        switch self {
        case .sparkleAura: "sparkles"
        case .starCrown: "crown.fill"
        case .nightRing: "moon.stars.fill"
        }
    }
}

struct CompanionCosmeticDecoration: View {
    let cosmeticID: CompanionCosmeticID
    let dimension: CGFloat

    var body: some View {
        Group {
            switch self.cosmeticID {
            case .sparkleAura:
                ZStack {
                    Circle()
                        .stroke(.yellow.opacity(0.35), lineWidth: 2)
                        .frame(
                            width: self.dimension * 0.88,
                            height: self.dimension * 0.88)
                    ForEach(0..<6, id: \.self) { index in
                        let angle = Double(index) * .pi / 3
                        Image(systemName: "sparkle")
                            .font(.system(size: max(self.dimension * 0.12, 7)))
                            .foregroundStyle(.yellow)
                            .offset(
                                x: CGFloat(cos(angle)) * self.dimension * 0.48,
                                y: CGFloat(sin(angle)) * self.dimension * 0.48)
                    }
                }
            case .starCrown:
                Image(systemName: "crown.fill")
                    .font(.system(size: max(self.dimension * 0.27, 12)))
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange.opacity(0.45), radius: 2, y: 1)
                    .offset(y: -self.dimension * 0.39)
            case .nightRing:
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.indigo, .cyan, .purple, .indigo],
                            center: .center),
                        style: StrokeStyle(
                            lineWidth: max(self.dimension * 0.045, 2),
                            lineCap: .round,
                            dash: [self.dimension * 0.08, self.dimension * 0.04]))
                    .frame(
                        width: self.dimension * 0.92,
                        height: self.dimension * 0.92)
                    .shadow(color: .indigo.opacity(0.5), radius: 3)
            }
        }
        .frame(width: self.dimension, height: self.dimension)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
