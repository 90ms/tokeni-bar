import TokeniCore
import AppKit
import SwiftUI

struct ProviderIcon: View {
    @MainActor private static var imageCache: [String: NSImage] = [:]

    let descriptor: ProviderDescriptor
    var dimension: CGFloat = 16

    var body: some View {
        Group {
            if let iconAssetName = self.descriptor.iconAssetName,
               let image = Self.loadImage(named: iconAssetName)
            {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: self.descriptor.systemImage)
            }
        }
        .frame(width: self.dimension, height: self.dimension)
        .accessibilityHidden(true)
    }

    private static func loadImage(named name: String) -> NSImage? {
        if let cachedImage = self.imageCache[name] {
            return cachedImage
        }

        let packagedURL = Bundle.main.url(
            forResource: name,
            withExtension: "svg",
            subdirectory: "BrandIcons")
        let developmentURL: URL?
        if packagedURL == nil,
           Bundle.main.bundleURL.pathExtension.lowercased() != "app"
        {
            developmentURL = Bundle.module.url(
                forResource: name,
                withExtension: "svg",
                subdirectory: "BrandIcons")
        } else {
            developmentURL = nil
        }

        guard let url = packagedURL ?? developmentURL,
              let image = NSImage(contentsOf: url)
        else { return nil }

        image.isTemplate = true
        self.imageCache[name] = image
        return image
    }
}
