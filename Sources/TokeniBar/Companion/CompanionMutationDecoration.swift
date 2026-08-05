import SwiftUI
import TokeniCore

struct CompanionMutationDecoration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let mutationID: CompanionMutationID
    let dimension: CGFloat
    let animationsEnabled: Bool
    let motionIntensity: Double

    @State private var rotating = false

    var body: some View {
        ZStack {
            switch self.mutationID.rawValue {
            case "neon":
                self.neon
            case "shadow":
                self.shadow
            case "crystal":
                self.crystal
            case "glitch":
                self.glitch
            case "aurora":
                self.aurora
            default:
                EmptyView()
            }
        }
        .frame(width: self.dimension * 1.28, height: self.dimension * 1.28)
        .rotationEffect(.degrees(self.rotating ? 8 : -8))
        .animation(
            self.motionEnabled
                ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                : .linear(duration: 0.01),
            value: self.rotating)
        .onAppear {
            self.rotating = self.motionEnabled
        }
        .onChange(of: self.motionEnabled) { _, enabled in
            self.rotating = enabled
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var motionEnabled: Bool {
        self.animationsEnabled
            && self.motionIntensity > 0
            && !self.reduceMotion
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var neon: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.9), lineWidth: max(2, self.dimension * 0.035))
                .blur(radius: self.dimension * 0.08)
            Circle()
                .stroke(Color.pink.opacity(0.9), lineWidth: max(1, self.dimension * 0.015))
                .padding(self.dimension * 0.09)
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "bolt.fill")
                    .font(.system(size: max(8, self.dimension * 0.12)))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.cyan : Color.pink)
                    .offset(y: -self.dimension * 0.54)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
        }
    }

    private var shadow: some View {
        ZStack {
            Circle()
                .fill(Color.indigo.opacity(0.25))
                .blur(radius: self.dimension * 0.12)
            Circle()
                .stroke(Color.indigo.opacity(0.85), lineWidth: max(2, self.dimension * 0.03))
                .padding(self.dimension * 0.08)
            Circle()
                .stroke(Color.black.opacity(0.55), lineWidth: max(1, self.dimension * 0.014))
                .padding(self.dimension * 0.17)
        }
        .shadow(color: .black.opacity(0.5), radius: self.dimension * 0.12)
    }

    private var crystal: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: max(1, self.dimension * 0.018))
                .padding(self.dimension * 0.1)
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "diamond.fill")
                    .font(.system(size: max(8, self.dimension * 0.11)))
                    .foregroundStyle(
                        index.isMultiple(of: 2) ? Color.cyan : Color.white)
                    .offset(y: -self.dimension * 0.51)
                    .rotationEffect(.degrees(Double(index) * 72))
            }
        }
        .shadow(color: .cyan.opacity(0.75), radius: self.dimension * 0.1)
    }

    private var glitch: some View {
        ZStack {
            RoundedRectangle(cornerRadius: self.dimension * 0.18)
                .stroke(Color.red.opacity(0.8), lineWidth: max(1, self.dimension * 0.025))
                .offset(x: self.dimension * 0.08)
            RoundedRectangle(cornerRadius: self.dimension * 0.18)
                .stroke(Color.blue.opacity(0.8), lineWidth: max(1, self.dimension * 0.025))
                .offset(x: -self.dimension * 0.08)
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 2) ? Color.red : Color.blue)
                    .frame(
                        width: self.dimension * 0.24,
                        height: max(1, self.dimension * 0.02))
                    .offset(
                        x: CGFloat(index - 1) * self.dimension * 0.18,
                        y: CGFloat(index.isMultiple(of: 2) ? -1 : 1)
                            * self.dimension * 0.34)
            }
        }
    }

    private var aurora: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [.mint, .cyan, .purple, .pink, .yellow, .mint],
                    center: .center),
                lineWidth: max(3, self.dimension * 0.05))
            .blur(radius: self.dimension * 0.025)
            .shadow(color: .mint.opacity(0.7), radius: self.dimension * 0.12)
    }
}
