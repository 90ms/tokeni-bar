import Foundation

final class WindowsTaskCompletionSignal: @unchecked Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let pair = AsyncStream<Void>.makeStream()
        self.stream = pair.stream
        self.continuation = pair.continuation
    }

    func finish() {
        self.continuation.finish()
    }

    func wait() async {
        for await _ in self.stream {}
    }
}

enum WindowsBoundedShutdown {
    static let providerDeadline = Duration.seconds(2)

    static func wait(
        for signal: WindowsTaskCompletionSignal,
        timeout: Duration) async -> Bool
    {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await signal.wait()
                return true
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                    return false
                } catch {
                    return false
                }
            }
            let completed = await group.next() ?? false
            group.cancelAll()
            return completed
        }
    }
}
