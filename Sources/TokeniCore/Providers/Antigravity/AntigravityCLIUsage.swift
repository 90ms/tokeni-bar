import Foundation

struct AntigravityCLIUsageResult: Sendable, Equatable {
    let quotaWindows: [QuotaWindow]
    let fetchedAt: Date
}

enum AntigravityCLIUsageError: LocalizedError, Sendable, Equatable {
    case executableUnavailable
    case profileUnavailable
    case unsupportedVersion
    case launchFailed
    case timedOut
    case signInRequired
    case commandFailed
    case invalidResponse
    case usageUnavailable

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            "Antigravity CLI was not found. Install agy or make it available in PATH."
        case .profileUnavailable:
            "Antigravity CLI is not signed in. Run agy once in Terminal to sign in."
        case .unsupportedVersion:
            "Antigravity CLI 1.1.11 or newer is required for safe quota checks."
        case .launchFailed:
            "Antigravity CLI could not be started."
        case .timedOut:
            "Antigravity CLI quota check timed out."
        case .signInRequired:
            "Antigravity CLI sign-in is required. Run agy once in Terminal."
        case .commandFailed:
            "Antigravity CLI quota check failed."
        case .invalidResponse:
            "Antigravity CLI returned an invalid quota response."
        case .usageUnavailable:
            "Antigravity quotas are unavailable for this account."
        }
    }
}

private struct AntigravityCLIEnvelope: Decodable {
    let status: String?
    let command: Command?

    struct Command: Decodable {
        let name: String?
        let data: UsageData?
    }

    struct UsageData: Decodable {
        let groups: [Group]?
    }

    struct Group: Decodable {
        let name: String?
        let buckets: [Bucket]?
    }

    struct Bucket: Decodable {
        let id: String?
        let name: String?
        let window: String?
        let remainingFraction: Double?
        let resetTime: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case window
            case remainingFraction = "remaining_fraction"
            case resetTime = "reset_time"
        }
    }
}

enum AntigravityCLIUsageParser {
    static func parse(_ data: Data) throws -> [QuotaWindow] {
        guard let output = String(data: data, encoding: .utf8),
              let jsonStart = output.firstIndex(of: "{")
        else { throw AntigravityCLIUsageError.invalidResponse }
        let envelope: AntigravityCLIEnvelope
        do {
            envelope = try JSONDecoder().decode(
                AntigravityCLIEnvelope.self,
                from: Data(output[jsonStart...].utf8))
        } catch {
            throw AntigravityCLIUsageError.invalidResponse
        }

        guard envelope.status?.uppercased() == "SUCCESS",
              envelope.command?.name?.lowercased() == "usage"
        else { throw AntigravityCLIUsageError.commandFailed }
        guard let groups = envelope.command?.data?.groups else {
            throw AntigravityCLIUsageError.invalidResponse
        }

        var windows: [QuotaWindow] = []
        for group in groups {
            let groupName = group.name?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            for bucket in group.buckets ?? [] {
                guard let id = bucket.id, !id.isEmpty,
                      let remaining = bucket.remainingFraction,
                      remaining.isFinite,
                      (0 ... 1).contains(remaining)
                else { continue }
                let descriptor = self.windowDescriptor(
                    rawWindow: bucket.window,
                    rawName: bucket.name)
                let label = [groupName, descriptor.label]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                windows.append(QuotaWindow(
                    id: id,
                    kind: descriptor.kind,
                    label: label.isEmpty ? id : label,
                    usedPercent: (1 - remaining) * 100,
                    resetsAt: bucket.resetTime.flatMap {
                        TimestampParser.parse($0)
                    },
                    durationMinutes: descriptor.durationMinutes))
            }
        }
        guard !windows.isEmpty else {
            throw AntigravityCLIUsageError.usageUnavailable
        }
        return windows.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return Self.sortOrder(lhs.kind) < Self.sortOrder(rhs.kind)
            }
            return lhs.label < rhs.label
        }
    }

    static func supportsSafeUsageCommand(_ output: String) -> Bool {
        let components = output.split { !$0.isNumber && $0 != "." }
        guard let version = components.first(where: {
            $0.split(separator: ".").count >= 3
        }) else { return false }
        let numbers = version.split(separator: ".").prefix(3).compactMap { Int($0) }
        guard numbers.count == 3 else { return false }
        return numbers.lexicographicallyPrecedes([1, 1, 11]) == false
    }

    private static func windowDescriptor(
        rawWindow: String?,
        rawName: String?) -> (kind: QuotaWindowKind, label: String?, durationMinutes: Int?)
    {
        switch rawWindow?.lowercased() {
        case "5h":
            return (.session, "5-hour", 5 * 60)
        case "weekly":
            return (.weekly, "Weekly", 7 * 24 * 60)
        case "monthly":
            return (.monthly, "Monthly", nil)
        default:
            return (.custom, rawName, nil)
        }
    }

    private static func sortOrder(_ kind: QuotaWindowKind) -> Int {
        switch kind {
        case .session: 0
        case .weekly: 1
        case .monthly: 2
        case .context: 3
        case .custom: 4
        }
    }
}

