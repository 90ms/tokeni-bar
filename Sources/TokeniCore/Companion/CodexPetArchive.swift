import Foundation

public struct CompanionArchiveEntry: Codable, Equatable, Sendable {
    public let path: String
    public let compressedSize: Int
    public let uncompressedSize: Int
    public let compressionMethod: Int
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let isEncrypted: Bool

    public init(
        path: String,
        compressedSize: Int,
        uncompressedSize: Int,
        compressionMethod: Int = 0,
        isDirectory: Bool = false,
        isSymbolicLink: Bool = false,
        isEncrypted: Bool = false)
    {
        self.path = path
        self.compressedSize = compressedSize
        self.uncompressedSize = uncompressedSize
        self.compressionMethod = compressionMethod
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.isEncrypted = isEncrypted
    }
}

public enum ZIPArchiveInspectionError: Error, Equatable, Sendable {
    case malformedArchive
    case unsupportedZIP64
    case invalidFilename
    case centralAndLocalHeaderMismatch
}

/// A minimal, read-only ZIP inspector used before any external extractor is
/// allowed to touch the archive. It validates both central and local filenames
/// so a conflicting local header cannot bypass the path policy.
public struct ZIPArchiveInspector: Sendable {
    public init() {}

    public func inspect(_ data: Data) throws -> [CompanionArchiveEntry] {
        let endOffset = try self.endOfCentralDirectoryOffset(in: data)
        let diskNumber = try self.uint16(data, at: endOffset + 4)
        let centralDisk = try self.uint16(data, at: endOffset + 6)
        let diskEntries = try self.uint16(data, at: endOffset + 8)
        let totalEntries = try self.uint16(data, at: endOffset + 10)
        let centralSize = try self.uint32(data, at: endOffset + 12)
        let centralOffset = try self.uint32(data, at: endOffset + 16)
        guard diskNumber == 0,
              centralDisk == 0,
              diskEntries == totalEntries
        else { throw ZIPArchiveInspectionError.unsupportedZIP64 }
        guard totalEntries != UInt16.max,
              centralSize != UInt32.max,
              centralOffset != UInt32.max
        else { throw ZIPArchiveInspectionError.unsupportedZIP64 }

        let centralStart = Int(centralOffset)
        let centralEnd = centralStart + Int(centralSize)
        guard centralStart >= 0,
              centralEnd >= centralStart,
              centralEnd <= endOffset
        else { throw ZIPArchiveInspectionError.malformedArchive }

        var entries: [CompanionArchiveEntry] = []
        entries.reserveCapacity(Int(totalEntries))
        var cursor = centralStart
        for _ in 0..<Int(totalEntries) {
            guard try self.uint32(data, at: cursor) == 0x0201_4B50 else {
                throw ZIPArchiveInspectionError.malformedArchive
            }
            let versionMadeBy = try self.uint16(data, at: cursor + 4)
            let flags = try self.uint16(data, at: cursor + 8)
            let method = try self.uint16(data, at: cursor + 10)
            let compressedSize = try self.uint32(data, at: cursor + 20)
            let uncompressedSize = try self.uint32(data, at: cursor + 24)
            let filenameLength = Int(try self.uint16(data, at: cursor + 28))
            let extraLength = Int(try self.uint16(data, at: cursor + 30))
            let commentLength = Int(try self.uint16(data, at: cursor + 32))
            let externalAttributes = try self.uint32(data, at: cursor + 38)
            let localOffset = try self.uint32(data, at: cursor + 42)
            guard compressedSize != UInt32.max,
                  uncompressedSize != UInt32.max,
                  localOffset != UInt32.max
            else { throw ZIPArchiveInspectionError.unsupportedZIP64 }

            let filenameStart = cursor + 46
            let next = filenameStart + filenameLength + extraLength
                + commentLength
            guard filenameLength > 0, next <= centralEnd else {
                throw ZIPArchiveInspectionError.malformedArchive
            }
            let filenameData = data.subdata(
                in: filenameStart..<(filenameStart + filenameLength))
            guard let path = String(data: filenameData, encoding: .utf8) else {
                throw ZIPArchiveInspectionError.invalidFilename
            }
            try self.validateLocalHeader(
                in: data,
                offset: Int(localOffset),
                expectedFilename: filenameData,
                expectedFlags: flags,
                expectedMethod: method,
                compressedSize: Int(compressedSize),
                before: centralStart)

            let unixPlatform = versionMadeBy >> 8 == 3
            let unixMode = externalAttributes >> 16
            let fileType = unixMode & 0o170000
            entries.append(CompanionArchiveEntry(
                path: path,
                compressedSize: Int(compressedSize),
                uncompressedSize: Int(uncompressedSize),
                compressionMethod: Int(method),
                isDirectory: path.hasSuffix("/")
                    || (unixPlatform && fileType == 0o040000),
                isSymbolicLink: unixPlatform && fileType == 0o120000,
                isEncrypted: flags & 0x1 != 0))
            cursor = next
        }
        guard cursor == centralEnd else {
            throw ZIPArchiveInspectionError.malformedArchive
        }
        return entries
    }

