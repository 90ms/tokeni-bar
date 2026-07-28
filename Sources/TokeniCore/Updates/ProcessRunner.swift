import Darwin
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

    public init(
        executable: String,
        arguments: [String],
        timeout: TimeInterval? = nil)
    {
        self.executable = executable
        self.arguments = arguments
        self.timeout = timeout
    }
}

public enum ProcessRunnerError: Error, Sendable, Equatable {
    case launchFailed(String)
    case timedOut(TimeInterval)
}

public protocol ProcessRunning: Sendable {
    func run(_ command: ProcessCommand) async throws -> CommandResult
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
        let identifier = process.processIdentifier
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + self.terminationGracePeriod)
        {
            if process.isRunning {
                Darwin.kill(identifier, SIGKILL)
            }
        }
    }
}
