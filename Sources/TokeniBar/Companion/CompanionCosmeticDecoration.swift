import Foundation
import SwiftUI
import TokeniCore

extension CompanionCosmeticID {
    var systemImage: String {
        switch self {
        case .sparkleAura: "sparkles"
        case .starCrown: "crown.fill"
        case .nightRing: "moon.stars.fill"
        case .pixelHearts: "heart.circle.fill"
        case .developerHeadphones: "headphones"
        case .wizardHat: "wand.and.stars"
        case .terminalNight: "terminal.fill"
        case .cloudGarden: "cloud.sun.fill"
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
            case .pixelHearts:
                ZStack {
                    ForEach(0..<5, id: \.self) { index in
                        let angle = Double(index) * .pi * 2 / 5 - .pi / 2
                        Image(systemName: "heart.fill")
                            .font(.system(size: max(self.dimension * 0.11, 7)))
                            .foregroundStyle(index.isMultiple(of: 2) ? .pink : .red)
                            .offset(
                                x: CGFloat(cos(angle)) * self.dimension * 0.48,
                                y: CGFloat(sin(angle)) * self.dimension * 0.45)
                    }
                }
            case .developerHeadphones:
                Image(systemName: "headphones")
                    .font(.system(size: max(self.dimension * 0.34, 15), weight: .bold))
                    .foregroundStyle(.cyan)
                    .shadow(color: .blue.opacity(0.55), radius: 2)
                    .offset(y: -self.dimension * 0.22)
            case .wizardHat:
                ZStack {
                    PixelHatTriangle()
                        .fill(.purple)
                        .frame(
                            width: self.dimension * 0.42,
                            height: self.dimension * 0.32)
                    Rectangle()
                        .fill(.indigo)
                        .frame(
                            width: self.dimension * 0.52,
                            height: max(self.dimension * 0.07, 3))
                        .offset(y: self.dimension * 0.14)
                    Image(systemName: "star.fill")
                        .font(.system(size: max(self.dimension * 0.09, 6)))
                        .foregroundStyle(.yellow)
                        .offset(y: -self.dimension * 0.02)
                }
                .offset(y: -self.dimension * 0.39)
            case .terminalNight:
                ZStack {
                    RoundedRectangle(cornerRadius: self.dimension * 0.12)
                        .fill(.black.opacity(0.72))
                    ForEach(1..<4, id: \.self) { index in
                        Rectangle()
                            .fill(.green.opacity(0.12))
                            .frame(width: 1)
                            .offset(x: (CGFloat(index) - 2) * self.dimension * 0.2)
                        Rectangle()
                            .fill(.green.opacity(0.12))
                            .frame(height: 1)
                            .offset(y: (CGFloat(index) - 2) * self.dimension * 0.2)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: max(self.dimension * 0.12, 7), weight: .bold))
                        .foregroundStyle(.green.opacity(0.55))
                        .offset(
                            x: -self.dimension * 0.31,
                            y: self.dimension * 0.30)
                }
                .padding(self.dimension * 0.03)
            case .cloudGarden:
                ZStack {
                    RoundedRectangle(cornerRadius: self.dimension * 0.18)
                        .fill(LinearGradient(
                            colors: [.cyan.opacity(0.34), .blue.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom))
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: max(self.dimension * 0.18, 9)))
                        .foregroundStyle(.yellow.opacity(0.8))
                        .offset(
                            x: self.dimension * 0.27,
                            y: -self.dimension * 0.27)
                    HStack(spacing: -self.dimension * 0.06) {
                        Image(systemName: "cloud.fill")
                        Image(systemName: "cloud.fill")
                    }
                    .font(.system(size: max(self.dimension * 0.24, 12)))
                    .foregroundStyle(.white.opacity(0.72))
                    .offset(y: self.dimension * 0.30)
                }
                .padding(self.dimension * 0.03)
            }
        }
        .frame(width: self.dimension, height: self.dimension)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PixelHatTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
