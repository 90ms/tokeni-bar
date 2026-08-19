import Foundation

struct ClaudeCLIUsageResponse: Sendable, Equatable {
    let quotaWindows: [QuotaWindow]
}

struct ClaudeCLIUsageResult: Sendable {
    let response: ClaudeCLIUsageResponse
    let fetchedAt: Date
}

enum ClaudeCLIUsageError: LocalizedError, Sendable, Equatable {
    case executableUnavailable
    case launchFailed
    case timedOut
    case signInRequired
    case sessionExpired
    case commandFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            "Claude Code CLI was not found. Install Claude Code or make it available in PATH."
        case .launchFailed:
            "Claude Code CLI could not be started."
        case .timedOut:
            "Claude Code CLI usage timed out."
        case .signInRequired:
            "Claude Code is not signed in. Run Claude Code once to sign in."
        case .sessionExpired:
            "Claude Code sign-in expired. Run Claude Code once to sign in again."
        case .commandFailed:
            "Claude Code CLI usage is unavailable."
        case .invalidResponse:
            "Claude Code CLI returned an invalid usage response."
        }
    }
}

struct ClaudeCLIUsageEnvelope: Decodable, Sendable {
    let isError: Bool?
    let result: String?

    enum CodingKeys: String, CodingKey {
        case isError = "is_error"
        case result
    }
}

enum ClaudeCLIUsageParser {
    static func parse(
        _ data: Data,
        now: Date = .now,
        timeZone: TimeZone = .current) throws -> ClaudeCLIUsageResponse
    {
        let envelope: ClaudeCLIUsageEnvelope
        do {
            envelope = try JSONDecoder().decode(ClaudeCLIUsageEnvelope.self, from: data)
        } catch {
            throw ClaudeCLIUsageError.invalidResponse
        }

        guard envelope.isError != true, let result = envelope.result else {
            let message = envelope.result?.lowercased() ?? ""
            if message.contains("expired") || message.contains("unauthorized") {
                throw ClaudeCLIUsageError.sessionExpired
            }
            if message.contains("sign in") || message.contains("login")
                || message.contains("authentication")
            {
                throw ClaudeCLIUsageError.signInRequired
            }
            throw ClaudeCLIUsageError.commandFailed
        }

        let windows = result.split(whereSeparator: \.isNewline).compactMap {
            self.parseWindow(String($0), now: now, timeZone: timeZone)
        }
        guard !windows.isEmpty else { throw ClaudeCLIUsageError.invalidResponse }
        return ClaudeCLIUsageResponse(quotaWindows: windows)
    }

    private static func parseWindow(
        _ line: String,
        now: Date,
        timeZone: TimeZone) -> QuotaWindow?
    {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        let kind: QuotaWindowKind
        let id: String
        let label: String
        let durationMinutes: Int

        if lowercased.hasPrefix("current session") {
            kind = .session
            id = "five-hour"
            label = "5-hour"
            durationMinutes = 5 * 60
        } else if lowercased.hasPrefix("current week") {
            kind = .weekly
            durationMinutes = 7 * 24 * 60
            if let model = self.parenthesizedValue(in: normalized),
               model.lowercased() != "all models"
            {
                let slug = model.lowercased().replacingOccurrences(of: " ", with: "-")
                id = "scoped-weekly-" + slug
                label = model + " weekly"
            } else {
                id = "seven-day"
                label = "Weekly"
            }
        } else {
            return nil
        }

        guard let usedPercent = self.percent(in: normalized) else { return nil }
        return QuotaWindow(
            id: id,
            kind: kind,
            label: label,
            usedPercent: usedPercent,
            resetsAt: self.resetDate(in: normalized, now: now, timeZone: timeZone),
            durationMinutes: durationMinutes)
    }

    private static func percent(in line: String) -> Double? {
        guard let percentIndex = line.firstIndex(of: "%") else { return nil }
        let prefix = line[..<percentIndex]
        let number = prefix.split { character in
            !character.isNumber && character != "."
        }.last
        return number.flatMap { Double(String($0)) }
    }

    private static func parenthesizedValue(in line: String) -> String? {
        guard let start = line.firstIndex(of: "("),
              let end = line[start...].firstIndex(of: ")")
        else { return nil }
        let value = line[line.index(after: start)..<end]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func resetDate(
        in line: String,
        now: Date,
        timeZone: TimeZone) -> Date?
    {
        guard let range = line.range(of: "resets", options: .caseInsensitive) else {
            return nil
        }
        let remainder = line[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = remainder.split(separator: "(", maxSplits: 1)
            .first
            .map(String.init) ?? ""
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dateText.isEmpty else { return nil }

        let resetTimeZone = self.parenthesizedValue(in: String(remainder))
            .flatMap { TimeZone(identifier: $0) } ?? timeZone
        let normalized = dateText
            .replacingOccurrences(of: "am", with: "AM", options: .caseInsensitive)
            .replacingOccurrences(of: "pm", with: "PM", options: .caseInsensitive)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = resetTimeZone
        let year = calendar.component(.year, from: now)
        let formats = ["yyyy MMM d, h:mma", "yyyy MMM d, ha"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = resetTimeZone

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: String(year) + " " + normalized) {
                if date.timeIntervalSince(now) < -24 * 60 * 60 {
                    return formatter.date(from: String(year + 1) + " " + normalized) ?? date
                }
                return date
            }
        }
        return nil
    }
}

actor ClaudeCLIUsageCache {
    private var result: ClaudeCLIUsageResult?

    func value(maxAge: TimeInterval, now: Date = .now) -> ClaudeCLIUsageResult? {
        guard let result,
              now.timeIntervalSince(result.fetchedAt) >= 0,
              now.timeIntervalSince(result.fetchedAt) < maxAge
        else { return nil }
        return result
    }

    func store(_ result: ClaudeCLIUsageResult) {
        self.result = result
    }

    func invalidate() {
        self.result = nil
    }
}

struct ClaudeExecutableLocator: Sendable {
    private let explicitURL: URL?
    private let pathEnvironment: String?
    private let homeDirectory: URL