    private func endOfCentralDirectoryOffset(in data: Data) throws -> Int {
        guard data.count >= 22 else {
            throw ZIPArchiveInspectionError.malformedArchive
        }
        let lowerBound = max(0, data.count - 65_557)
        for offset in stride(
            from: data.count - 22,
            through: lowerBound,
            by: -1)
        {
            guard (try? self.uint32(data, at: offset)) == 0x0605_4B50,
                  let commentLength = try? self.uint16(data, at: offset + 20),
                  offset + 22 + Int(commentLength) == data.count
            else { continue }
            return offset
        }
        throw ZIPArchiveInspectionError.malformedArchive
    }

    private func validateLocalHeader(
        in data: Data,
        offset: Int,
        expectedFilename: Data,
        expectedFlags: UInt16,
        expectedMethod: UInt16,
        compressedSize: Int,
        before centralStart: Int) throws
    {
        guard try self.uint32(data, at: offset) == 0x0403_4B50,
              try self.uint16(data, at: offset + 6) == expectedFlags,
              try self.uint16(data, at: offset + 8) == expectedMethod
        else {
            throw ZIPArchiveInspectionError.centralAndLocalHeaderMismatch
        }
        let filenameLength = Int(try self.uint16(data, at: offset + 26))
        let extraLength = Int(try self.uint16(data, at: offset + 28))
        let filenameStart = offset + 30
        let payloadStart = filenameStart + filenameLength + extraLength
        guard filenameLength == expectedFilename.count,
              payloadStart >= filenameStart,
              payloadStart + compressedSize <= centralStart,
              data.subdata(in: filenameStart..<(filenameStart + filenameLength))
                == expectedFilename
        else {
            throw ZIPArchiveInspectionError.centralAndLocalHeaderMismatch
        }
    }

    private func uint16(_ data: Data, at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else {
            throw ZIPArchiveInspectionError.malformedArchive
        }
        return UInt16(data[data.startIndex + offset])
            | UInt16(data[data.startIndex + offset + 1]) << 8
    }

    private func uint32(_ data: Data, at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else {
            throw ZIPArchiveInspectionError.malformedArchive
        }
        return UInt32(data[data.startIndex + offset])
            | UInt32(data[data.startIndex + offset + 1]) << 8
            | UInt32(data[data.startIndex + offset + 2]) << 16
            | UInt32(data[data.startIndex + offset + 3]) << 24
    }
}

public enum CodexPetArchiveValidationIssue: Equatable, Sendable {
    case tooManyEntries(maximum: Int)
    case unsafePath(String)
    case symbolicLink(String)
    case encryptedEntry(String)
    case unsupportedCompressionMethod(path: String, method: Int)
    case unsupportedFile(String)
    case missingManifest
    case multipleManifests
    case missingSpritesheet
    case multipleSpritesheets
    case manifestTooLarge(maximumBytes: Int)
    case compressedArchiveTooLarge(maximumBytes: Int)
    case expandedArchiveTooLarge(maximumBytes: Int)
    case suspiciousCompressionRatio(String)
}

