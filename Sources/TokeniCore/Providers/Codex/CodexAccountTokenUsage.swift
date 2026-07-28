import Foundation

struct CodexAccountTokenUsageResponse: Decodable, Sendable {
    let summary: Summary
    let dailyUsageBuckets: [DailyUsageBucket]?

    struct Summary: Decodable, Sendable {
        let lifetimeTokens: Int64?
        let peakDailyTokens: Int64?
        let longestRunningTurnSec: Int64?
        let currentStreakDays: Int64?
        let longestStreakDays: Int64?
    }

    struct DailyUsageBucket: Decodable, Sendable, Equatable {
        let startDate: String
        let tokens: Int64
    }
}

struct CodexAccountTokenUsageResult: Sendable {
    let response: CodexAccountTokenUsageResponse
    let fetchedAt: Date
}

enum CodexAccountTokenUsageError: LocalizedError, Sendable, Equatable {
    case executableUnavailable
    case launchFailed
    case timedOut
    case unsupported
    case accountUnavailable
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            "Codex CLI was not found. Install Codex or make it available in PATH."
        case .launchFailed:
            "Codex app-server could not be started."
        case .timedOut:
            "Codex account token usage timed out."
        case .unsupported:
            "This Codex CLI version does not support account token usage."
        case .accountUnavailable:
            "Codex account token usage is unavailable. Run Codex once to sign in."
        case let .server(code):
            "Codex account token usage failed with error \(code)."
        case .invalidResponse:
            "Codex account token usage returned an invalid response."
        }
    }
}

actor CodexAccountTokenUsageCache {
    static let shared = CodexAccountTokenUsageCache()

    private var entries: [String: CodexAccountTokenUsageResult] = [:]

    func value(
        accountID: String?,
        maxAge: TimeInterval,
        now: Date = .now) -> CodexAccountTokenUsageResult?
    {
        let key = Self.key(for: accountID)
        guard let entry = self.entries[key],
              now.timeIntervalSince(entry.fetchedAt) >= 0,
              now.timeIntervalSince(entry.fetchedAt) < maxAge
        else { return nil }
        return entry
    }

    func store(
        _ response: CodexAccountTokenUsageResponse,
        accountID: String?,
        fetchedAt: Date)
    {
        self.entries[Self.key(for: accountID)] = .init(
            response: response,
            fetchedAt: fetchedAt)
    }

    func invalidate() {
        self.entries.removeAll()
    }

    private static func key(for accountID: String?) -> String {
        let trimmed = accountID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { return trimmed }
        return "__current_account__"
    }
}

struct CodexExecutableLocator: Sendable {
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

        let commonPaths = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
        ]
        for path in commonPaths {
            let candidate = URL(fileURLWithPath: path)
            if self.isExecutable(candidate) { return candidate }
        }

        for relativePath in [
            ".local/bin/codex",
            ".volta/bin/codex",
            ".asdf/shims/codex",
            ".bun/bin/codex",
            ".local/share/mise/shims/codex",
            ".mise/shims/codex",
        ] {
            let candidate = self.homeDirectory.appending(path: relativePath)
            if self.isExecutable(candidate) { return candidate }
        }

        for candidate in self.versionManagedCandidates() {
            if self.isExecutable(candidate) { return candidate }
        }

        for directory in (self.pathEnvironment ?? "").split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
                .appending(path: "codex")
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
            return versions.sorted { $0.lastPathComponent > $1.lastPathComponent }.map { version in
                if root.lastPathComponent == "node" {
                    version.appending(path: "bin/codex")
                } else {
                    version.appending(path: "installation/bin/codex")
                }
            }
        }
    }

    private func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }
}

struct CodexAccountTokenUsageClient: Sendable {
    private let locator: CodexExecutableLocator
    private let cache: CodexAccountTokenUsageCache
    private let cacheMaxAge: TimeInterval
    private let timeout: TimeInterval

    init(
        executableURL: URL? = nil,
        pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        cache: CodexAccountTokenUsageCache = .shared,
        cacheMaxAge: TimeInterval = 5 * 60,
        timeout: TimeInterval = 15)
    {
        self.locator = .init(
            explicitURL: executableURL,
            pathEnvironment: pathEnvironment,
            homeDirectory: homeDirectory)
        self.cache = cache
        self.cacheMaxAge = cacheMaxAge
        self.timeout = timeout
    }

    func fetch(accountID: String? = nil) async throws -> CodexAccountTokenUsageResult {
        if let cached = await self.cache.value(
            accountID: accountID,
            maxAge: self.cacheMaxAge)
        {
            return cached
        }

        guard let executableURL = self.locator.resolve() else {
            throw CodexAccountTokenUsageError.executableUnavailable
        }

        let runner = CodexAppServerUsageRunner(executableURL: executableURL)
        let response = try await Self.run(runner, timeout: self.timeout)
        let fetchedAt = Date.now
        await self.cache.store(response, accountID: accountID, fetchedAt: fetchedAt)
        return .init(response: response, fetchedAt: fetchedAt)
    }

    func invalidateCache() async {
        await self.cache.invalidate()
    }

