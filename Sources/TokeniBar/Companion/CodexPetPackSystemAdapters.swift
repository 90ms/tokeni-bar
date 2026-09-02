import Foundation
import ImageIO
import TokeniCore

struct DittoCompanionArchiveExtractor: CompanionArchiveExtracting {
    private let runner: any ProcessRunning

    init(runner: any ProcessRunning = SystemProcessRunner()) {
        self.runner = runner
    }

    func extract(archiveURL: URL, to destinationURL: URL) async throws {
        let result = try await self.runner.run(ProcessCommand(
            executable: "/usr/bin/ditto",
            arguments: [
                "-x",
                "-k",
                "--noqtn",
                archiveURL.path,
                destinationURL.path,
            ],
            timeout: 30))
        guard result.succeeded else {
            throw CodexPetPackInstallationError.extractionFailed
        }
    }
}

struct ImageIOCompanionAtlasInspector: CompanionAtlasInspecting {
    func pixelSize(at imageURL: URL) throws -> CompanionAtlasPixelSize {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CodexPetPackInstallationError.atlasUnreadable }
        return CompanionAtlasPixelSize(
            width: image.width,
            height: image.height)
    }
}

extension CodexPetPackInstaller {
    static func live(installationRoot: URL) -> Self {
        Self(
            installationRoot: installationRoot,
            extractor: DittoCompanionArchiveExtractor(),
            atlasInspector: ImageIOCompanionAtlasInspector())
    }
}
