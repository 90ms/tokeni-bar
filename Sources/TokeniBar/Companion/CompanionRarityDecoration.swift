import Foundation
import SwiftUI
import TokeniCore

struct CompanionRarityDecoration: View {
    let speciesID: CompanionSpeciesID?
    let rarity: CompanionRarity
    let dimension: CGFloat

    var body: some View {
        Group {
            switch self.rarity {
            case .normal:
                EmptyView()
            case .rare:
                self.rareAura
            case .epic:
                self.epicAura
            case .legendary:
                self.legendaryAura
            }
        }
        .frame(width: self.dimension, height: self.dimension)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var rareAura: some View {
        ZStack {
            Circle()
                .stroke(
                    self.primaryColor.opacity(0.72),
                    style: StrokeStyle(
                        lineWidth: max(self.dimension * 0.025, 1),
                        dash: [self.dimension * 0.08, self.dimension * 0.06]))
                .frame(
                    width: self.dimension * 0.84,
                    height: self.dimension * 0.84)

            ForEach(0..<2, id: \.self) { index in
                self.sparkle(index: index, count: 2, radius: 0.47)
                    .foregroundStyle(self.secondaryColor)
            }
        }
    }

    private var epicAura: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            self.primaryColor,
                            .purple,
                            self.secondaryColor,
                            self.primaryColor,
                        ],
                        center: .center),
                    lineWidth: max(self.dimension * 0.035, 1.5))
                .frame(
                    width: self.dimension * 0.88,
                    height: self.dimension * 0.88)
                .shadow(
                    color: self.primaryColor.opacity(0.55),
                    radius: self.dimension * 0.055)

            ForEach(0..<5, id: \.self) { index in
                self.sparkle(index: index, count: 5, radius: 0.49)
                    .foregroundStyle(
                        index.isMultiple(of: 2)
                            ? self.secondaryColor
                            : Color.purple)
            }
        }
    }

    private var legendaryAura: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .yellow,
                            self.primaryColor,
                            .orange,
                            self.secondaryColor,
                            .yellow,
                        ],
                        center: .center),
                    lineWidth: max(self.dimension * 0.045, 2))
                .frame(
                    width: self.dimension * 0.9,
                    height: self.dimension * 0.9)
                .shadow(
                    color: .yellow.opacity(0.72),
                    radius: self.dimension * 0.07)

            Circle()
                .stroke(.yellow.opacity(0.42), lineWidth: 1)
                .frame(
                    width: self.dimension * 0.72,
                    height: self.dimension * 0.72)

            ForEach(0..<8, id: \.self) { index in
                self.sparkle(index: index, count: 8, radius: 0.5)
                    .foregroundStyle(
                        index.isMultiple(of: 2)
                            ? Color.yellow
                            : self.secondaryColor)
            }

            Image(systemName: "diamond.fill")
                .font(.system(size: max(self.dimension * 0.11, 5)))
                .foregroundStyle(.yellow)
                .shadow(color: .orange.opacity(0.7), radius: 1)
                .offset(y: -self.dimension * 0.47)
        }
    }

    private func sparkle(
        index: Int,
        count: Int,
        radius: CGFloat) -> some View
    {
        let angle = Double(index) * .pi * 2 / Double(count) - .pi / 2
        return Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "diamond.fill")
            .font(.system(size: max(self.dimension * 0.075, 4)))
            .offset(
                x: CGFloat(cos(angle)) * self.dimension * radius,
                y: CGFloat(sin(angle)) * self.dimension * radius)
    }

    private var primaryColor: Color {
        switch self.speciesID ?? .bytebot {
        case .bytebot: .mint
        case .cachecat: .orange
        case .stackfox: .red
        case .promptpup: .green
        case .nullslime: .purple
        }
    }

    private var secondaryColor: Color {
        switch self.speciesID ?? .bytebot {
        case .bytebot: .cyan
        case .cachecat: .cyan
        case .stackfox: .yellow
        case .promptpup: .mint
        case .nullslime: .cyan
        }
    }
}