    init(
        explicitURL: URL? = nil,
        pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
    {
        self.explicitURL = explicitURL
        self.pathEnvironment = pathEnvironment
        self.homeDirectory = homeDirectory
    }

    func resolve() -> URL? {
        if let explicitURL {
            return self.isExecutable(explicitURL) ? explicitURL : nil
        }

        for relativePath in [
            ".local/bin/claude",
            ".npm-global/bin/claude",
            ".bun/bin/claude",
            ".volta/bin/claude",
            ".asdf/shims/claude",
            ".local/share/mise/shims/claude",
            ".mise/shims/claude",
        ] {
            let candidate = self.homeDirectory.appending(path: relativePath)
            if self.isExecutable(candidate) { return candidate }
        }

        for path in [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude",
        ] {
            let candidate = URL(fileURLWithPath: path)
            if self.isExecutable(candidate) { return candidate }
        }

        for candidate in self.versionManagedCandidates() {
            if self.isExecutable(candidate) { return candidate }
        }

        for directory in (self.pathEnvironment ?? "").split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
                .appending(path: "claude")
            if self.isExecutable(candidate) { return candidate }
        }
        return nil
    }

    private func versionManagedCandidates() -> [URL] {
        let roots = [
            self.homeDirectory.appending(path: ".nvm/versions/node", directoryHint: .isDirectory),
            self.homeDirectory.appending(
                path: ".local/share/fnm/node-versions",
                directoryHint: .isDirectory),
            self.homeDirectory.appending(path: ".fnm/node-versions", directoryHint: .isDirectory),
        ]
        return roots.flatMap { root in
            let versions = (try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])) ?? []
            return versions.sorted {
                $0.lastPathComponent.compare(
                    $1.lastPathComponent,
                    options: .numeric) == .orderedDescending
            }.map { version in
                if root.lastPathComponent == "node" {
                    version.appending(path: "bin/claude")
                } else {
                    version.appending(path: "installation/bin/claude")
                }
            }
        }
    }

    private func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }
}

struct ClaudeCLIUsageClient: Sendable {
    private static let arguments = [
        "--print",
        "--no-session-persistence",
        "--setting-sources",
        "user",
        "--tools",
        "",
        "--output-format",
        "json",
        "/usage",
    ]

    private let locator: ClaudeExecutableLocator
    private let processRunner: any ProcessRunning
    private let cache: ClaudeCLIUsageCache
    private let cacheMaxAge: TimeInterval
    private let timeout: TimeInterval

    init(
        executableURL: URL? = nil,
        pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        processRunner: any ProcessRunning = SystemProcessRunner(),
        cache: ClaudeCLIUsageCache = ClaudeCLIUsageCache(),
        cacheMaxAge: TimeInterval = 5 * 60,
        timeout: TimeInterval = 20)
    {
        self.locator = ClaudeExecutableLocator(
            explicitURL: executableURL,
            pathEnvironment: pathEnvironment,
            homeDirectory: homeDirectory)
        self.processRunner = processRunner
        self.cache = cache
        self.cacheMaxAge = cacheMaxAge
        self.timeout = timeout
    }

    func fetch(forceRefresh: Bool = false) async throws -> ClaudeCLIUsageResult {
        if !forceRefresh,
           let cached = await self.cache.value(maxAge: self.cacheMaxAge)
        {
            return cached
        }
        guard let executableURL = self.locator.resolve() else {
            throw ClaudeCLIUsageError.executableUnavailable
        }

        let command = ProcessCommand(
            executable: executableURL.path,
            arguments: Self.arguments,
            timeout: self.timeout)
        let result: CommandResult
        do {
            result = try await self.processRunner.run(command)
        } catch let error as ProcessRunnerError {
            switch error {
            case .launchFailed:
                throw ClaudeCLIUsageError.launchFailed
            case .timedOut:
                throw ClaudeCLIUsageError.timedOut
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ClaudeCLIUsageError.commandFailed
        }

        guard result.succeeded else {
            throw Self.error(for: result)
        }
        let response = try ClaudeCLIUsageParser.parse(Data(result.standardOutput.utf8))
        let fetched = ClaudeCLIUsageResult(response: response, fetchedAt: .now)
        await self.cache.store(fetched)
        return fetched
    }

    func invalidateCache() async {
        await self.cache.invalidate()
    }

    private static func error(for result: CommandResult) -> ClaudeCLIUsageError {
        let output = (result.standardOutput + "\n" + result.standardError).lowercased()
        if output.contains("expired") || output.contains("unauthorized") {
            return .sessionExpired
        }
        if output.contains("sign in") || output.contains("login")
            || output.contains("authentication")
        {
            return .signInRequired
        }
        return .commandFailed
    }
}
