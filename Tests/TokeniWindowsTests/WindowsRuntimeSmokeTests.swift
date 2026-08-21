import Foundation
import Testing
@testable import TokeniWindows

struct WindowsRuntimeSmokeTests {
    @Test
    func validatesPackagedAssetsAndDeterministicPresentation() throws {
        let packageRoot = try self.makePackage(manifest: Data("{}".utf8))
        defer { try? FileManager.default.removeItem(at: packageRoot) }
        var messages: [String] = []

        let exitCode = WindowsRuntimeSmoke.run(
            executableURL: packageRoot.appendingPathComponent("TokeniWindows.exe"),
            output: { messages.append($0) })

        #expect(exitCode == 0)
        #expect(messages == [
            "TOKENI_WINDOWS_SMOKE_OK assets=bytebot presentation=75",
        ])
    }

    @Test
    func failsWithoutPackagedAssets() {
        let executableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("TokeniWindows.exe")

        let result = WindowsRuntimeSmoke.validate(executableURL: executableURL)

        guard case let .failure(error) = result else {
            Issue.record("Expected missing companion assets to fail")
            return
        }
        #expect(error == .companionAssetsUnavailable)
    }

    @Test
    func rejectsInvalidManifestJSON() throws {
        let packageRoot = try self.makePackage(manifest: Data("not-json".utf8))
        defer { try? FileManager.default.removeItem(at: packageRoot) }

        let result = WindowsRuntimeSmoke.validate(
            executableURL: packageRoot.appendingPathComponent("TokeniWindows.exe"))

        guard case let .failure(error) = result else {
            Issue.record("Expected invalid manifest JSON to fail")
            return
        }
        #expect(error == .invalidCompanionManifest)
    }

    private func makePackage(manifest: Data) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manifestURL = root
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("CompanionAssets", isDirectory: true)
            .appendingPathComponent("bytebot", isDirectory: true)
            .appendingPathComponent("manifest.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try manifest.write(to: manifestURL)
        return root
    }
}
