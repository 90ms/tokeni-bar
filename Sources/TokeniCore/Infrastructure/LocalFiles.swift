import Foundation

enum LocalFiles {
    static let maximumJSONBytes = 16 * 1_024 * 1_024
    static let maximumJSONLinesBytes = 64 * 1_024 * 1_024

    static func latestModificationDate(
        below root: URL,
        modifiedAfter cutoff: Date,
        matching predicate: (URL) -> Bool) -> Date?
    {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return nil }

        var latest: Date?
        for case let url as URL in enumerator where predicate(url) {
            guard let values = try? url.resourceValues(
                forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                values.isRegularFile == true,
                let modifiedAt = values.contentModificationDate,
                modifiedAt >= cutoff
            else { continue }
            if latest.map({ modifiedAt > $0 }) != false {
                latest = modifiedAt
            }
        }
        return latest
    }

    static func newestFiles(
        below root: URL,
        named fileName: String? = nil,
        extension fileExtension: String? = nil,
        modifiedAfter: Date? = nil,
        limit: Int) -> [URL]
    {
        guard limit > 0 else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }

        var candidates: [(url: URL, modifiedAt: Date)] = []
        for case let url as URL in enumerator {
            guard fileName == nil || url.lastPathComponent == fileName else { continue }
            guard fileExtension == nil || url.pathExtension == fileExtension else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate
            else { continue }
            guard modifiedAfter == nil || modifiedAt >= modifiedAfter! else { continue }
            candidates.append((url, modifiedAt))
            if candidates.count >= max(limit * 2, 256) {
                candidates = Array(
                    candidates.sorted { $0.modifiedAt > $1.modifiedAt }
                        .prefix(limit))
            }
        }

        return candidates
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map(\.url)
    }

    static func data(
        in file: URL,
        maximumBytes: Int = LocalFiles.maximumJSONBytes) -> Data?
    {
        guard maximumBytes >= 0,
              let values = try? file.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let fileSize = values.fileSize,
              fileSize >= 0,
              fileSize <= maximumBytes
        else { return nil }
        return try? Data(contentsOf: file, options: .mappedIfSafe)
    }

    static func lines(
        in file: URL,
        maximumBytes: Int = LocalFiles.maximumJSONLinesBytes) -> [Data]?
    {
        guard let data = self.data(in: file, maximumBytes: maximumBytes) else {
            return nil
        }
        return data.split(whereSeparator: { $0 == 0x0A }).map { Data($0) }
    }
}

enum TimestampParser {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = try? Date(value, strategy: .iso8601) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
