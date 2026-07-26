import Foundation
import Testing
@testable import TokeniCore

@Suite("App storage paths")
struct AppStoragePathsTests {
    @Test("Migrates the legacy application support directory")
    func migratesLegacyDirectory() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let legacyURL = baseURL.appending(
            path: AppStoragePaths.legacyDirectoryName,
            directoryHint: .isDirectory)
        let markerURL = legacyURL.appending(path: "usage-history.json")
        defer { try? fileManager.removeItem(at: baseURL) }

        try fileManager.createDirectory(at: legacyURL, withIntermediateDirectories: true)
        try Data("history".utf8).write(to: markerURL)

        let result = AppStoragePaths.applicationSupportDirectory(
            baseURL: baseURL,
            fileManager: fileManager)

        #expect(result.lastPathComponent == AppStoragePaths.directoryName)
        #expect(fileManager.fileExists(
            atPath: result.appending(path: "usage-history.json").path))
        #expect(!fileManager.fileExists(atPath: legacyURL.path))
    }

    @Test("Keeps the current directory when both directories exist")
    func prefersCurrentDirectory() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let currentURL = baseURL.appending(
            path: AppStoragePaths.directoryName,
            directoryHint: .isDirectory)
        let legacyURL = baseURL.appending(
            path: AppStoragePaths.legacyDirectoryName,
            directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: baseURL) }

        try fileManager.createDirectory(at: currentURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: legacyURL, withIntermediateDirectories: true)

        let result = AppStoragePaths.applicationSupportDirectory(
            baseURL: baseURL,
            fileManager: fileManager)

        #expect(result == currentURL)
        #expect(fileManager.fileExists(atPath: legacyURL.path))
    }
}
