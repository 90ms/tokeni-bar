import Foundation
import Testing
@testable import TokeniCore

@Suite("Local file safety")
struct LocalFileSafetyTests {
    @Test("Oversized local data is rejected before reading")
    func rejectsOversizedData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let file = directory.appending(path: "large.json")
        try Data("12345".utf8).write(to: file)

        #expect(LocalFiles.data(in: file, maximumBytes: 4) == nil)
        #expect(LocalFiles.data(in: file, maximumBytes: 5) == Data("12345".utf8))
    }

    @Test("Symbolic links are not accepted as provider data")
    func rejectsSymbolicLinks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let target = directory.appending(path: "target.json")
        let link = directory.appending(path: "link.json")
        try Data("{}".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: target)

        #expect(LocalFiles.data(in: link) == nil)
    }

    @Test("JSON lines fail closed when the file exceeds its limit")
    func rejectsOversizedJSONLines() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let file = directory.appending(path: "events.jsonl")
        try Data("one\ntwo\n".utf8).write(to: file)

        var streamed: [String] = []
        #expect(LocalFiles.forEachLine(in: file, maximumBytes: 16) {
            streamed.append(String(decoding: $0, as: UTF8.self))
        })
        #expect(streamed == ["one", "two"])
        #expect(!LocalFiles.forEachLine(in: file, maximumBytes: 4) { _ in
            Issue.record("An oversized file must not be consumed")
        })
    }

    @Test("JSONL aggregate budget rejects a set of oversized files")
    func rejectsOversizedJSONLinesAggregate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let first = directory.appending(path: "first.jsonl")
        let second = directory.appending(path: "second.jsonl")
        try Data("12345".utf8).write(to: first)
        try Data("67890".utf8).write(to: second)

        #expect(LocalFiles.totalSize(of: [first, second], maximumBytes: 10) == 10)
        #expect(LocalFiles.totalSize(of: [first, second], maximumBytes: 9) == nil)
    }

    @Test("Timestamp parser handles the common ISO-8601 forms")
    func parsesISO8601Timestamps() {
        #expect(TimestampParser.parse("2026-08-14T00:00:00Z") != nil)
        #expect(TimestampParser.parse("2026-08-14T00:00:00.123Z") != nil)
        #expect(TimestampParser.parse(nil) == nil)
    }
}
