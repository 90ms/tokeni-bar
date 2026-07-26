import Foundation

public struct SemanticVersion: Hashable, Sendable, Comparable, CustomStringConvertible {
    public enum Identifier: Hashable, Sendable {
        case numeric(Int)
        case text(String)
    }

    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [Identifier]
    public let buildMetadata: [String]

    public init?(_ value: String) {
        var candidate = value
        if candidate.first == "v" || candidate.first == "V" {
            candidate.removeFirst()
        }
        guard !candidate.isEmpty,
              candidate == candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }

        let buildParts = candidate.split(separator: "+", omittingEmptySubsequences: false)
        guard buildParts.count <= 2 else { return nil }
        let versionAndPrerelease = String(buildParts[0])
        let build = buildParts.count == 2 ? String(buildParts[1]) : nil

        let prereleaseParts = versionAndPrerelease.split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false)
        let core = prereleaseParts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3,
              let major = Self.parseCoreNumber(core[0]),
              let minor = Self.parseCoreNumber(core[1]),
              let patch = Self.parseCoreNumber(core[2])
        else { return nil }

        var prereleaseIdentifiers: [Identifier] = []
        if prereleaseParts.count == 2 {
            let identifiers = prereleaseParts[1].split(
                separator: ".",
                omittingEmptySubsequences: false)
            guard !identifiers.isEmpty else { return nil }
            for identifier in identifiers {
                guard Self.isValidIdentifier(identifier) else { return nil }
                if identifier.allSatisfy(\.isNumber) {
                    guard (identifier.count == 1 || identifier.first != "0"),
                          let number = Int(identifier)
                    else { return nil }
                    prereleaseIdentifiers.append(.numeric(number))
                } else {
                    prereleaseIdentifiers.append(.text(String(identifier)))
                }
            }
        }

        var buildIdentifiers: [String] = []
        if let build {
            let identifiers = build.split(separator: ".", omittingEmptySubsequences: false)
            guard !identifiers.isEmpty, identifiers.allSatisfy(Self.isValidIdentifier) else {
                return nil
            }
            buildIdentifiers = identifiers.map(String.init)
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prereleaseIdentifiers
        self.buildMetadata = buildIdentifiers
    }

    public var description: String {
        var value = "\(self.major).\(self.minor).\(self.patch)"
        if !self.prerelease.isEmpty {
            value += "-" + self.prerelease.map { identifier in
                switch identifier {
                case let .numeric(number): String(number)
                case let .text(text): text
                }
            }.joined(separator: ".")
        }
        if !self.buildMetadata.isEmpty {
            value += "+" + self.buildMetadata.joined(separator: ".")
        }
        return value
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        lhs.major == rhs.major &&
            lhs.minor == rhs.minor &&
            lhs.patch == rhs.patch &&
            lhs.prerelease == rhs.prerelease
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.major)
        hasher.combine(self.minor)
        hasher.combine(self.patch)
        hasher.combine(self.prerelease)
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let lhsCore = (lhs.major, lhs.minor, lhs.patch)
        let rhsCore = (rhs.major, rhs.minor, rhs.patch)
        if lhsCore != rhsCore {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            return lhs.patch < rhs.patch
        }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }

        for index in 0..<min(lhs.prerelease.count, rhs.prerelease.count) {
            let left = lhs.prerelease[index]
            let right = rhs.prerelease[index]
            if left == right { continue }
            switch (left, right) {
            case let (.numeric(leftNumber), .numeric(rightNumber)):
                return leftNumber < rightNumber
            case (.numeric, .text):
                return true
            case (.text, .numeric):
                return false
            case let (.text(leftText), .text(rightText)):
                return leftText < rightText
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private static func parseCoreNumber(_ value: Substring) -> Int? {
        guard !value.isEmpty,
              value.allSatisfy(\.isNumber),
              value.count == 1 || value.first != "0"
        else { return nil }
        return Int(value)
    }

    private static func isValidIdentifier(_ value: Substring) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) ||
                (65...90).contains(byte) ||
                (97...122).contains(byte) ||
                byte == 45
        }
    }
}