actor AntigravityCLIUsageCache {
    private var result: AntigravityCLIUsageResult?
    private var verifiedExecutablePath: String?

    func value(maxAge: TimeInterval, now: Date = .now) -> AntigravityCLIUsageResult? {
        guard let result,
              now.timeIntervalSince(result.fetchedAt) <= max(maxAge, 0)
        else { return nil }
        return result
    }

    func store(_ result: AntigravityCLIUsageResult) {
        self.result = result
    }

    func isVerified(_ executableURL: URL) -> Bool {
        self.verifiedExecutablePath == executableURL.standardizedFileURL.path
    }

    func markVerified(_ executableURL: URL) {
        self.verifiedExecutablePath = executableURL.standardizedFileURL.path
    }

    func invalidate() {
        self.result = nil
    }
}

struct AntigravityCLIUsageClient: Sendable {
    private let executableURL: URL?
    private let pathEnvironment: String?
    private let homeDirectory: URL
    private let processRunner: any ProcessRunning
    private let cache: AntigravityCLIUsageCache
    private let cacheMaxAge: TimeInterval
    private let timeout: TimeInterval

    init(
        executableURL: URL? = nil,
        pathEnvironment: String? = PlatformEnvironment.pathValue(
            from: ProcessInfo.processInfo.environment),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        processRunner: any ProcessRunning = SystemProcessRunner(),
        cache: AntigravityCLIUsageCache = AntigravityCLIUsageCache(),
        cacheMaxAge: TimeInterval = 5 * 60,
        timeout: TimeInterval = 45)
    {
        self.executableURL = executableURL
        self.pathEnvironment = pathEnvironment
        self.homeDirectory = homeDirectory
        self.processRunner = processRunner
        self.cache = cache
        self.cacheMaxAge = cacheMaxAge
        self.timeout = timeout
    }

    func fetch(forceRefresh: Bool = false) async throws -> AntigravityCLIUsageResult {
        if !forceRefresh,
           let cached = await self.cache.value(maxAge: self.cacheMaxAge)
        {
            return cached
        }
        let profile = self.homeDirectory.appending(
            path: ".gemini/antigravity-cli",
            directoryHint: .isDirectory)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: profile.path,
            isDirectory: &isDirectory),
            isDirectory.boolValue
        else { throw AntigravityCLIUsageError.profileUnavailable }

        guard let executableURL = self.resolveExecutable() else {
            throw AntigravityCLIUsageError.executableUnavailable
        }
        if !(await self.cache.isVerified(executableURL)) {
            try await self.verifyVersion(executableURL)
            await self.cache.markVerified(executableURL)
        }

        #if os(Windows)
        let nullDevice = "NUL"
        #else
        let nullDevice = "/dev/null"
        #endif
        let result = try await self.run(ProcessCommand(
            executable: executableURL.path,
            arguments: [
                "-p", "/usage", "--output-format", "json",
                "--log-file", nullDevice,
            ],
            timeout: self.timeout,
            environment: CLIProcessEnvironment.make(
                executableURL: executableURL,
                homeDirectory: self.homeDirectory)))
        guard result.succeeded else {
            throw Self.commandError(result)
        }
        let windows = try AntigravityCLIUsageParser.parse(
            Data(result.standardOutput.utf8))
        let fetched = AntigravityCLIUsageResult(
            quotaWindows: windows,
            fetchedAt: .now)
        await self.cache.store(fetched)
        return fetched
    }

    func invalidate() async {
        await self.cache.invalidate()
    }

    private func verifyVersion(_ executableURL: URL) async throws {
        let result = try await self.run(ProcessCommand(
            executable: executableURL.path,
            arguments: ["--version"],
            timeout: 10,
            environment: CLIProcessEnvironment.make(
                executableURL: executableURL,
                homeDirectory: self.homeDirectory)))
        guard result.succeeded,
              AntigravityCLIUsageParser.supportsSafeUsageCommand(
                result.standardOutput + " " + result.standardError)
        else { throw AntigravityCLIUsageError.unsupportedVersion }
    }

    private func run(_ command: ProcessCommand) async throws -> CommandResult {
        do {
            return try await self.processRunner.run(command)
        } catch let error as ProcessRunnerError {
            switch error {
            case .launchFailed:
                throw AntigravityCLIUsageError.launchFailed
            case .timedOut:
                throw AntigravityCLIUsageError.timedOut
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AntigravityCLIUsageError.commandFailed
        }
    }

    private func resolveExecutable() -> URL? {
        if let executableURL {
            #if os(Windows)
            return FileManager.default.fileExists(atPath: executableURL.path)
                ? executableURL : nil
            #else
            return FileManager.default.isExecutableFile(atPath: executableURL.path)
                ? executableURL : nil
            #endif
        }
        return SystemExecutableLocator().locate(
            executableNames: ["agy"],
            pathEnvironment: self.pathEnvironment,
            homeDirectory: self.homeDirectory)
    }

    private static func commandError(_ result: CommandResult)
        -> AntigravityCLIUsageError
    {
        let message = (result.standardError + " " + result.standardOutput)
            .lowercased()
        if ["sign in", "sign-in", "login", "oauth", "authentication required"]
            .contains(where: message.contains)
        {
            return .signInRequired
        }
        return .commandFailed
    }
}
