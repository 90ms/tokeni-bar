import Foundation

#if os(Windows)
import WinSDK
#elseif canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Writes a complete file through a same-directory temporary file and then
/// atomically replaces the destination after every temporary handle is closed.
///
/// swift-foundation's `Data.write(options: .atomic)` can keep a handle involved
/// in its replacement sequence open on Windows, causing sharing violations.
/// Owning the temporary handle and replacement explicitly avoids that failure
/// while preserving the old destination until the new data is durable.
enum DurableFileWriter {
    static func write(
        _ data: Data,
        to fileURL: URL,
        fileManager: FileManager = .default) throws
    {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true)
        let temporaryURL = directoryURL.appending(
            path: ".\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)")

        do {
            try Data().write(to: temporaryURL, options: .withoutOverwriting)
            let handle = try FileHandle(forWritingTo: temporaryURL)
            do {
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }

            try self.replace(
                temporaryURL,
                withDestination: fileURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func replace(
        _ temporaryURL: URL,
        withDestination destinationURL: URL) throws
    {
        #if os(Windows)
        let flags = DWORD(MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)
        for attempt in 0..<4 {
            let succeeded = temporaryURL.path.withCString(
                encodedAs: UTF16.self
            ) { temporaryPath in
                destinationURL.path.withCString(encodedAs: UTF16.self) {
                    destinationPath in
                    MoveFileExW(temporaryPath, destinationPath, flags)
                }
            }
            if succeeded { return }

            let code = GetLastError()
            let canRetry = code == ERROR_SHARING_VIOLATION
                || code == ERROR_LOCK_VIOLATION
            guard canRetry, attempt < 3 else {
                throw DurableFileWriterError.replacementFailed(
                    code: Int64(code))
            }
            Sleep(DWORD(25 * (attempt + 1)))
        }
        #elseif canImport(Darwin) || canImport(Glibc)
        let result = temporaryURL.path.withCString { temporaryPath in
            destinationURL.path.withCString { destinationPath in
                rename(temporaryPath, destinationPath)
            }
        }
        guard result == 0 else {
            throw DurableFileWriterError.replacementFailed(code: Int64(errno))
        }
        #else
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            _ = try FileManager.default.replaceItemAt(
                destinationURL,
                withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(
                at: temporaryURL,
                to: destinationURL)
        }
        #endif
    }
}

private enum DurableFileWriterError: Error {
    case replacementFailed(code: Int64)
}
