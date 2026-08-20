#if canImport(Darwin)
import Darwin
#endif
import Foundation

public struct CommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var succeeded: Bool {
        self.exitCode == 0
    }
}

public struct ProcessCommand: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let timeout: TimeInterval?
    public let environment: [String: String]?

    public init(
        executable: String,
        arguments: [String],
        timeout: TimeInterval? = nil,
        environment: [String: String]? = nil)
    {
        self.executable = executable
        self.arguments = arguments
        self.timeout = timeout
        self.environment = environment
    }
}

public enum ProcessRunnerError: Error, Sendable, Equatable {
    case launchFailed(String)
    case timedOut(TimeInterval)
}

public protocol ProcessRunning: Sendable {
    func run(_ command: ProcessCommand) async throws -> CommandResult
}

enum CLIProcessEnvironment {
    static func make(
        executableURL: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String]
    {
        var environment = base
        environment["HOME"] = homeDirectory.path
        #if os(Windows)
        environment["USERPROFILE"] = homeDirectory.path
        #endif

        var searchPaths = [
            executableURL.deletingLastPathComponent().path,
            homeDirectory.appending(path: ".local/bin").path,
            homeDirectory.appending(path: ".npm-global/bin").path,
            homeDirectory.appending(path: ".bun/bin").path,
            homeDirectory.appending(path: ".volta/bin").path,
            homeDirectory.appending(path: ".asdf/shims").path,
            homeDirectory.appending(path: ".local/share/mise/shims").path,
            homeDirectory.appending(path: ".mise/shims").path,
            homeDirectory.appending(path: ".nvm/current/bin").path,
            homeDirectory.appending(path: ".fnm/current/bin").path,
            homeDirectory.appending(path: ".local/share/fnm/current/bin").path,
        ]

        #if os(Windows)
        searchPaths.append(contentsOf: [
            homeDirectory.appending(path: "AppData/Roaming/npm").path,
            homeDirectory.appending(path: "AppData/Local/bin").path,
        ])
        if let appData = base["APPDATA"], !appData.isEmpty {
            searchPaths.append(URL(fileURLWithPath: appData, isDirectory: true)
                .appending(path: "npm").path)
        }
        if let localAppData = base["LOCALAPPDATA"], !localAppData.isEmpty {
            searchPaths.append(URL(fileURLWithPath: localAppData, isDirectory: true)
                .appending(path: "Programs/nodejs").path)
        }
        #else
        searchPaths.append(contentsOf: [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ])
        #endif

        searchPaths.append(contentsOf: self.versionManagedRuntimePaths(
            homeDirectory: homeDirectory))
        searchPaths.append(contentsOf: PlatformEnvironment.pathEntries(
            PlatformEnvironment.pathValue(from: base)))

        var seen = Set<String>()
        searchPaths = searchPaths.filter { path in
            !path.isEmpty && seen.insert(path).inserted
        }
        environment["PATH"] = PlatformEnvironment.joinedPath(searchPaths)
        return environment
    }

    static func make(for command: ProcessCommand) -> [String: String] {
        let base = command.environment ?? ProcessInfo.processInfo.environment
        let homeDirectory = (base["HOME"] ?? base["USERPROFILE"])
            .flatMap { path in
                guard !path.isEmpty else { return nil }
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            ?? FileManager.default.homeDirectoryForCurrentUser
        return self.make(
            executableURL: URL(fileURLWithPath: command.executable),
            homeDirectory: homeDirectory,
            base: base)
    }

    private static func versionManagedRuntimePaths(
        homeDirectory: URL) -> [String]
    {
        #if os(Windows)
        return []
        #else
        let roots: [(URL, String)] = [
            (
                homeDirectory.appending(
                    path: ".nvm/versions/node",
                    directoryHint: .isDirectory),
                "bin"),
            (
                homeDirectory.appending(
                    path: ".local/share/fnm/node-versions",
                    directoryHint: .isDirectory),
                "installation/bin"),
            (
                homeDirectory.appending(
                    path: ".fnm/node-versions",
                    directoryHint: .isDirectory),
                "installation/bin"),
        ]

        return roots.flatMap { root, runtimePath in
            let versions = (try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])) ?? []
            return versions.sorted {
                $0.lastPathComponent.compare(
                    $1.lastPathComponent,
                    options: .numeric) == .orderedDescending
            }.map {
                $0.appending(path: runtimePath).path
            }
        }
        #endif
    }
}