    private static func run(
        _ runner: CodexAppServerUsageRunner,
        timeout: TimeInterval) async throws -> CodexAccountTokenUsageResponse
    {
        try await withThrowingTaskGroup(of: CodexAccountTokenUsageResponse.self) { group in
            group.addTask {
                try runner.run()
            }
            group.addTask {
                let nanoseconds = UInt64(max(timeout, 0) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                runner.cancel()
                throw CodexAccountTokenUsageError.timedOut
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw CodexAccountTokenUsageError.invalidResponse
            }
            return first
        }
    }
}

private final class CodexAppServerUsageRunner: @unchecked Sendable {
    private static let initializeRequest = Data(
        #"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"tokeni-bar","version":"0.5.0"},"capabilities":{"experimentalApi":true}}}"#.utf8)
    private static let initializedNotification = Data(#"{"method":"initialized"}"#.utf8)
    private static let usageRequest = Data(
        #"{"id":2,"method":"account/usage/read","params":null}"#.utf8)

    private let executableURL: URL
    private let lock = NSLock()
    private var process: Process?
    private var input: FileHandle?
    private var cancelled = false

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

    func run() throws -> CodexAccountTokenUsageResponse {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.executableURL = self.executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        self.lock.lock()
        guard !self.cancelled else {
            self.lock.unlock()
            throw CodexAccountTokenUsageError.timedOut
        }
        self.process = process
        self.input = inputPipe.fileHandleForWriting
        self.lock.unlock()

        do {
            try process.run()
        } catch {
            self.clearProcess()
            throw CodexAccountTokenUsageError.launchFailed
        }
        defer { self.shutdown(process: process) }
        if self.isCancelled {
            process.terminate()
            throw CodexAccountTokenUsageError.timedOut
        }

        let reader = CodexJSONLineReader(handle: outputPipe.fileHandleForReading)
        try Self.write(Self.initializeRequest, to: inputPipe.fileHandleForWriting)
        let _: CodexEmptyResult = try self.readResponse(id: 1, from: reader)

        try Self.write(Self.initializedNotification, to: inputPipe.fileHandleForWriting)
        try Self.write(Self.usageRequest, to: inputPipe.fileHandleForWriting)
        return try self.readResponse(id: 2, from: reader)
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let input = self.input
        let process = self.process
        self.lock.unlock()

        try? input?.close()
        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func readResponse<Result: Decodable>(
        id: Int,
        from reader: CodexJSONLineReader) throws -> Result
    {
        while let line = try reader.nextLine() {
            guard let envelope = try? JSONDecoder().decode(
                CodexRPCResponse<Result>.self,
                from: line),
                envelope.id == .integer(id)
            else { continue }

            if let error = envelope.error {
                throw Self.map(error: error)
            }
            guard let result = envelope.result else {
                throw CodexAccountTokenUsageError.invalidResponse
            }
            return result
        }
        throw self.isCancelled
            ? CodexAccountTokenUsageError.timedOut
            : CodexAccountTokenUsageError.invalidResponse
    }

    private static func write(_ data: Data, to handle: FileHandle) throws {
        do {
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data([0x0A]))
        } catch {
            throw CodexAccountTokenUsageError.invalidResponse
        }
    }

    private static func map(error: CodexRPCError) -> CodexAccountTokenUsageError {
        if error.code == -32601 { return .unsupported }
        let message = error.message.lowercased()
        if message.contains("login") || message.contains("sign in")
            || message.contains("auth") || message.contains("credential")
        {
            return .accountUnavailable
        }
        return .server(error.code)
    }

    private func shutdown(process: Process) {
        self.lock.lock()
        let input = self.input
        self.input = nil
        self.process = nil
        self.lock.unlock()

        try? input?.close()
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
    }

    private func clearProcess() {
        self.lock.lock()
        self.input = nil
        self.process = nil
        self.lock.unlock()
    }

    private var isCancelled: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.cancelled
    }
}

private final class CodexJSONLineReader {
    private let handle: FileHandle
    private var buffer = Data()
    private let maximumBytes = 8 * 1_024 * 1_024

    init(handle: FileHandle) {
        self.handle = handle
    }

    func nextLine() throws -> Data? {
        while true {
            if let newline = self.buffer.firstIndex(of: 0x0A) {
                let line = self.buffer[..<newline]
                self.buffer.removeSubrange(...newline)
                if line.isEmpty { continue }
                return Data(line)
            }

            let chunk = self.handle.availableData
            if chunk.isEmpty {
                guard !self.buffer.isEmpty else { return nil }
                defer { self.buffer.removeAll() }
                return self.buffer
            }
            self.buffer.append(chunk)
            if self.buffer.count > self.maximumBytes {
                throw CodexAccountTokenUsageError.invalidResponse
            }
        }
    }
}

private struct CodexEmptyResult: Decodable {
    init(from decoder: Decoder) throws {
        _ = try decoder.singleValueContainer()
    }
}

private struct CodexRPCResponse<Result: Decodable>: Decodable {
    let id: CodexRPCRequestID?
    let result: Result?
    let error: CodexRPCError?
}

private enum CodexRPCRequestID: Decodable, Equatable {
    case integer(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }
}

private struct CodexRPCError: Decodable {
    let code: Int
    let message: String
}
