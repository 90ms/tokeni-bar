import Combine
import Foundation
import SwiftUI
import TokeniCore

struct CompanionCosmeticDecoration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPowerModeEnabled =
        ProcessInfo.processInfo.isLowPowerModeEnabled

    let cosmeticID: CompanionCosmeticID
    let dimension: CGFloat
    var animationsEnabled = true
    var motionIntensity = 1.0
    var lightBackground = false
    private let canvasDimension: CGFloat = 136

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 15.0,
            paused: !self.motionEnabled))
        { timeline in
            self.decoration(
                time: self.motionEnabled
                    ? timeline.date.timeIntervalSinceReferenceDate
                        * self.motionIntensity
                    : 0)
        }
        .frame(width: self.canvasDimension, height: self.canvasDimension)
        .scaleEffect(self.dimension / self.canvasDimension)
        .frame(width: self.dimension, height: self.dimension)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(
            for: .NSProcessInfoPowerStateDidChange))
        { _ in
            self.lowPowerModeEnabled =
                ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    @ViewBuilder
    private func decoration(time: TimeInterval) -> some View {
        let slowWave = CGFloat(sin(time * 2))
        ZStack {
            switch self.cosmeticID {
            case .sparkleAura:
                ZStack {
                    ForEach(Array(Self.sparklePoints.enumerated()), id: \.offset) {
                        index,
                        point in
                        let wave = (sin(time * 2.4 + Double(index) * 1.73) + 1) / 2
                        Image(systemName: index.isMultiple(of: 3)
                            ? "star.fill"
                            : "sparkle")
                            .font(.system(
                                size: self.canvasDimension
                                    * (0.065 + CGFloat(wave) * 0.055)))
                            .foregroundStyle(
                                self.sparkleColor(index: index))
                            .offset(
                                x: point.x * self.canvasDimension,
                                y: point.y * self.canvasDimension
                                    - CGFloat(wave) * self.canvasDimension * 0.035)
                            .opacity(0.12 + wave * 0.88)
                            .rotationEffect(.degrees(time * 18 + Double(index) * 29))
                    }
                }
            case .starCrown:
                ZStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: max(self.canvasDimension * 0.27, 12)))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow, .white, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing))
                        .shadow(color: .orange.opacity(0.45), radius: 2, y: 1)
                    Image(systemName: "sparkle")
                        .font(.system(size: self.canvasDimension * 0.09))
                        .foregroundStyle(.white)
                        .offset(
                            x: slowWave * self.canvasDimension * 0.12,
                            y: -self.canvasDimension * 0.08)
                        .opacity(0.35 + abs(slowWave) * 0.65)
                }
                .rotationEffect(.degrees(Double(slowWave) * 2.5))
                .offset(y: -self.canvasDimension * 0.39 + slowWave * 2)
            case .nightRing:
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.indigo, .cyan, .purple, .indigo],
                            center: .center),
                        style: StrokeStyle(
                            lineWidth: max(self.canvasDimension * 0.045, 2),
                            lineCap: .round,
                            dash: [
                                self.canvasDimension * 0.08,
                                self.canvasDimension * 0.04,
                            ]))
                    .frame(
                        width: self.canvasDimension * 0.92,
                        height: self.canvasDimension * 0.92)
                    .shadow(color: .indigo.opacity(0.5), radius: 3)
                    .rotationEffect(.degrees(time * 24))
                    .scaleEffect(1 + slowWave * 0.018)
            case .pixelHearts:
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        let progress = (time * 0.20 + Double(index) / 6)
                            .truncatingRemainder(dividingBy: 1)
                        let x = Self.heartX[index] * self.canvasDimension
                            + CGFloat(sin(time * 2 + Double(index))) * 3
                        Image(systemName: "heart.fill")
                            .font(.system(size: max(
                                self.canvasDimension
                                    * (0.075 + 0.04 * CGFloat(1 - progress)),
                                7)))
                            .foregroundStyle(index.isMultiple(of: 2) ? .pink : .red)
                            .offset(
                                x: x,
                                y: self.canvasDimension
                                    * (0.44 - CGFloat(progress) * 0.9))
                            .opacity(sin(progress * .pi))
                    }
                }
            case .developerHeadphones:
                ZStack {
                    Image(systemName: "headphones")
                        .font(.system(
                            size: max(self.canvasDimension * 0.34, 15),
                            weight: .bold))
                        .foregroundStyle(.cyan)
                        .shadow(color: .blue.opacity(0.55), radius: 2)
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index.isMultiple(of: 2) ? .cyan : .mint)
                            .frame(
                                width: 3,
                                height: self.canvasDimension
                                    * (0.05 + 0.035 * CGFloat(
                                        (sin(time * 5 + Double(index) * 1.4) + 1) / 2)))
                            .offset(
                                x: (CGFloat(index) - 1) * 7,
                                y: self.canvasDimension * 0.17)
                    }
                }
                .scaleEffect(x: 1, y: 1 + slowWave * 0.025)
                .offset(y: -self.canvasDimension * 0.22)
            case .wizardHat:
                ZStack {
                    PixelHatTriangle()
                        .fill(.purple)
                        .frame(
                            width: self.canvasDimension * 0.42,
                            height: self.canvasDimension * 0.32)
                    Rectangle()
                        .fill(.indigo)
                        .frame(
                            width: self.canvasDimension * 0.52,
                            height: max(self.canvasDimension * 0.07, 3))
                        .offset(y: self.canvasDimension * 0.14)
                    Image(systemName: "star.fill")
                        .font(.system(size: max(self.canvasDimension * 0.09, 6)))
                        .foregroundStyle(.yellow)
                        .offset(y: -self.canvasDimension * 0.02)
                        .scaleEffect(0.8 + abs(slowWave) * 0.35)
                        .rotationEffect(.degrees(time * 45))
                }
                .rotationEffect(.degrees(Double(slowWave) * 2))
                .offset(y: -self.canvasDimension * 0.39)
            case .terminalNight:
                ZStack {
                    RoundedRectangle(cornerRadius: self.canvasDimension * 0.12)
                        .fill(.black.opacity(0.72))
                    ForEach(1..<4, id: \.self) { index in
                        Rectangle()
                            .fill(.green.opacity(0.12))
                            .frame(width: 1)
                            .offset(
                                x: (CGFloat(index) - 2) * self.canvasDimension * 0.2)
                        Rectangle()
                            .fill(.green.opacity(0.12))
                            .frame(height: 1)
                            .offset(
                                y: (CGFloat(index) - 2) * self.canvasDimension * 0.2)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(
                            size: max(self.canvasDimension * 0.12, 7),
                            weight: .bold))
                        .foregroundStyle(.green.opacity(0.55))
                        .offset(
                            x: -self.canvasDimension * 0.31,
                            y: self.canvasDimension * 0.30)
                        .opacity(0.35 + abs(slowWave) * 0.55)
                    Rectangle()
                        .fill(.green.opacity(0.22))
                        .frame(height: 2)
                        .offset(y: self.canvasDimension
                            * (-0.42 + 0.84 * CGFloat(
                                (time * 0.18).truncatingRemainder(dividingBy: 1))))
                }
                .padding(self.canvasDimension * 0.03)
            case .cloudGarden:
                ZStack {
                    RoundedRectangle(cornerRadius: self.canvasDimension * 0.18)
                        .fill(LinearGradient(
                            colors: [.cyan.opacity(0.34), .blue.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom))
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: max(self.canvasDimension * 0.18, 9)))
                        .foregroundStyle(.yellow.opacity(0.8))
                        .offset(
                            x: self.canvasDimension * 0.27,
                            y: -self.canvasDimension * 0.27)
                    HStack(spacing: -self.canvasDimension * 0.06) {
                        Image(systemName: "cloud.fill")
                        Image(systemName: "cloud.fill")
                    }
                    .font(.system(size: max(self.canvasDimension * 0.24, 12)))
                    .foregroundStyle(.white.opacity(0.72))
                    .offset(
                        x: slowWave * self.canvasDimension * 0.08,
                        y: self.canvasDimension * 0.30)
                }
                .padding(self.canvasDimension * 0.03)
            case .azurePalette:
                Circle()
                    .fill(LinearGradient(
                        colors: [.cyan, .blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(
                        width: self.canvasDimension * 0.64,
                        height: self.canvasDimension * 0.64)
                    .overlay {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: self.canvasDimension * 0.24))
                            .foregroundStyle(.white)
                    }
                    .rotationEffect(.degrees(Double(slowWave) * 2))
            case .violetPalette:
                Circle()
                    .fill(LinearGradient(
                        colors: [.pink, .purple, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(
                        width: self.canvasDimension * 0.64,
                        height: self.canvasDimension * 0.64)
                    .overlay {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: self.canvasDimension * 0.24))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(1 + slowWave * 0.015)
            }
        }
    }

    private var motionEnabled: Bool {
        self.animationsEnabled
            && self.motionIntensity > 0
            && !self.reduceMotion
            && !self.lowPowerModeEnabled
    }

    private func sparkleColor(index: Int) -> Color {
        if self.lightBackground {
            return index.isMultiple(of: 2) ? .orange : .purple
        }
        return index.isMultiple(of: 2) ? .yellow : .white
    }

    private static let sparklePoints: [CGPoint] = [
        CGPoint(x: -0.41, y: -0.24),
        CGPoint(x: 0.34, y: -0.38),
        CGPoint(x: -0.31, y: 0.31),
        CGPoint(x: 0.43, y: 0.18),
        CGPoint(x: -0.07, y: -0.47),
        CGPoint(x: 0.13, y: 0.43),
        CGPoint(x: -0.47, y: 0.04),
        CGPoint(x: 0.48, y: -0.09),
    ]
    private static let heartX: [CGFloat] = [-0.40, -0.22, 0.04, 0.32, 0.43, -0.05]
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