public final class SystemProcessRunner: ProcessRunning {
    private let terminationGracePeriod: TimeInterval

    public init(terminationGracePeriod: TimeInterval = 0.5) {
        self.terminationGracePeriod = terminationGracePeriod
    }

    public func run(_ command: ProcessCommand) async throws -> CommandResult {
        let controller = ProcessController(
            terminationGracePeriod: self.terminationGracePeriod)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<CommandResult, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: command.executable)
                    process.arguments = command.arguments
                    process.environment = CLIProcessEnvironment.make(for: command)
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    do {
                        try process.run()
                        controller.didLaunch(process)
                    } catch {
                        continuation.resume(throwing: ProcessRunnerError.launchFailed(
                            error.localizedDescription))
                        return
                    }

                    if let timeout = command.timeout {
                        controller.scheduleTimeout(after: timeout)
                    }

                    let output = LockedData()
                    let error = LockedData()
                    let readers = DispatchGroup()
                    readers.enter()
                    DispatchQueue.global(qos: .utility).async {
                        output.value = BoundedPipeReader.read(
                            outputPipe.fileHandleForReading)
                        readers.leave()
                    }
                    readers.enter()
                    DispatchQueue.global(qos: .utility).async {
                        error.value = BoundedPipeReader.read(
                            errorPipe.fileHandleForReading)
                        readers.leave()
                    }
                    readers.wait()
                    process.waitUntilExit()

                    switch controller.finish() {
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    case let .timedOut(timeout):
                        continuation.resume(throwing: ProcessRunnerError.timedOut(timeout))
                    case nil:
                        continuation.resume(returning: CommandResult(
                            exitCode: process.terminationStatus,
                            standardOutput: String(data: output.value, encoding: .utf8) ?? "",
                            standardError: String(data: error.value, encoding: .utf8) ?? ""))
                    }
                }
            }
        } onCancel: {
            controller.cancel()
        }
    }
}

private enum BoundedPipeReader {
    private static let maximumCapturedBytes = 1 * 1_024 * 1_024

    static func read(_ handle: FileHandle) -> Data {
        var result = Data()
        while true {
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return result }
            let remaining = self.maximumCapturedBytes - result.count
            if remaining > 0 {
                result.append(chunk.prefix(remaining))
            }
        }
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var value: Data {
        get {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.storage
        }
        set {
            self.lock.lock()
            self.storage = newValue
            self.lock.unlock()
        }
    }
}

private final class ProcessController: @unchecked Sendable {
    enum StopReason {
        case cancelled
        case timedOut(TimeInterval)
    }

    private let lock = NSLock()
    private let terminationGracePeriod: TimeInterval
    private var process: Process?
    private var stopReason: StopReason?
    private var finished = false

    init(terminationGracePeriod: TimeInterval) {
        self.terminationGracePeriod = terminationGracePeriod
    }

    func didLaunch(_ process: Process) {
        self.lock.lock()
        self.process = process
        let shouldStop = self.stopReason != nil
        self.lock.unlock()
        if shouldStop {
            self.stop(process)
        }
    }

    func scheduleTimeout(after timeout: TimeInterval) {
        guard timeout >= 0 else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            [weak self] in
            self?.requestStop(.timedOut(timeout))
        }
    }

    func cancel() {
        self.requestStop(.cancelled)
    }

    func finish() -> StopReason? {
        self.lock.lock()
        self.finished = true
        let reason = self.stopReason
        self.process = nil
        self.lock.unlock()
        return reason
    }

    private func requestStop(_ reason: StopReason) {
        self.lock.lock()
        guard !self.finished, self.stopReason == nil else {
            self.lock.unlock()
            return
        }
        if let process = self.process, !process.isRunning {
            self.lock.unlock()
            return
        }
        self.stopReason = reason
        let runningProcess = self.process
        self.lock.unlock()
        if let runningProcess {
            self.stop(runningProcess)
        }
    }

    private func stop(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + self.terminationGracePeriod)
        {
            if process.isRunning {
                #if canImport(Darwin)
                let identifier = process.processIdentifier
                Darwin.kill(identifier, SIGKILL)
                #else
                process.terminate()
                #endif
            }
        }
    }
}
