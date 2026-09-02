import Foundation

public struct CodexPetManifest: Decodable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String?
    public let spritesheetPath: String
    public let spriteVersionNumber: Int?

    public init(
        id: String,
        displayName: String,
        description: String? = nil,
        spritesheetPath: String,
        spriteVersionNumber: Int? = nil)
    {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.spritesheetPath = spritesheetPath
        self.spriteVersionNumber = spriteVersionNumber
    }
}

public struct ValidatedCodexPetPack: Equatable, Sendable {
    public let manifest: CodexPetManifest
    public let packID: CompanionAssetPackID
    public let speciesID: CompanionSpeciesID
    public let format: CompanionAssetFormat
    public let atlasColumns: Int
    public let atlasRows: Int
    public let frameWidth: Int
    public let frameHeight: Int

    public init(
        manifest: CodexPetManifest,
        packID: CompanionAssetPackID,
        speciesID: CompanionSpeciesID,
        format: CompanionAssetFormat,
        atlasColumns: Int,
        atlasRows: Int,
        frameWidth: Int,
        frameHeight: Int)
    {
        self.manifest = manifest
        self.packID = packID
        self.speciesID = speciesID
        self.format = format
        self.atlasColumns = atlasColumns
        self.atlasRows = atlasRows
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
    }
}

public enum CodexPetPackValidationIssue: Equatable, Sendable {
    case malformedManifest
    case invalidID
    case invalidDisplayName
    case descriptionTooLong
    case unsafeSpritesheetPath
    case unsupportedSpriteVersion(Int)
    case atlasSizeMismatch(
        expectedWidth: Int,
        expectedHeight: Int,
        actualWidth: Int,
        actualHeight: Int)
}

public struct CodexPetPackValidationError: Error, Equatable, Sendable {
    public let issues: [CodexPetPackValidationIssue]

    public init(issues: [CodexPetPackValidationIssue]) {
        self.issues = issues
    }
}

public struct CodexPetPackValidator: Sendable {
    public static let atlasColumns = 8
    public static let frameWidth = 192
    public static let frameHeight = 208
    public static let maximumManifestBytes = 1_048_576

    public init() {}

    public func validate(
        manifestData: Data,
        atlasPixelWidth: Int,
        atlasPixelHeight: Int) throws -> ValidatedCodexPetPack
    {
        guard !manifestData.isEmpty,
              manifestData.count <= Self.maximumManifestBytes,
              let manifest = try? JSONDecoder().decode(
                  CodexPetManifest.self,
                  from: manifestData)
        else {
            throw CodexPetPackValidationError(issues: [.malformedManifest])
        }

        var issues: [CodexPetPackValidationIssue] = []
        let id = manifest.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = manifest.displayName.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if !Self.isSafeID(id) {
            issues.append(.invalidID)
        }
        if displayName.isEmpty || displayName.count > 120 {
            issues.append(.invalidDisplayName)
        }
        if manifest.description?.count ?? 0 > 2_000 {
            issues.append(.descriptionTooLong)
        }
        if !Self.isSupportedSpritesheetPath(manifest.spritesheetPath) {
            issues.append(.unsafeSpritesheetPath)
        }

        let format: CompanionAssetFormat
        let rows: Int
        switch manifest.spriteVersionNumber {
        case nil, 1:
            format = .codexV1
            rows = 9
        case 2:
            format = .codexV2
            rows = 11
        case let version?:
            issues.append(.unsupportedSpriteVersion(version))
            format = .codexV1
            rows = 9
        }

        let expectedWidth = Self.atlasColumns * Self.frameWidth
        let expectedHeight = rows * Self.frameHeight
        if atlasPixelWidth != expectedWidth
            || atlasPixelHeight != expectedHeight
        {
            issues.append(.atlasSizeMismatch(
                expectedWidth: expectedWidth,
                expectedHeight: expectedHeight,
                actualWidth: atlasPixelWidth,
                actualHeight: atlasPixelHeight))
        }
        guard issues.isEmpty else {
            throw CodexPetPackValidationError(issues: issues)
        }

        let normalizedManifest = CodexPetManifest(
            id: id,
            displayName: displayName,
            description: manifest.description,
            spritesheetPath: manifest.spritesheetPath,
            spriteVersionNumber: manifest.spriteVersionNumber)
        let namespacedID = "codex.\(id)"
        return ValidatedCodexPetPack(
            manifest: normalizedManifest,
            packID: CompanionAssetPackID(rawValue: namespacedID),
            speciesID: CompanionSpeciesID(rawValue: namespacedID),
            format: format,
            atlasColumns: Self.atlasColumns,
            atlasRows: rows,
            frameWidth: Self.frameWidth,
            frameHeight: Self.frameHeight)
    }

    private static func isSafeID(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= 128,
              let first = value.unicodeScalars.first,
              Self.isASCIIAlphanumeric(first)
        else { return false }
        return value.unicodeScalars.allSatisfy {
            Self.isASCIIAlphanumeric($0) || $0 == "-" || $0 == "_" || $0 == "."
        }
    }

    private static func isASCIIAlphanumeric(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 48 && scalar.value <= 57)
            || (scalar.value >= 65 && scalar.value <= 90)
            || (scalar.value >= 97 && scalar.value <= 122)
    }

    private static func isSupportedSpritesheetPath(_ value: String) -> Bool {
        value == "spritesheet.webp" || value == "spritesheet.png"
    }
}