public struct CodexPetArchiveValidationError: Error, Equatable, Sendable {
    public let issues: [CodexPetArchiveValidationIssue]

    public init(issues: [CodexPetArchiveValidationIssue]) {
        self.issues = issues
    }
}

public struct ValidatedCodexPetArchive: Equatable, Sendable {
    public let manifestPath: String
    public let spritesheetPath: String
    public let entries: [CompanionArchiveEntry]
}

public struct CodexPetArchiveValidator: Sendable {
    public static let maximumEntryCount = 16
    public static let maximumCompressedBytes = 64 * 1_024 * 1_024
    public static let maximumExpandedBytes = 256 * 1_024 * 1_024
    public static let maximumCompressionRatio = 200

    public init() {}

    public func validate(
        entries: [CompanionArchiveEntry],
        archiveByteCount: Int) throws -> ValidatedCodexPetArchive
    {
        var issues: [CodexPetArchiveValidationIssue] = []
        if entries.count > Self.maximumEntryCount {
            issues.append(.tooManyEntries(maximum: Self.maximumEntryCount))
        }
        if archiveByteCount > Self.maximumCompressedBytes {
            issues.append(.compressedArchiveTooLarge(
                maximumBytes: Self.maximumCompressedBytes))
        }
        let expandedBytes = entries.reduce(0) {
            $0.addingReportingOverflow($1.uncompressedSize).overflow
                ? Int.max
                : $0 + $1.uncompressedSize
        }
        if expandedBytes > Self.maximumExpandedBytes {
            issues.append(.expandedArchiveTooLarge(
                maximumBytes: Self.maximumExpandedBytes))
        }

        for entry in entries {
            if !Self.isSafeRootPath(entry.path) {
                issues.append(.unsafePath(entry.path))
            }
            if entry.isSymbolicLink {
                issues.append(.symbolicLink(entry.path))
            }
            if entry.isEncrypted {
                issues.append(.encryptedEntry(entry.path))
            }
            if entry.compressionMethod != 0 && entry.compressionMethod != 8 {
                issues.append(.unsupportedCompressionMethod(
                    path: entry.path,
                    method: entry.compressionMethod))
            }
            if entry.isDirectory
                || !["pet.json", "spritesheet.webp", "spritesheet.png"]
                    .contains(entry.path)
            {
                issues.append(.unsupportedFile(entry.path))
            }
            if entry.uncompressedSize
                > max(entry.compressedSize, 1) * Self.maximumCompressionRatio
            {
                issues.append(.suspiciousCompressionRatio(entry.path))
            }
        }

        let manifests = entries.filter { $0.path == "pet.json" }
        let spritesheets = entries.filter {
            $0.path == "spritesheet.webp" || $0.path == "spritesheet.png"
        }
        if manifests.isEmpty {
            issues.append(.missingManifest)
        } else if manifests.count > 1 {
            issues.append(.multipleManifests)
        } else if manifests[0].uncompressedSize
            > CodexPetPackValidator.maximumManifestBytes
        {
            issues.append(.manifestTooLarge(
                maximumBytes: CodexPetPackValidator.maximumManifestBytes))
        }
        if spritesheets.isEmpty {
            issues.append(.missingSpritesheet)
        } else if spritesheets.count > 1 {
            issues.append(.multipleSpritesheets)
        }
        guard manifests.count == 1,
              spritesheets.count == 1,
              issues.isEmpty
        else { throw CodexPetArchiveValidationError(issues: issues) }
        return ValidatedCodexPetArchive(
            manifestPath: manifests[0].path,
            spritesheetPath: spritesheets[0].path,
            entries: entries)
    }

    private static func isSafeRootPath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\"),
              !path.contains("\0"),
              path.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 })
        else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count == 1 && components[0] != "." && components[0] != ".."
    }
}
