import Foundation

public struct CopilotUsageProvider: UsageProviding, UsageActivityProviding {
    public let descriptor = ProviderDescriptor(
        id: .copilot,
        displayName: "GitHub Copilot",
        shortName: "Copilot",
        systemImage: "chevron.left.forwardslash.chevron.right",
        capabilities: .init(supportsTokenUsage: true))

    private let homeDirectory: URL
    private let calendar: Calendar
    private let configuredOTelPath: URL?

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current,
        otelPath: URL? = nil)
    {
        self.homeDirectory = homeDirectory
        self.calendar = calendar
        self.configuredOTelPath = otelPath ?? ProcessInfo.processInfo.environment[
            "COPILOT_OTEL_FILE_EXPORTER_PATH"
        ].map { URL(fileURLWithPath: $0) }
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let otelFiles = self.otelFiles(modifiedAfter: startOfDay)
        let otelUsage = CopilotOTelParser.aggregate(files: otelFiles, since: startOfDay)
        let fallback = otelUsage == nil
            ? CopilotSessionStateParser.aggregate(
                files: self.sessionStateFiles(modifiedAfter: startOfDay),
                since: startOfDay)
            : nil
        guard let usage = otelUsage ?? fallback else {
            return .init(
                descriptor: self.descriptor,
                availability: .unavailable,
                source: .localSessionLog,
                detail: "Enable Copilot OTel file export to show today's token usage")
        }

        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: otelUsage == nil ? .localSessionLog : .localProtocol,
            tokenUsage: usage.tokenUsage,
            growthUsageObservation: .daily(
                providerID: .copilot,
                dateKey: GrowthLocalDate.key(for: usage.observedAt, calendar: self.calendar),
                totalTokens: usage.tokenUsage.totalTokens,
                observedAt: usage.observedAt),
            detail: otelUsage == nil
                ? "Today from completed local Copilot CLI sessions"
                : "Today from Copilot OpenTelemetry",
            updatedAt: usage.observedAt)
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        let configuredFileDate = self.configuredOTelPath.flatMap { file -> Date? in
            guard let values = try? file.resourceValues(
                forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                values.isRegularFile == true,
                let modifiedAt = values.contentModificationDate,
                modifiedAt >= cutoff
            else { return nil }
            return modifiedAt
        }
        let roots = self.otelRoots() + [self.sessionStateDirectory]
        return (roots.compactMap { root in
            LocalFiles.latestModificationDate(
                below: root,
                modifiedAfter: cutoff,
                matching: { $0.pathExtension == "jsonl" })
        } + [configuredFileDate].compactMap { $0 }).max()
    }

    private var sessionStateDirectory: URL {
        self.homeDirectory.appending(path: ".copilot/session-state", directoryHint: .isDirectory)
    }

    private func otelRoots() -> [URL] {
        var roots = [self.homeDirectory.appending(path: ".copilot/otel", directoryHint: .isDirectory)]
        if let configuredOTelPath,
           (try? configuredOTelPath.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        {
            roots.insert(configuredOTelPath, at: 0)
        }
        return Array(Set(roots.map(\.standardizedFileURL)))
    }

    private func otelFiles(modifiedAfter startDate: Date) -> [URL] {
        var files: [URL] = []
        if let configuredOTelPath,
           (try? configuredOTelPath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
           configuredOTelPath.pathExtension == "jsonl"
        {
            files.append(configuredOTelPath)
        }
        for root in self.otelRoots() {
            files.append(contentsOf: LocalFiles.newestFiles(
                below: root,
                extension: "jsonl",
                modifiedAfter: startDate,
                limit: 128))
        }
        var seen: Set<URL> = []
        return files.filter { seen.insert($0.standardizedFileURL).inserted }
    }

    private func sessionStateFiles(modifiedAfter startDate: Date) -> [URL] {
        LocalFiles.newestFiles(
            below: self.sessionStateDirectory,
            named: "events.jsonl",
            modifiedAfter: startDate,
            limit: 128)
    }
}

struct CopilotTodayUsage {
    let tokenUsage: TokenUsage
    let observedAt: Date
}

enum CopilotOTelParser {
    static func aggregate(files: [URL], since startDate: Date) -> CopilotTodayUsage? {
        guard LocalFiles.totalSize(of: files) != nil else { return nil }
        var seenSpans: Set<String> = []
        var input: Int64 = 0
        var cached: Int64 = 0
        var cacheCreation: Int64 = 0
        var output: Int64 = 0
        var reasoning: Int64 = 0
        var total: Int64 = 0
        var modelIDs: Set<String> = []
        var observedAt = startDate
        var count = 0

        for file in files {
            guard LocalFiles.forEachLine(in: file, { line in
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      object["type"] as? String == "span",
                      let attributes = object["attributes"] as? [String: Any]
                else { return }
                let operation = attributes["gen_ai.operation.name"] as? String
                let name = object["name"] as? String
                guard operation == "chat" || name?.hasPrefix("chat ") == true,
                      let timestamp = self.timestamp(object["endTime"])
                        ?? self.timestamp(object["startTime"]),
                      timestamp >= startDate
                else { return }

                let traceID = (object["traceId"] as? String) ?? "unknown-trace"
                let spanID = (object["spanId"] as? String) ?? "unknown-span"
                guard seenSpans.insert("\(traceID):\(spanID)").inserted else { return }

                let fullInput = self.token(attributes["gen_ai.usage.input_tokens"])
                let cacheRead = self.token(attributes["gen_ai.usage.cache_read.input_tokens"])
                let cacheWrite = max(
                    self.token(attributes["gen_ai.usage.cache_creation.input_tokens"]),
                    self.token(attributes["gen_ai.usage.cache_write.input_tokens"]))
                let uncachedInput = max(fullInput - cacheRead - cacheWrite, 0)
                let responseOutput = self.token(attributes["gen_ai.usage.output_tokens"])
                let reasoningOutput = self.token(
                    attributes["gen_ai.usage.reasoning.output_tokens"])
                let normalizedTotal = saturatedAdd(
                    fullInput,
                    saturatedAdd(responseOutput, reasoningOutput))
                guard normalizedTotal > 0 else { return }

                input = saturatedAdd(input, uncachedInput)
                cached = saturatedAdd(cached, cacheRead)
                cacheCreation = saturatedAdd(cacheCreation, cacheWrite)
                output = saturatedAdd(output, responseOutput)
                reasoning = saturatedAdd(reasoning, reasoningOutput)
                total = saturatedAdd(total, normalizedTotal)
                observedAt = max(observedAt, timestamp)
                count += 1
                if let model = (attributes["gen_ai.response.model"]
                    ?? attributes["gen_ai.request.model"]) as? String,
                    !model.isEmpty
                {
                    modelIDs.insert(model)
                }
            }) else { continue }
        }

        guard count > 0 else { return nil }
        return CopilotTodayUsage(
            tokenUsage: TokenUsage(
                label: "Today",
                modelID: modelIDs.count == 1 ? modelIDs.first : nil,
                inputTokens: input,
                cacheCreationInputTokens: cacheCreation,
                cachedInputTokens: cached,
                outputTokens: output,
                reasoningTokens: reasoning,
                totalTokens: total),
            observedAt: observedAt)
    }

    private static func token(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber { return max(number.int64Value, 0) }
        if let string = value as? String, let number = Int64(string) { return max(number, 0) }
        return 0
    }

    private static func timestamp(_ value: Any?) -> Date? {
        if let pair = value as? [Any], let first = pair.first {
            let seconds = (first as? NSNumber)?.doubleValue
                ?? (first as? String).flatMap(Double.init)
            let nanos = pair.count > 1
                ? ((pair[1] as? NSNumber)?.doubleValue
                    ?? (pair[1] as? String).flatMap(Double.init) ?? 0)
                : 0
            return seconds.map { Date(timeIntervalSince1970: $0 + nanos / 1_000_000_000) }
        }
        if let string = value as? String {
            return TimestampParser.parse(string)
                ?? Double(string).flatMap { self.timestamp(number: $0) }
        }
        if let number = value as? NSNumber {
            return self.timestamp(number: number.doubleValue)
        }
        return nil
    }

    private static func timestamp(number: Double) -> Date? {
        guard number.isFinite, number > 0 else { return nil }
        if number > 1e15 { return Date(timeIntervalSince1970: number / 1e9) }
        if number > 1e12 { return Date(timeIntervalSince1970: number / 1e3) }
        return Date(timeIntervalSince1970: number)
    }
}

enum CopilotSessionStateParser {
    static func aggregate(files: [URL], since startDate: Date) -> CopilotTodayUsage? {
        guard LocalFiles.totalSize(of: files) != nil else { return nil }
        var input: Int64 = 0
        var cached: Int64 = 0
        var cacheCreation: Int64 = 0
        var output: Int64 = 0
        var reasoning: Int64 = 0
        var total: Int64 = 0
        var modelIDs: Set<String> = []
        var observedAt = startDate
        var count = 0

        for file in files {
            guard let session = self.lastCompletedSession(in: file),
                  let startedAt = session.startedAt,
                  startedAt >= startDate,
                  session.observedAt >= startDate,
                  session.modelUsage.values.contains(where: {
                      $0.inputTokens > 0
                          || $0.outputTokens > 0
                          || $0.cacheReadTokens > 0
                          || $0.cacheWriteTokens > 0
                          || $0.reasoningTokens > 0
                  })
            else { continue }
            count += 1
            observedAt = max(observedAt, session.observedAt)
            for (model, usage) in session.modelUsage {
                let fullInput = max(usage.inputTokens, 0)
                let cacheRead = max(usage.cacheReadTokens, 0)
                let cacheWrite = max(usage.cacheWriteTokens, 0)
                let uncachedInput = max(fullInput - cacheRead - cacheWrite, 0)
                let responseOutput = max(usage.outputTokens, 0)
                let reasoningOutput = max(usage.reasoningTokens, 0)
                input = saturatedAdd(input, uncachedInput)
                cached = saturatedAdd(cached, cacheRead)
                cacheCreation = saturatedAdd(cacheCreation, cacheWrite)
                output = saturatedAdd(output, responseOutput)
                reasoning = saturatedAdd(reasoning, reasoningOutput)
                total = saturatedAdd(
                    total,
                    saturatedAdd(fullInput, saturatedAdd(responseOutput, reasoningOutput)))
                if !model.isEmpty { modelIDs.insert(model) }
            }
        }

        guard count > 0 else { return nil }
        return CopilotTodayUsage(
            tokenUsage: TokenUsage(
                label: "Today",
                modelID: modelIDs.count == 1 ? modelIDs.first : nil,
                inputTokens: input,
                cacheCreationInputTokens: cacheCreation,
                cachedInputTokens: cached,
                outputTokens: output,
                reasoningTokens: reasoning,
                totalTokens: total),
            observedAt: observedAt)
    }

    private static func lastCompletedSession(in file: URL) -> Session? {
        var sessionStartedAt: Date?
        var lastTimestamp: Date?
        var lastShutdown: Session?
        guard LocalFiles.forEachLine(in: file, { line in
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
            else { return }
            let timestamp = (object["timestamp"] as? String).flatMap {
                TimestampParser.parse($0)
            }
            if object["type"] as? String == "session.start", sessionStartedAt == nil {
                sessionStartedAt = timestamp
            }
            if let timestamp { lastTimestamp = timestamp }
            guard object["type"] as? String == "session.shutdown",
                  let data = object["data"] as? [String: Any],
                  let modelMetrics = data["modelMetrics"] as? [String: Any]
            else { return }

            let start = sessionStartedAt
                ?? self.timestamp(data["sessionStartTime"])
            var modelUsage: [String: ModelUsage] = [:]
            for (model, rawMetrics) in modelMetrics {
                guard let metrics = rawMetrics as? [String: Any],
                      let usage = metrics["usage"] as? [String: Any]
                else { continue }
                modelUsage[model] = ModelUsage(
                    inputTokens: self.token(usage["inputTokens"]),
                    outputTokens: self.token(usage["outputTokens"]),
                    cacheReadTokens: self.token(usage["cacheReadTokens"]),
                    cacheWriteTokens: self.token(usage["cacheWriteTokens"]),
                    reasoningTokens: self.token(usage["reasoningTokens"]))
            }
            lastShutdown = Session(
                startedAt: start,
                observedAt: timestamp ?? lastTimestamp ?? .distantPast,
                modelUsage: modelUsage)
        }) else { return nil }
        return lastShutdown
    }

    private static func token(_ value: Any?) -> Int64 {
        (value as? NSNumber).map { max($0.int64Value, 0) }
            ?? (value as? String).flatMap(Int64.init).map { max($0, 0) }
            ?? 0
    }

    private static func timestamp(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber else { return nil }
        let raw = number.doubleValue
        return Date(timeIntervalSince1970: raw > 1e12 ? raw / 1e3 : raw)
    }

    private struct Session {
        let startedAt: Date?
        let observedAt: Date
        let modelUsage: [String: ModelUsage]
    }

    private struct ModelUsage {
        let inputTokens: Int64
        let outputTokens: Int64
        let cacheReadTokens: Int64
        let cacheWriteTokens: Int64
        let reasoningTokens: Int64
    }
}

private func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let result = lhs.addingReportingOverflow(max(rhs, 0))
    return result.overflow ? .max : result.partialValue
}
