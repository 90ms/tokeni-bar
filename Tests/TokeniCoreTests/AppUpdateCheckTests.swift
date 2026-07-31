@testable import TokeniCore
import Foundation
import Testing

struct AppUpdateCheckTests {
    @Test
    func semanticVersionsFollowSemVerPrecedence() throws {
        let orderedValues = [
            "1.0.0-alpha",
            "1.0.0-alpha.1",
            "1.0.0-alpha.beta",
            "1.0.0-beta",
            "1.0.0-beta.2",
            "1.0.0-beta.11",
            "1.0.0-rc.1",
            "1.0.0",
            "1.0.1",
            "1.1.0",
            "2.0.0",
        ]
        let versions = try orderedValues.map { try #require(SemanticVersion($0)) }

        #expect(versions.sorted() == versions)
        #expect(SemanticVersion("v1.2.3+build.5")?.description == "1.2.3+build.5")
        #expect(SemanticVersion("1.2.3+first") == SemanticVersion("1.2.3+second"))
    }

    @Test
    func rejectsAmbiguousOrMalformedVersions() {
        for value in ["1", "1.2", "01.2.3", "1.02.3", "1.2.03", "1.2.3-01", "1.2.3-", " 1.2.3", "1.2.3+"] {
            #expect(SemanticVersion(value) == nil)
        }
    }

    @Test
    func choosesHighestStableReleaseAndComparesCurrentVersion() async throws {
        let directory = self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = self.releaseData([
            self.release(tag: "v0.4.0-beta.1", prerelease: true),
            self.release(tag: "v9.0.0", draft: true),
            self.release(tag: "v0.3.2"),
            self.release(tag: "v0.4.0"),
        ])
        let client = self.client(directory: directory) { request in
            (data, self.response(url: request.url!, status: 200))
        }

        let available = try await client.check(currentVersion: "0.3.1")
        let current = try await client.check(currentVersion: "0.4.0", force: true)

        #expect(available.latestRelease.version == SemanticVersion("0.4.0"))
        #expect(available.isUpdateAvailable)
        #expect(!current.isUpdateAvailable)
        #expect(available.source == .remote)
    }

    @Test
    func throttlesChecksAndReturnsValidatedCache() async throws {
        let directory = self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = RequestCounter()
        let data = self.releaseData([self.release(tag: "v0.4.0")])
        let client = self.client(directory: directory) { request in
            await counter.increment()
            return (data, self.response(url: request.url!, status: 200))
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        _ = try await client.check(currentVersion: "0.3.1", at: now)
        let cached = try await client.check(
            currentVersion: "0.3.1",
            at: now.addingTimeInterval(60))

        #expect(await counter.value == 1)
        #expect(cached.source == .cache)
        #expect(!cached.isStale)
    }

    @Test
    func fallsBackToLatestReleasePageWhenAPIRateLimitIsExhausted() async throws {
        let directory = self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = RequestCounter()
        let latestURL = URL(
            string: "https://github.com/90ms/tokeni-bar/releases/tag/v0.17.2")!
        let client = self.client(directory: directory) { request in
            await counter.increment()
            if request.url == GitHubReleaseUpdateClient.defaultEndpoint {
                return (Data(), self.response(url: request.url!, status: 403))
            }
            #expect(request.url == GitHubReleaseUpdateClient.defaultLatestReleasePageURL)
            #expect(request.httpMethod == "HEAD")
            return (Data(), self.response(url: latestURL, status: 200))
        }

        let result = try await client.check(currentVersion: "0.17.1")

        #expect(await counter.value == 2)
        #expect(result.latestRelease.version == SemanticVersion("0.17.2"))
        #expect(result.latestRelease.pageURL == latestURL)
        #expect(result.source == .remote)
        #expect(!result.isStale)
    }

    @Test
    func rejectsUntrustedEndpointAndRedirectHosts() async throws {
        let directory = self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let untrustedEndpoint = self.client(
            endpoint: URL(string: "https://api.github.com.evil.example/releases")!,
            directory: directory)
        do {
            _ = try await untrustedEndpoint.check(currentVersion: "0.3.1")
            Issue.record("Expected an untrusted host error")
        } catch {
            #expect(error as? AppUpdateCheckError == .untrustedHost)
        }

        let redirected = self.client(directory: directory) { _ in
            let url = URL(string: "https://evil.example/releases")!
            return (self.releaseData([]), self.response(url: url, status: 200))
        }
        do {
            _ = try await redirected.check(currentVersion: "0.3.1")
            Issue.record("Expected an untrusted redirect host error")
        } catch {
            #expect(error as? AppUpdateCheckError == .untrustedHost)
        }
    }

    @Test
    func validatesHTTPStatusAndResponseSize() async throws {
        let firstDirectory = self.temporaryDirectory()
        let secondDirectory = self.temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: firstDirectory)
            try? FileManager.default.removeItem(at: secondDirectory)
        }
        let failed = self.client(directory: firstDirectory) { request in
            (Data(), self.response(url: request.url!, status: 503))
        }
        do {
            _ = try await failed.check(currentVersion: "0.3.1")
            Issue.record("Expected an HTTP status error")
        } catch {
            #expect(error as? AppUpdateCheckError == .invalidHTTPStatus(503))
        }

        let oversized = Data(repeating: 0, count: GitHubReleaseUpdateClient.maximumResponseBytes + 1)
        let tooLarge = self.client(directory: secondDirectory) { request in
            (oversized, self.response(url: request.url!, status: 200))
        }
        do {
            _ = try await tooLarge.check(currentVersion: "0.3.1")
            Issue.record("Expected a response size error")
        } catch {
            #expect(error as? AppUpdateCheckError == .responseTooLarge)
        }
    }

    @Test
    func excludesDraftPrereleaseAndPrereleaseTags() async throws {
        let directory = self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = self.releaseData([
            self.release(tag: "v1.0.0", draft: true),
            self.release(tag: "v0.9.0", prerelease: true),
            self.release(tag: "v0.8.0-rc.1"),
        ])
        let client = self.client(directory: directory) { request in
            (data, self.response(url: request.url!, status: 200))
        }

        do {
            _ = try await client.check(currentVersion: "0.3.1")
            Issue.record("Expected no stable release")
        } catch {
            #expect(error as? AppUpdateCheckError == .noStableRelease)
        }
    }

    private func client(
        endpoint: URL = GitHubReleaseUpdateClient.defaultEndpoint,
        directory: URL,
        load: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            (Data("[]".utf8), HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil)!)
        }) -> GitHubReleaseUpdateClient
    {
        GitHubReleaseUpdateClient(
            endpoint: endpoint,
            cacheURL: directory.appending(path: "latest-release.json"),
            load: load)
    }

    private func release(
        tag: String,
        draft: Bool = false,
        prerelease: Bool = false) -> [String: Any]
    {
        [
            "tag_name": tag,
            "name": tag,
            "html_url": "https://github.com/90ms/tokeni-bar/releases/tag/\(tag)",
            "draft": draft,
            "prerelease": prerelease,
            "published_at": "2026-07-17T00:00:00Z",
        ]
    }

    private func releaseData(_ releases: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: releases, options: [.sortedKeys])
    }

    private func response(url: URL, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }
}

private actor RequestCounter {
    private(set) var value = 0

    func increment() {
        self.value += 1
    }
}
