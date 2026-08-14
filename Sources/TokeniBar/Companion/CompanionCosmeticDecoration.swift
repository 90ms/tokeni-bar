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
    var isBackground = false
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
        .scaleEffect(
            self.dimension / self.canvasDimension
                * (self.isBackground ? 1.10 : 1))
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
            case .nightRing:
                EmptyView()
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
            case .fireflyAura:
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        let angle = time * 0.55 + Double(index) * .pi / 4
                        Circle()
                            .fill(index.isMultiple(of: 2) ? .yellow : .mint)
                            .frame(width: 5, height: 5)
                            .shadow(color: .yellow, radius: 3)
                            .offset(
                                x: cos(angle) * self.canvasDimension * 0.4,
                                y: sin(angle * 1.3) * self.canvasDimension * 0.35)
                    }
                }
            case .orbitAura:
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        let angle = time * 0.7 + Double(index) * 2 * .pi / 3
                        Circle()
                            .fill([Color.cyan, .purple, .orange][index])
                            .frame(width: 8, height: 8)
                            .shadow(
                                color: [Color.cyan, .purple, .orange][index]
                                    .opacity(0.65),
                                radius: 3)
                            .offset(
                                x: cos(angle) * self.canvasDimension * 0.45,
                                y: sin(angle) * self.canvasDimension * 0.23)
                    }
                }
            case .cloudCushion:
                ZStack {
                    Capsule()
                        .fill(.blue.opacity(0.18))
                        .frame(
                            width: self.canvasDimension * 0.72,
                            height: self.canvasDimension * 0.17)
                        .blur(radius: 2)
                    HStack(spacing: -self.canvasDimension * 0.08) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "cloud.fill")
                                .font(.system(
                                    size: self.canvasDimension
                                        * (index == 1 ? 0.25 : 0.20)))
                                .foregroundStyle(index == 1
                                    ? Color.white.opacity(0.92)
                                    : Color.cyan.opacity(0.72))
                        }
                    }
                    Image(systemName: "heart.fill")
                        .font(.system(size: self.canvasDimension * 0.075))
                        .foregroundStyle(.pink)
                        .offset(
                            x: self.canvasDimension * 0.25,
                            y: -self.canvasDimension * 0.08)
                        .scaleEffect(1 + abs(slowWave) * 0.12)
                }
                .offset(y: self.canvasDimension * 0.34)
            case .hologramPlatform:
                ZStack {
                    Capsule()
                        .fill(.cyan.opacity(0.12))
                        .frame(
                            width: self.canvasDimension * 0.72,
                            height: self.canvasDimension * 0.17)
                        .shadow(color: .cyan.opacity(0.8), radius: 6)
                    Capsule()
                        .stroke(.cyan.opacity(0.85), lineWidth: 2)
                        .frame(
                            width: self.canvasDimension * 0.72,
                            height: self.canvasDimension * 0.17)
                    Capsule()
                        .stroke(.purple.opacity(0.7), lineWidth: 1)
                        .frame(
                            width: self.canvasDimension * 0.48,
                            height: self.canvasDimension * 0.09)
                    ForEach(0..<5, id: \.self) { index in
                        Rectangle()
                            .fill(index.isMultiple(of: 2) ? .cyan : .purple)
                            .frame(width: 3, height: 3)
                            .offset(
                                x: (CGFloat(index) - 2)
                                    * self.canvasDimension * 0.105,
                                y: -self.canvasDimension
                                    * (0.09 + 0.02 * CGFloat(
                                        sin(time * 2 + Double(index)))))
                    }
                }
                .offset(y: self.canvasDimension * 0.35)
            case .meadowPatch:
                ZStack {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.green.opacity(0.78), .mint.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing))
                        .frame(
                            width: self.canvasDimension * 0.76,
                            height: self.canvasDimension * 0.18)
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index.isMultiple(of: 2)
                            ? "camera.macro"
                            : "leaf.fill")
                            .font(.system(size: self.canvasDimension * 0.085))
                            .foregroundStyle(index.isMultiple(of: 2)
                                ? Color.pink
                                : Color.green)
                            .offset(
                                x: (CGFloat(index) - 2)
                                    * self.canvasDimension * 0.14,
                                y: -self.canvasDimension
                                    * (0.08 + 0.018 * CGFloat(
                                        sin(time * 1.7 + Double(index)))))
                            .rotationEffect(.degrees(
                                Double(slowWave) * 4 + Double(index - 2) * 2))
                    }
                }
                .offset(y: self.canvasDimension * 0.35)
            case .miniDrone:
                ZStack {
                    HStack(spacing: self.canvasDimension * 0.17) {
                        ForEach(0..<2, id: \.self) { _ in
                            Capsule()
                                .fill(.cyan.opacity(0.85))
                                .frame(
                                    width: self.canvasDimension * 0.17,
                                    height: 3)
                                .rotationEffect(.degrees(time * 180))
                        }
                    }
                    RoundedRectangle(cornerRadius: self.canvasDimension * 0.045)
                        .fill(LinearGradient(
                            colors: [.indigo, .cyan],
                            startPoint: .top,
                            endPoint: .bottom))
                        .frame(
                            width: self.canvasDimension * 0.22,
                            height: self.canvasDimension * 0.16)
                        .overlay {
                            HStack(spacing: self.canvasDimension * 0.035) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 3, height: 3)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 3, height: 3)
                            }
                        }
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: self.canvasDimension * 0.07))
                        .foregroundStyle(.cyan)
                        .offset(y: -self.canvasDimension * 0.12)
                }
                .offset(
                    x: self.canvasDimension * 0.39,
                    y: -self.canvasDimension * 0.10
                        + slowWave * self.canvasDimension * 0.025)
            case .starSprite:
                ZStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: self.canvasDimension * 0.25))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.75), radius: 5)
                    HStack(spacing: self.canvasDimension * 0.035) {
                        Circle()
                            .fill(.indigo)
                            .frame(width: 3, height: 4)
                        Circle()
                            .fill(.indigo)
                            .frame(width: 3, height: 4)
                    }
                    .offset(y: -self.canvasDimension * 0.012)
                    Image(systemName: "sparkle")
                        .font(.system(size: self.canvasDimension * 0.08))
                        .foregroundStyle(.white)
                        .offset(
                            x: -self.canvasDimension * 0.13,
                            y: -self.canvasDimension * 0.13)
                }
                .rotationEffect(.degrees(Double(slowWave) * 4))
                .offset(
                    x: self.canvasDimension * 0.38,
                    y: -self.canvasDimension * 0.17
                        + slowWave * self.canvasDimension * 0.025)
            case .pixelChick:
                ZStack {
                    Circle()
                        .fill(.yellow)
                        .frame(
                            width: self.canvasDimension * 0.23,
                            height: self.canvasDimension * 0.23)
                        .overlay {
                            HStack(spacing: self.canvasDimension * 0.045) {
                                Circle()
                                    .fill(.brown)
                                    .frame(width: 3, height: 4)
                                Circle()
                                    .fill(.brown)
                                    .frame(width: 3, height: 4)
                            }
                            .offset(y: -self.canvasDimension * 0.025)
                        }
                    Image(systemName: "diamond.fill")
                        .font(.system(size: self.canvasDimension * 0.055))
                        .foregroundStyle(.orange)
                        .offset(y: self.canvasDimension * 0.025)
                    HStack(spacing: self.canvasDimension * 0.17) {
                        ForEach(0..<2, id: \.self) { _ in
                            Capsule()
                                .fill(.orange.opacity(0.85))
                                .frame(
                                    width: self.canvasDimension * 0.07,
                                    height: self.canvasDimension * 0.035)
                        }
                    }
                    .offset(y: self.canvasDimension * 0.065)
                }
                .offset(
                    x: -self.canvasDimension * 0.39,
                    y: self.canvasDimension * 0.24
                        + abs(slowWave) * self.canvasDimension * 0.018)
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
            case .sunsetGrid:
                RoundedRectangle(cornerRadius: self.canvasDimension * 0.16)
                    .fill(LinearGradient(
                        colors: [.purple.opacity(0.45), .orange.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom))
                    .overlay {
                        Image(systemName: "sun.horizon.fill")
                            .font(.system(size: self.canvasDimension * 0.5))
                            .foregroundStyle(.orange.opacity(0.55))
                    }
                    .padding(self.canvasDimension * 0.03)
            case .pixelForest:
                RoundedRectangle(cornerRadius: self.canvasDimension * 0.16)
                    .fill(LinearGradient(
                        colors: [.indigo.opacity(0.35), .green.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom))
                    .overlay {
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { _ in
                                Image(systemName: "tree.fill")
                            }
                        }
                        .font(.system(size: self.canvasDimension * 0.18))
                        .foregroundStyle(.green.opacity(0.55))
                        .offset(y: self.canvasDimension * 0.22)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: self.canvasDimension * 0.16))
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
